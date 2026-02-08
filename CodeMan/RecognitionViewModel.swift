//
//  RecognitionViewModel.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI
import Vision
import Highlighter
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
  private let highlighter = Highlighter()
  
  var codeTitle: String = ""
  var translatedCode: String = ""
  var prettifiedCode: AttributedString = ""
  var translationError: String = ""
  var isShowingNameDialog: Bool = false
  var isTranslating: Bool = false
  var showingTranslationError: Bool = false
  
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
  
  func performRecognitionAndTranslation(for image: PhotoData) async {
    do {
      try await recognizer.performRecognition(image)
      await translateAllText()
    } catch {
      showingTranslationError = true
      print("Recognition failed: \(error)")
    }
  }
  
  func translateAllText() async {
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
        
        guard let highlighter else { return }
        
        var lineNumberingData = LineNumberData()
        lineNumberingData.minWidth = 1
        lineNumberingData.numberStart = 1
        lineNumberingData.fontSize = 16
        
        highlighter.setTheme("atom-one-light")
        
        if let highlightedCode = highlighter.highlight(cleanedCode, as: "python", lineNumbering: lineNumberingData) {
          prettifiedCode = AttributedString(highlightedCode)
          print("Translation complete:\n\(cleanedCode)")
        }
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
  
  func saveCode(image: PhotoData?) throws {
    let translation = Translation(
      id: self.uuid(),
      title: codeTitle,
      image: image?.imageData,
      originalText: recognizer.fullCodeBlock,
      translatedCode: translatedCode,
      prettifiedCode: prettifiedCode
    )
    
    withErrorReporting {
      try database.write { db in
        try Translation
          .insert { translation }
          .execute(db)
      }
    }
  }
  
  private func stripMarkdownCodeBlocks(from text: String) -> String {
    var result = text
    
    result = result.replacingOccurrences(of: #"^```\w*\n?"#, with: "", options: .regularExpression)
    
    result = result.replacingOccurrences(of: #"\n?```$"#, with: "", options: .regularExpression)
    
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
