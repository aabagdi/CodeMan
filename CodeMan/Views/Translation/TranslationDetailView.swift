//
//  TranslationDetailView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import Foundation
import SwiftUI
import SQLiteData

struct TranslationDetailView: View {
  let translationID: Translation.ID
  
  @FetchOne var translation: Translation?
  
  @Environment(\.colorScheme) private var colorScheme
  
  init(translationID: Translation.ID) {
    self.translationID = translationID
    _translation = FetchOne(Translation.find(translationID))
  }
  
  private var highlightedCode: AttributedString {
    guard let code = translation?.translatedCode, !code.isEmpty else {
      return AttributedString()
    }
    return CodeHighlighter.shared.highlight(code, colorScheme: colorScheme)
  }
  
  var body: some View {
    ScrollView {
      if let translation {
        VStack(spacing: 16) {
          if let uiImage = UIImage(data: translation.image ?? Data()) {
            ImageHeaderView(image: Image(uiImage: uiImage))
          }
          
          CodeBlockView(
            title: "Original:",
            code: translation.originalText,
            backgroundColor: .secondary
          )
          
          Divider()
            .padding()
          
          CodeBlockView(
            title: "Python:",
            code: highlightedCode,
            backgroundColor: .green
          )
        }
        .navigationTitle(translation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            NavigationLink(destination: CodeEditAndExecutionView(translationID: translationID)) {
              Text("Edit and run code")
            }
          }
        }
      }
    }
  }
}
