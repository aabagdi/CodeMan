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
    if let image {
      image
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    } else {
      Color.black
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
