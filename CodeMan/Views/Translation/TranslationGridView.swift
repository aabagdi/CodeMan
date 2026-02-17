//
//  TranslationGridView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import SwiftUI
import SQLiteData
import TipKit

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
          case .algorithmGenerator:
            AlgorithmSearchView(navigationPath: $navigationPath)
          }
        }
        .navigationTitle("Algorithms")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            HStack {
              addButton
                .popoverTip(CaptureTip())
              generateButton
            }
          }
          ToolbarItem(placement: .topBarTrailing) {
            creditsButton
          }
        }
    }
    .searchable(text: $searchText)
    .onChange(of: translations.isEmpty) {
      if translations.isEmpty {
        inDeletionMode = false
      }
    }
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
            ForEach(translations.enumerated(), id: \.offset) { index, item in
              gridItem(for: item, size: max(itemSize, 0))
                .popoverTip(index == 0 ? DeleteTip() : nil)
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
          DeleteButtonView(isPresented: inDeletionMode) {
            deleteTranslation(item)
          }
          .jiggle(inDeletionMode)
          .offset(x: 8, y: -8)
        }
        .onTapGesture { gridItemTapped(item) }
        .onLongPressGesture { inDeletionMode = true }
    }
    
    private func gridItemTapped(_ item: Translation) {
      if inDeletionMode {
        inDeletionMode = false
      } else {
        selectedTranslationID = item.id
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
      Button { addButtonTapped() } label: {
        Image(systemName: "plus")
      }
      .disabled(inDeletionMode)
    }
    
    private var generateButton: some View {
      Button { navigationPath.append(CameraNavigation.algorithmGenerator) } label: {
        Image(systemName: "wand.and.stars")
      }
      .disabled(inDeletionMode)
    }
    
    private func addButtonTapped() {
      cameraID = UUID()
      navigationPath.append(CameraNavigation.camera)
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
  case algorithmGenerator
}
