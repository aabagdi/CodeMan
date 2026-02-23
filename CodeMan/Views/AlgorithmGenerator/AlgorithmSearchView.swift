//
//  AlgorithmSearchView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/14/26.
//

import SwiftUI
import TipKit

struct AlgorithmSearchView: View {
  @Binding var navigationPath: NavigationPath
  
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  
  @State private var viewModel = AlgorithmGeneratorViewModel()
  @State private var showingSaveError: Bool = false
  
  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
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
    .navigationTitle("Generate Algorithm")
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
      Button("Retry") {
        viewModel.dismissError()
        Task {
          await viewModel.generateAlgorithm(colorScheme: colorScheme)
        }
      }
      Button("Cancel", role: .cancel) {
        viewModel.dismissError()
      }
    } message: {
      Text(viewModel.errorMessage.isEmpty
           ? "An unexpected error occurred."
           : viewModel.errorMessage)
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
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "wand.and.stars")
          .font(.title2)
          .foregroundStyle(.tint)
        Text("Describe your algorithm")
          .font(.title3.bold())
      }
      
      TextField("e.g., merge sort, BFS traversal...", text: $viewModel.searchText, axis: .vertical)
        .textFieldStyle(.plain)
        .lineLimit(3...6)
        .disabled(viewModel.isGenerating)
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
      
      Button {
        Task {
          await viewModel.generateAlgorithm(colorScheme: colorScheme)
        }
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "sparkles")
          Text("Generate Python Code")
            .fontWeight(.semibold)
            .popoverTip(GenerateTip())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
      }
      .buttonStyle(.glassProminent)
      .disabled(!viewModel.canGenerate || viewModel.modelUnavailable)
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    .intelligenceBackground(in: RoundedRectangle(cornerRadius: 16))
  }
  
  private var unavailableView: some View {
    ContentUnavailableView {
      Label("Apple Intelligence Unavailable", systemImage: "brain")
    } description: {
      Text("The on-device AI model is not available. Make sure Apple Intelligence is enabled in Settings and your device supports it.")
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }
  
  private var generatingView: some View {
    VStack(spacing: 16) {
      ProgressView()
        .scaleEffect(1.5)
        .tint(.accentColor)
      
      Text("Generating algorithm...")
        .font(.headline)
        .foregroundStyle(.secondary)
      
      Text("Using on-device AI")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 48)
    .padding(.horizontal)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }
  
  private var instructionsView: some View {
    VStack(spacing: 20) {
      VStack(spacing: 12) {
        Image(systemName: "chevron.left.forwardslash.chevron.right")
          .font(.system(size: 44, weight: .light))
          .foregroundStyle(.tint)
        
        Text("Create Python algorithms instantly")
          .font(.headline)
        
        Text("Describe what you need and let AI generate the code for you.")
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
      
      VStack(alignment: .leading, spacing: 12) {
        Text("Try an example")
          .font(.subheadline.bold())
          .foregroundStyle(.secondary)
        
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
          exampleChip("Binary search", icon: "magnifyingglass")
          exampleChip("Bubble sort", icon: "arrow.up.arrow.down")
          exampleChip("DFS traversal", icon: "point.3.connected.trianglepath.dotted")
          exampleChip("Fibonacci", icon: "number")
        }
      }
    }
    .padding()
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }
  
  private func exampleChip(_ text: String, icon: String) -> some View {
    Button {
      withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
        viewModel.searchText = text
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: icon)
          .font(.caption)
          .foregroundStyle(.tint)
        Text(text)
          .font(.subheadline)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .padding(.horizontal, 12)
      .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
    .buttonStyle(.plain)
  }
  
  private var resultSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "checkmark.circle.fill")
          .foregroundStyle(.green)
        Text("Algorithm Generated")
          .font(.headline)
        Spacer()
      }
      .padding(.horizontal)
      
      CodeBlockView(
        title: "Generated Python:",
        code: viewModel.prettifiedCode,
        backgroundColor: .green
      )
    }
    .padding(.vertical)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
  }
}
