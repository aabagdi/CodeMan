//
//  CodeRecognizerManager.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import Foundation
import Vision
import UIKit

@Observable
@MainActor
class CodeRecognizer {
  var observations = [VNRecognizedTextObservation]()
  var fullCodeBlock = ""
  
  var isDoneRecognizing = false
  
  func performRecognition(_ image: PhotoData) async throws {
    isDoneRecognizing = false
    observations.removeAll()
    fullCodeBlock = ""
    
    let results = try await runVisionRecognition(on: image.imageData)
    
    observations = results
    fullCodeBlock = combineObservationsIntoCodeBlock(results)
    isDoneRecognizing = true
  }
  
  @concurrent
  private func runVisionRecognition(on imageData: Data) async throws -> [VNRecognizedTextObservation] {
    let request = VNRecognizeTextRequest()
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["en-US"]
    request.recognitionLevel = .accurate
    request.minimumTextHeight = 0.0
    
    request.customWords = [
      "add", "var", "list", "left", "right", "each", "index",
      "if", "then", "else", "for", "while", "do", "return"
    ]
    
    guard let cgImage = await Self.createCGImage(from: imageData) else {
      throw NSError(domain: "CodeRecognizer", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage from data"])
    }
    
    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try requestHandler.perform([request])
    
    return request.results ?? []
  }
  
  private func combineObservationsIntoCodeBlock(_ observations: [VNRecognizedTextObservation]) -> String {
    let sortedObservations = observations.sorted { obs1, obs2 in
      obs1.boundingBox.origin.y > obs2.boundingBox.origin.y
    }
    
    let lines = sortedObservations.compactMap { observation -> String? in
      observation.topCandidates(1).first?.string
    }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    
    return lines.joined(separator: "\n")
  }
  
  private static func createCGImage(from data: Data) -> CGImage? {
    guard let uiImage = UIImage(data: data) else {
      return nil
    }
    
    let orientedImage = uiImage.rotatedToPortraitIfNeeded()
    return orientedImage.cgImage
  }
}
