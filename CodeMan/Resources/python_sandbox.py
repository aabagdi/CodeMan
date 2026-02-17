# Python Sandbox Setup
# This module sets up a restricted execution environment for user code.
# It provides memory safety checks, blocked dangerous operations, and module whitelisting.

import ast
import sys
import linecache
import time as _time
from io import StringIO

# Configuration constants
_MAX_ALLOCATION_SIZE = 1_000_000  # Maximum elements in collections
_MAX_LITERAL_NUMBER = 10_000_000  # Maximum value for literal numbers in expressions
_MAX_RESULT_BITS = 1_000_000      # ~300k decimal digits, reasonable for most algorithms
_user_filename = "<user_code>"    # Filename used in tracebacks

# =============================================================================
# AST-based Static Analysis
# =============================================================================

class AllocationChecker(ast.NodeVisitor):
    """Walks the AST to detect potentially dangerous allocations before execution."""
    
    def __init__(self):
        self.errors = []
    
    def _try_eval_number(self, node):
        """Try to statically evaluate a node to a number.
        Returns None if the value can't be determined at parse time."""
        
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
                        # Estimate bit-length to prevent hanging on huge numbers
                        if right > 0 and left != 0 and abs(left) != 1:
                            import math
                            base_bits = int(math.log2(abs(left))) + 1 if abs(left) >= 1 else 1
                            estimated_bits = int(right * base_bits)
                            if estimated_bits > _MAX_RESULT_BITS:
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
                        base, exp = args[0], args[1]
                        if exp > 0 and base != 0 and abs(base) != 1:
                            import math
                            base_bits = int(math.log2(abs(base))) + 1 if abs(base) >= 1 else 1
                            if int(exp * base_bits) > 1_000_000:
                                return float('inf')
                        return pow(base, exp)
                    except:
                        return None
            
            # math.pow(x, y)
            if func_name == 'math.pow' and len(args) == 2:
                if args[0] is not None and args[1] is not None:
                    try:
                        base, exp = args[0], args[1]
                        if exp > 0 and base != 0 and abs(base) != 1:
                            import math
                            base_bits = int(math.log2(abs(base))) + 1 if abs(base) >= 1 else 1
                            if int(exp * base_bits) > 1_000_000:
                                return float('inf')
                        return math.pow(base, exp)
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
        """Extract function name from a Call node."""
        if isinstance(node.func, ast.Name):
            return node.func.id
        elif isinstance(node.func, ast.Attribute):
            # Handle math.pow, etc.
            if isinstance(node.func.value, ast.Name):
                return f"{node.func.value.id}.{node.func.attr}"
        return None
    
    def _is_sequence_literal(self, node):
        """Check if node is a list, tuple, or string literal."""
        if isinstance(node, (ast.List, ast.Tuple)):
            return True
        if isinstance(node, ast.Constant) and isinstance(node.value, (str, bytes)):
            return True
        return False
    
    def _get_sequence_length(self, node):
        """Get length of a sequence literal."""
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
        """Estimate size of a string expression."""
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
    """Parse and check code for potential memory/CPU issues."""
    try:
        tree = ast.parse(code)
        checker = AllocationChecker()
        checker.visit(tree)
        return checker.errors
    except SyntaxError:
        return []  # Let the actual execution report syntax errors


# =============================================================================
# Safe Builtin Wrappers
# =============================================================================

_real_range = range
class _safe_range:
    """range() replacement that checks size before returning."""
    def __new__(cls, *args):
        r = _real_range(*args)
        if len(r) > _MAX_ALLOCATION_SIZE:
            raise MemoryError(f"range() would create {len(r):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
        return r


_real_list = list
class _safe_list(_real_list):
    """list replacement that checks size on creation and multiplication."""
    def __new__(cls, iterable=()):
        result = _real_list.__new__(cls)
        return result
    
    def __init__(self, iterable=()):
        # For iterables without __len__, consume incrementally with limit check
        if not hasattr(iterable, '__len__'):
            count = 0
            for item in iterable:
                count += 1
                if count > _MAX_ALLOCATION_SIZE:
                    self.clear()
                    raise MemoryError(f"list() exceeded {_MAX_ALLOCATION_SIZE:,} elements from iterator")
                super().append(item)
            return
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


_real_tuple = tuple
class _safe_tuple(_real_tuple):
    """tuple replacement that checks size on creation."""
    def __new__(cls, iterable=()):
        # For iterables without __len__, consume incrementally with limit check
        if not hasattr(iterable, '__len__'):
            items = _real_list()
            for item in iterable:
                if len(items) >= _MAX_ALLOCATION_SIZE:
                    raise MemoryError(f"tuple() exceeded {_MAX_ALLOCATION_SIZE:,} elements from iterator")
                items.append(item)
            return _real_tuple.__new__(cls, items)
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


_real_str = str
class _safe_str(_real_str):
    """str replacement that checks size on creation and multiplication."""
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
        # Final check on actual result (estimate could be slightly off)
        if len(result) > _MAX_ALLOCATION_SIZE:
            raise MemoryError(f"str.join() created {len(result):,} characters (max {_MAX_ALLOCATION_SIZE:,})")
        return _safe_str(result)


_real_bytes = bytes
class _safe_bytes(_real_bytes):
    """bytes replacement that checks size on creation and multiplication."""
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


_real_bytearray = bytearray
class _safe_bytearray(_real_bytearray):
    """bytearray replacement that checks size on creation and multiplication."""
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


_real_set = set
class _safe_set(_real_set):
    """set replacement that checks size on creation."""
    def __new__(cls, iterable=()):
        result = _real_set.__new__(cls)
        return result
    
    def __init__(self, iterable=()):
        # For iterables without __len__, consume incrementally with limit check
        if not hasattr(iterable, '__len__'):
            count = 0
            for item in iterable:
                count += 1
                if count > _MAX_ALLOCATION_SIZE:
                    self.clear()
                    raise MemoryError(f"set() exceeded {_MAX_ALLOCATION_SIZE:,} elements from iterator")
                super().add(item)
            return
        super().__init__(iterable)
        if len(self) > _MAX_ALLOCATION_SIZE:
            self.clear()
            raise MemoryError(f"set() would create {len(self):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
    
    def add(self, item):
        if len(self) + 1 > _MAX_ALLOCATION_SIZE:
            raise MemoryError(f"set.add() would exceed {_MAX_ALLOCATION_SIZE:,} elements")
        super().add(item)
    
    def update(self, *others):
        # Process each iterable incrementally, checking actual set size
        for other in others:
            for item in other:
                # Only count if item is actually new
                if item not in self:
                    if len(self) + 1 > _MAX_ALLOCATION_SIZE:
                        raise MemoryError(f"set.update() would exceed {_MAX_ALLOCATION_SIZE:,} elements")
                super().add(item)


_real_dict = dict
class _safe_dict(_real_dict):
    """dict replacement that checks size on creation."""
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


_real_frozenset = frozenset
class _safe_frozenset(_real_frozenset):
    """frozenset replacement that checks size on creation."""
    def __new__(cls, iterable=()):
        # For iterables without __len__, consume incrementally with limit check
        if not hasattr(iterable, '__len__'):
            items = _real_list()
            for item in iterable:
                if len(items) >= _MAX_ALLOCATION_SIZE:
                    raise MemoryError(f"frozenset() exceeded {_MAX_ALLOCATION_SIZE:,} elements from iterator")
                items.append(item)
            return _real_frozenset.__new__(cls, items)
        result = _real_frozenset.__new__(cls, iterable)
        if len(result) > _MAX_ALLOCATION_SIZE:
            raise MemoryError(f"frozenset() would create {len(result):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
        return result


# =============================================================================
# Blocked Builtins
# =============================================================================

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

def _blocked_delattr(*args, **kwargs):
    raise NameError("'delattr' is not allowed in this environment")

def _blocked_vars(*args, **kwargs):
    raise NameError("'vars' is not allowed in this environment")

def _blocked_memoryview(*args, **kwargs):
    raise NameError("'memoryview' is not allowed in this environment")

def _blocked_globals(*args, **kwargs):
    raise NameError("'globals' is not allowed in this environment")

def _blocked_locals(*args, **kwargs):
    raise NameError("'locals' is not allowed in this environment")


# =============================================================================
# Safe Attribute Access
# =============================================================================

_dangerous_attrs = {
    # Class/type introspection
    '__class__', '__bases__', '__subclasses__', '__mro__', '__base__',
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
    # Memory view (can manipulate raw memory)
    'cast', 'toreadonly',
    # Additional introspection
    'gi_frame', 'gi_code', 'cr_frame', 'cr_code', 'ag_frame', 'ag_code',
    # Metaclass hooks (can run code during class creation/GC)
    '__init_subclass__', '__set_name__', '__del__',
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


# =============================================================================
# AST Transformer to Intercept Attribute Access
# =============================================================================

_protected_names = {'__safe_getattr__', '__builtins__'}

class AttributeAccessTransformer(ast.NodeTransformer):
    """Transforms attribute access to use safe getattr for dangerous attributes."""
    
    def visit_Attribute(self, node):
        self.generic_visit(node)  # Transform children first
        
        # Check if accessing a dangerous attribute
        if node.attr in _dangerous_attrs:
            if isinstance(node.ctx, ast.Load):
                # Transform obj.attr into __safe_getattr__(obj, 'attr')
                return ast.Call(
                    func=ast.Name(id='__safe_getattr__', ctx=ast.Load()),
                    args=[node.value, ast.Constant(value=node.attr)],
                    keywords=[]
                )
            elif isinstance(node.ctx, (ast.Store, ast.Del)):
                # Block assignment/deletion to dangerous attributes
                raise SyntaxError(f"Access to '{node.attr}' is not allowed (line {node.lineno})")
        return node
    
    def visit_Name(self, node):
        """Block assignment to protected sandbox names."""
        if isinstance(node.ctx, (ast.Store, ast.Del)) and node.id in _protected_names:
            raise SyntaxError(f"Cannot modify protected name '{node.id}' (line {node.lineno})")
        return node
    
    def visit_Import(self, node):
        """Block 'import builtins' which could bypass restrictions."""
        for alias in node.names:
            if alias.name == 'builtins' or alias.name.startswith('builtins.'):
                raise SyntaxError(f"Import of 'builtins' is not allowed (line {node.lineno})")
        return node
    
    def visit_ImportFrom(self, node):
        """Block 'from builtins import ...' which could bypass restrictions."""
        if node.module == 'builtins' or (node.module and node.module.startswith('builtins.')):
            raise SyntaxError(f"Import from 'builtins' is not allowed (line {node.lineno})")
        return node


# =============================================================================
# Safe Type and Collection Functions
# =============================================================================

_real_type = type
def _safe_type(*args):
    """Only allow inspection, not dynamic class creation."""
    if len(args) == 1:
        return _real_type(args[0])  # type(x) for inspection is fine
    raise TypeError("Dynamic class creation with type() is not allowed")

_real_sorted = sorted
def _safe_sorted(iterable, **kwargs):
    """sorted() wrapper that checks input size before sorting."""
    if hasattr(iterable, '__len__'):
        if len(iterable) > _MAX_ALLOCATION_SIZE:
            raise MemoryError(f"sorted() input has {len(iterable):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
    lst = _real_list(iterable)
    if len(lst) > _MAX_ALLOCATION_SIZE:
        raise MemoryError(f"sorted() would process {len(lst):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
    return _safe_list(_real_sorted(lst, **kwargs))

def _limited_iter(iterable, limit=_MAX_ALLOCATION_SIZE):
    """Helper to create a limited iterator that raises after too many iterations."""
    count = 0
    for item in iterable:
        count += 1
        if count > limit:
            raise MemoryError(f"Iterator exceeded {limit:,} elements")
        yield item

_real_sum = sum
def _safe_sum(iterable, start=0):
    """sum() wrapper that limits iteration count for generators."""
    if hasattr(iterable, '__len__'):
        if len(iterable) > _MAX_ALLOCATION_SIZE:
            raise MemoryError(f"sum() input has {len(iterable):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
        return _real_sum(iterable, start)
    return _real_sum(_limited_iter(iterable), start)

_real_min = min
def _safe_min(*args, **kwargs):
    """min() wrapper that limits iteration count for generators."""
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
    """max() wrapper that limits iteration count for generators."""
    if len(args) == 1:
        iterable = args[0]
        if hasattr(iterable, '__len__'):
            if len(iterable) > _MAX_ALLOCATION_SIZE:
                raise MemoryError(f"max() input has {len(iterable):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
            return _real_max(iterable, **kwargs)
        return _real_max(_limited_iter(iterable), **kwargs)
    return _real_max(*args, **kwargs)

_real_any = any
def _safe_any(iterable):
    """any() wrapper that limits iteration count."""
    if hasattr(iterable, '__len__'):
        return _real_any(iterable)
    return _real_any(_limited_iter(iterable))

_real_all = all
def _safe_all(iterable):
    """all() wrapper that limits iteration count."""
    if hasattr(iterable, '__len__'):
        return _real_all(iterable)
    return _real_all(_limited_iter(iterable))

_real_reversed = reversed
def _safe_reversed(seq):
    """reversed() wrapper that checks size before reversing."""
    if hasattr(seq, '__len__'):
        if len(seq) > _MAX_ALLOCATION_SIZE:
            raise MemoryError(f"reversed() input has {len(seq):,} elements (max {_MAX_ALLOCATION_SIZE:,})")
    return _real_reversed(seq)

_real_pow = pow

def _estimate_result_bits(base, exp):
    """Estimate the bit-length of base**exp without computing it."""
    if exp <= 0:
        return 1  # Result is 1 or a fraction
    if base == 0:
        return 1
    
    abs_base = abs(base)
    if abs_base == 1:
        return 1
    
    # bit_length of result ≈ exp * log2(|base|) ≈ exp * bit_length(|base|)
    # For more accuracy: log2(n) ≈ bit_length(n) - 1 + fraction
    # We use a conservative estimate
    if isinstance(abs_base, int):
        base_bits = abs_base.bit_length()
    else:
        # For floats, estimate from the value
        import math
        if abs_base < 1:
            return 1  # Result shrinks
        base_bits = int(math.log2(abs_base)) + 1
    
    return int(exp * base_bits)

def _safe_pow(base, exp, mod=None):
    """pow() wrapper that prevents huge computations."""
    # Three-arg pow with modulo is always safe (used in cryptography)
    if mod is not None:
        return _real_pow(base, exp, mod)
    
    # Check for dangerous exponentiation
    try:
        if isinstance(base, (int, float)) and isinstance(exp, (int, float)):
            estimated_bits = _estimate_result_bits(base, exp)
            if estimated_bits > _MAX_RESULT_BITS:
                raise OverflowError(
                    f"pow({base}, {exp}) would produce ~{estimated_bits:,} bits "
                    f"(max {_MAX_RESULT_BITS:,} bits)"
                )
    except TypeError:
        pass  # Complex or other types, let Python handle it
    
    return _real_pow(base, exp)

_real_dir = dir
def _safe_dir(obj=None):
    """dir() wrapper that filters out dangerous attributes."""
    if obj is None:
        # dir() with no args - return empty to prevent namespace introspection
        return []
    result = _real_dir(obj)
    return [attr for attr in result if attr not in _dangerous_attrs]


# =============================================================================
# Safe Regex Wrapper
# =============================================================================

_real_re_module = None

class _SafePattern:
    """Wrapper around compiled regex pattern that enforces input length limits."""
    _max_input_length = 100_000
    
    def __init__(self, real_pattern):
        self._real_pattern = real_pattern
    
    def _check_string(self, string):
        if string is not None and len(string) > self._max_input_length:
            raise ValueError(f"Input string too long ({len(string)} > {self._max_input_length})")
    
    def search(self, string, pos=0, endpos=None):
        self._check_string(string)
        if endpos is None:
            return self._real_pattern.search(string, pos)
        return self._real_pattern.search(string, pos, endpos)
    
    def match(self, string, pos=0, endpos=None):
        self._check_string(string)
        if endpos is None:
            return self._real_pattern.match(string, pos)
        return self._real_pattern.match(string, pos, endpos)
    
    def fullmatch(self, string, pos=0, endpos=None):
        self._check_string(string)
        if endpos is None:
            return self._real_pattern.fullmatch(string, pos)
        return self._real_pattern.fullmatch(string, pos, endpos)
    
    def findall(self, string, pos=0, endpos=None):
        self._check_string(string)
        if endpos is None:
            return self._real_pattern.findall(string, pos)
        return self._real_pattern.findall(string, pos, endpos)
    
    def finditer(self, string, pos=0, endpos=None):
        self._check_string(string)
        if endpos is None:
            return self._real_pattern.finditer(string, pos)
        return self._real_pattern.finditer(string, pos, endpos)
    
    def sub(self, repl, string, count=0):
        self._check_string(string)
        return self._real_pattern.sub(repl, string, count)
    
    def subn(self, repl, string, count=0):
        self._check_string(string)
        return self._real_pattern.subn(repl, string, count)
    
    def split(self, string, maxsplit=0):
        self._check_string(string)
        return self._real_pattern.split(string, maxsplit)
    
    # Pass through read-only attributes
    @property
    def pattern(self):
        return self._real_pattern.pattern
    
    @property
    def flags(self):
        return self._real_pattern.flags
    
    @property
    def groups(self):
        return self._real_pattern.groups
    
    @property
    def groupindex(self):
        return self._real_pattern.groupindex
    
    def __repr__(self):
        return f"_SafePattern({self._real_pattern!r})"


class _SafeRegex:
    """Wrapper to prevent ReDoS attacks."""
    _max_input_length = 100_000
    _max_pattern_length = 1_000
    
    def _check_limits(self, pattern, string=None):
        if isinstance(pattern, str) and len(pattern) > self._max_pattern_length:
            raise ValueError(f"Regex pattern too long ({len(pattern)} > {self._max_pattern_length})")
        if string is not None and len(string) > self._max_input_length:
            raise ValueError(f"Input string too long ({len(string)} > {self._max_input_length})")
    
    def _get_pattern_str(self, pattern):
        # Handle both string patterns and compiled Pattern objects (including our wrapper)
        if isinstance(pattern, _SafePattern):
            return pattern.pattern
        if hasattr(pattern, 'pattern'):
            return pattern.pattern
        return pattern
    
    def compile(self, pattern, flags=0):
        self._check_limits(pattern)
        real_pattern = _real_re_module.compile(pattern, flags)
        return _SafePattern(real_pattern)
    
    def search(self, pattern, string, flags=0):
        self._check_limits(self._get_pattern_str(pattern), string)
        return _real_re_module.search(pattern, string, flags)
    
    def match(self, pattern, string, flags=0):
        self._check_limits(self._get_pattern_str(pattern), string)
        return _real_re_module.match(pattern, string, flags)
    
    def fullmatch(self, pattern, string, flags=0):
        self._check_limits(self._get_pattern_str(pattern), string)
        return _real_re_module.fullmatch(pattern, string, flags)
    
    def findall(self, pattern, string, flags=0):
        self._check_limits(self._get_pattern_str(pattern), string)
        return _real_re_module.findall(pattern, string, flags)
    
    def finditer(self, pattern, string, flags=0):
        self._check_limits(self._get_pattern_str(pattern), string)
        return _real_re_module.finditer(pattern, string, flags)
    
    def sub(self, pattern, repl, string, count=0, flags=0):
        self._check_limits(self._get_pattern_str(pattern), string)
        return _real_re_module.sub(pattern, repl, string, count, flags)
    
    def subn(self, pattern, repl, string, count=0, flags=0):
        self._check_limits(self._get_pattern_str(pattern), string)
        return _real_re_module.subn(pattern, repl, string, count, flags)
    
    def split(self, pattern, string, maxsplit=0, flags=0):
        self._check_limits(self._get_pattern_str(pattern), string)
        return _real_re_module.split(pattern, string, maxsplit, flags)
    
    def escape(self, pattern):
        return _real_re_module.escape(pattern)
    
    def purge(self):
        return _real_re_module.purge()
    
    # Pass through constants and flags
    def __getattr__(self, name):
        return getattr(_real_re_module, name)

_safe_re_instance = _SafeRegex()


# =============================================================================
# Module Import Restrictions
# =============================================================================

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


# =============================================================================
# Safe Builtins Dictionary
# =============================================================================

_safe_builtins = {
    # Math & Numbers
    'abs': abs,
    'round': round,
    'pow': _safe_pow,
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
    'reversed': _safe_reversed,
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
    
    # Introspection (filtered)
    'dir': _safe_dir,
    
    # I/O
    'print': print,
    
    # Blocked builtins (explicitly blocked for security)
    'eval': _blocked_eval,
    'exec': _blocked_exec,
    'compile': _blocked_compile,
    'open': _blocked_open,
    'input': _blocked_input,
    'breakpoint': _blocked_breakpoint,
    'memoryview': _blocked_memoryview,
    'globals': _blocked_globals,
    'locals': _blocked_locals,
    
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

_safe_builtins['__import__'] = _safe_import


# =============================================================================
# Setup Function - Called from Swift
# =============================================================================

def setup_sandbox(user_code, user_globals, timeout_seconds):
    """
    Set up the sandbox environment for executing user code.
    
    Args:
        user_code: The user's Python code as a string
        user_globals: The globals dict for user code execution
        timeout_seconds: Maximum execution time
    
    Returns:
        Compiled code object ready for execution, or raises an error
    """
    global _timeout_seconds, _real_re_module
    _timeout_seconds = timeout_seconds
    
    # Check code memory safety
    safety_errors = check_code_safety(user_code)
    if safety_errors:
        raise MemoryError("Code rejected:\n" + "\n".join(safety_errors))
    
    # Parse and transform AST to intercept dangerous attribute access
    try:
        tree = ast.parse(user_code)
        transformer = AttributeAccessTransformer()
        tree = transformer.visit(tree)
        ast.fix_missing_locations(tree)
    except SyntaxError as e:
        raise SyntaxError(str(e))
    
    # Store source in linecache so tracebacks can display it
    linecache.cache[_user_filename] = (
        len(user_code),
        None,
        user_code.splitlines(keepends=True),
        _user_filename
    )
    
    # Configure user namespace with restricted builtins
    user_globals['__builtins__'] = _safe_builtins
    user_globals['__name__'] = '__main__'
    
    # Add the safe getattr function for transformed attribute access
    user_globals['__safe_getattr__'] = _safe_getattr
    
    # Set recursion stack limit
    sys.setrecursionlimit(500)
    
    # Compile transformed AST
    compiled_code = compile(tree, _user_filename, 'exec')
    
    return compiled_code
