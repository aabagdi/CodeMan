//
//  AlgorithmGeneratorViewModel.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/14/26.
//

import SwiftUI
import SQLiteData

@Observable
@MainActor
final class AlgorithmGeneratorViewModel {
  @ObservationIgnored
  @Dependency(\.defaultDatabase) var database
  
  @ObservationIgnored
  @Dependency(\.uuid) var uuid
  
  private let generator = AlgorithmGenerator()
  
  var searchText: String = ""
  var generatedCode: String = ""
  var prettifiedCode: AttributedString = ""
  var isGenerating: Bool = false
  var showingError: Bool = false
  var errorMessage: String = ""
  var isShowingNameDialog: Bool = false
  var codeTitle: String = ""
  var showingSameNameExistsError: Bool = false
  var modelUnavailable: Bool = false
  
  var hasGeneratedCode: Bool {
    !String(prettifiedCode.characters).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  var canGenerate: Bool {
    !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
  }
  
  func checkModelAvailability() async {
    modelUnavailable = await !generator.isAvailable
  }
  
  func generateAlgorithm(colorScheme: ColorScheme) async {
    let prompt = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !prompt.isEmpty else { return }
    
    isGenerating = true
    generatedCode = ""
    prettifiedCode = ""
    
    do {
      let code = try await generator.generate(from: prompt)
      generatedCode = code
      prettifiedCode = CodeHighlighter.shared.highlight(code, colorScheme: colorScheme)
    } catch {
      errorMessage = error.localizedDescription
      showingError = true
    }
    
    isGenerating = false
  }
  
  func rehighlight(colorScheme: ColorScheme) {
    guard !generatedCode.isEmpty else { return }
    prettifiedCode = CodeHighlighter.shared.highlight(generatedCode, colorScheme: colorScheme)
  }
  
  func saveCode() throws -> Bool {
    let exists = try database.read { db in
      try Translation.where { $0.title.eq(codeTitle) }.fetchCount(db) > 0
    }
    
    if !exists {
      let translation = Translation(
        id: self.uuid(),
        title: codeTitle,
        image: nil,
        originalText: searchText,
        translatedCode: generatedCode
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
  
  func dismissError() {
    errorMessage = ""
    showingError = false
  }
}
