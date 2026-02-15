//
//  String+MarkdownStripping.swift
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
}
