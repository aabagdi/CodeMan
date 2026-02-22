//
//  ConfirmImageView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI
import UIKit

struct ConfirmImageView: View {
  var onSave: () -> Void
  
  @Environment(CameraModel.self) var model
  @Environment(\.dismiss) private var dismissCover
  
  @State private var isCropMode = false
  @State private var rotationAngle: Int = 0
  @State private var normalizedImage: UIImage?
  @State private var navPath = NavigationPath()
  @State private var didSave = false
  @State private var shouldDismiss = false
  
  private let headerHeight: CGFloat = 90.0
  
  var body: some View {
    let dismissAction = dismissCover
    NavigationStack(path: $navPath) {
      Group {
        if isCropMode, let normalized = normalizedImage {
          ImageCropperView(
            normalizedImage: normalized,
            rotationAngle: rotationAngle,
            onCropComplete: { croppedPhoto in
              model.photoTaken = croppedPhoto
              rotationAngle = 0
              normalizedImage = nil
              isCropMode = false
            },
            onCancel: {
              isCropMode = false
            }
          )
          .toolbar(.hidden, for: .navigationBar)
        } else {
          ZStack {
            if let photoImage = model.photoTaken?.image {
              photoImage
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .rotationEffect(.degrees(Double(rotationAngle)))
            }
            
            VStack {
              Spacer()
              
              buttonsView()
                .frame(height: headerHeight)
                .padding(.bottom, 16)
            }
          }
          .ignoresSafeArea()
          .background(Color.black)
          .toolbar(.hidden, for: .navigationBar)
        }
      }
      .navigationDestination(for: PhotoData.self) { photo in
        RecognitionView(image: photo, onSave: {
          didSave = true
        })
        .navigationTitle("Recognized Code")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              dismissAction()
            } label: {
              HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                Text("Back")
              }
            }
          }
        }
      }
    }
    .onAppear {
      prepareNormalizedImage()
    }
    .onChange(of: isCropMode) {
      if !isCropMode && normalizedImage == nil {
        prepareNormalizedImage()
      }
    }
    .onChange(of: didSave) {
      if didSave {
        onSave()
        dismissAction()
      }
    }
    .onChange(of: shouldDismiss) {
      if shouldDismiss {
        dismissAction()
      }
    }
  }
  
  @ViewBuilder
  private func buttonsView() -> some View {
    HStack {
      Button { retakeButtonTapped() } label: {
        Text("Retake")
          .font(.body)
          .foregroundStyle(.white)
      }
      
      Spacer()
      
      Button { enterCropMode() } label: {
        Label("Crop", systemImage: "crop")
          .font(.body)
          .foregroundStyle(.white)
      }
      
      Spacer()
      
      Button { rotateButtonTapped() } label: {
        Label("Rotate", systemImage: "rotate.right")
          .font(.body)
          .foregroundStyle(.white)
      }
      
      Spacer()
      
      Button { useImageButtonTapped() } label: {
        Text("Use Image")
          .font(.body.bold())
          .foregroundStyle(.white)
      }
    }
    .padding(.horizontal, 32)
    .padding(.top, 32)
  }
  
  private func prepareNormalizedImage() {
    guard let photo = model.photoTaken,
          let uiImage = UIImage(data: photo.imageData) else { return }
    normalizedImage = uiImage.normalizedImage()
  }
  
  private func enterCropMode() {
    guard normalizedImage != nil else { return }
    isCropMode = true
  }
  
  private func retakeButtonTapped() {
    shouldDismiss = true
  }
  
  private func rotateButtonTapped() {
    withAnimation(.easeInOut(duration: 0.2)) {
      rotationAngle = (rotationAngle + 90) % 360
    }
  }
  
  private func useImageButtonTapped() {
    guard let photo = model.photoTaken else { return }
    
    let photoForRecognition: PhotoData
    if rotationAngle != 0,
       let rotatedData = photo.imageData.applyingEXIFOrientation(for: rotationAngle) {
      let displayImage: Image
      if let normalized = normalizedImage {
        displayImage = Image(uiImage: normalized.withDisplayRotation(rotationAngle))
      } else {
        displayImage = photo.image
      }
      let isSwapped = rotationAngle == 90 || rotationAngle == 270
      photoForRecognition = PhotoData(
        image: displayImage,
        imageData: rotatedData,
        imageSize: isSwapped
          ? (width: photo.imageSize.height, height: photo.imageSize.width)
          : photo.imageSize
      )
    } else {
      photoForRecognition = photo
    }
    
    navPath.append(photoForRecognition)
  }
}
