//
//  PythonRunner.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/8/26.
//

import Foundation

// PythonRunner must be @MainActor because Python's C API requires all calls
// to happen on the same thread where Py_Initialize() was called. The GIL only
// protects Python's internal state - it doesn't handle thread state setup.
@MainActor
final class PythonRunner {
  static let shared = PythonRunner()
  
  private var isInitialized = false
  private var sandboxCode: String?
  private var executorCode: String?
  
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
    
    if let sandboxURL = Bundle.main.url(forResource: "python_sandbox", withExtension: "py"),
       let sandbox = try? String(contentsOf: sandboxURL, encoding: .utf8) {
      sandboxCode = sandbox
    }
    
    if let executorURL = Bundle.main.url(forResource: "python_executor", withExtension: "py"),
       let executor = try? String(contentsOf: executorURL, encoding: .utf8) {
      executorCode = executor
    }
    
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
    
    guard let sandboxCode else {
      return ExecutionResult(output: "Could not load sandbox code", isError: true)
    }
    
    guard let executorCode else {
      return ExecutionResult(output: "Could not load executor code", isError: true)
    }
    
    guard let sandboxCodeObj = Py_CompileString(sandboxCode, "<sandbox>", Py_file_input) else {
      PyErr_Clear()
      return ExecutionResult(output: "Could not compile sandbox code", isError: true)
    }
    defer { Py_DecRef(sandboxCodeObj) }
    
    let sandboxResult = PyEval_EvalCode(sandboxCodeObj, setupGlobals, setupGlobals)
    if sandboxResult != nil {
      Py_DecRef(sandboxResult)
    } else if PyErr_Occurred() != nil {
      var pType: UnsafeMutablePointer<PyObject>?
      var pValue: UnsafeMutablePointer<PyObject>?
      var pTraceback: UnsafeMutablePointer<PyObject>?
      PyErr_Fetch(&pType, &pValue, &pTraceback)
      
      var errorMessage = "Sandbox load failed"
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
    
    guard let executorCodeObj = Py_CompileString(executorCode, "<executor>", Py_file_input) else {
      PyErr_Clear()
      return ExecutionResult(output: "Could not compile executor code", isError: true)
    }
    defer { Py_DecRef(executorCodeObj) }
    
    let executorResult = PyEval_EvalCode(executorCodeObj, setupGlobals, setupGlobals)
    if executorResult != nil {
      Py_DecRef(executorResult)
    } else if PyErr_Occurred() != nil {
      PyErr_Clear()
      return ExecutionResult(output: "Could not load executor module", isError: true)
    }
    
    let setupCall = """
    _compiled_code = setup_sandbox(_user_code, _user_globals, \(executionTimeoutSeconds))
    """
    
    guard let setupCallObj = Py_CompileString(setupCall, "<setup>", Py_file_input) else {
      PyErr_Clear()
      return ExecutionResult(output: "Could not compile setup call", isError: true)
    }
    defer { Py_DecRef(setupCallObj) }
    
    let setupResult = PyEval_EvalCode(setupCallObj, setupGlobals, setupGlobals)
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
      
      return ExecutionResult(output: errorMessage, isError: true)
    }
    
    let executeCall = """
    _captured_stdout, _captured_stderr, _exec_error = execute_code(_compiled_code, _user_globals, \(executionTimeoutSeconds))
    """
    
    guard let executeCallObj = Py_CompileString(executeCall, "<execute>", Py_file_input) else {
      PyErr_Clear()
      return ExecutionResult(output: "Could not compile execute call", isError: true)
    }
    defer { Py_DecRef(executeCallObj) }
    
    let execResult = PyEval_EvalCode(executeCallObj, setupGlobals, setupGlobals)
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
