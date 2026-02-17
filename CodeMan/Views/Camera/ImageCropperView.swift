//
//  ImageCropperView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/3/26.
//

import SwiftUI
import UIKit

struct ImageCropperView: View {
  let image: PhotoData
  let initialRotation: Int
  let onCropComplete: (PhotoData) -> Void
  let onCancel: () -> Void
  
  @State private var selectionRect: CGRect = .zero
  @State private var isDragging = false
  @State private var dragStart: CGPoint = .zero
  @State private var imageFrame: CGRect = .zero
  @State private var isResizing = false
  @State private var resizingCorner: Int?
  @State private var rotationAngle: Int = 0
  @State private var cachedRotatedImage: UIImage?
  @State private var cachedRotationAngle: Int = -1

  private func updateRotatedImageIfNeeded() {
    guard cachedRotationAngle != rotationAngle else { return }
    guard let uiImage = UIImage(data: image.imageData) else { return }
    let normalized = uiImage.normalizedImage()
    
    switch rotationAngle {
    case 90:
      cachedRotatedImage = normalized.rotatedClockwise()
    case 180:
      cachedRotatedImage = normalized.rotatedClockwise().rotatedClockwise()
    case 270:
      cachedRotatedImage = normalized.rotatedCounterClockwise()
    default:
      cachedRotatedImage = normalized
    }
    cachedRotationAngle = rotationAngle
  }
  
  private var displayImage: Image {
    if let cached = cachedRotatedImage {
      return Image(uiImage: cached)
    }
    return image.image
  }
  
  var body: some View {
    GeometryReader { geometry in
        ZStack {
          Color.clear
            .onAppear {
              imageFrame = geometry.frame(in: .local)
            }
            .onChange(of: geometry.size) {
              imageFrame = geometry.frame(in: .local)
            }
          
          displayImage
            .resizable()
            .scaledToFit()
          
          if selectionRect != .zero {
            SelectionOverlay(selectionRect: selectionRect, containerSize: geometry.size)
              .allowsHitTesting(false)
            
            ForEach(0..<4, id: \.self) { corner in
              ResizeHandle(
                position: handlePosition(for: corner),
                corner: corner,
                onDrag: { value in
                  handleResize(corner: corner, dragValue: value)
                },
                onEnd: {
                  isResizing = false
                  resizingCorner = nil
                },
                onStart: {
                  isResizing = true
                  resizingCorner = corner
                }
              )
            }
          }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .gesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              guard !isResizing else { return }
              
              let handleRadius: CGFloat = 30
              for corner in 0..<4 {
                let handlePos = handlePosition(for: corner)
                let distance = hypot(value.startLocation.x - handlePos.x,
                                     value.startLocation.y - handlePos.y)
                if distance < handleRadius {
                  return
                }
              }
              
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
        )
      }
      .safeAreaInset(edge: .bottom) {
        HStack {
          Button("Cancel") {
            onCancel()
          }
          .foregroundStyle(.white)
          
          Spacer()
          
          Button {
            withAnimation(.easeInOut(duration: 0.2)) {
              rotationAngle = (rotationAngle + 90) % 360
              selectionRect = .zero
            }
          } label: {
            Label("Rotate", systemImage: "rotate.right")
              .foregroundStyle(.white)
          }
          
          Spacer()
          
          Button("Crop") {
            cropImage()
          }
          .disabled(selectionRect == .zero || selectionRect.width < 10 || selectionRect.height < 10)
          .foregroundStyle(.white)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.6))
      }
      .onAppear {
        rotationAngle = initialRotation
        updateRotatedImageIfNeeded()
      }
      .onChange(of: rotationAngle) {
        updateRotatedImageIfNeeded()
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
  
  private func handleResize(corner: Int, dragValue: DragGesture.Value) {
    let location = dragValue.location
    var newRect = selectionRect
    
    switch corner {
    case 0: // Top-left
      newRect = CGRect(
        x: location.x,
        y: location.y,
        width: selectionRect.maxX - location.x,
        height: selectionRect.maxY - location.y
      )
    case 1: // Top-right
      newRect = CGRect(
        x: selectionRect.minX,
        y: location.y,
        width: location.x - selectionRect.minX,
        height: selectionRect.maxY - location.y
      )
    case 2: // Bottom-left
      newRect = CGRect(
        x: location.x,
        y: selectionRect.minY,
        width: selectionRect.maxX - location.x,
        height: location.y - selectionRect.minY
      )
    case 3: // Bottom-right
      newRect = CGRect(
        x: selectionRect.minX,
        y: selectionRect.minY,
        width: location.x - selectionRect.minX,
        height: location.y - selectionRect.minY
      )
    default:
      break
    }
    
    if newRect.width < 0 {
      newRect = CGRect(x: newRect.maxX, y: newRect.minY, width: abs(newRect.width), height: newRect.height)
    }
    if newRect.height < 0 {
      newRect = CGRect(x: newRect.minX, y: newRect.maxY, width: newRect.width, height: abs(newRect.height))
    }
    
    selectionRect = newRect
  }
  
  private func cropImage() {
    guard let normalizedImage = cachedRotatedImage else { return }
    guard let cgImage = normalizedImage.cgImage else { return }
    
    let displayedSize = imageFrame.size
    let actualSize = CGSize(width: cgImage.width, height: cgImage.height)
    
    let aspectRatio = actualSize.width / actualSize.height
    let displayAspect = displayedSize.width / displayedSize.height
    
    var actualImageFrame = CGRect(origin: .zero, size: displayedSize)
    if displayAspect > aspectRatio {
      let scaledWidth = displayedSize.height * aspectRatio
      actualImageFrame = CGRect(
        x: (displayedSize.width - scaledWidth) / 2,
        y: 0,
        width: scaledWidth,
        height: displayedSize.height
      )
    } else {
      let scaledHeight = displayedSize.width / aspectRatio
      actualImageFrame = CGRect(
        x: 0,
        y: (displayedSize.height - scaledHeight) / 2,
        width: displayedSize.width,
        height: scaledHeight
      )
    }
    
    let relativeRect = CGRect(
      x: (selectionRect.minX - actualImageFrame.minX) / actualImageFrame.width,
      y: (selectionRect.minY - actualImageFrame.minY) / actualImageFrame.height,
      width: selectionRect.width / actualImageFrame.width,
      height: selectionRect.height / actualImageFrame.height
    )
    
    let clampedRect = CGRect(
      x: max(0, min(1, relativeRect.origin.x)),
      y: max(0, min(1, relativeRect.origin.y)),
      width: max(0, min(1 - relativeRect.origin.x, relativeRect.width)),
      height: max(0, min(1 - relativeRect.origin.y, relativeRect.height))
    )
    
    let cropRect = CGRect(
      x: clampedRect.origin.x * actualSize.width,
      y: clampedRect.origin.y * actualSize.height,
      width: clampedRect.width * actualSize.width,
      height: clampedRect.height * actualSize.height
    )
    
    guard let croppedCGImage = cgImage.cropping(to: cropRect) else { return }
    
    let croppedUIImage = UIImage(cgImage: croppedCGImage)
    
    guard let croppedData = croppedUIImage.jpegData(compressionQuality: 0.9) else {
      return
    }
    
    let croppedPhoto = PhotoData(
      image: Image(uiImage: croppedUIImage),
      imageData: croppedData,
      imageSize: (width: croppedCGImage.width, height: croppedCGImage.height)
    )
    
    onCropComplete(croppedPhoto)
  }
}

struct ResizeHandle: View {
  let position: CGPoint
  let corner: Int
  let onDrag: (DragGesture.Value) -> Void
  let onEnd: () -> Void
  let onStart: () -> Void
  
  var body: some View {
    Circle()
      .fill(Color.blue)
      .frame(width: 30, height: 30)
      .overlay(
        Circle()
          .fill(Color.white)
          .frame(width: 20, height: 20)
      )
      .overlay(
        Circle()
          .fill(Color.blue)
          .frame(width: 12, height: 12)
      )
      .position(position)
      .highPriorityGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { value in
            onStart()
            onDrag(value)
          }
          .onEnded { _ in
            onEnd()
          }
      )
  }
}

struct SelectionOverlay: View {
  let selectionRect: CGRect
  let containerSize: CGSize
  
  var body: some View {
    Canvas { context, size in
      context.fill(
        Path(CGRect(origin: .zero, size: size)),
        with: .color(.black.opacity(0.5))
      )
      
      context.blendMode = .destinationOut
      context.fill(
        Path(selectionRect),
        with: .color(.white)
      )
      
      context.blendMode = .normal
      context.stroke(
        Path(selectionRect),
        with: .color(.blue),
        lineWidth: 2
      )
    }
  }
}
