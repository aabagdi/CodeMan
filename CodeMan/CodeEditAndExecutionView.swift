//
//  CodeEditAndExecutionView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/8/26.
//

import SwiftUI

struct CodeEditAndExecutionView: View {
  @Binding var translation: Translation
  
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  
  @State private var executionResult: PythonRunner.ExecutionResult?
  @State private var isRunning = false
  
  private var hasError: Bool {
    executionResult?.isError == true
  }
  
  private var outputText: String {
    executionResult?.output ?? "Press Run to execute code"
  }
  
  private var outputTextColor: Color {
    if executionResult == nil {
      return .secondary
    }
    return hasError ? .red : .primary
  }
  
  private var isLandscapePhone: Bool {
    horizontalSizeClass == .compact && verticalSizeClass == .compact
  }
  
  var body: some View {
    Group {
      if isLandscapePhone {
        landscapeLayout
      } else {
        portraitLayout
      }
    }
    .navigationTitle("Edit & Run")
    .navigationBarTitleDisplayMode(.inline)
  }
  
  private var portraitLayout: some View {
    VStack(spacing: 0) {
      CodeEditorView(translation: $translation)
      
      Divider()
      
      VStack(spacing: 12) {
        runButton
          .padding(.horizontal)
        
        OutputSection(
          hasError: hasError,
          outputText: outputText,
          outputTextColor: outputTextColor
        )
        .padding(.horizontal)
      }
      .padding(.vertical)
    }
  }
  
  private var landscapeLayout: some View {
    HStack(spacing: 0) {
      CodeEditorView(translation: $translation)
        .frame(maxWidth: .infinity)
      
      Divider()
      
      VStack(spacing: 12) {
        runButton
        
        OutputSection(
          hasError: hasError,
          outputText: outputText,
          outputTextColor: outputTextColor
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
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    .disabled(isRunning)
  }
  
  func runCode() {
    guard let code = translation.translatedCode, !code.isEmpty else {
      executionResult = PythonRunner.ExecutionResult(output: "No code to run", isError: true)
      return
    }
    
    isRunning = true
    executionResult = PythonRunner.shared.run(code: code)
    isRunning = false
  }
}

private struct OutputSection: View {
  let hasError: Bool
  let outputText: String
  let outputTextColor: Color
  
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
        Text(outputText)
          .font(.system(.body, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
          .foregroundStyle(outputTextColor)
      }
      .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 200)
      .padding(8)
      .background(hasError ? Color.red.opacity(0.1) : Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 8))
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(hasError ? Color.red.opacity(0.5) : Color.clear, lineWidth: 1)
      )
    }
  }
}

