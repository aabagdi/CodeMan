//
//  CodeEditAndExecutionView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/8/26.
//

import SwiftUI

struct CodeEditAndExecutionView: View {
  @Binding var translation: Translation
  
  @State private var executionResult: String?
  @State private var isRunning = false
  
  var body: some View {
    VStack(spacing: 0) {
      CodeEditorView(translation: $translation)
      
      Divider()
      
      VStack(spacing: 12) {
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
        .padding(.horizontal)
        
        VStack(alignment: .leading, spacing: 4) {
          Text("Output:")
            .font(.caption)
            .foregroundStyle(.secondary)
          
          ScrollView {
            Text(executionResult ?? "Press Run to execute code")
              .font(.system(.body, design: .monospaced))
              .frame(maxWidth: .infinity, alignment: .leading)
              .foregroundStyle(executionResult == nil ? .secondary : .primary)
          }
          .frame(maxWidth: .infinity, minHeight: 100, maxHeight: 150)
          .padding(8)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(.horizontal)
      }
      .padding(.vertical)
    }
    .navigationTitle("Edit & Run")
    .navigationBarTitleDisplayMode(.inline)
  }
  
  func runCode() {
    guard let code = translation.translatedCode, !code.isEmpty else {
      executionResult = "No code to run"
      return
    }
    
    isRunning = true
    executionResult = PythonRunner.shared.run(code: code)
    isRunning = false
  }
}

