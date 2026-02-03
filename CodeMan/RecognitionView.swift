//
//  RecognitionView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI
import Vision

struct RecognitionView: View {
  let image: PhotoData?
  
  @State private var recognizer = CodeRecognizer()
  @State private var translator = PythonTranslator()
  @State private var translatedTexts: [String: String] = [:]
  @State private var isTranslating = false
  
  private var codeObservations: [(Int, VNRecognizedTextObservation)] {
    recognizer.observations.enumerated().compactMap { index, observation in
      let text = observation.topCandidates(1).first?.string ?? ""
      if looksLikeCode(text) && translatedTexts[text] != nil && !translatedTexts[text]!.isEmpty {
        return (index, observation)
      }
      return nil
    }
  }
  
  private var allTranslationsComplete: Bool {
    guard !recognizer.observations.isEmpty else { return false }
    
    for observation in recognizer.observations {
      let text = observation.topCandidates(1).first?.string ?? ""
      if looksLikeCode(text) && translatedTexts[text] == nil {
        return false
      }
    }
    return true
  }
  
  private var combinedPythonOutput: String {
    codeObservations.compactMap { _, observation in
      let text = observation.topCandidates(1).first?.string ?? ""
      return translatedTexts[text]
    }.filter { !$0.isEmpty }
      .joined(separator: "\n")
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
        } else if codeObservations.isEmpty && allTranslationsComplete {
          Text("No code found in image")
            .foregroundStyle(.secondary)
            .padding()
        } else {
          if !codeObservations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
              Text("Original:")
                .font(.headline)
                .padding(.horizontal)
              
              ForEach(codeObservations, id: \.0) { index, observation in
                let originalText = observation.topCandidates(1).first?.string ?? ""
                
                Text(originalText)
                  .font(.system(.body, design: .monospaced))
                  .padding(8)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .background(Color.secondary.opacity(0.1))
                  .cornerRadius(8)
                  .padding(.horizontal)
              }
            }
            
            Divider()
              .padding()
            
            VStack(alignment: .leading, spacing: 8) {
              Text("Python:")
                .font(.headline)
                .padding(.horizontal)
              
              if isTranslating || !allTranslationsComplete {
                HStack {
                  ProgressView()
                  Text("Translating...")
                    .foregroundStyle(.secondary)
                }
                .padding()
              } else {
                ScrollView(.horizontal, showsIndicators: true) {
                  Text(combinedPythonOutput)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                }
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
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
    isTranslating = true
    
    let sortedObservations = recognizer.observations.sorted { obs1, obs2 in
      obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
    }
    
    for observation in sortedObservations {
      let originalText = observation.topCandidates(1).first?.string ?? ""
      guard !originalText.isEmpty else { continue }
      
      guard looksLikeCode(originalText) else {
        print("Skipping non-code text: \(originalText)")
        translatedTexts[originalText] = ""
        continue
      }
      
      do {
        let translated = try await translator.translate(originalText)
        translatedTexts[originalText] = translated
        if translated.isEmpty {
          print("AI filtered out: \(originalText)")
        } else {
          print("Translated: \(originalText) -> \(translated)")
        }
      } catch {
        print("Translation error: \(error)")
        translatedTexts[originalText] = ""
      }
    }
    
    isTranslating = false
  }
  
  private func looksLikeCode(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > 2 else { return false }
    
    let lowercased = trimmed.lowercased()
    
    let obviousNonCode = [
      "top-down implementation",
      "pseudocode for",
      "[ edit ]", "[edit]",
      "page ", "chapter ", "section ", "figure ",
      "http://", "https://", "www."
    ]
    
    for marker in obviousNonCode {
      if lowercased.contains(marker) {
        return false
      }
    }
    
    let words = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
    if words.count > 15 {
      let hasAnyCodeMarker = trimmed.contains(where: { "()[]{}=;:".contains($0) }) ||
                             lowercased.contains("function") ||
                             lowercased.contains(" := ") ||
                             lowercased.contains("var ") ||
                             lowercased.contains("if ") ||
                             lowercased.contains("for ") ||
                             lowercased.contains("return")
      
      if !hasAnyCodeMarker {
        return false
      }
    }
    
    if words.count == 1 {
      let hasSpecialChars = trimmed.contains(where: { "()[]{}=;:".contains($0) })
      return hasSpecialChars
    }
    
    return true
  }
}
