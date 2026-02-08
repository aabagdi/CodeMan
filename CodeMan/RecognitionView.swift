//
//  RecognitionView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI

struct RecognitionView: View {
  let image: PhotoData?
  
  @State private var viewModel = RecognitionViewModel()
  
  var body: some View {
    NavigationStack {
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
    }
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
        try? viewModel.saveCode(image: image)
      }
      
      Button("Cancel", role: .cancel) { }
    }
    .alert("Translation Error: \(viewModel.translationError). Please try taking another photo.",
           isPresented: $viewModel.showingTranslationError) {
      Button("OK") {
        viewModel.dismissTranslationError()
      }
    }
    .task {
      guard let imageData = image else { return }
      await viewModel.performRecognitionAndTranslation(for: imageData)
    }
  }
}
