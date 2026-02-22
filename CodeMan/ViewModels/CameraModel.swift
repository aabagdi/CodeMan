//
//  CameraModel.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import Foundation
@preconcurrency import AVFoundation
import SwiftUI

@Observable
@MainActor
class CameraModel {
  let camera = CameraManager()
  private let ciContext = CIContext()
  
  var previewImage: Image?
  var photoTaken: PhotoData?
  
  func startCameraHandlers() {
    camera.previewFrameHandler = { [weak self] ciImage in
      self?.previewImage = self?.makeImage(from: ciImage)
    }
    camera.photoCaptureHandler = { [weak self] photo in
      self?.photoTaken = self?.unpackPhoto(photo)
    }
  }
  
  private func unpackPhoto(_ photo: AVCapturePhoto) -> PhotoData? {
    guard let imageData = photo.fileDataRepresentation() else { return nil }
    guard let cgImage = photo.cgImageRepresentation(),
          let metadataOrientation = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32,
          let cgImageOrientation = CGImagePropertyOrientation(rawValue: metadataOrientation)
    else { return nil }
    
    let imageOrientation = UIImage.Orientation(cgImageOrientation)
    let image = Image(uiImage: UIImage(cgImage: cgImage, scale: 1, orientation: imageOrientation))
    
    let photoDimensions = photo.resolvedSettings.photoDimensions
    let imageSize = (width: Int(photoDimensions.width), height: Int(photoDimensions.height))
    
    return PhotoData(image: image, imageData: imageData, imageSize: imageSize)
  }
  
  func resumePreview() {
    camera.setPreviewPaused(false)
  }
  
  func pausePreview() {
    camera.setPreviewPaused(true)
  }
  
  func focusCamera(at point: CGPoint) {
    try? camera.setFocusPoint(point)
  }
  
  private func makeImage(from ciImage: CIImage) -> Image? {
    guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
    return Image(decorative: cgImage, scale: 1, orientation: .up)
  }
}

fileprivate extension UIImage.Orientation {
  init(_ cgImageOrientation: CGImagePropertyOrientation) {
    switch cgImageOrientation {
    case .up: self = .up
    case .upMirrored: self = .upMirrored
    case .down: self = .down
    case .downMirrored: self = .downMirrored
    case .left: self = .left
    case .leftMirrored: self = .leftMirrored
    case .right: self = .right
    case .rightMirrored: self = .rightMirrored
    }
  }
}
