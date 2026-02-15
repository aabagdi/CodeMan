//
//  AlgorithmSearchView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/14/26.
//

import SwiftUI

struct AlgorithmSearchView: View {
  @Binding var navigationPath: NavigationPath
  
  @Environment(\.colorScheme) private var colorScheme
  
  @State private var viewModel = AlgorithmGeneratorViewModel()
  @State private var showingSaveError: Bool = false
  
  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        promptSection
        
        if viewModel.modelUnavailable {
          unavailableView
        } else if viewModel.isGenerating {
          generatingView
        } else if viewModel.hasGeneratedCode {
          resultSection
        } else {
          instructionsView
        }
      }
      .padding()
    }
    .navigationTitle("Generate algorithm")
    .navigationBarTitleDisplayMode(.inline)
    .sensoryFeedback(.success, trigger: viewModel.hasGeneratedCode)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Save") {
          viewModel.codeTitle = suggestedTitle
          viewModel.isShowingNameDialog.toggle()
        }
        .disabled(!viewModel.hasGeneratedCode)
      }
    }
    .alert("Name your algorithm!", isPresented: $viewModel.isShowingNameDialog) {
      TextField("Name", text: $viewModel.codeTitle)
      
      Button("Save") {
        do {
          if try viewModel.saveCode() {
            navigationPath = NavigationPath()
          }
        } catch {
          showingSaveError = true
        }
      }
      
      Button("Cancel", role: .cancel) { }
    }
    .alert("Save error! Please try again.",
           isPresented: $showingSaveError) {
      Button("OK") {
        showingSaveError = false
      }
    }
    .alert("Algorithm with the same name already exists!",
           isPresented: $viewModel.showingSameNameExistsError) {
      Button("OK") {
        viewModel.showingSameNameExistsError = false
      }
    }
    .alert("Generation Error",
           isPresented: $viewModel.showingError) {
      Button("OK") {
        viewModel.dismissError()
      }
    } message: {
      Text(viewModel.errorMessage)
    }
    .task {
      await viewModel.checkModelAvailability()
    }
    .onChange(of: colorScheme) {
      viewModel.rehighlight(colorScheme: colorScheme)
    }
  }
  
  private var suggestedTitle: String {
    let text = viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    if text.count <= 30 {
      return text.capitalized
    }
    return String(text.prefix(30)).capitalized + "..."
  }
  
  private var promptSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Describe the algorithm you want:")
        .font(.headline)
      
      TextField("e.g., binary search, merge sort, BFS traversal...", text: $viewModel.searchText, axis: .vertical)
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)
        .disabled(viewModel.isGenerating)
      
      Button {
        Task {
          await viewModel.generateAlgorithm(colorScheme: colorScheme)
        }
      } label: {
        HStack {
          Image(systemName: "wand.and.stars")
          Text("Generate Python Code")
        }
        .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .glassEffect()
      .disabled(!viewModel.canGenerate || viewModel.modelUnavailable)
    }
  }
  
  private var unavailableView: some View {
    ContentUnavailableView {
      Label("Apple Intelligence Unavailable", systemImage: "brain")
    } description: {
      Text("The on-device AI model is not available. Make sure Apple Intelligence is enabled in Settings and your device supports it.")
    }
  }
  
  private var generatingView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .scaleEffect(1.5)
      Text("Generating algorithm...")
        .foregroundStyle(.secondary)
    }
    .padding(.vertical, 40)
  }
  
  private var instructionsView: some View {
    VStack(spacing: 16) {
      Image(systemName: "text.badge.plus")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
      
      Text("Enter an algorithm name or description above, then tap Generate to create Python code.")
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
      
      VStack(alignment: .leading, spacing: 8) {
        Text("Examples:")
          .font(.subheadline.bold())
        
        exampleChip("Binary search")
        exampleChip("Bubble sort")
        exampleChip("Depth-first search on a graph")
        exampleChip("Find the nth Fibonacci number")
      }
      .padding()
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
    .padding(.vertical, 20)
  }
  
  private func exampleChip(_ text: String) -> some View {
    Button {
      viewModel.searchText = text
    } label: {
      HStack {
        Image(systemName: "arrow.right.circle.fill")
          .foregroundStyle(.secondary)
        Text(text)
      }
    }
    .buttonStyle(.plain)
  }
  
  private var resultSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Divider()
      
      CodeBlockView(
        title: "Generated Python:",
        code: viewModel.prettifiedCode,
        backgroundColor: .green
      )
    }
  }
}
