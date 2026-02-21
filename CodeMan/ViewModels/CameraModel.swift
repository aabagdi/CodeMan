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
  
  var previewImage: Image?
  var photoTaken: PhotoData?
  
  init() {
    setupCallbacks()
  }
  
  private func setupCallbacks() {
    camera.onPreviewFrame = { [weak self] ciImage in
      Task { @MainActor [weak self] in
        self?.previewImage = ciImage.image
      }
    }
    
    camera.onPhotoCaptured = { [weak self] photo in
      Task { @MainActor [weak self] in
        self?.photoTaken = self?.unpackPhoto(photo)
      }
    }
  }
  
  func handleCameraPreviews() async {
    for await ciImage in camera.previewStream {
      previewImage = ciImage.image
    }
  }
  
  func handleCameraPhotos() async {
    for await photo in camera.photoStream {
      photoTaken = unpackPhoto(photo)
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
    previewImage = nil
    camera.setPreviewPaused(false)
  }
  
  func pausePreview() {
    camera.setPreviewPaused(true)
  }
  
  func focusCamera(at point: CGPoint) {
    try? camera.setFocusPoint(point)
  }
}

fileprivate extension CIImage {
  var image: Image? {
    let ciContext = CIContext()
    guard let cgImage = ciContext.createCGImage(self, from: self.extent) else { return nil }
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
