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
    
    guard let freshGlobals = PyDict_New() else {
      return ExecutionResult(output: "Could not create namespace", isError: true)
    }
    defer { Py_DecRef(freshGlobals) }
    
    if let builtins = PyEval_GetBuiltins() {
      PyDict_SetItemString(freshGlobals, "__builtins__", builtins)
    }
    
    if let nameObj = PyUnicode_FromString("__main__") {
      PyDict_SetItemString(freshGlobals, "__name__", nameObj)
      Py_DecRef(nameObj)
    }
    
    guard let codeObj = PyUnicode_FromString(code) else {
      return ExecutionResult(output: "Could not create code string", isError: true)
    }
    PyDict_SetItemString(freshGlobals, "_user_code", codeObj)
    Py_DecRef(codeObj)
    
    PyErr_Clear()
    
    PyDict_SetItemString(freshGlobals, "_fresh_ns", freshGlobals)
    
    let setupCode = """
    import sys
    import linecache
    import builtins
    import time as _time
    from io import StringIO
    
    # Security: Execution timeout
    _start_time = _time.time()
    _timeout_seconds = \(executionTimeoutSeconds)
    
    class _TimeoutError(Exception):
        pass
    
    def _timeout_trace(frame, event, arg):
        if _time.time() - _start_time > _timeout_seconds:
            raise _TimeoutError(f"Execution exceeded {_timeout_seconds} second time limit")
        return _timeout_trace
    
    _user_filename = "<user_code>"
    
    # Store source in linecache so tracebacks can display it
    linecache.cache[_user_filename] = (
        len(_user_code),
        None,
        _user_code.splitlines(keepends=True),
        _user_filename
    )
    
    _stdout_capture = StringIO()
    _stderr_capture = StringIO()
    _old_stdout = sys.stdout
    _old_stderr = sys.stderr
    sys.stdout = _stdout_capture
    sys.stderr = _stderr_capture
    
    _fresh_ns['_exec_error'] = None
    _fresh_ns['_captured_stdout'] = ""
    _fresh_ns['_captured_stderr'] = ""
    try:
        _compiled = compile(_user_code, _user_filename, 'exec')
        sys.settrace(_timeout_trace)
        exec(_compiled, _fresh_ns)
    except _TimeoutError as e:
        _fresh_ns['_exec_error'] = str(e)
    except Exception as e:
        import traceback
        _fresh_ns['_exec_error'] = ''.join(traceback.format_exception(type(e), e, e.__traceback__))
    finally:
        sys.settrace(None)
        sys.stdout = _old_stdout
        sys.stderr = _old_stderr
        _fresh_ns['_captured_stdout'] = _stdout_capture.getvalue()
        _fresh_ns['_captured_stderr'] = _stderr_capture.getvalue()
    """
    
    guard let setupCodeObj = Py_CompileString(setupCode, "<setup>", Py_file_input) else {
      PyErr_Clear()
      return ExecutionResult(output: "Could not compile setup code", isError: true)
    }
    defer { Py_DecRef(setupCodeObj) }
    
    let result = PyEval_EvalCode(setupCodeObj, freshGlobals, freshGlobals)
    if result != nil {
      Py_DecRef(result)
    } else if PyErr_Occurred() != nil {
      var pType: UnsafeMutablePointer<PyObject>?
      var pValue: UnsafeMutablePointer<PyObject>?
      var pTraceback: UnsafeMutablePointer<PyObject>?
      PyErr_Fetch(&pType, &pValue, &pTraceback)
      
      var errorMessage = "Setup code failed"
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
    
    if let outputObj = PyDict_GetItemString(freshGlobals, "_captured_stdout") {
      var size: Int = 0
      if let outputPtr = PyUnicode_AsUTF8AndSize(outputObj, &size) {
        stdoutOutput = String(cString: outputPtr).trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    
    if let errorObj = PyDict_GetItemString(freshGlobals, "_captured_stderr") {
      var size: Int = 0
      if let errorPtr = PyUnicode_AsUTF8AndSize(errorObj, &size) {
        stderrOutput = String(cString: errorPtr).trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    
    if let execErrorObj = PyDict_GetItemString(freshGlobals, "_exec_error") {
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
