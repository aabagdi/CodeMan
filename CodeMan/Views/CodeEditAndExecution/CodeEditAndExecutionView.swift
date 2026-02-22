//
//  CodeEditAndExecutionView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/8/26.
//

import SwiftUI
import SQLiteData
import Dependencies
import TipKit

private struct KeyboardDismissingView: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> KeyboardDismissingViewController {
    KeyboardDismissingViewController()
  }
  func updateUIViewController(_ uiViewController: KeyboardDismissingViewController, context: Context) { }
}

private class KeyboardDismissingViewController: UIViewController {
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    view.window?.endEditing(true)
  }
}

struct CodeEditAndExecutionView: View {
  let translationID: Translation.ID
  
  @FetchOne var translation: Translation?
  
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  @Environment(\.verticalSizeClass) private var verticalSizeClass
  
  @Dependency(\.defaultDatabase) var database
  
  @State private var executionResult: PythonRunner.ExecutionResult?
  @State private var isRunning = false
  @State private var isFixing = false
  @State private var fixUnavailable = false
  @State private var showingFixError = false
  @State private var fixErrorMessage = ""
  @State private var fixCount = 0
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
    .ignoresSafeArea(.keyboard)
    .sensoryFeedback(.success, trigger: successCount)
    .sensoryFeedback(.success, trigger: fixCount)
    .sensoryFeedback(.error, trigger: errorCount)
    .navigationTitle("Edit & Run")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Copy output") {
          UIPasteboard.general.string = executionResult?.output
        }
        .disabled(executionResult == nil)
      }
    }
    .alert("Fix Error", isPresented: $showingFixError) {
      Button("OK") {
        fixErrorMessage = ""
        showingFixError = false
      }
    } message: {
      Text(fixErrorMessage.isEmpty
           ? "An unexpected error occurred."
           : fixErrorMessage)
    }
    .background {
      KeyboardDismissingView()
        .frame(width: 0, height: 0)
    }
    .onTapGesture {
      self.dismissKeyboard()
    }
    .onAppear {
      pythonVersion = "Python " + PythonRunner.shared.getVersion()
      let fixer = CodeFixer()
      fixUnavailable = !fixer.isAvailable
    }
  }
  
  private var portraitLayout: some View {
    VStack(spacing: 0) {
      CodeEditorView(translationID: translationID)
        .popoverTip(EditTip())
      
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
        
        if hasError && !fixUnavailable {
          fixButton
            .padding(.horizontal)
        }
      }
      .padding(.vertical)
    }
  }
  
  private var landscapeLayout: some View {
    HStack(spacing: 0) {
      CodeEditorView(translationID: translationID)
        .frame(maxWidth: .infinity)
        .popoverTip(EditTip())
      
      Divider()
      
      VStack(spacing: 12) {
        runButton
        
        OutputSection(
          hasError: hasError,
          outputText: outputText,
          outputTextColor: outputTextColor,
          pythonVersion: pythonVersion
        )
        
        if hasError && !fixUnavailable {
          fixButton
        }
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
    }
    .buttonStyle(.glassProminent)
    .tint(isRunning ? .orange : .green)
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
  
  private var fixButton: some View {
    Button {
      Task {
        await fixCode()
      }
    } label: {
      HStack {
        if isFixing {
          ProgressView()
          Text("Fixing...")
        } else {
          Image(systemName: "sparkles")
          Text("Fix with AI")
        }
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.glass)
    .intelligenceBackground(in: Capsule())
    .disabled(isFixing || isRunning)
  }
  
  private func fixCode() async {
    guard let code = translation?.translatedCode,
          let error = executionResult?.output,
          executionResult?.isError == true else { return }
    
    isFixing = true
    
    do {
      let fixer = CodeFixer()
      let fixedCode = try await fixer.fix(code: code, error: error)
      
      guard !fixedCode.isEmpty else {
        fixErrorMessage = "Could not generate a fix."
        showingFixError = true
        isFixing = false
        return
      }
      
      try await database.write { db in
        try Translation
          .find(translationID)
          .update {
            $0.translatedCode = #bind(fixedCode)
          }
          .execute(db)
      }
      
      fixCount += 1
      executionResult = nil
    } catch {
      fixErrorMessage = error.localizedDescription
      showingFixError = true
    }
    
    isFixing = false
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

