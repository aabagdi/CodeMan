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
}
