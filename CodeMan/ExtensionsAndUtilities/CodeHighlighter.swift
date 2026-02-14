//
//  CodeHighlighter.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/14/26.
//

import SwiftUI
import Highlighter
import UIKit

final class CodeHighlighter {
  static let shared = CodeHighlighter()
  
  private let highlighter = Highlighter()
  
  private init() { }
  
  func highlight(_ code: String, colorScheme: ColorScheme) -> AttributedString {
    guard let highlighter, !code.isEmpty else {
      return AttributedString(code)
    }
    
    let theme = colorScheme == .dark ? "atom-one-dark" : "atom-one-light"
    highlighter.setTheme(theme)
    
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
