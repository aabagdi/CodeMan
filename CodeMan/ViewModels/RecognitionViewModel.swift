//
//  RecognitionViewModel.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI
import Vision
import SQLiteData

@Observable
@MainActor
final class RecognitionViewModel {
  @ObservationIgnored
  @Dependency(\.defaultDatabase) var database
  
  @ObservationIgnored
  @Dependency(\.uuid) var uuid
  
  private var recognizer = CodeRecognizer()
  private let translator = TranslationSessionManager()
  
  var codeTitle: String = ""
  var translatedCode: String = ""
  var prettifiedCode: AttributedString = ""
  var translationError: String = ""
  var isShowingNameDialog: Bool = false
  var isTranslating: Bool = false
  var showingTranslationError: Bool = false
  var showingSameNameExistsError: Bool = false
  
  var observations: [VNRecognizedTextObservation] {
    recognizer.observations
  }
  
  var isDoneRecognizing: Bool {
    recognizer.isDoneRecognizing
  }
  
  var fullCodeBlock: String {
    recognizer.fullCodeBlock
  }
  
  var hasCodeToTranslate: Bool {
    !recognizer.fullCodeBlock.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  var hasTranslatedCode: Bool {
    !String(prettifiedCode.characters).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  func performRecognitionAndTranslation(for image: PhotoData, colorScheme: ColorScheme) async {
    do {
      try await recognizer.performRecognition(image)
      await translateAllText(colorScheme: colorScheme)
    } catch {
      showingTranslationError = true
      print("Recognition failed: \(error)")
    }
  }
  
  func translateAllText(colorScheme: ColorScheme) async {
    guard hasCodeToTranslate else {
      print("No code to translate")
      return
    }
    
    isTranslating = true
    
    do {
      print("Translating entire code block:\n\(recognizer.fullCodeBlock)")
      let translated = try await translator.translate(recognizer.fullCodeBlock)
      
      if translated.isEmpty || translated == "NOT_CODE" {
        print("AI filtered out the code block")
        translatedCode = ""
      } else {
        let cleanedCode = stripMarkdownCodeBlocks(from: translated)
        
        translatedCode = cleanedCode
        
        prettifiedCode = CodeHighlighter.shared.highlight(cleanedCode, colorScheme: colorScheme)
        print("Translation complete:\n\(cleanedCode)")
      }
    } catch {
      print("Translation error: \(error)")
      translationError = error.localizedDescription
      showingTranslationError = true
      translatedCode = ""
    }
    
    isTranslating = false
  }
  
  func dismissTranslationError() {
    translationError = ""
    showingTranslationError = false
  }
  
  func rehighlight(colorScheme: ColorScheme) {
    guard !translatedCode.isEmpty else { return }
    prettifiedCode = CodeHighlighter.shared.highlight(translatedCode, colorScheme: colorScheme)
  }
  
  func saveCode(image: PhotoData?) throws -> Bool {
    let exists = try database.read { db in
      try Translation.where { $0.title.eq(codeTitle) }.fetchCount(db) > 0
    }
    
    if !exists {
      let translation = Translation(
        id: self.uuid(),
        title: codeTitle,
        image: image?.imageData,
        originalText: recognizer.fullCodeBlock,
        translatedCode: translatedCode
      )
      
      withErrorReporting {
        try database.write { db in
          try Translation
            .insert { translation }
            .execute(db)
        }
      }
      
      return true
    } else {
      showingSameNameExistsError = true
      return false
    }
  }
  
  private func stripMarkdownCodeBlocks(from text: String) -> String {
    var result = text
    
    // Remove opening code fence at start (```python, ```swift, etc.)
    result = result.replacing(/^```\w*\n?/, with: "")
    
    // Remove closing code fence at end (``` or ```python, etc.)
    result = result.replacing(/\n?```\w*$/, with: "")
    
    // Remove any standalone code fence lines (with or without language)
    result = result.replacing(/(?m)^```\w*\s*$/, with: "")
    
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
