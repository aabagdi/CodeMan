//
//  CodeEditorView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/8/26.
//

import SwiftUI
import SQLiteData
import Highlighter
import UIKit
import Dependencies

struct CodeEditorView: View {
  @Binding var translation: Translation
  
  @Dependency(\.defaultDatabase) var database
  
  @State private var text: AttributedString = ""
  @State private var selection = AttributedTextSelection()
  @State private var highlightTask: Task<Void, Never>?
  @State private var saveTask: Task<Void, Never>?
  
  let highlighter = Highlighter()
  
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
        text = highlight(translation.translatedCode ?? "")
      }
      .onChange(of: text) {
        let newPlainText = String(text.characters)
        
        if translation.translatedCode != newPlainText {
          translation.translatedCode = newPlainText
          
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
            
            let highlightedCode = highlight(newPlainText)
            translation.prettifiedCode = highlightedCode
            await saveToDatabase()
          }
        }
      }
  }
  
  func saveToDatabase() async {
    let id = translation.id
    let translatedCode = translation.translatedCode
    let prettifiedCode = translation.prettifiedCode
    
    do {
      try await database.write { db in
        try Translation
          .find(id)
          .update {
            $0.translatedCode = translatedCode
            $0.prettifiedCode = prettifiedCode
          }
          .execute(db)
      }
    } catch {
      print("Failed to save translation: \(error)")
    }
  }
  
  func highlight(_ code: String) -> AttributedString {
    guard let highlighter else { return AttributedString(code) }
    
    highlighter.setTheme("atom-one-light")
    
    guard let highlightedNS = highlighter.highlight(code, as: "python") else {
      return AttributedString(code)
    }
    
    var result = AttributedString(code)
    
    highlightedNS.enumerateAttributes(
      in: NSRange(location: 0, length: highlightedNS.length),
      options: []
    ) { attrs, nsRange, _ in
      guard let stringRange = Range(nsRange, in: code) else { return }
      
      let startOffset = code.distance(from: code.startIndex, to: stringRange.lowerBound)
      let endOffset = code.distance(from: code.startIndex, to: stringRange.upperBound)
      
      let attrStart = result.characters.index(result.startIndex, offsetBy: startOffset)
      let attrEnd = result.characters.index(result.startIndex, offsetBy: endOffset)
      let attrRange = attrStart..<attrEnd
      
      if let uiColor = attrs[.foregroundColor] as? UIColor {
        result[attrRange].foregroundColor = Color(uiColor: uiColor)
      }
    }
    
    return result
  }
}
