//
//  TranslationDetailView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import Foundation
import SwiftUI
import SQLiteData
import TipKit

struct TranslationDetailView: View {
  let translationID: Translation.ID
  
  @FetchOne var translation: Translation?
  
  @Environment(\.colorScheme) private var colorScheme
  
  @State private var pythonFileURL: URL?
  
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
          .popoverTip(CopyTip())
        }
        .navigationTitle(translation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            HStack {
              NavigationLink(destination: CodeEditAndExecutionView(translationID: translationID)) {
                Image(systemName: "play.fill")
              }
              
              Divider()
              
              if let pythonFileURL {
                ShareLink(item: pythonFileURL) {
                  Image(systemName: "square.and.arrow.up")
                    .offset(x: -2, y: -3)
                }
              }
            }
          }
        }
      }
    }
    .onChange(of: translation, initial: true) {
      pythonFileURL = preparePythonFileURL()
    }
  }
  
  private func preparePythonFileURL() -> URL? {
    guard let translation, let code = translation.translatedCode else { return nil }
    let tempDir = FileManager.default.temporaryDirectory
    let fileName = "\(translation.title).py"
    let fileURL = tempDir.appendingPathComponent(fileName)
    try? code.write(to: fileURL, atomically: true, encoding: .utf8)
    return fileURL
  }
}
