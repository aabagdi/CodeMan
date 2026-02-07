//
//  ConfirmImageView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI
import UIKit

struct ConfirmImageView: View {
  @Environment(CameraModel.self) var model
  
  @State private var isCropMode = false
  @State private var croppedImage: PhotoData?
  @State private var navigateToRecognition = false
  
  private let headerHeight: CGFloat = 90.0
  
  var body: some View {
    NavigationStack {
      if isCropMode, let photoTaken = model.photoTaken {
        ImageCropperView(
          image: photoTaken,
          onCropComplete: { croppedPhoto in
            croppedImage = croppedPhoto
            isCropMode = false
            navigateToRecognition = true
          },
          onCancel: {
            isCropMode = false
          }
        )
      } else {
        ZStack {
          GeometryReader { geometry in
            if let photoImage = model.photoTaken?.image {
              photoImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
          }
          .ignoresSafeArea()
          
          VStack {
            Spacer()
            
            buttonsView()
              .frame(height: headerHeight)
              .padding(.bottom, 16)
          }
        }
        .background(Color.black)
        .navigationDestination(isPresented: $navigateToRecognition) {
          RecognitionView(image: croppedImage ?? model.photoTaken)
        }
      }
    }
  }
  
  @ViewBuilder
  private func buttonsView() -> some View {
    HStack {
      Button {
        model.photoTaken = nil
      } label: {
        Text("Retake")
          .font(.body)
          .foregroundStyle(.white)
      }
      
      Spacer()
      
      Button {
        isCropMode = true
      } label: {
        Label("Crop", systemImage: "crop")
          .font(.body)
          .foregroundStyle(.white)
      }
      
      Spacer()
      
      Button {
        croppedImage = nil
        navigateToRecognition = true
      } label: {
        Text("Use Full Image")
          .font(.body.bold())
          .foregroundStyle(.white)
      }
    }
    .padding(.horizontal, 32)
    .padding(.top, 32)
  }
}
