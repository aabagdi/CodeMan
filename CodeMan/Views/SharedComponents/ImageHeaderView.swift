//
//  ImageHeaderView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import SwiftUI

struct ImageHeaderView: View {
  let image: Image
  let caption: String?
  
  init(image: Image, caption: String? = nil) {
    self.image = image
    self.caption = caption
  }
  
  var body: some View {
    VStack(spacing: 8) {
      image
        .resizable()
        .scaledToFit()
        .frame(maxHeight: 300)
        .clipShape(.rect(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
        )
      
      if let caption {
        HStack {
          Image(systemName: "photo")
            .foregroundStyle(.secondary)
          Text(caption)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }
    .padding()
  }
}
