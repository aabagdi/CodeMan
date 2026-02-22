//
//  TranslationGridView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import SwiftUI
import SQLiteData
import TipKit
import FoundationModels
import Dependencies

struct TranslationGridView: View {
  @State private var inDeletionMode = false
  @State private var selectedTranslationID: Translation.ID?
  @State private var cameraID: UUID
  @State private var navigationPath = NavigationPath()
  @State private var searchText = ""
  @State private var showingUnavailableAlert = false
  @State private var unavailableMessage = ""
  @State private var refreshID: UUID
  
  @Environment(\.scenePhase) private var scenePhase
  
  @FetchAll(Translation.none, animation: .default) var translations: [Translation]
  
  @Dependency(\.defaultDatabase) var database
  @Dependency(\.uuid) var uuid
  
  init() {
    @Dependency(\.uuid) var uuid
    
    self._cameraID = State(initialValue: uuid())
    self._refreshID = State(initialValue: uuid())
  }
  
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
            RecognitionView(image: photoData, onSave: { navigationPath = NavigationPath() })
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
              
              Divider()
              
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
    .task(id: TranslationLoadTrigger(searchText: searchText, refreshID: refreshID)) {
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
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        refreshID = uuid()
      }
    }
    .alert("Apple Intelligence Unavailable", isPresented: $showingUnavailableAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text(unavailableMessage)
    }
  }
  
  private func checkAppleIntelligenceAvailability() -> Bool {
    switch SystemLanguageModel.default.availability {
    case .available:
      return true
    case .unavailable(let reason):
      switch reason {
      case .deviceNotEligible:
        unavailableMessage = "This device doesn't support Apple Intelligence."
      case .appleIntelligenceNotEnabled:
        unavailableMessage = "Please enable Apple Intelligence in Settings to use this feature."
      case .modelNotReady:
        unavailableMessage = "Apple Intelligence is still downloading. Please try again later."
      @unknown default:
        unavailableMessage = "Apple Intelligence is currently unavailable."
      }
      showingUnavailableAlert = true
      return false
    }
  }
    
  @ViewBuilder
    private var contentView: some View {
      if !translations.isEmpty {
        gridView
      } else if !searchText.isEmpty {
        ContentUnavailableView.search(text: searchText)
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
            ForEach(Array(translations.enumerated()), id: \.element.id) { index, item in
              gridItem(for: item, size: max(itemSize, 0))
                .popoverTip(index == 0 ? DeleteTip() : nil)
            }
          }
          .padding(spacing)
        }
        .onTapGesture {
          if inDeletionMode {
            inDeletionMode = false
          }
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
      Button {
        if checkAppleIntelligenceAvailability() {
          navigationPath.append(CameraNavigation.algorithmGenerator)
        }
      } label: {
        Image(systemName: "wand.and.stars")
      }
      .disabled(inDeletionMode)
    }
    
    private func addButtonTapped() {
      if checkAppleIntelligenceAvailability() {
        cameraID = uuid()
        navigationPath.append(CameraNavigation.camera)
      }
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

private struct TranslationLoadTrigger: Equatable {
  let searchText: String
  let refreshID: UUID
}
