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
  @State private var showCamera = false
  @State private var cameraID = UUID()
  
  @FetchAll(animation: .default) var translations: [Translation]
  
  @Dependency(\.defaultDatabase) var database
    
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
                .overlay(alignment: .topTrailing) {
                  DeleteButtonView(isPresented: $inDeletionMode) {
                    withErrorReporting {
                      try database.write { db in
                        try Translation.find(item.id)
                          .delete()
                          .execute(db)
                      }
                    }
                  }
                  .jiggle(inDeletionMode)
                  .offset(x: 8, y: -8)
                }
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
        .navigationDestination(isPresented: $showCamera) {
          CameraView()
            .id(cameraID)
        }
        .onChange(of: showCamera) { oldValue, newValue in
          if newValue {
            cameraID = UUID()
          }
        }
        .navigationTitle("Captured algorithms")
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              showCamera = true
            } label: {
              Image(systemName: "plus")
            }
            .disabled(inDeletionMode)
          }
        }
      }
    }
  }
}
