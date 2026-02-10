//
//  PythonRunner.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/8/26.
//

import Foundation

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
  
  func run(code: String) -> ExecutionResult {
    guard isInitialized else {
      return ExecutionResult(output: "Python not initialized", isError: true)
    }
    
    guard let mainModule = PyImport_AddModule("__main__") else {
      return ExecutionResult(output: "Could not get __main__ module", isError: true)
    }
    
    guard let globalDict = PyModule_GetDict(mainModule) else {
      return ExecutionResult(output: "Could not get global dict", isError: true)
    }
    
    guard let codeObj = PyUnicode_FromString(code) else {
      return ExecutionResult(output: "Could not create code string", isError: true)
    }
    PyDict_SetItemString(globalDict, "_user_code", codeObj)
    Py_DecRef(codeObj)
    
    PyErr_Clear()
    
    let setupCode = """
    import sys
    import linecache
    from io import StringIO
    
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
    
    _exec_error = None
    _captured_stdout = ""
    _captured_stderr = ""
    try:
        _compiled = compile(_user_code, _user_filename, 'exec')
        exec(_compiled, globals())
    except Exception as e:
        import traceback
        _exec_error = ''.join(traceback.format_exception(type(e), e, e.__traceback__))
    finally:
        sys.stdout = _old_stdout
        sys.stderr = _old_stderr
        _captured_stdout = _stdout_capture.getvalue()
        _captured_stderr = _stderr_capture.getvalue()
    """
    PyRun_SimpleString(setupCode)
    
    var stdoutOutput = ""
    var stderrOutput = ""
    var execError = ""
    
    if let outputObj = PyDict_GetItemString(globalDict, "_captured_stdout") {
      var size: Int = 0
      if let outputPtr = PyUnicode_AsUTF8AndSize(outputObj, &size) {
        stdoutOutput = String(cString: outputPtr).trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    
    if let errorObj = PyDict_GetItemString(globalDict, "_captured_stderr") {
      var size: Int = 0
      if let errorPtr = PyUnicode_AsUTF8AndSize(errorObj, &size) {
        stderrOutput = String(cString: errorPtr).trimmingCharacters(in: .whitespacesAndNewlines)
      }
    }
    
    if let execErrorObj = PyDict_GetItemString(globalDict, "_exec_error") {
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
    
    return ExecutionResult(output: stdoutOutput, isError: false)
  }
  
  private func formatPythonException(globalDict: UnsafeMutablePointer<PyObject>) -> String {
    var pType: UnsafeMutablePointer<PyObject>?
    var pValue: UnsafeMutablePointer<PyObject>?
    var pTraceback: UnsafeMutablePointer<PyObject>?
    
    PyErr_Fetch(&pType, &pValue, &pTraceback)
    
    guard pType != nil else {
      return ""
    }
    
    PyErr_NormalizeException(&pType, &pValue, &pTraceback)
    
    defer {
      if let t = pType { Py_DecRef(t) }
      if let v = pValue { Py_DecRef(v) }
      if let tb = pTraceback { Py_DecRef(tb) }
    }
    
    if let tracebackModule = PyImport_ImportModule("traceback") {
      defer { Py_DecRef(tracebackModule) }
      
      if let formatException = PyObject_GetAttrString(tracebackModule, "format_exception") {
        defer { Py_DecRef(formatException) }
        
        if let args = PyTuple_New(3) {
          if let t = pType { Py_IncRef(t) }
          if let v = pValue { Py_IncRef(v) }
          if let tb = pTraceback { Py_IncRef(tb) }
          
          PyTuple_SetItem(args, 0, pType)
          PyTuple_SetItem(args, 1, pValue)
          PyTuple_SetItem(args, 2, pTraceback)
          
          if let resultList = PyObject_CallObject(formatException, args) {
            defer { Py_DecRef(resultList) }
            Py_DecRef(args)
            
            var errorLines: [String] = []
            let listSize = PyList_Size(resultList)
            for i in 0..<listSize {
              if let item = PyList_GetItem(resultList, i) {
                var size: Int = 0
                if let strPtr = PyUnicode_AsUTF8AndSize(item, &size) {
                  let line = String(cString: strPtr)
                  errorLines.append(line)
                }
              }
            }
            
            return errorLines.joined().trimmingCharacters(in: .whitespacesAndNewlines)
          } else {
            Py_DecRef(args)
          }
        }
      }
    }
    
    var typeName = "Exception"
    if let typeObj = pType,
       let typeNameObj = PyObject_GetAttrString(typeObj, "__name__") {
      defer { Py_DecRef(typeNameObj) }
      var size: Int = 0
      if let namePtr = PyUnicode_AsUTF8AndSize(typeNameObj, &size) {
        typeName = String(cString: namePtr)
      }
    }
    
    var message = ""
    if let valueObj = pValue,
       let strObj = PyObject_Str(valueObj) {
      defer { Py_DecRef(strObj) }
      var size: Int = 0
      if let strPtr = PyUnicode_AsUTF8AndSize(strObj, &size) {
        message = String(cString: strPtr)
      }
    }
    
    return message.isEmpty ? typeName : "\(typeName): \(message)"
  }
  
  deinit {
    if isInitialized {
      Py_Finalize()
    }
  }
}
