//
//  ImageCropperView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/3/26.
//

import SwiftUI
import UIKit

struct ImageCropperView: View {
  let normalizedImage: UIImage
  let rotationAngle: Int
  let onCropComplete: (PhotoData) -> Void
  let onCancel: () -> Void
  
  @State private var selectionRect: CGRect = .zero
  @State private var isDragging = false
  @State private var dragStart: CGPoint = .zero
  @State private var imageFrame: CGRect = .zero
  @State private var isResizing = false
  @State private var resizingCorner: Int?
  
  var body: some View {
    GeometryReader { geometry in
        ZStack {
          Color.black
            .onAppear {
              imageFrame = geometry.frame(in: .local)
            }
            .onChange(of: geometry.size) {
              imageFrame = geometry.frame(in: .local)
            }
          
          Image(uiImage: normalizedImage.withDisplayRotation(rotationAngle))
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
      .ignoresSafeArea()
      .safeAreaInset(edge: .bottom) {
        HStack {
          Button("Cancel") {
            onCancel()
          }
          .foregroundStyle(.white)
          
          Spacer()
          
          Button("Crop") {
            cropImage()
          }
          .disabled(selectionRect == .zero || selectionRect.width < 10 || selectionRect.height < 10)
          .foregroundStyle(.white)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(Color.black)
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
    guard let cgImage = normalizedImage.cgImage else { return }
    
    let displayImage = normalizedImage.withDisplayRotation(rotationAngle)
    let rotatedW = displayImage.size.width
    let rotatedH = displayImage.size.height
    
    let containerSize = imageFrame.size
    let aspectRatio = rotatedW / rotatedH
    let displayAspect = containerSize.width / containerSize.height
    
    var displayFrame: CGRect
    if displayAspect > aspectRatio {
      let scaledWidth = containerSize.height * aspectRatio
      displayFrame = CGRect(
        x: (containerSize.width - scaledWidth) / 2,
        y: 0,
        width: scaledWidth,
        height: containerSize.height
      )
    } else {
      let scaledHeight = containerSize.width / aspectRatio
      displayFrame = CGRect(
        x: 0,
        y: (containerSize.height - scaledHeight) / 2,
        width: containerSize.width,
        height: scaledHeight
      )
    }
    
    var relX = (selectionRect.minX - displayFrame.minX) / displayFrame.width
    var relY = (selectionRect.minY - displayFrame.minY) / displayFrame.height
    var relW = selectionRect.width / displayFrame.width
    var relH = selectionRect.height / displayFrame.height
    
    relX = max(0, min(1, relX))
    relY = max(0, min(1, relY))
    relW = max(0, min(1 - relX, relW))
    relH = max(0, min(1 - relY, relH))
    
    let pixelW = CGFloat(cgImage.width)
    let pixelH = CGFloat(cgImage.height)
    
    let cropRect: CGRect
    switch rotationAngle {
    case 90:
      // Display .right: displayed (x,y) -> pixel (y, 1-x-w)
      cropRect = CGRect(
        x: relY * pixelW,
        y: (1 - relX - relW) * pixelH,
        width: relH * pixelW,
        height: relW * pixelH
      )
    case 180:
      // Display .down: displayed (x,y) -> pixel (1-x-w, 1-y-h)
      cropRect = CGRect(
        x: (1 - relX - relW) * pixelW,
        y: (1 - relY - relH) * pixelH,
        width: relW * pixelW,
        height: relH * pixelH
      )
    case 270:
      // Display .left: displayed (x,y) -> pixel (1-y-h, x)
      cropRect = CGRect(
        x: (1 - relY - relH) * pixelW,
        y: relX * pixelH,
        width: relH * pixelW,
        height: relW * pixelH
      )
    default:
      cropRect = CGRect(
        x: relX * pixelW,
        y: relY * pixelH,
        width: relW * pixelW,
        height: relH * pixelH
      )
    }
    
    guard cropRect.width > 0, cropRect.height > 0,
          let croppedCGImage = cgImage.cropping(to: cropRect) else { return }
    
    let orientation: UIImage.Orientation
    switch rotationAngle {
    case 90: orientation = .right
    case 180: orientation = .down
    case 270: orientation = .left
    default: orientation = .up
    }
    
    let croppedUIImage = UIImage(cgImage: croppedCGImage, scale: normalizedImage.scale, orientation: orientation)
    let finalImage = croppedUIImage.normalizedImage()
    
    guard let croppedData = finalImage.jpegData(compressionQuality: 0.9) else {
      return
    }
    
    let croppedPhoto = PhotoData(
      image: Image(uiImage: finalImage),
      imageData: croppedData,
      imageSize: (width: Int(finalImage.size.width), height: Int(finalImage.size.height))
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
