//
//  UIImage+Extensions.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/3/26.
//

import Foundation
import UIKit

extension UIImage {
  func normalizedImage() -> UIImage {
    if imageOrientation == .up {
      return self
    }
    
    UIGraphicsBeginImageContextWithOptions(size, false, scale)
    draw(in: CGRect(origin: .zero, size: size))
    let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    
    return normalizedImage ?? self
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
}
