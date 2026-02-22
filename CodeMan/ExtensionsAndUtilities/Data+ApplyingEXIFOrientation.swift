//
//  Data+ApplyingEXIFOrientation.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/22/26.
//

import Foundation
import ImageIO

extension Data {
  func applyingEXIFOrientation(for angle: Int) -> Data? {
    guard angle != 0 else { return self }
    
    let exifOrientation: Int
    switch angle {
    case 90:
      exifOrientation = 6   // Rotated 90° CW
    case 180:
      exifOrientation = 3   // Rotated 180°
    case 270:
      exifOrientation = 8   // Rotated 270° CW (90° CCW)
    default:
      return self
    }
    
    guard let source = CGImageSourceCreateWithData(self as CFData, nil),
          let uti = CGImageSourceGetType(source) else {
      return nil
    }
    
    let mutableData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(mutableData, uti, 1, nil) else {
      return nil
    }
    
    let properties: [CFString: Any] = [
      kCGImagePropertyOrientation: exifOrientation
    ]
    
    CGImageDestinationAddImageFromSource(destination, source, 0, properties as CFDictionary)
    
    guard CGImageDestinationFinalize(destination) else {
      return nil
    }
    
    return mutableData as Data
  }
}
