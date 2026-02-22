//
//  RecognitionView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI

struct RecognitionView: View {
  let image: PhotoData?
  var onSave: () -> Void
  
  @Environment(\.colorScheme) private var colorScheme
  
  @State private var viewModel = RecognitionViewModel()
  @State private var showingSaveError: Bool = false
  
  var body: some View {
    ScrollView {
        VStack(spacing: 16) {
          if let image {
            ImageHeaderView(
              image: image.image,
              caption: "Image: \(image.imageSize.width) × \(image.imageSize.height) pixels"
            )
          }
          
          if viewModel.observations.isEmpty && !viewModel.isDoneRecognizing {
            ProgressView("Recognizing text...")
              .padding()
          } else if viewModel.observations.isEmpty && viewModel.isDoneRecognizing {
            Text("No text found in image")
              .foregroundStyle(.secondary)
              .padding()
          } else if !viewModel.hasCodeToTranslate && viewModel.isDoneRecognizing {
            Text("No code found in image")
              .foregroundStyle(.secondary)
              .padding()
          } else {
            if viewModel.hasCodeToTranslate {
              CodeBlockView(
                title: "Original:",
                code: viewModel.fullCodeBlock,
                backgroundColor: .secondary
              )
              
              Divider()
                .padding()
              
              if viewModel.isTranslating {
                HStack {
                  ProgressView()
                  Text("Translating entire code block...")
                    .foregroundStyle(.secondary)
                }
                .padding()
              } else if viewModel.hasTranslatedCode {
                CodeBlockView(
                  title: "Python:",
                  code: viewModel.prettifiedCode,
                  backgroundColor: .green
                )
              } else {
                Text("No code was recognized")
                  .foregroundStyle(.secondary)
                  .padding()
              }
            } else if viewModel.isTranslating {
              HStack {
                ProgressView()
                Text("Processing...")
                  .foregroundStyle(.secondary)
              }
              .padding()
            }
          }
        }
      }
    .sensoryFeedback(.success, trigger: viewModel.hasTranslatedCode)
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button("Save code") {
          viewModel.isShowingNameDialog.toggle()
        }
        .disabled(!viewModel.hasTranslatedCode)
      }
    }
    .alert("Name your code snippet!", isPresented: $viewModel.isShowingNameDialog) {
      TextField("Name", text: $viewModel.codeTitle)
      
      Button("Save") {
        do {
          if (try viewModel.saveCode(image: image)) {
            onSave()
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
    .alert("Translation Error. Please try taking another photo.",
           isPresented: $viewModel.showingTranslationError) {
      Button("OK") {
        viewModel.dismissTranslationError()
      }
    }
    .task {
      guard let imageData = image else { return }
      await viewModel.performRecognitionAndTranslation(for: imageData, colorScheme: colorScheme)
    }
    .onChange(of: colorScheme) {
      viewModel.rehighlight(colorScheme: colorScheme)
    }
  }
}
