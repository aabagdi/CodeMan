//
//  String+Sanitation.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/15/26.
//

import Foundation

extension String {
  nonisolated func strippingMarkdownCodeBlocks() -> String {
    var result = self
    
    // Remove opening code fence at start (```python, ```swift, etc.)
    result = result.replacing(/^```\w*\n?/, with: "")
    
    // Remove closing code fence at end (``` or ```python, etc.)
    result = result.replacing(/\n?```\w*$/, with: "")
    
    // Remove any standalone code fence lines (with or without language)
    result = result.replacing(/(?m)^```\w*\s*$/, with: "")
    
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  func validatingModelOutput() -> String {
    var validated = self
    
    let leakedTags = [
      "<code_to_translate>",
      "</code_to_translate>",
      "<algorithm_request>",
      "</algorithm_request>",
      "<instruction>",
      "</instruction>",
      "<s>",
      "</s>",
    ]
    
    for tag in leakedTags {
      validated = validated.replacingOccurrences(of: tag, with: "", options: .caseInsensitive)
    }
    
    let codeOutsideStrings = validated.strippingStringLiterals()
    
    let refusalPatterns = [
      "I cannot",
      "I can't",
      "I will not",
      "I won't",
      "As an AI",
      "As a language model",
      "I'm sorry",
      "I apologize",
    ]
    
    for pattern in refusalPatterns {
      if codeOutsideStrings.lowercased().contains(pattern.lowercased()) {
        return ""
      }
    }
    
    return validated.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  func strippingOutputComments() -> String {
    var result = self
    // Removes "# Output:", "# Example output:", "# Expected output:" comments and everything after them
    result = result.replacing(/(?s)\n*\s*#\s*([Ee]xample\s+)?([Ee]xpected\s+)?[Oo]utput:?.*$/, with: "")
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  func escapingDelimiterTags() -> String {
    let tagsToEscape = [
      "<code_to_translate>",
      "</code_to_translate>",
      "<algorithm_request>",
      "</algorithm_request>",
      "<instruction>",
      "</instruction>",
      "<s>",
      "</s>",
    ]
    
    var escaped = self
    for tag in tagsToEscape {
      let escapedTag = tag
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
      escaped = escaped.replacingOccurrences(of: tag, with: escapedTag, options: .caseInsensitive)
    }
    
    return escaped
  }
  
  private func strippingStringLiterals() -> String {
    var result = self
    // Triple-quoted strings first
    result = result.replacing(/"""[\s\S]*?"""/, with: "")
    result = result.replacing(/'''[\s\S]*?'''/, with: "")
    // Single-line strings (handle escaped quotes)
    result = result.replacing(/"(?:[^"\\]|\\.)*"/, with: "")
    result = result.replacing(/'(?:[^'\\]|\\.)*'/, with: "")
    return result
  }
}
