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
    let pythonHome = libPath + "/python3.13"
    
    setenv("PYTHONHOME", libPath, 1)
    setenv("PYTHONPATH", pythonHome, 1)
    
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
  
  func run(code: String) -> String {
    guard isInitialized else { return "Error: Python not initialized" }
    
    guard let mainModule = PyImport_AddModule("__main__") else {
      return "Error: Could not get __main__ module"
    }
    
    guard let globalDict = PyModule_GetDict(mainModule) else {
      return "Error: Could not get global dict"
    }
    
    let captureCode = """
    import sys
    from io import StringIO
    _stdout_capture = StringIO()
    _old_stdout = sys.stdout
    sys.stdout = _stdout_capture
    """
    PyRun_SimpleString(captureCode)
    
    let result = PyRun_SimpleString(code)
    
    let getOutputCode = """
    sys.stdout = _old_stdout
    _captured_output = _stdout_capture.getvalue()
    """
    PyRun_SimpleString(getOutputCode)
    
    if let outputObj = PyDict_GetItemString(globalDict, "_captured_output") {
      var size: Int = 0
      if let outputPtr = PyUnicode_AsUTF8AndSize(outputObj, &size) {
        let output = String(cString: outputPtr)
        if !output.isEmpty {
          return output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
      }
    }
    
    if result == 0 {
      return "Code executed successfully (no output)"
    } else {
      return "Error executing code"
    }
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
