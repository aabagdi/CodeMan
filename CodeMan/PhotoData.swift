//
//  PhotoData.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import Foundation
import SwiftUI

struct PhotoData: Hashable {
  var image: Image
  var imageData: Data
  var imageSize: (width: Int, height: Int)
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(imageData)
  }
  
  static func == (lhs: PhotoData, rhs: PhotoData) -> Bool {
    lhs.imageData == rhs.imageData
  }
}
