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
  
  @State private var saved = false
  @State private var isCropMode = false
  @State private var selectionRect: CGRect = .zero
  @State private var isDragging = false
  @State private var dragStart: CGPoint = .zero
  @State private var imageFrame: CGRect = .zero
  @State private var croppedImage: PhotoData?
  @State private var navigateToRecognition = false
  
  private let headerHeight: CGFloat = 90.0
  
  var body: some View {
    NavigationStack {
      ZStack {
        GeometryReader { geometry in
          if let photoImage = model.photoTaken?.image {
            photoImage
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
              .background(
                GeometryReader { imageGeometry in
                  Color.clear
                    .onAppear {
                      imageFrame = imageGeometry.frame(in: .local)
                    }
                    .onChange(of: imageGeometry.frame(in: .local)) { _, newFrame in
                      imageFrame = newFrame
                    }
                }
              )
              .overlay {
                if isCropMode {
                  if selectionRect != .zero {
                    Rectangle()
                      .fill(Color.black.opacity(0.6))
                      .mask {
                        Rectangle()
                          .overlay {
                            Rectangle()
                              .frame(width: selectionRect.width, height: selectionRect.height)
                              .position(x: selectionRect.midX, y: selectionRect.midY)
                              .blendMode(.destinationOut)
                          }
                      }
                      .allowsHitTesting(false)
                  }
                  
                  if selectionRect != .zero {
                    Rectangle()
                      .stroke(Color.blue, lineWidth: 3)
                      .frame(width: selectionRect.width, height: selectionRect.height)
                      .position(x: selectionRect.midX, y: selectionRect.midY)
                      .allowsHitTesting(false)
                    
                    ForEach(0..<4, id: \.self) { corner in
                      Circle()
                        .fill(Color.blue)
                        .frame(width: 24, height: 24)
                        .position(handlePosition(for: corner))
                        .allowsHitTesting(false)
                    }
                  }
                }
              }
              .contentShape(Rectangle())
              .gesture(
                isCropMode ? DragGesture(minimumDistance: 0)
                  .onChanged { value in
                    if !isDragging {
                      isDragging = true
                      dragStart = value.startLocation
                      selectionRect = CGRect(
                        x: dragStart.x,
                        y: dragStart.y,
                        width: 0,
                        height: 0
                      )
                    }
                    
                    let currentPoint = value.location
                    let x = min(dragStart.x, currentPoint.x)
                    let y = min(dragStart.y, currentPoint.y)
                    let width = abs(currentPoint.x - dragStart.x)
                    let height = abs(currentPoint.y - dragStart.y)
                    
                    selectionRect = CGRect(x: x, y: y, width: width, height: height)
                  }
                  .onEnded { _ in
                    isDragging = false
                  }
                : nil
              )
          }
        }
        .ignoresSafeArea()
        
        VStack {
          if isCropMode {
            HStack {
              Text("Draw a box around the code")
                .font(.headline)
                .foregroundStyle(.white)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
            }
            .padding(.top, 60)
          }
          
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
  
  private func handlePosition(for corner: Int) -> CGPoint {
    switch corner {
    case 0:
      return CGPoint(x: selectionRect.minX, y: selectionRect.minY)
    case 1:
      return CGPoint(x: selectionRect.maxX, y: selectionRect.minY)
    case 2:
      return CGPoint(x: selectionRect.minX, y: selectionRect.maxY)
    case 3:
      return CGPoint(x: selectionRect.maxX, y: selectionRect.maxY)
    default:
      return .zero
    }
  }
  
  @ViewBuilder
  private func buttonsView() -> some View {
    HStack {
      if isCropMode {
        Button {
          isCropMode = false
          selectionRect = .zero
        } label: {
          Text("Cancel")
            .font(.body)
            .foregroundStyle(.white)
        }
        
        Spacer()
        
        Button {
          if selectionRect.width > 10 && selectionRect.height > 10 {
            cropImage()
            isCropMode = false
            Task { @MainActor in
              try? await Task.sleep(for: .milliseconds(50))
              navigateToRecognition = true
            }
          }
        } label: {
          Text("Apply Crop")
            .font(.body.bold())
            .foregroundStyle(.white)
        }
        .disabled(selectionRect == .zero || selectionRect.width < 10 || selectionRect.height < 10)
        .opacity((selectionRect == .zero || selectionRect.width < 10 || selectionRect.height < 10) ? 0.5 : 1.0)
      } else {
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
    }
    .padding(.horizontal, 32)
    .padding(.top, 32)
  }
  
  private func cropImage() {
    guard let photoTaken = model.photoTaken,
          let uiImage = UIImage(data: photoTaken.imageData) else {
      print("Failed to get image data")
      return
    }

    let normalizedImage = uiImage.normalizedImage()
    
    guard let cgImage = normalizedImage.cgImage else {
      print("Failed to get CGImage from normalized image")
      return
    }
    
    let displayedSize = imageFrame.size
    let actualSize = CGSize(width: cgImage.width, height: cgImage.height)
    
    print("Displayed size: \(displayedSize)")
    print("Actual image size: \(actualSize)")
    print("Selection rect: \(selectionRect)")
    
    let imageAspect = actualSize.width / actualSize.height
    let displayAspect = displayedSize.width / displayedSize.height
    
    var actualImageFrame = CGRect(origin: .zero, size: displayedSize)
    if displayAspect > imageAspect {
      let scaledWidth = displayedSize.height * imageAspect
      actualImageFrame = CGRect(
        x: (displayedSize.width - scaledWidth) / 2,
        y: 0,
        width: scaledWidth,
        height: displayedSize.height
      )
    } else {
      let scaledHeight = displayedSize.width / imageAspect
      actualImageFrame = CGRect(
        x: 0,
        y: (displayedSize.height - scaledHeight) / 2,
        width: displayedSize.width,
        height: scaledHeight
      )
    }
    
    print("Actual image frame: \(actualImageFrame)")
    
    let relativeX = (selectionRect.minX - actualImageFrame.minX) / actualImageFrame.width
    let relativeY = (selectionRect.minY - actualImageFrame.minY) / actualImageFrame.height
    let relativeWidth = selectionRect.width / actualImageFrame.width
    let relativeHeight = selectionRect.height / actualImageFrame.height
    
    let clampedX = max(0, min(1, relativeX))
    let clampedY = max(0, min(1, relativeY))
    let clampedWidth = max(0, min(1 - clampedX, relativeWidth))
    let clampedHeight = max(0, min(1 - clampedY, relativeHeight))
    
    print("Relative rect: x=\(relativeX), y=\(relativeY), w=\(relativeWidth), h=\(relativeHeight)")
    print("Clamped: x=\(clampedX), y=\(clampedY), w=\(clampedWidth), h=\(clampedHeight)")
    
    let cropX = clampedX * CGFloat(cgImage.width)
    let cropY = clampedY * CGFloat(cgImage.height)
    let cropWidth = clampedWidth * CGFloat(cgImage.width)
    let cropHeight = clampedHeight * CGFloat(cgImage.height)
    
    let cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
    
    print("Final crop rect: \(cropRect)")
    
    guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
      print("Failed to crop CGImage")
      return
    }
    
    let croppedUIImage = UIImage(cgImage: croppedCGImage)
    
    guard let croppedData = croppedUIImage.jpegData(compressionQuality: 0.9) else {
      print("Failed to convert to JPEG")
      return
    }
    
    print("Cropped image created: \(croppedCGImage.width) × \(croppedCGImage.height)")
    
    croppedImage = PhotoData(
      image: Image(uiImage: croppedUIImage),
      imageData: croppedData,
      imageSize: (width: croppedCGImage.width, height: croppedCGImage.height)
    )
  }
}
