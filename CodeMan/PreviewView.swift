//
//  PreviewVie.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI

struct PreviewView: View {
  @Environment(CameraModel.self) var model
  private let footerHeight: CGFloat = 110.0
  
  var body: some View {
    GeometryReader { geometry in
      ImageView(image: model.previewImage)
        .frame(width: geometry.size.width, height: geometry.size.height)
        .overlay(alignment: .bottom) {
          buttonsView()
            .frame(height: footerHeight)
            .padding(.bottom, 40)
        }
    }
    .ignoresSafeArea()
  }
  
  private func buttonsView() -> some View {
    HStack {
      Spacer()
      
      Button {
        Task {
          try await model.camera.takePhoto()
        }
      } label: {
        ZStack {
          Circle()
            .strokeBorder(.white, lineWidth: 3)
            .frame(width: 72, height: 72)
          Circle()
            .fill(.white)
            .frame(width: 62, height: 62)
        }
      }
      .buttonStyle(.plain)
      
      Spacer()
    }
    .padding(.horizontal, 20)
    .frame(maxWidth: .infinity)
  }
}
