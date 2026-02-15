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
    }
  }
  
  func translateAllText(colorScheme: ColorScheme) async {
    guard hasCodeToTranslate else { return }
    
    isTranslating = true
    
    do {
      let translated = try await translator.translate(recognizer.fullCodeBlock)
      
      if translated.isEmpty || translated == "NOT_CODE" {
        translatedCode = ""
      } else {
        let cleanedCode = translated.strippingMarkdownCodeBlocks()
        
        translatedCode = cleanedCode
        
        prettifiedCode = CodeHighlighter.shared.highlight(cleanedCode, colorScheme: colorScheme)
      }
    } catch {
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
}
