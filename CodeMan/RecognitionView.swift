//
//  RecognitionView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI
import Vision
import Highlightr

struct RecognitionView: View {
  let image: PhotoData?
  
  @State private var recognizer = CodeRecognizer()
  @State private var translator = PythonTranslator()
  @State private var translatedCode: AttributedString = ""
  @State private var isTranslating = false
  
  private var hasCodeToTranslate: Bool {
    !recognizer.fullCodeBlock.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  private var hasTranslatedCode: Bool {
    !String(translatedCode.characters).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  var body: some View {
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
        
        if recognizer.observations.isEmpty && !recognizer.isDoneRecognizing {
          ProgressView("Recognizing text...")
            .padding()
        } else if recognizer.observations.isEmpty && recognizer.isDoneRecognizing {
          Text("No text found in image")
            .foregroundStyle(.secondary)
            .padding()
        } else if !hasCodeToTranslate && recognizer.isDoneRecognizing {
          Text("No code found in image")
            .foregroundStyle(.secondary)
            .padding()
        } else {
          if hasCodeToTranslate {
            VStack(alignment: .leading, spacing: 8) {
              Text("Original:")
                .font(.headline)
                .padding(.horizontal)
              
              ScrollView(.horizontal, showsIndicators: true) {
                Text(recognizer.fullCodeBlock)
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
              
              if isTranslating {
                HStack {
                  ProgressView()
                  Text("Translating entire code block...")
                    .foregroundStyle(.secondary)
                }
                .padding()
              } else if hasTranslatedCode {
                ScrollView(.horizontal, showsIndicators: true) {
                  Text(translatedCode)
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
          } else if isTranslating {
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
    .task {
      guard let imageData = image else { return }
      do {
        try await recognizer.performRecognition(imageData)
        await translateAllText()
      } catch {
        print("Recognition failed: \(error)")
      }
    }
  }
  
  private func translateAllText() async {
    guard hasCodeToTranslate else {
      print("No code to translate")
      return
    }
    
    isTranslating = true
    
    do {
      print("Translating entire code block:\n\(recognizer.fullCodeBlock)")
      let translated = try await translator.translate(recognizer.fullCodeBlock)
      
      if translated.isEmpty || translated == "NOT_CODE" {
        print("AI filtered out the code block")
        translatedCode = ""
      } else {
        let cleanedCode = stripMarkdownCodeBlocks(from: translated)
        
        let highlightr = Highlightr()
        
        highlightr?.setTheme(to: "paraiso-dark")
        
        let highlightedCode = highlightr?.highlight(cleanedCode, as: "python") ?? NSAttributedString(string: "Syntax highlighting error")
        translatedCode = AttributedString(highlightedCode)
        print("Translation complete:\n\(cleanedCode)")
      }
    } catch {
      print("Translation error: \(error)")
      translatedCode = ""
    }
    
    isTranslating = false
  }
  
  private func stripMarkdownCodeBlocks(from text: String) -> String {
    var result = text
    
    result = result.replacingOccurrences(of: #"^```\w*\n?"#, with: "", options: .regularExpression)
    
    result = result.replacingOccurrences(of: #"\n?```$"#, with: "", options: .regularExpression)
    
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
