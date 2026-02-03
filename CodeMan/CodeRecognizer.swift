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
class CodeRecognizer {
  var observations = [VNRecognizedTextObservation]()
  
  var isDoneRecognizing = false
  
  func performRecognition(_ image: PhotoData) async throws {
    isDoneRecognizing = false
    observations.removeAll()
    
    let request = VNRecognizeTextRequest()
    request.usesLanguageCorrection = false
    request.recognitionLanguages = ["en-US"]
    request.recognitionLevel = .accurate
    request.minimumTextHeight = 0.0
    
    request.customWords = [
      "add", "var", "list", "left", "right", "each", "index",
      "if", "then", "else", "for", "while", "do", "return"
    ]
    
    guard let cgImage = createCGImage(from: image.imageData) else {
      throw NSError(domain: "CodeRecognizer", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create CGImage from data"])
    }
    
    let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    
    try requestHandler.perform([request])
    
    if let results = request.results {
      observations = results
    }
    
    isDoneRecognizing = true
  }
  
  private func createCGImage(from data: Data) -> CGImage? {
#if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    guard let uiImage = UIImage(data: data),
          let cgImage = uiImage.cgImage else {
      return nil
    }
    return cgImage
#elseif os(macOS)
    guard let nsImage = NSImage(data: data),
          let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
      return nil
    }
    return cgImage
#endif
  }
}
