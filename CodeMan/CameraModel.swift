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
class CameraModel {
  let camera = CameraManager()
  
  var previewImage: Image?
  var photoTaken: PhotoData?
  
  func handleCameraPreviews() async {
    let imageStream = camera.previewStream
      .map { await $0.image }
    
    for await image in imageStream {
      Task { @MainActor in
        previewImage = image
      }
    }
  }
  
  func handleCameraPhotos() async {
    let unpackedPhotoStream = camera.photoStream
      .compactMap { await self.unpackPhoto($0) }
    
    for await photoData in unpackedPhotoStream {
      Task { @MainActor in
        photoTaken = photoData
      }
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
  
  func resumePreview() async {
    await camera.setPreviewPaused(false)
  }
  
  func pausePreview() async {
    await camera.setPreviewPaused(true)
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
