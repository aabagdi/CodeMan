//
//  CodeExecutionView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/8/26.
//

import SwiftUI
import Dependencies

struct CodeExecutionView: View {
  let code: AttributedString
  
  @Dependency(\.date) var now
  
  @State private var isRunningCode = false
  @State private var pythonVersion: String?
  @State private var executionResult: PythonRunner.ExecutionResult?
  
  var body: some View {
    VStack {
      Button {
        executionResult = run(code: code)
      } label: {
        Image(systemName: "play.fill")
      }
      .disabled(isRunningCode)
      
      Text(pythonVersion ?? "Initializing Python...")
        .task {
          pythonVersion = createInitText()
        }
      
      if let result = executionResult {
        Text(result.output)
          .foregroundStyle(result.isError ? .red : .primary)
      }
    }
  }
  
  func run(code: AttributedString) -> PythonRunner.ExecutionResult {
    isRunningCode = true
    defer { isRunningCode = false }
    
    let rawCode = String(code.characters)
    return PythonRunner.shared.run(code: rawCode)
  }
  
  func createInitText() -> String {
    let version = PythonRunner.shared.getVersion()
    let date = now.now.formatted(date: .long, time: .standard)
    
    return "Python \(version), \(date)"
  }
}
