//
//  TranslationGridItemView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import SwiftUI

struct TranslationGridItemView: View {
  let translation: Translation
  let size: CGFloat
  @Environment(\.displayScale) private var displayScale
  
  var body: some View {
    VStack {
      thumbnailView
      
      Text(translation.title)
        .font(.caption2)
        .bold()
        .lineLimit(1)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(translation.title)
  }
  
  @ViewBuilder
  private var thumbnailView: some View {
    if let imageData = translation.image,
       let thumbnail = downsampledImage(from: imageData, targetSize: CGSize(width: size * 2, height: size * 2)) {
      Image(uiImage: thumbnail)
        .resizable()
        .scaledToFill()
        .frame(width: size, height: size)
        .contentShape(Rectangle())
        .clipped()
        .clipShape(.rect(cornerRadius: 5))
    } else {
      Image(systemName: "chevron.left.forwardslash.chevron.right")
        .font(.system(size: size * 0.4))
        .frame(width: size, height: size)
        .background(Color.gray.opacity(0.2))
        .clipShape(.rect(cornerRadius: 5))
    }
  }
  
  private func downsampledImage(from data: Data, targetSize: CGSize) -> UIImage? {
    let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
    guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
      return nil
    }
    
    let maxDimension = max(targetSize.width, targetSize.height) * displayScale
    let downsampleOptions = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceShouldCacheImmediately: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: maxDimension
    ] as CFDictionary
    
    guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
      return nil
    }
    
    return UIImage(cgImage: downsampledImage)
  }
}
