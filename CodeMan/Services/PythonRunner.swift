//
//  PythonRunner.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/8/26.
//

import Foundation

@MainActor
final class PythonRunner {
  static let shared = PythonRunner()
  
  private var isInitialized = false
  
  private init() { }
  
  func initialize() {
    guard !isInitialized else { return }
    
    let bundlePath = Bundle.main.bundlePath
    let libPath = bundlePath + "/lib"
    let pythonHome = libPath + "/python3.14"
    let libDynload = bundlePath + "/lib-dynload"
    
    setenv("PYTHONHOME", libPath, 1)
    setenv("PYTHONPATH", "\(pythonHome):\(libDynload)", 1)
    
    Py_Initialize()
    isInitialized = true
  }
  
  func getVersion() -> String {
    guard isInitialized else { return "Python not initialized" }
    
    guard let versionPtr = Py_GetVersion() else {
      return "Unknown version"
    }
    return String(cString: versionPtr)
  }
  
  struct ExecutionResult {
    let output: String
    let isError: Bool
  }
  
  private let maxCodeLength = 50_000
  private let maxOutputLength = 100_000
  private let executionTimeoutSeconds = 5
  
  func run(code: String) -> ExecutionResult {
    guard isInitialized else {
      return ExecutionResult(output: "Python not initialized", isError: true)
    }
    
    guard code.count <= maxCodeLength else {
      return ExecutionResult(
        output: "Code exceeds maximum length of \(maxCodeLength) characters",
        isError: true
      )
    }
    
    guard let setupGlobals = PyDict_New() else {
      return ExecutionResult(output: "Could not create setup namespace", isError: true)
    }
    defer { Py_DecRef(setupGlobals) }
    
    guard let userGlobals = PyDict_New() else {
      return ExecutionResult(output: "Could not create user namespace", isError: true)
    }
    defer { Py_DecRef(userGlobals) }
    
    PyDict_SetItemString(setupGlobals, "_user_globals", userGlobals)
    
    guard let codeObj = PyUnicode_FromString(code) else {
      return ExecutionResult(output: "Could not create code string", isError: true)
    }
    PyDict_SetItemString(setupGlobals, "_user_code", codeObj)
    Py_DecRef(codeObj)
    
    if let builtins = PyEval_GetBuiltins() {
      PyDict_SetItemString(setupGlobals, "__builtins__", builtins)
    }
    
    PyErr_Clear()
    
    let setupCode = """
    import ast
    import sys
    import linecache
    import time as _time
    from io import StringIO
    
    _MAX_ALLOCATION_SIZE = 1_000_000
    _MAX_LITERAL_NUMBER = 10_000_000
    
    _timeout_seconds = \(executionTimeoutSeconds)
    
    _user_filename = "<user_code>"
    
    class AllocationChecker(ast.NodeVisitor):
        def __init__(self):
            self.errors = []
        
        def _try_eval_number(self, node):
            # Try to statically evaluate a node to a number.
            # Returns None if the value can't be determined at parse time.
            
            # Direct constant
            if isinstance(node, ast.Constant) and isinstance(node.value, (int, float)):
                return node.value
            
            # Unary minus: -5
            if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
                val = self._try_eval_number(node.operand)
                if val is not None:
                    return -val
            
            # Binary operations: 10**9, 2*5, etc.
            if isinstance(node, ast.BinOp):
                left = self._try_eval_number(node.left)
                right = self._try_eval_number(node.right)
                if left is not None and right is not None:
                    try:
                        if isinstance(node.op, ast.Pow):
                            # Limit exponent to prevent hanging on huge numbers
                            # Also check if base is greater than max and power is greater than 1
                            if right > 20 or (left >= _MAX_LITERAL_NUMBER and right > 1):
                                return float('inf')  # Signal "too big"
                            return left ** right
                        elif isinstance(node.op, ast.Mult):
                            return left * right
                        elif isinstance(node.op, ast.Add):
                            return left + right
                        elif isinstance(node.op, ast.Sub):
                            return left - right
                        elif isinstance(node.op, ast.Div):
                            return left / right if right != 0 else None
                        elif isinstance(node.op, ast.FloorDiv):
                            return left // right if right != 0 else None
                        elif isinstance(node.op, ast.Mod):
                            return left % right if right != 0 else None
                    except:
                        return None
            
            # Function calls: int(...), float(...), math.pow(...), pow(...)
            if isinstance(node, ast.Call):
                func_name = self._get_func_name(node)
                args = [self._try_eval_number(arg) for arg in node.args]
                
                # int(x) or float(x)
                if func_name == 'int' and len(args) == 1 and args[0] is not None:
                    try:
                        return int(args[0])
                    except:
                        return None
                
                if func_name == 'float' and len(args) == 1 and args[0] is not None:
                    try:
                        return float(args[0])
                    except:
                        return None
                
                # pow(x, y) builtin
                if func_name == 'pow' and len(args) >= 2:
                    if args[0] is not None and args[1] is not None:
                        try:
                            if args[1] > 20 or (args[0] >= _MAX_LITERAL_NUMBER and args[1] > 1):
                                return float('inf')
                            return pow(args[0], args[1])
                        except:
                            return None
                
                # math.pow(x, y)
                if func_name == 'math.pow' and len(args) == 2:
                    if args[0] is not None and args[1] is not None:
                        try:
                            if args[1] > 20 or (args[0] >= _MAX_LITERAL_NUMBER and args[1] > 1):
                                return float('inf')
                            import math
                            return math.pow(args[0], args[1])
                        except:
                            return None
                
                # abs(x)
                if func_name == 'abs' and len(args) == 1 and args[0] is not None:
                    return abs(args[0])
                
                # len() on a literal list/tuple/string
                if func_name == 'len' and len(node.args) == 1:
                    arg = node.args[0]
                    if isinstance(arg, ast.List):
                        return len(arg.elts)
                    elif isinstance(arg, ast.Tuple):
                        return len(arg.elts)
                    elif isinstance(arg, ast.Constant) and isinstance(arg.value, (str, bytes)):
                        return len(arg.value)
            
            return None
        
        def _get_func_name(self, node):
            # Extract function name from a Call node.
            if isinstance(node.func, ast.Name):
                return node.func.id
            elif isinstance(node.func, ast.Attribute):
                # Handle math.pow, etc.
                if isinstance(node.func.value, ast.Name):
                    return f"{node.func.value.id}.{node.func.attr}"
            return None
        
        def _is_sequence_literal(self, node):
            # Check if node is a list, tuple, or string literal.
            if isinstance(node, (ast.List, ast.Tuple)):
                return True
            if isinstance(node, ast.Constant) and isinstance(node.value, (str, bytes)):
                return True
            return False
        
        def _get_sequence_length(self, node):
            # Get length of a sequence literal.
            if isinstance(node, ast.List):
                return len(node.elts)
            elif isinstance(node, ast.Tuple):
                return len(node.elts)
            elif isinstance(node, ast.Constant):
                if isinstance(node.value, (str, bytes)):
                    return len(node.value)
            return None
            
        def visit_BinOp(self, node):
            # Check for sequence * number patterns
            if isinstance(node.op, ast.Mult):
                left_seq_len = self._get_sequence_length(node.left)
                right_seq_len = self._get_sequence_length(node.right)
                left_num = self._try_eval_number(node.left)
                right_num = self._try_eval_number(node.right)
                
                # [x, y] * big_number
                if left_seq_len is not None and right_num is not None:
                    result_size = left_seq_len * right_num
                    if result_size > _MAX_ALLOCATION_SIZE:
                        self.errors.append(
                            f"Line {node.lineno}: sequence multiplication would create ~{int(result_size):,} elements (max {_MAX_ALLOCATION_SIZE:,})"
                        )
                
                # big_number * [x, y]
                if right_seq_len is not None and left_num is not None:
                    result_size = right_seq_len * left_num
                    if result_size > _MAX_ALLOCATION_SIZE:
                        self.errors.append(
                            f"Line {node.lineno}: sequence multiplication would create ~{int(result_size):,} elements (max {_MAX_ALLOCATION_SIZE:,})"
                        )
                
            # Check for dangerously large exponentiation
            if isinstance(node.op, ast.Pow):
                result = self._try_eval_number(node)
                if result is not None and result > _MAX_LITERAL_NUMBER:
                    self.errors.append(
                        f"Line {node.lineno}: exponentiation result exceeds maximum safe value ({_MAX_LITERAL_NUMBER:,})"
                    )
                
            self.generic_visit(node)
            
        def visit_Call(self, node):
            func_name = self._get_func_name(node)
            
            # Check range(big_number)
            if func_name == 'range':
                if len(node.args) >= 1:
                    # range(stop) -> check stop
                    # range(start, stop) -> check stop - start
                    # range(start, stop, step) -> check (stop - start) / step
                    if len(node.args) == 1:
                        stop = self._try_eval_number(node.args[0])
                        if stop is not None and stop > _MAX_ALLOCATION_SIZE:
                            self.errors.append(
                                f"Line {node.lineno}: range() would create ~{int(stop):,} elements (max {_MAX_ALLOCATION_SIZE:,})"
                            )
                    elif len(node.args) >= 2:
                        start = self._try_eval_number(node.args[0])
                        stop = self._try_eval_number(node.args[1])
                        step = 1
                        if len(node.args) >= 3:
                            step_val = self._try_eval_number(node.args[2])
                            if step_val is not None and step_val != 0:
                                step = step_val
                        if start is not None and stop is not None:
                            try:
                                size = max(0, (stop - start + step - 1) // step) if step > 0 else max(0, (start - stop - step - 1) // (-step))
                                if size > _MAX_ALLOCATION_SIZE:
                                    self.errors.append(
                                        f"Line {node.lineno}: range() would create ~{int(size):,} elements (max {_MAX_ALLOCATION_SIZE:,})"
                                    )
                            except:
                                pass
            
            # Check bytearray(big_number)
            if func_name == 'bytearray' and len(node.args) == 1:
                size = self._try_eval_number(node.args[0])
                if size is not None and size > _MAX_ALLOCATION_SIZE:
                    self.errors.append(
                        f"Line {node.lineno}: bytearray() would allocate ~{int(size):,} bytes (max {_MAX_ALLOCATION_SIZE:,})"
                    )
            
            # Check math.factorial(big_number)
            if func_name == 'math.factorial' and len(node.args) == 1:
                val = self._try_eval_number(node.args[0])
                if val is not None and val > 10000:
                    self.errors.append(
                        f"Line {node.lineno}: math.factorial({int(val)}) is too large (max 10000)"
                    )
            
            # Check math.comb and math.perm
            if func_name in ('math.comb', 'math.perm') and len(node.args) >= 2:
                n = self._try_eval_number(node.args[0])
                if n is not None and n > 10000:
                    self.errors.append(
                        f"Line {node.lineno}: {func_name}({int(n)}, ...) is too large (max n=10000)"
                    )
            
            # Check sorted/list/tuple/set wrapping range(big)
            if func_name in ('sorted', 'list', 'tuple', 'set', 'frozenset'):
                if len(node.args) >= 1 and isinstance(node.args[0], ast.Call):
                    inner_func = self._get_func_name(node.args[0])
                    if inner_func == 'range' and node.args[0].args:
                        # Get the stop value (last arg for 1-2 args, second arg for 3 args)
                        range_args = node.args[0].args
                        if len(range_args) == 1:
                            size = self._try_eval_number(range_args[0])
                        else:
                            start = self._try_eval_number(range_args[0]) or 0
                            stop = self._try_eval_number(range_args[1])
                            size = (stop - start) if stop is not None else None
                        if size is not None and size > _MAX_ALLOCATION_SIZE:
                            self.errors.append(
                                f"Line {node.lineno}: {func_name}(range(...)) would create ~{int(size):,} elements (max {_MAX_ALLOCATION_SIZE:,})"
                            )
                
            self.generic_visit(node)
        
        def visit_ListComp(self, node):
            # Check for [x for x in range(big)]
            for generator in node.generators:
                if isinstance(generator.iter, ast.Call):
                    func_name = self._get_func_name(generator.iter)
                    if func_name == 'range' and generator.iter.args:
                        size = self._try_eval_number(generator.iter.args[-1] if len(generator.iter.args) <= 2 else generator.iter.args[1])
                        if size is not None and size > _MAX_ALLOCATION_SIZE:
                            self.errors.append(
                                f"Line {node.lineno}: list comprehension over range({int(size):,}) would create too many elements"
                            )
            self.generic_visit(node)
        
        def visit_SetComp(self, node):
            # Similar check for set comprehensions
            for generator in node.generators:
                if isinstance(generator.iter, ast.Call):
                    func_name = self._get_func_name(generator.iter)
                    if func_name == 'range' and generator.iter.args:
                        size = self._try_eval_number(generator.iter.args[-1] if len(generator.iter.args) <= 2 else generator.iter.args[1])
                        if size is not None and size > _MAX_ALLOCATION_SIZE:
                            self.errors.append(
                                f"Line {node.lineno}: set comprehension over range({int(size):,}) would create too many elements"
                            )
            self.generic_visit(node)
        
        def visit_DictComp(self, node):
            # Similar check for dict comprehensions
            for generator in node.generators:
                if isinstance(generator.iter, ast.Call):
                    func_name = self._get_func_name(generator.iter)
                    if func_name == 'range' and generator.iter.args:
                        size = self._try_eval_number(generator.iter.args[-1] if len(generator.iter.args) <= 2 else generator.iter.args[1])
                        if size is not None and size > _MAX_ALLOCATION_SIZE:
                            self.errors.append(
                                f"Line {node.lineno}: dict comprehension over range({int(size):,}) would create too many entries"
                            )
            self.generic_visit(node)
        
        def _estimate_string_size(self, node):
            # Estimate size of a string expression
            if isinstance(node, ast.Constant) and isinstance(node.value, (str, bytes)):
                return len(node.value)
            if isinstance(node, ast.BinOp) and isinstance(node.op, ast.Mult):
                left_size = self._estimate_string_size(node.left)
                right_size = self._estimate_string_size(node.right)
                left_num = self._try_eval_number(node.left)
                right_num = self._try_eval_number(node.right)
                if left_size is not None and right_num is not None:
                    return left_size * right_num
                if right_size is not None and left_num is not None:
                    return right_size * left_num
            return None
        
        def visit_Compare(self, node):
            # Check for "x" in large_string patterns (CPU-intensive substring search)
            for i, (op, comparator) in enumerate(zip(node.ops, node.comparators)):
                if isinstance(op, (ast.In, ast.NotIn)):
                    # Check the right side (what we're searching in)
                    str_size = self._estimate_string_size(comparator)
                    if str_size is not None and str_size > _MAX_ALLOCATION_SIZE:
                        self.errors.append(
                            f"Line {node.lineno}: substring search in string of ~{int(str_size):,} chars would be too slow"
                        )
            self.generic_visit(node)
    
    def check_code_safety(code: str) -> list[str]:
        try:
            tree = ast.parse(code)
            checker = AllocationChecker()
            checker.visit(tree)
            return checker.errors
        except SyntaxError:
            return []  # Let the actual execution report syntax errors
    
    # Check code memory safety
    _safety_errors = check_code_safety(_user_code)
    if _safety_errors:
        raise MemoryError("Code rejected:\\n" + "\\n".join(_safety_errors))
    
    _real_range = range
    class _safe_range:
        # range() replacement that checks size before returning.
        def __new__(cls, *args):
            r = _real_range(*args)
            if len(r) > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"range() would create {len(r):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
            return r
    
    # Safe list wrapper
    _real_list = list
    class _safe_list(_real_list):
        # list replacement that checks size on creation and multiplication.
        def __new__(cls, iterable=()):
            result = _real_list.__new__(cls)
            return result
        
        def __init__(self, iterable=()):
            super().__init__(iterable)
            if len(self) > _MAX_ALLOCATION_SIZE:
                self.clear()
                raise MemoryError(f"list() would create {len(self):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
        
        def __mul__(self, n):
            if not isinstance(n, int):
                return NotImplemented
            result_size = len(self) * max(0, n)
            if result_size > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"list * {n} would create {result_size:,} elements (max {_MAX_ALLOCATION_SIZE:,})")
            return _safe_list(_real_list.__mul__(self, n))
        
        def __rmul__(self, n):
            return self.__mul__(n)
        
        def __imul__(self, n):
            if not isinstance(n, int):
                return NotImplemented
            result_size = len(self) * max(0, n)
            if result_size > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"list *= {n} would create {result_size:,} elements (max {_MAX_ALLOCATION_SIZE:,})")
            return _safe_list(_real_list.__mul__(self, n))
        
        def extend(self, iterable):
            new_items = _real_list(iterable)
            if len(self) + len(new_items) > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"list.extend() would create {len(self) + len(new_items):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
            super().extend(new_items)
        
        def append(self, item):
            if len(self) + 1 > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"list.append() would exceed {_MAX_ALLOCATION_SIZE:,} elements")
            super().append(item)
    
    # Safe tuple wrapper
    _real_tuple = tuple
    class _safe_tuple(_real_tuple):
        # tuple replacement that checks size on creation.
        def __new__(cls, iterable=()):
            result = _real_tuple.__new__(cls, iterable)
            if len(result) > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"tuple() would create {len(result):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
            return result
        
        def __mul__(self, n):
            if not isinstance(n, int):
                return NotImplemented
            result_size = len(self) * max(0, n)
            if result_size > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"tuple * {n} would create {result_size:,} elements (max {_MAX_ALLOCATION_SIZE:,})")
            return _safe_tuple(_real_tuple.__mul__(self, n))
        
        def __rmul__(self, n):
            return self.__mul__(n)
    
    # Safe str wrapper
    _real_str = str
    class _safe_str(_real_str):
        # str replacement that checks size on creation and multiplication.
        def __new__(cls, obj=''):
            result = _real_str.__new__(cls, obj)
            if len(result) > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"str() would create {len(result):,} characters (max {_MAX_ALLOCATION_SIZE:,})")
            return result
        
        def __mul__(self, n):
            if not isinstance(n, int):
                return NotImplemented
            result_size = len(self) * max(0, n)
            if result_size > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"str * {n} would create {result_size:,} characters (max {_MAX_ALLOCATION_SIZE:,})")
            return _safe_str(_real_str.__mul__(self, n))
        
        def __rmul__(self, n):
            return self.__mul__(n)
        
        def join(self, iterable):
            # Convert to list to check size (also limits infinite iterators)
            items = _real_list(iterable)
            if len(items) > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"str.join() with {len(items):,} items (max {_MAX_ALLOCATION_SIZE:,})")
            # Estimate result size
            total_len = len(self) * (len(items) - 1) if items else 0
            for item in items:
                total_len += len(item)
                if total_len > _MAX_ALLOCATION_SIZE:
                    raise MemoryError(f"str.join() would create ~{total_len:,}+ characters (max {_MAX_ALLOCATION_SIZE:,})")
            result = _real_str.join(self, items)
            return _safe_str(result) if len(result) <= _MAX_ALLOCATION_SIZE else result
    
    # Safe bytes wrapper
    _real_bytes = bytes
    class _safe_bytes(_real_bytes):
        # bytes replacement that checks size on creation and multiplication.
        def __new__(cls, source=b'', *args, **kwargs):
            result = _real_bytes.__new__(cls, source, *args, **kwargs)
            if len(result) > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"bytes() would create {len(result):,} bytes (max {_MAX_ALLOCATION_SIZE:,})")
            return result
        
        def __mul__(self, n):
            if not isinstance(n, int):
                return NotImplemented
            result_size = len(self) * max(0, n)
            if result_size > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"bytes * {n} would create {result_size:,} bytes (max {_MAX_ALLOCATION_SIZE:,})")
            return _safe_bytes(_real_bytes.__mul__(self, n))
        
        def __rmul__(self, n):
            return self.__mul__(n)
    
    # Safe bytearray wrapper
    _real_bytearray = bytearray
    class _safe_bytearray(_real_bytearray):
        # bytearray replacement that checks size on creation and multiplication.
        def __new__(cls, source=b'', *args, **kwargs):
            if isinstance(source, int):
                if source > _MAX_ALLOCATION_SIZE:
                    raise MemoryError(f"bytearray({source}) would create {source:,} bytes (max {_MAX_ALLOCATION_SIZE:,})")
            result = _real_bytearray.__new__(cls, source, *args, **kwargs)
            return result
        
        def __init__(self, source=b'', *args, **kwargs):
            super().__init__(source, *args, **kwargs)
            if len(self) > _MAX_ALLOCATION_SIZE:
                self.clear()
                raise MemoryError(f"bytearray() would create too many bytes (max {_MAX_ALLOCATION_SIZE:,})")
        
        def __mul__(self, n):
            if not isinstance(n, int):
                return NotImplemented
            result_size = len(self) * max(0, n)
            if result_size > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"bytearray * {n} would create {result_size:,} bytes (max {_MAX_ALLOCATION_SIZE:,})")
            return _safe_bytearray(_real_bytearray.__mul__(self, n))
        
        def __rmul__(self, n):
            return self.__mul__(n)
    
    # Safe set wrapper  
    _real_set = set
    class _safe_set(_real_set):
        # set replacement that checks size on creation.
        def __new__(cls, iterable=()):
            result = _real_set.__new__(cls)
            return result
        
        def __init__(self, iterable=()):
            super().__init__(iterable)
            if len(self) > _MAX_ALLOCATION_SIZE:
                self.clear()
                raise MemoryError(f"set() would create {len(self):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
        
        def add(self, item):
            if len(self) + 1 > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"set.add() would exceed {_MAX_ALLOCATION_SIZE:,} elements")
            super().add(item)
        
        def update(self, *others):
            # Estimate worst case size
            for other in others:
                other_list = _real_list(other)
                if len(self) + len(other_list) > _MAX_ALLOCATION_SIZE:
                    raise MemoryError(f"set.update() could exceed {_MAX_ALLOCATION_SIZE:,} elements")
            super().update(*others)
    
    # Safe dict wrapper
    _real_dict = dict
    class _safe_dict(_real_dict):
        # dict replacement that checks size on creation.
        def __init__(self, *args, **kwargs):
            super().__init__(*args, **kwargs)
            if len(self) > _MAX_ALLOCATION_SIZE:
                self.clear()
                raise MemoryError(f"dict() would create {len(self):,} entries (max {_MAX_ALLOCATION_SIZE:,})")
        
        def __setitem__(self, key, value):
            if key not in self and len(self) + 1 > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"dict assignment would exceed {_MAX_ALLOCATION_SIZE:,} entries")
            super().__setitem__(key, value)
        
        def update(self, *args, **kwargs):
            temp = _real_dict(*args, **kwargs)
            new_keys = sum(1 for k in temp if k not in self)
            if len(self) + new_keys > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"dict.update() would exceed {_MAX_ALLOCATION_SIZE:,} entries")
            super().update(temp)
    
    # Safe frozenset wrapper
    _real_frozenset = frozenset
    class _safe_frozenset(_real_frozenset):
        # frozenset replacement that checks size on creation.
        def __new__(cls, iterable=()):
            result = _real_frozenset.__new__(cls, iterable)
            if len(result) > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"frozenset() would create {len(result):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
            return result
    
    # Blocked builtins - these could be used to escape the sandbox
    def _blocked_eval(*args, **kwargs):
        raise NameError("'eval' is not allowed in this environment")
    
    def _blocked_exec(*args, **kwargs):
        raise NameError("'exec' is not allowed in this environment")
    
    def _blocked_compile(*args, **kwargs):
        raise NameError("'compile' is not allowed in this environment")
    
    def _blocked_open(*args, **kwargs):
        raise NameError("'open' is not allowed in this environment")
    
    def _blocked_input(*args, **kwargs):
        raise NameError("'input' is not allowed in this environment")
    
    def _blocked_breakpoint(*args, **kwargs):
        raise NameError("'breakpoint' is not allowed in this environment")
    
    # Safe attribute access - prevent introspection attacks
    _dangerous_attrs = {
        # Class/type introspection
        '__class__', '__bases__', '__subclasses__', '__mro__',
        # Code/globals access
        '__globals__', '__code__', '__builtins__', '__import__',
        # Module internals
        '__loader__', '__spec__', '__dict__',
        # Pickling (can execute arbitrary code)
        '__reduce__', '__reduce_ex__', '__getstate__', '__setstate__',
        # Function/method internals
        '__closure__', '__func__', '__self__', '__wrapped__',
        # Frame access
        '__traceback__', 'tb_frame', 'tb_next', 'f_locals', 'f_globals', 'f_code', 'f_back',
        # Descriptor protocol (can bypass restrictions)
        '__get__', '__set__', '__delete__',
    }
    
    _real_getattr = getattr
    def _safe_getattr(obj, name, *default):
        if isinstance(name, str) and name in _dangerous_attrs:
            raise AttributeError(f"Access to '{name}' is not allowed")
        return _real_getattr(obj, name, *default) if default else _real_getattr(obj, name)
    
    _real_setattr = setattr
    def _safe_setattr(obj, name, value):
        if isinstance(name, str) and name in _dangerous_attrs:
            raise AttributeError(f"Setting '{name}' is not allowed")
        _real_setattr(obj, name, value)
    
    def _blocked_delattr(*args, **kwargs):
        raise NameError("'delattr' is not allowed in this environment")
    
    def _blocked_vars(*args, **kwargs):
        raise NameError("'vars' is not allowed in this environment")
    
    # Safe type() - only allow inspection, not dynamic class creation
    _real_type = type
    def _safe_type(*args):
        if len(args) == 1:
            return _real_type(args[0])  # type(x) for inspection is fine
        raise TypeError("Dynamic class creation with type() is not allowed")
    
    # Safe sorted wrapper - checks input size before sorting
    _real_sorted = sorted
    def _safe_sorted(iterable, **kwargs):
        if hasattr(iterable, '__len__'):
            if len(iterable) > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"sorted() input has {len(iterable):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
        lst = _real_list(iterable)
        if len(lst) > _MAX_ALLOCATION_SIZE:
            raise MemoryError(f"sorted() would process {len(lst):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
        return _safe_list(_real_sorted(lst, **kwargs))
    
    # Helper to create a limited iterator that raises after too many iterations
    def _limited_iter(iterable, limit=_MAX_ALLOCATION_SIZE):
        count = 0
        for item in iterable:
            count += 1
            if count > limit:
                raise MemoryError(f"Iterator exceeded {limit:,} elements")
            yield item
    
    # Safe sum wrapper - limits iteration count for generators
    _real_sum = sum
    def _safe_sum(iterable, start=0):
        if hasattr(iterable, '__len__'):
            if len(iterable) > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"sum() input has {len(iterable):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
            return _real_sum(iterable, start)
        return _real_sum(_limited_iter(iterable), start)
    
    # Safe min/max wrappers - limit iteration count for generators
    _real_min = min
    def _safe_min(*args, **kwargs):
        if len(args) == 1:
            iterable = args[0]
            if hasattr(iterable, '__len__'):
                if len(iterable) > _MAX_ALLOCATION_SIZE:
                    raise MemoryError(f"min() input has {len(iterable):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
                return _real_min(iterable, **kwargs)
            return _real_min(_limited_iter(iterable), **kwargs)
        return _real_min(*args, **kwargs)
    
    _real_max = max
    def _safe_max(*args, **kwargs):
        if len(args) == 1:
            iterable = args[0]
            if hasattr(iterable, '__len__'):
                if len(iterable) > _MAX_ALLOCATION_SIZE:
                    raise MemoryError(f"max() input has {len(iterable):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
                return _real_max(iterable, **kwargs)
            return _real_max(_limited_iter(iterable), **kwargs)
        return _real_max(*args, **kwargs)
    
    # Safe any/all wrappers - limit iteration count
    _real_any = any
    def _safe_any(iterable):
        if hasattr(iterable, '__len__'):
            return _real_any(iterable)
        return _real_any(_limited_iter(iterable))
    
    _real_all = all
    def _safe_all(iterable):
        if hasattr(iterable, '__len__'):
            return _real_all(iterable)
        return _real_all(_limited_iter(iterable))
    
    # Store source in linecache so tracebacks can display it
    linecache.cache[_user_filename] = (
        len(_user_code),
        None,
        _user_code.splitlines(keepends=True),
        _user_filename
    )
    
    _safe_builtins = {
        # Math & Numbers
        'abs': abs,
        'round': round,
        'pow': pow,
        'divmod': divmod,
        'min': _safe_min,
        'max': _safe_max,
        'sum': _safe_sum,
        'int': int,
        'float': float,
        'complex': complex,
        'bool': bool,
        'bin': bin,
        'oct': oct,
        'hex': hex,
        
        # Strings & Characters
        'str': _safe_str,
        'repr': repr,
        'format': format,
        'chr': chr,
        'ord': ord,
        'ascii': ascii,
        
        # Collections
        'list': _safe_list,
        'tuple': _safe_tuple,
        'dict': _safe_dict,
        'set': _safe_set,
        'frozenset': _safe_frozenset,
        'len': len,
        'sorted': _safe_sorted,
        'reversed': reversed,
        'slice': slice,
        'range': _safe_range,
    
        # Bytes
        'bytes': _safe_bytes,
        'bytearray': _safe_bytearray,
    
        # Classes & Type Checking
        '__build_class__': __build_class__,
        'isinstance': isinstance,
        'issubclass': issubclass,
        'type': _safe_type,
        'callable': callable,
        'staticmethod': staticmethod,
        'classmethod': classmethod,
        'property': property,
        
        # Attribute access (restricted)
        'getattr': _safe_getattr,
        'setattr': _safe_setattr,
        'hasattr': hasattr,
        'delattr': _blocked_delattr,
        'vars': _blocked_vars,
        
        # Iteration
        'iter': iter,
        'next': next,
        'enumerate': enumerate,
        'zip': zip,
        'map': map,
        'filter': filter,
        'any': _safe_any,
        'all': _safe_all,
        
        # I/O
        'print': print,
        
        # Blocked builtins (explicitly blocked for security)
        'eval': _blocked_eval,
        'exec': _blocked_exec,
        'compile': _blocked_compile,
        'open': _blocked_open,
        'input': _blocked_input,
        'breakpoint': _blocked_breakpoint,
        
        # Constants
        'True': True,
        'False': False,
        'None': None,
        
        # Exceptions
        'Exception': Exception,
        'BaseException': BaseException,
        'ValueError': ValueError,
        'TypeError': TypeError,
        'IndexError': IndexError,
        'KeyError': KeyError,
        'AttributeError': AttributeError,
        'ZeroDivisionError': ZeroDivisionError,
        'RuntimeError': RuntimeError,
        'StopIteration': StopIteration,
        'OverflowError': OverflowError,
        'MemoryError': MemoryError,
        'RecursionError': RecursionError,
        'ArithmeticError': ArithmeticError,
        'LookupError': LookupError,
        'AssertionError': AssertionError,
        'NotImplementedError': NotImplementedError,
    }
    
    # Allowed modules whitelist
    _allowed_modules = {
        # Math & Science
        'math', 'cmath', 'decimal', 'fractions', 'random', 'statistics',
        
        # Data Structures
        'collections', 'heapq', 'bisect', 'array', 'itertools', 'functools',
        
        # String & Text
        'string', 're', 'textwrap',
        
        # Type Hints
        'typing', 'types',
        
        # Date & Time
        'datetime', 'calendar',
        
        # Data Formats
        'json', 'csv',
        
        # Other Safe Modules
        'copy', 'pprint', 'enum', 'dataclasses',
    }
    
    _real_import = __import__
    
    def _safe_import(name, globals=None, locals=None, fromlist=(), level=0):
        top_level = name.split('.')[0]
        if top_level not in _allowed_modules:
            raise ImportError(f"Module '{name}' is not allowed. Allowed modules: {', '.join(sorted(_allowed_modules))}")
        return _real_import(name, globals, locals, fromlist, level)
    
    _safe_builtins['__import__'] = _safe_import
    
    # Configure user namespace with restricted builtins
    _user_globals['__builtins__'] = _safe_builtins
    _user_globals['__name__'] = '__main__'
    
    # Set recursion stack limit
    sys.setrecursionlimit(200) 
    
    # Compile user code
    _compiled_code = compile(_user_code, _user_filename, 'exec')
    """
    
    guard let setupCodeObj = Py_CompileString(setupCode, "<setup>", Py_file_input) else {
      PyErr_Clear()
      return ExecutionResult(output: "Could not compile setup code", isError: true)
    }
    defer { Py_DecRef(setupCodeObj) }
    
    let setupResult = PyEval_EvalCode(setupCodeObj, setupGlobals, setupGlobals)
    if setupResult != nil {
      Py_DecRef(setupResult)
    } else if PyErr_Occurred() != nil {
      var pType: UnsafeMutablePointer<PyObject>?
      var pValue: UnsafeMutablePointer<PyObject>?
      var pTraceback: UnsafeMutablePointer<PyObject>?
      PyErr_Fetch(&pType, &pValue, &pTraceback)
      
      var errorMessage = "Setup failed"
      if let pValue = pValue, let strObj = PyObject_Str(pValue) {
        var size: Int = 0
        if let strPtr = PyUnicode_AsUTF8AndSize(strObj, &size) {
          errorMessage = String(cString: strPtr)
        }
        Py_DecRef(strObj)
      }
      
      if let t = pType { Py_DecRef(t) }
      if let v = pValue { Py_DecRef(v) }
      if let tb = pTraceback { Py_DecRef(tb) }
      
      return ExecutionResult(output: "Internal error: \(errorMessage)", isError: true)
    }
    
    let executeCode = """
    class _TimeoutError(Exception):
        pass
    
    _start_time = _time.time()
    
    def _timeout_trace(frame, event, arg):
        if _time.time() - _start_time > _timeout_seconds:
            raise _TimeoutError(f"Execution exceeded {_timeout_seconds} second time limit")
        return _timeout_trace
    
    _stdout_capture = StringIO()
    _stderr_capture = StringIO()
    _old_stdout = sys.stdout
    _old_stderr = sys.stderr
    sys.stdout = _stdout_capture
    sys.stderr = _stderr_capture
    
    _exec_error = None
    _captured_stdout = ""
    _captured_stderr = ""
    
    try:
        sys.settrace(_timeout_trace)
        exec(_compiled_code, _user_globals)
    except _TimeoutError as e:
        _exec_error = str(e)
    except Exception as e:
        import traceback
        _exec_error = ''.join(traceback.format_exception(type(e), e, e.__traceback__))
    finally:
        sys.settrace(None)
        sys.stdout = _old_stdout
        sys.stderr = _old_stderr
        _captured_stdout = _stdout_capture.getvalue()
        _captured_stderr = _stderr_capture.getvalue()
    """
    
    guard let executeCodeObj = Py_CompileString(executeCode, "<execute>", Py_file_input) else {
      PyErr_Clear()
      return ExecutionResult(output: "Could not compile execute code", isError: true)
    }
    defer { Py_DecRef(executeCodeObj) }
    
    let execResult = PyEval_EvalCode(executeCodeObj, setupGlobals, setupGlobals)
    if execResult != nil {
      Py_DecRef(execResult)
    } else if PyErr_Occurred() != nil {
      var pType: UnsafeMutablePointer<PyObject>?
      var pValue: UnsafeMutablePointer<PyObject>?
      var pTraceback: UnsafeMutablePointer<PyObject>?
      PyErr_Fetch(&pType, &pValue, &pTraceback)
      
      var errorMessage = "Execution failed"
      if let pValue = pValue, let strObj = PyObject_Str(pValue) {
        var size: Int = 0
        if let strPtr = PyUnicode_AsUTF8AndSize(strObj, &size) {
          errorMessage = String(cString: strPtr)
        }
        Py_DecRef(strObj)
      }
      
      if let t = pType { Py_DecRef(t) }
      if let v = pValue { Py_DecRef(v) }
      if let tb = pTraceback { Py_DecRef(tb) }
      
      return ExecutionResult(output: "Internal error: \(errorMessage)", isError: true)
    }
    
    var stdoutOutput = ""
    var stderrOutput = ""
    var execError = ""
    
    if let outputObj = PyDict_GetItemString(setupGlobals, "_captured_stdout") {
      var size: Int = 0
      if let outputPtr = PyUnicode_AsUTF8AndSize(outputObj, &size) {
        stdoutOutput = String(cString: outputPtr).trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    
    if let errorObj = PyDict_GetItemString(setupGlobals, "_captured_stderr") {
      var size: Int = 0
      if let errorPtr = PyUnicode_AsUTF8AndSize(errorObj, &size) {
        stderrOutput = String(cString: errorPtr).trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    
    if let execErrorObj = PyDict_GetItemString(setupGlobals, "_exec_error") {
      var size: Int = 0
      if let errorPtr = PyUnicode_AsUTF8AndSize(execErrorObj, &size), size > 0 {
        execError = String(cString: errorPtr).trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    
    if !execError.isEmpty {
      return ExecutionResult(output: execError, isError: true)
    }
    
    if !stderrOutput.isEmpty {
      return ExecutionResult(output: stderrOutput, isError: true)
    }
    
    if stdoutOutput.isEmpty {
      return ExecutionResult(
        output: "Code ran without errors but produced no output.\n\nTip: Add print() statements to see results. For example:\n• print(result)\n• print(f\"Answer: {value}\")",
        isError: false
      )
    }
    
    if stdoutOutput.count > maxOutputLength {
      let truncated = String(stdoutOutput.prefix(maxOutputLength))
      return ExecutionResult(
        output: truncated + "\n\n... (output truncated at \(maxOutputLength) characters)",
        isError: false
      )
    }
    
    return ExecutionResult(output: stdoutOutput, isError: false)
  }
  
  deinit {
    if isInitialized {
      Py_Finalize()
    }
  }
}
