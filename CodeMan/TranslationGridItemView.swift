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
  
  var body: some View {
    VStack {
      if let imageData = translation.image, let thumbnail = UIImage(data: imageData) {
        Image(uiImage: thumbnail)
          .resizable()
          .scaledToFill()
          .frame(width: size, height: size)
          .clipped()
          .clipShape(RoundedRectangle(cornerRadius: 5))
      } else {
        Image(systemName: "questionmark.text.page")
          .font(.system(size: size * 0.4))
          .frame(width: size, height: size)
          .background(Color.gray.opacity(0.2))
          .clipShape(RoundedRectangle(cornerRadius: 5))
      }
      
      Text(translation.title)
        .font(.caption2)
        .lineLimit(1)
    }
  }
}
