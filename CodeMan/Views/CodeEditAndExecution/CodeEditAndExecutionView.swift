//
//  CodeEditAndExecutionView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/8/26.
//

import SwiftUI
import SQLiteData

struct CodeEditAndExecutionView: View {
  let translationID: Translation.ID
  
  @FetchOne var translation: Translation?
  
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  
  @State private var executionResult: PythonRunner.ExecutionResult?
  @State private var isRunning = false
  @State private var pythonVersion: String?
  @State private var successCount = 0
  @State private var errorCount = 0
  
  init(translationID: Translation.ID) {
    self.translationID = translationID
    _translation = FetchOne(Translation.find(translationID))
  }
  
  private var hasError: Bool {
    executionResult?.isError == true
  }
  
  private var outputText: String? {
    executionResult?.output
  }
  
  private var outputTextColor: Color {
    if outputText == nil {
      return .secondary
    }
    return hasError ? .red : .primary
  }
  
  private var isLandscapePhone: Bool {
    horizontalSizeClass == .compact && verticalSizeClass == .compact
  }
  
  var body: some View {
    Group {
      if translation != nil {
        if isLandscapePhone {
          landscapeLayout
        } else {
          portraitLayout
        }
      }
    }
    .sensoryFeedback(.success, trigger: successCount)
    .sensoryFeedback(.error, trigger: errorCount)
    .navigationTitle("Edit & Run")
    .navigationBarTitleDisplayMode(.inline)
    .task {
      pythonVersion = "Python " + PythonRunner.shared.getVersion()
    }
  }
  
  private var portraitLayout: some View {
    VStack(spacing: 0) {
      CodeEditorView(translationID: translationID)
      
      Divider()
      
      VStack(spacing: 12) {
        runButton
          .padding(.horizontal)
        
        OutputSection(
          hasError: hasError,
          outputText: outputText,
          outputTextColor: outputTextColor,
          pythonVersion: pythonVersion
        )
        .padding(.horizontal)
      }
      .padding(.vertical)
    }
  }
  
  private var landscapeLayout: some View {
    HStack(spacing: 0) {
      CodeEditorView(translationID: translationID)
        .frame(maxWidth: .infinity)
      
      Divider()
      
      VStack(spacing: 12) {
        runButton
        
        OutputSection(
          hasError: hasError,
          outputText: outputText,
          outputTextColor: outputTextColor,
          pythonVersion: pythonVersion
        )
      }
      .padding()
      .frame(width: 280)
    }
  }
  
  private var runButton: some View {
    Button {
      runCode()
    } label: {
      HStack {
        Image(systemName: isRunning ? "stop.fill" : "play.fill")
        Text(isRunning ? "Running..." : "Run Code")
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .background(isRunning ? Color.orange : Color.green)
      .foregroundStyle(.white)
      .clipShape(.rect(cornerRadius: 8))
    }
    .disabled(isRunning)
  }
  
  func runCode() {
    guard let code = translation?.translatedCode, !code.isEmpty else {
      executionResult = PythonRunner.ExecutionResult(output: "No code to run", isError: true)
      return
    }
    
    isRunning = true
    executionResult = PythonRunner.shared.run(code: code)
    isRunning = false
    
    if executionResult?.isError == true {
      errorCount += 1
    } else {
      successCount += 1
    }
  }
}

private struct OutputSection: View {
  let hasError: Bool
  let outputText: String?
  let outputTextColor: Color
  let pythonVersion: String?
  
  private var displayText: String {
    if let output = outputText {
      return output
    }
    return pythonVersion ?? "Initializing Python..."
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(hasError ? "Error:" : "Output:")
          .font(.caption)
          .foregroundStyle(hasError ? .red : .secondary)
        
        if hasError {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.caption)
            .foregroundStyle(.red)
        }
      }
      
      ScrollView {
        Text(displayText)
          .font(.system(.body, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
          .foregroundStyle(outputTextColor)
      }
      .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 200)
      .padding(8)
      .background(hasError ? Color.red.opacity(0.1) : Color(.systemGray6))
      .clipShape(.rect(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(hasError ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
      )
    }
  }
}

