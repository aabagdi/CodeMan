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
  @State private var selectedTranslationID: Translation.ID?
  @State private var cameraID = UUID()
  @State private var navigationPath = NavigationPath()
  @State private var searchText = ""
  
  @FetchAll(Translation.none, animation: .default) var translations: [Translation]
  
  @Dependency(\.defaultDatabase) var database
  
  private let columns = 3
  private let spacing: CGFloat = 12
  
  var body: some View {
    NavigationStack(path: $navigationPath) {
      contentView
        .navigationDestination(item: $selectedTranslationID) { translationID in
          TranslationDetailView(translationID: translationID)
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
            addButton
          }
          ToolbarItem(placement: .topBarTrailing) {
            creditsButton
          }
        }
    }
    .searchable(text: $searchText)
    .task(id: searchText) {
      _ = await withErrorReporting {
        if searchText.isEmpty {
          try await $translations.load(
            Translation.order(by: \.title),
            animation: .default)
        } else {
          try await $translations.load(
            Translation.where { $0.title.collate(.nocase).contains(searchText) },
            animation: .default
          )
        }
      }
    }
  }
    
  @ViewBuilder
    private var contentView: some View {
      if !translations.isEmpty {
        gridView
      } else {
        ContentUnavailableView(
          "No algorithms captured",
          systemImage: "camera",
          description: Text("Press the plus button to capture something!")
        )
      }
    }
    
    private var gridView: some View {
      GeometryReader { g in
        let itemSize = (g.size.width - spacing * CGFloat(columns + 1)) / CGFloat(columns)
        
        ScrollView {
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns), spacing: spacing) {
            ForEach(translations) { item in
              gridItem(for: item, size: max(itemSize, 0))
            }
          }
          .padding(spacing)
        }
      }
    }
    
    private func gridItem(for item: Translation, size: CGFloat) -> some View {
      TranslationGridItemView(translation: item, size: size)
        .jiggle(inDeletionMode)
        .overlay(alignment: .topTrailing) {
          DeleteButtonView(isPresented: $inDeletionMode) {
            deleteTranslation(item)
          }
          .jiggle(inDeletionMode)
          .offset(x: 8, y: -8)
        }
        .onTapGesture {
          if inDeletionMode {
            inDeletionMode = false
          } else {
            selectedTranslationID = item.id
          }
        }
        .onLongPressGesture {
          inDeletionMode = true
        }
    }
    
    private func deleteTranslation(_ item: Translation) {
      withErrorReporting {
        try database.write { db in
          try Translation.find(item.id)
            .delete()
            .execute(db)
        }
      }
    }
    
    private var addButton: some View {
      Button {
        cameraID = UUID()
        navigationPath.append(CameraNavigation.camera)
      } label: {
        Image(systemName: "plus")
      }
      .disabled(inDeletionMode)
    }
    
    private var creditsButton: some View {
      NavigationLink(destination: CreditsView()) {
        Text("Credits")
      }
      .disabled(inDeletionMode)
    }
  
}
enum CameraNavigation: Hashable {
  case camera
  case recognition(PhotoData)
}
