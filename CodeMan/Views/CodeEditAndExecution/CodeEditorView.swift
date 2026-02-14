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
  
  @State private var text: AttributedString = ""
  @State private var selection = AttributedTextSelection()
  @State private var highlightTask: Task<Void, Never>?
  @State private var saveTask: Task<Void, Never>?
  @State private var isInitialized = false
  
  init(translationID: Translation.ID) {
    self.translationID = translationID
    _translation = FetchOne(Translation.find(translationID))
  }
  
  var body: some View {
    TextEditor(text: $text, selection: $selection)
      .fontDesign(.monospaced)
      .textInputAutocapitalization(.never)
      .autocorrectionDisabled(true)
      .padding()
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color.blue.opacity(0.3), lineWidth: 2)
          .padding()
      )
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
        let newPlainText = String(text.characters)
        
        if translation?.translatedCode != newPlainText {
          highlightTask?.cancel()
          saveTask?.cancel()
          
          highlightTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            
            guard !Task.isCancelled else { return }
            
            let cursorOffset: Int? = {
              switch selection.indices(in: text) {
              case .insertionPoint(let index):
                return text.characters.distance(from: text.startIndex, to: index)
              case .ranges(let rangeSet):
                guard let lastRange = rangeSet.ranges.last else { return nil }
                return text.characters.distance(from: text.startIndex, to: lastRange.upperBound)
              }
            }()
            
            let highlighted = highlight(newPlainText)
            text = highlighted
            
            if let offset = cursorOffset {
              let clampedOffset = min(offset, highlighted.characters.count)
              let newIndex = highlighted.characters.index(
                highlighted.startIndex,
                offsetBy: clampedOffset
              )
              selection = AttributedTextSelection(insertionPoint: newIndex)
            }
          }
          
          saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            
            await saveToDatabase(translatedCode: newPlainText)
          }
        }
      }
  }
  
  func saveToDatabase(translatedCode: String) async {
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
  }
  
  func highlight(_ code: String) -> AttributedString {
    CodeHighlighter.shared.highlight(code, colorScheme: colorScheme)
  }
}
