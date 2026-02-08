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
            VStack(spacing: 8) {
              image.image
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .cornerRadius(12)
                .overlay(
                  RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                )
              
              HStack {
                Image(systemName: "photo")
                  .foregroundStyle(.secondary)
                Text("Image: \(image.imageSize.width) × \(image.imageSize.height) pixels")
                  .font(.caption)
                  .foregroundStyle(.secondary)
              }
            }
            .padding()
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
              VStack(alignment: .leading, spacing: 8) {
                Text("Original:")
                  .font(.headline)
                  .padding(.horizontal)
                
                ScrollView(.horizontal, showsIndicators: true) {
                  Text(viewModel.fullCodeBlock)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
              }
              
              Divider()
                .padding()
              
              VStack(alignment: .leading, spacing: 8) {
                Text("Python:")
                  .font(.headline)
                  .padding(.horizontal)
                
                if viewModel.isTranslating {
                  HStack {
                    ProgressView()
                    Text("Translating entire code block...")
                      .foregroundStyle(.secondary)
                  }
                  .padding()
                } else if viewModel.hasTranslatedCode {
                  ScrollView(.horizontal, showsIndicators: true) {
                    Text(viewModel.prettifiedCode)
                      .font(.system(.body, design: .monospaced))
                      .padding()
                      .frame(maxWidth: .infinity, alignment: .leading)
                      .textSelection(.enabled)
                  }
                  .background(Color.green.opacity(0.1))
                  .cornerRadius(8)
                  .padding(.horizontal)
                } else {
                  Text("No code was recognized")
                    .foregroundStyle(.secondary)
                    .padding()
                }
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
