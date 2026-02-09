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
  @State private var cameraID = UUID()
  @State private var navigationPath = NavigationPath()
  
  @FetchAll(animation: .default) var translations: [Translation]
  
  @Dependency(\.defaultDatabase) var database
    
  private let columns = 3
  private let spacing: CGFloat = 12
  
  var body: some View {
    NavigationStack(path: $navigationPath) {
      Group {
        if !translations.isEmpty {
          GeometryReader { g in
            let itemSize = (g.size.width - spacing * CGFloat(columns + 1)) / CGFloat(columns)
            
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
          }
        } else {
          ContentUnavailableView(
            "No algorithms captured",
            systemImage: "camera",
            description: Text("Press the plus button to capture something!")
          )
        }
      }
      .navigationDestination(item: $selectedTranslation) { translation in
        TranslationDetailView(translation: translation)
      }
      .navigationDestination(for: CameraNavigation.self) { destination in
        switch destination {
        case .camera:
          CameraView(navigationPath: $navigationPath)
            .id(cameraID)
        case .recognition(let photoData):
          RecognitionView(image: photoData, navigationPath: $navigationPath)
        }
      }
      .navigationTitle("Captured algorithms")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            cameraID = UUID()
            navigationPath.append(CameraNavigation.camera)
          } label: {
            Image(systemName: "plus")
          }
          .disabled(inDeletionMode)
          
        }
        
        ToolbarItem(placement: .topBarTrailing) {
          NavigationLink(destination: CreditsView()) {
            Text("Credits")
          }
          .disabled(inDeletionMode)
        }
      }
    }
  }
}

enum CameraNavigation: Hashable {
  case camera
  case recognition(PhotoData)
}
