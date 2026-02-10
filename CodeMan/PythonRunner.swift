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
    
    let captureCode = """
    import sys
    from io import StringIO
    _stdout_capture = StringIO()
    _stderr_capture = StringIO()
    _old_stdout = sys.stdout
    _old_stderr = sys.stderr
    sys.stdout = _stdout_capture
    sys.stderr = _stderr_capture
    """
    PyRun_SimpleString(captureCode)
    
    let result = PyRun_SimpleString(code)
    
    let getOutputCode = """
    sys.stdout = _old_stdout
    sys.stderr = _old_stderr
    _captured_stdout = _stdout_capture.getvalue()
    _captured_stderr = _stderr_capture.getvalue()
    """
    PyRun_SimpleString(getOutputCode)
    
    var stdoutOutput = ""
    var stderrOutput = ""
    
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
    
    if result != 0 {
      let tracebackCode = """
      import traceback
      _error_info = ""
      try:
          _error_info = traceback.format_exc()
      except:
          pass
      """
      PyRun_SimpleString(tracebackCode)
      
      if let errorInfoObj = PyDict_GetItemString(globalDict, "_error_info") {
        var size: Int = 0
        if let errorPtr = PyUnicode_AsUTF8AndSize(errorInfoObj, &size) {
          let traceback = String(cString: errorPtr).trimmingCharacters(in: .whitespacesAndNewlines)
          if !traceback.isEmpty && traceback != "NoneType: None" {
            stderrOutput = traceback
          }
        }
      }
    }
    
    if result != 0 || !stderrOutput.isEmpty {
      let errorMessage = stderrOutput.isEmpty ? "An unknown error occurred" : stderrOutput
      return ExecutionResult(output: errorMessage, isError: true)
    }
    
    if stdoutOutput.isEmpty {
      return ExecutionResult(output: "Code executed successfully (no output)", isError: false)
    }
    
    return ExecutionResult(output: stdoutOutput, isError: false)
  }
  
  func eval(expression: String) -> String {
    guard isInitialized else { return "Error: Python not initialized" }
    
    guard let mainModule = PyImport_AddModule("__main__") else {
      return "Error: Could not get __main__ module"
    }
    
    guard let globalDict = PyModule_GetDict(mainModule) else {
      return "Error: Could not get global dict"
    }
    
    guard let result = PyRun_String(
      expression,
      Py_eval_input,
      globalDict,
      globalDict
    ) else {
      PyErr_Clear()
      return "Error: Invalid expression"
    }
    
    defer { Py_DecRef(result) }
    
    guard let strObj = PyObject_Str(result) else {
      return "Error: Could not convert result to string"
    }
    
    defer { Py_DecRef(strObj) }
    
    var size: Int = 0
    if let strPtr = PyUnicode_AsUTF8AndSize(strObj, &size) {
      return String(cString: strPtr)
    }
    
    return "Error: Could not read result"
  }
  
  deinit {
    if isInitialized {
      Py_Finalize()
    }
  }
}
