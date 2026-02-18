//
//  CodeEditorView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/8/26.
//

import SwiftUI
import SQLiteData
import Dependencies

struct CodeEditorView: View {
  let translationID: Translation.ID
  
  @FetchOne var translation: Translation?
  
  @Dependency(\.defaultDatabase) var database
  
  @Environment(\.colorScheme) private var colorScheme
  
  @FocusState private var isEditorFocused: Bool
  
  @State private var text: AttributedString = ""
  @State private var selection = AttributedTextSelection()
  @State private var textVersion = 0
  @State private var isInitialized = false
  @State private var isSaving = false
  
  init(translationID: Translation.ID) {
    self.translationID = translationID
    _translation = FetchOne(Translation.find(translationID))
  }
  
  var body: some View {
    TextEditor(text: $text, selection: $selection)
      .focused($isEditorFocused)
      .fontDesign(.monospaced)
      .textInputAutocapitalization(.never)
      .keyboardType(.asciiCapable)
      .autocorrectionDisabled()
      .textContentType(.none)
      .padding()
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.blue.opacity(0.3), lineWidth: 2)
          .padding()
      )
      .overlay(alignment: .topTrailing) {
        HStack {
          Image(systemName: "checkmark.circle.fill")
          Text("Code Saved!")
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(24)
        .opacity(isSaving ? 1 : 0)
        .animation(.easeInOut(duration: 1.2), value: isSaving)
      }
        .toolbar {
          ToolbarItemGroup(placement: .keyboard) {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 16) {
                Group {
                  Button("⇥") { insertText("    ") }
                  Button("()") { insertPaired("(", ")") }
                  Button("[]") { insertPaired("[", "]") }
                  Button("{}") { insertPaired("{", "}") }
                  Button(":") { insertText(":") }
                  Button("\"\"") { insertPaired("\"", "\"") }
                  Button("=") { insertText("=") }
                  Button("#") { insertText("#") }
                  Button("_") { insertText("_") }
                }
                .fontDesign(.monospaced)
                
                Divider()
                
                Button("Done") { dismissKeyboard() }
              }
              .padding(.horizontal)
            }
          }
        }
        .onAppear {
          if !isInitialized, let translation {
            text = highlight(translation.translatedCode ?? "")
            isInitialized = true
          }
        }
        .onChange(of: translation) {
          if !isInitialized, let translation {
            text = highlight(translation.translatedCode ?? "")
            isInitialized = true
          }
        }
        .onChange(of: colorScheme) {
          let plainText = String(text.characters)
          text = highlight(plainText)
        }
        .onChange(of: text) {
          guard isInitialized else { return }
          if translation?.translatedCode != String(text.characters) {
            textVersion += 1
          }
        }
        .task(id: textVersion) {
          guard isInitialized, textVersion > 0 else { return }
          
          let plainText = String(text.characters)
          
          try? await Task.sleep(for: .milliseconds(300))
          guard !Task.isCancelled else { return }
          
          guard translation?.translatedCode != plainText else { return }
          
          let cursorOffset: Int? = {
            switch selection.indices(in: text) {
            case .insertionPoint(let index):
              return text.characters.distance(from: text.startIndex, to: index)
            case .ranges(let rangeSet):
              guard let lastRange = rangeSet.ranges.last else { return nil }
              return text.characters.distance(from: text.startIndex, to: lastRange.upperBound)
            }
          }()
          
          let highlighted = highlight(plainText)
          text = highlighted
          
          if let offset = cursorOffset {
            let clampedOffset = min(offset, highlighted.characters.count)
            let newIndex = highlighted.characters.index(
              highlighted.startIndex,
              offsetBy: clampedOffset
            )
            selection = AttributedTextSelection(insertionPoint: newIndex)
          }
          
          try? await Task.sleep(for: .milliseconds(200))
          guard !Task.isCancelled else { return }
          
          await saveToDatabase(translatedCode: plainText)
        }
  }
  
  private func saveToDatabase(translatedCode: String) async {
    isSaving = true
    await withErrorReporting {
      try await database.write { db in
        try Translation
          .find(translationID)
          .update {
            $0.translatedCode = translatedCode
          }
          .execute(db)
      }
    }
    
    isSaving = false
  }
  
  private func highlight(_ code: String) -> AttributedString {
    CodeHighlighter.shared.highlight(code, colorScheme: colorScheme)
  }
  
  private func insertText(_ newText: String) {
    let insertionIndex: AttributedString.Index
    
    switch selection.indices(in: text) {
    case .insertionPoint(let index):
      insertionIndex = index
    case .ranges(let rangeSet):
      insertionIndex = rangeSet.ranges.last?.upperBound ?? text.endIndex
    }
    
    text.insert(AttributedString(newText), at: insertionIndex)
    
    let newIndex = text.index(insertionIndex, offsetByCharacters: newText.count)
    selection = AttributedTextSelection(insertionPoint: newIndex)
  }
  
  private func insertPaired(_ open: String, _ close: String) {
    let insertionIndex: AttributedString.Index
    
    switch selection.indices(in: text) {
    case .insertionPoint(let index):
      insertionIndex = index
    case .ranges(let rangeSet):
      insertionIndex = rangeSet.ranges.last?.upperBound ?? text.endIndex
    }
    
    text.insert(AttributedString(open + close), at: insertionIndex)
    
    let cursorIndex = text.index(insertionIndex, offsetByCharacters: open.count)
    selection = AttributedTextSelection(insertionPoint: cursorIndex)
  }
  
  private func dismissKeyboard() {
    if isEditorFocused {
      UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
      isEditorFocused = false
    }
  }
}
