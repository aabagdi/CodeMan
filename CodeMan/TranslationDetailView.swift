//
//  TranslationDetailView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import Foundation
import SwiftUI

struct TranslationDetailView: View {
  @State var translation: Translation
  
  var body: some View {
    ScrollView {
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
          code: translation.prettifiedCode ?? AttributedString(),
          backgroundColor: .green
        )
      }
    }
    .navigationTitle(translation.title)
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        NavigationLink(destination: CodeEditorView(translation: $translation)) {
          Text("Edit and run code")
        }
      }
    }
  }
}
