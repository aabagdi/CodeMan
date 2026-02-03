//
//  PythonTranslater.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import Foundation
import FoundationModels

@Observable
class PythonTranslator {
  private let sessionManager: TranslationSessionManager
  
  init() {
    self.sessionManager = TranslationSessionManager()
  }
  
  func translate(_ input: String) async throws -> String {
    try await sessionManager.translate(input)
  }
}

actor TranslationSessionManager {
  let session: LanguageModelSession
  
  init() {
    let instructions = """
           Your job is to translate pseudocode or handwritten code in ANY language
           to the equivalent Python. Try to be as accurate as possible.
           
           You should translate:
           - All programming code (Swift, Java, C++, JavaScript, etc.)
           - All pseudocode (including statements like "add x to list", "for each element", etc.)
           - Algorithm descriptions written in code-like format
           - Variable assignments (including := notation)
           - Control flow statements (if/then/else, for/while loops)
           - Function/procedure definitions
           - Data structure operations (add, remove, insert, etc.)
           
           IMPORTANT: If the input is clearly not code or pseudocode (e.g., regular prose,
           titles, headers, page numbers, or conversational text that isn't describing an algorithm),
           respond with exactly "NOT_CODE" and nothing else.
           
           Examples of what TO translate:
           - "add x to left"
           - "for each item in list"
           - "var x := 5"
           - "if condition then do something"
           
           Examples of what NOT to translate (respond with "NOT_CODE"):
           - "Chapter 5: Sorting Algorithms"
           - "The example shows how merge sort works"
           - "Figure 3.2"
           """
    
    session = LanguageModelSession(instructions: instructions)
  }
  
  func translate(_ input: String) async throws -> String {
    let maxInputLength = 12000
    
    if input.count > maxInputLength {
      return try await translateInChunks(input, maxLength: maxInputLength)
    }
    
    let result = try await session.respond(to: input)
    let content = result.content.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if content == "NOT_CODE" {
      return ""
    }
    
    return content
  }
  
  private func translateInChunks(_ input: String, maxLength: Int) async throws -> String {
    let lines = input.components(separatedBy: .newlines)
    var chunks: [String] = []
    var currentChunk = ""
    
    for line in lines {
      let testChunk = currentChunk.isEmpty ? line : currentChunk + "\n" + line
      
      if testChunk.count > maxLength && !currentChunk.isEmpty {
        chunks.append(currentChunk)
        currentChunk = line
      } else {
        currentChunk = testChunk
      }
    }
    
    if !currentChunk.isEmpty {
      chunks.append(currentChunk)
    }
    
    var finalChunks: [String] = []
    for chunk in chunks {
      if chunk.count > maxLength {
        var start = chunk.startIndex
        while start < chunk.endIndex {
          let end = chunk.index(start, offsetBy: maxLength, limitedBy: chunk.endIndex) ?? chunk.endIndex
          finalChunks.append(String(chunk[start..<end]))
          start = end
        }
      } else {
        finalChunks.append(chunk)
      }
    }
    
    var translations: [String] = []
    for (index, chunk) in finalChunks.enumerated() {
      print("Translating chunk \(index + 1)/\(finalChunks.count)...")
      let result = try await session.respond(to: chunk)
      let content = result.content.trimmingCharacters(in: .whitespacesAndNewlines)
      
      if content != "NOT_CODE" {
        translations.append(content)
      }
    }
    
    return translations.joined(separator: "\n")
  }
}
