//
//  ConfirmImageView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI

struct ConfirmImageView: View {
  @Environment(CameraModel.self) var model
  
  @State private var saved = false
  
  private let headerHeight: CGFloat = 90.0
  
  var body: some View {
    ZStack {
      ImageView(image: model.photoTaken?.image)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
      
      VStack {
        Spacer()
        
        buttonsView()
          .frame(height: headerHeight)
          .padding(.bottom, 16)
      }
    }
    .background(Color.black)
  }
  
  private func buttonsView() -> some View {
    HStack {
      Button {
        model.photoTaken = nil
      } label: {
        Text("Retake")
          .font(.body)
      }
      
      Spacer()
      
      Button {
        guard let photoTaken = model.photoTaken else { return }
        Task {
          /*
           await model.photoLibraryManager?.savePhoto(imageData: photoTaken.imageData)
           */
          withAnimation {
            self.saved = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
              self.saved = false
            })
          }
        }
        
      } label: {
        Text("Use image")
          .font(.body)
      }
      
    }
    .font(.system(size: 24, weight: .bold))
    .foregroundColor(.white)
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.horizontal, 32)
    .padding(.top, 32)
    
  }
}
