//
//  UIImage+Extensions.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/3/26.
//

import Foundation
import ImageIO
import UIKit

extension UIImage {
  func normalizedImage() -> UIImage {
    if imageOrientation == .up {
      return self
    }
    
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }
  
  var isLandscape: Bool {
    size.width > size.height
  }
  
  func rotatedClockwise() -> UIImage {
    let newSize = CGSize(width: size.height, height: size.width)
    
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { context in
      context.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
      context.cgContext.rotate(by: .pi / 2)
      draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
    }
  }
  
  func rotatedCounterClockwise() -> UIImage {
    let newSize = CGSize(width: size.height, height: size.width)
    
    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { context in
      context.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
      context.cgContext.rotate(by: -.pi / 2)
      draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
    }
  }
  
  func rotatedToPortraitIfNeeded() -> UIImage {
    guard isLandscape else { return self }
    return rotatedClockwise()
  }
  
  func withDisplayRotation(_ angle: Int) -> UIImage {
    guard let cgImage else { return self }
    let orientation: UIImage.Orientation
    switch angle {
    case 90:
      orientation = .right
    case 180:
      orientation = .down
    case 270:
      orientation = .left
    default:
      return self
    }
    return UIImage(cgImage: cgImage, scale: scale, orientation: orientation)
  }
}

extension Data {
  func applyingEXIFOrientation(for angle: Int) -> Data? {
    guard angle != 0 else { return self }
    
    // EXIF orientation values for rotations applied to an already-upright image
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
