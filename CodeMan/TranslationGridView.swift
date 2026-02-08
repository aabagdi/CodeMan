//
//  TranslationGridView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import SwiftUI
import SQLiteData

struct TranslationGridView: View {
  @State private var inDeletionMode = false
  @State private var selectedTranslation: Translation?
  
  @FetchAll(animation: .default) var translations: [Translation]
    
  private let columns = 3
  private let spacing: CGFloat = 12
  
  var body: some View {
    GeometryReader { g in
      let itemSize = (g.size.width - spacing * CGFloat(columns + 1)) / CGFloat(columns)
      
      NavigationStack {
        ScrollView {
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns), spacing: spacing) {
            ForEach(translations) { item in
              TranslationGridItemView(translation: item, size: max(itemSize, 0))
                .jiggle(inDeletionMode)
                .onTapGesture {
                  if inDeletionMode {
                    inDeletionMode = false
                  } else {
                    selectedTranslation = item
                  }
                }
                .onLongPressGesture {
                  inDeletionMode = true
                }
            }
          }
          .padding(spacing)
        }
        .navigationDestination(item: $selectedTranslation) { translation in
          TranslationDetailView(translation: translation)
        }
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            NavigationLink(destination: CameraView()) {
              Image(systemName: "plus")
            }
            .disabled(inDeletionMode)
          }
        }
      }
    }
  }
}
