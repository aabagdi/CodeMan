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
           to idiomatic, Pythonic code. Follow Python best practices (PEP 8) while
           maintaining readability. In your response, only give the code, and no other text.
           
           CRITICAL RULES:
           1. Translate ONLY the exact code provided - do not add, infer, or complete anything
           2. Do NOT generate additional code beyond what is given
           3. Do NOT try to complete incomplete snippets or add missing logic
           4. Do NOT infer what the code is for or add context
           5. If given a partial function, translate only that partial function
           6. If given a single line, translate only that single line
           7. Preserve the exact structure and completeness level of the input
           
           PYTHON BEST PRACTICES - Apply these for Pythonic, readable output:
           
           Naming Conventions:
           - Use snake_case for variables and functions (not camelCase)
           - Use descriptive names: prefer 'total_count' over 'tc'
           - Use UPPER_CASE for constants
           - Use clear, meaningful names even for single letters when appropriate
           
           Idiomatic Python:
           - Use list comprehensions when clearer than loops: [x*2 for x in items]
           - Use 'in' for membership tests: if item in collection
           - Use enumerate() for indexed loops: for i, item in enumerate(items)
           - Use zip() for parallel iteration: for a, b in zip(list1, list2)
           - Prefer 'with' statements for file/resource handling
           - Use f-strings for string formatting: f"Value: {value}"
           - Use .append() for adding single items, .extend() for multiple
           - Use 'is' for None checks: if value is None
           
           Readability:
           - Use 4 spaces for indentation (PEP 8 standard)
           - Add blank lines between logical sections
           - Keep lines under 79 characters when practical
           - Preserve original comments and translate them to Python style
           - Use explicit comparisons for clarity when needed
           
           Data Structures:
           - Use lists for ordered collections: my_list = [1, 2, 3]
           - Use tuples for immutable sequences: coordinates = (x, y)
           - Use sets for unique items: unique_items = {1, 2, 3}
           - Use dicts for key-value pairs: data = {'key': 'value'}
           
           Control Flow:
           - Use 'elif' instead of 'else if'
           - Avoid unnecessary parentheses in conditions
           - Use 'and', 'or', 'not' (not &&, ||, !)
           - Prefer 'for' loops over 'while' when iterating
           
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
           
           Examples of Pythonic translations:
           - "add x to left" → "left.append(x)"
           - "for i from 0 to n" → "for i in range(n):"
           - "var totalCount := 5" → "total_count = 5"
           - "if condition then do something" → "if condition:\n    do_something()"
           - "for each item in list" → "for item in list:"
           - "create empty array" → "arr = []"
           - "length of array" → "len(arr)"
           
           Examples of what NOT to translate (respond with "NOT_CODE"):
           - "Chapter 5: Sorting Algorithms"
           - "The example shows how merge sort works"
           - "Figure 3.2"
           - Regular paragraph text without code-like structure
           
           Remember: Translate EXACTLY what you're given using Pythonic idioms, nothing more, nothing less.
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
    
    return translations
      .joined(separator: "\n")
  }
}
