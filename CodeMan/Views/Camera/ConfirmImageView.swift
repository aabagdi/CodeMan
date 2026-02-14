//
//  ConfirmImageView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI
import UIKit

struct ConfirmImageView: View {
  @Binding var navigationPath: NavigationPath
  
  @Environment(CameraModel.self) var model
  
  @State private var isCropMode = false
  @State private var rotationAngle: Int = 0
  
  private let headerHeight: CGFloat = 90.0
  
  var body: some View {
    Group {
      if isCropMode, let photoTaken = model.photoTaken {
        ImageCropperView(
          image: photoTaken,
          initialRotation: rotationAngle,
          onCropComplete: { croppedPhoto in
            model.photoTaken = croppedPhoto
            rotationAngle = 0
            isCropMode = false
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
                .rotationEffect(.degrees(Double(rotationAngle)))
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
      }
    }

  }
  
  @ViewBuilder
  private func buttonsView() -> some View {
    HStack {
      Button {
        Task {
          await model.resumePreview()
        }
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
        withAnimation(.easeInOut(duration: 0.2)) {
          rotationAngle = (rotationAngle + 90) % 360
        }
      } label: {
        Label("Rotate", systemImage: "rotate.right")
          .font(.body)
          .foregroundStyle(.white)
      }
      
      Spacer()
      
      Button {
        if let photo = model.photoTaken {
          let imageForRecognition = applyRotation(to: photo)
          navigationPath.append(CameraNavigation.recognition(imageForRecognition))
        }
      } label: {
        Text("Use Image")
          .font(.body.bold())
          .foregroundStyle(.white)
      }
    }
    .padding(.horizontal, 32)
    .padding(.top, 32)
  }
  
  private func applyRotation(to photo: PhotoData) -> PhotoData {
    guard rotationAngle != 0,
          let uiImage = UIImage(data: photo.imageData) else {
      return photo
    }
    
    let rotatedImage: UIImage
    switch rotationAngle {
    case 90:
      rotatedImage = uiImage.rotatedClockwise()
    case 180:
      rotatedImage = uiImage.rotatedClockwise().rotatedClockwise()
    case 270:
      rotatedImage = uiImage.rotatedCounterClockwise()
    default:
      return photo
    }
    
    guard let rotatedData = rotatedImage.jpegData(compressionQuality: 0.9) else {
      return photo
    }
    
    return PhotoData(
      image: Image(uiImage: rotatedImage),
      imageData: rotatedData,
      imageSize: (width: Int(rotatedImage.size.width), height: Int(rotatedImage.size.height))
    )
  }
}
