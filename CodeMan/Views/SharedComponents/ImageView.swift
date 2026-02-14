//
//  ImageView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI

struct ImageView: View {
  var image: Image?
  var body: some View {
    GeometryReader { geometry in
      if let image {
        image
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: geometry.size.width, height: geometry.size.height)
          .clipped()
      } else {
        Color.black
          .frame(width: geometry.size.width, height: geometry.size.height)
      }
    }
  }
}
