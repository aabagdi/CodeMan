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
    
    print("Python initialized: \(Py_IsInitialized() != 0)")
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
  private let executionTimeoutSeconds = 10
  
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
    import sys
    import linecache
    import time as _time
    from io import StringIO
    
    _timeout_seconds = \(executionTimeoutSeconds)
    
    _user_filename = "<user_code>"
    
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
        'min': min,
        'max': max,
        'sum': sum,
        'int': int,
        'float': float,
        'complex': complex,
        'bool': bool,
        'bin': bin,
        'oct': oct,
        'hex': hex,
        
        # Strings & Characters
        'str': str,
        'repr': repr,
        'format': format,
        'chr': chr,
        'ord': ord,
        'ascii': ascii,
        
        # Collections
        'list': list,
        'tuple': tuple,
        'dict': dict,
        'set': set,
        'frozenset': frozenset,
        'len': len,
        'sorted': sorted,
        'reversed': reversed,
        'slice': slice,
        'range': range,
    
        # Classes
        '__build_class__': __build_class__,
        
        # Iteration
        'iter': iter,
        'next': next,
        'enumerate': enumerate,
        'zip': zip,
        'map': map,
        'filter': filter,
        'any': any,
        'all': all,
        
        # I/O
        'print': print,
        
        # Constants
        'True': True,
        'False': False,
        'None': None,
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
      return ExecutionResult(output: "Code executed successfully (no output)", isError: false)
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
