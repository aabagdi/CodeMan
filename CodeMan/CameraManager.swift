//
//  CameraManager.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import Foundation
@preconcurrency import AVFoundation
import UIKit

enum CameraError: LocalizedError {
  case notAuthorized
  case deviceNotAvailable
  case deviceInputFailed
  case cannotAddInput
  case cannotAddOutput
  case sessionNotConfigured
  case captureDeviceNotFound
  
  var errorDescription: String? {
    switch self {
    case .notAuthorized:
      return "Camera access not authorized"
    case .deviceNotAvailable:
      return "Camera device is not available"
    case .deviceInputFailed:
      return "Failed to create device input"
    case .cannotAddInput:
      return "Unable to add device input to capture session"
    case .cannotAddOutput:
      return "Unable to add output to capture session"
    case .sessionNotConfigured:
      return "Camera session is not configured"
    case .captureDeviceNotFound:
      return "No capture device found"
    }
  }
}

actor CameraManager: NSObject {
  private let session = AVCaptureSession()
  
  private var isSessionConfigured = false
  private var deviceInput: AVCaptureDeviceInput?
  private var photoOutput: AVCapturePhotoOutput?
  private var videoOutput: AVCaptureVideoDataOutput?
  
  private var allCaptureDevices: [AVCaptureDevice] {
    AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera, .builtInDualWideCamera], mediaType: .video, position: .unspecified).devices
  }
  
  private var backCaptureDevices: [AVCaptureDevice] {
    allCaptureDevices
      .filter { $0.position == .back }
  }
  
  private var availableDevices: [AVCaptureDevice] {
    backCaptureDevices
      .filter { $0.isConnected }
      .filter { !$0.isSuspended }
  }
  
  private var captureDevice: AVCaptureDevice?
  
  private enum RotationAngle: CGFloat {
    case portrait = 90
    case portraitUpsideDown = 270
    case landscapeRight = 180
    case landscapeLeft = 0
  }
  
  var isRunning: Bool {
    session.isRunning
  }
  
  private let photoStreamContinuation: AsyncStream<AVCapturePhoto>.Continuation
  nonisolated let photoStream: AsyncStream<AVCapturePhoto>
  
  var isPreviewPaused = false
  private let previewStreamContinuation: AsyncStream<CIImage>.Continuation
  nonisolated let previewStream: AsyncStream<CIImage>
  
  override init() {
    var photoContinuation: AsyncStream<AVCapturePhoto>.Continuation!
    let photoStream = AsyncStream<AVCapturePhoto> { continuation in
      photoContinuation = continuation
    }
    self.photoStream = photoStream
    self.photoStreamContinuation = photoContinuation
    
    var previewContinuation: AsyncStream<CIImage>.Continuation!
    let previewStream = AsyncStream<CIImage> { continuation in
      previewContinuation = continuation
    }
    self.previewStream = previewStream
    self.previewStreamContinuation = previewContinuation
    
    super.init()
    
    session.sessionPreset = .photo
    captureDevice = nil
  }
  
  private func ensureCaptureDevice() {
    if captureDevice == nil {
      captureDevice = availableDevices.first ?? AVCaptureDevice.default(for: .video)
    }
  }
  
  func start() async throws {
    ensureCaptureDevice()
    
    let authorized = await checkAuthorization()
    
    guard authorized else {
      throw CameraError.notAuthorized
    }
    
    if isSessionConfigured {
      if !session.isRunning {
        session.startRunning()
      }
      return
    }
    
    try await configureCaptureSession()
    session.startRunning()
  }
  
  func stop() throws {
    guard isSessionConfigured else {
      throw CameraError.sessionNotConfigured
    }
    
    if session.isRunning {
      session.stopRunning()
    }
  }
  
  func setPreviewPaused(_ paused: Bool) {
    isPreviewPaused = paused
  }
  
  func takePhoto() async throws {
    guard let photoOutput else {
      throw CameraError.sessionNotConfigured
    }
    
    var photoSettings = AVCapturePhotoSettings()
    
    if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
      photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
    }
    
    let isFlashAvailable = self.deviceInput?.device.isFlashAvailable ?? false
    photoSettings.flashMode = isFlashAvailable ? .auto : .off
    
    if let previewPhotoPixelFormatTypes = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
      photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatTypes]
    }
    
    photoSettings.photoQualityPrioritization = .quality
    
    if let photoOutputVideoConnection = photoOutput.connection(with: .video) {
      photoOutputVideoConnection.videoRotationAngle = RotationAngle.portrait.rawValue
    }
    
    photoOutput.capturePhoto(with: photoSettings, delegate: self)
  }
  
  func setFocusPoint(_ point: CGPoint) throws {
    guard let device = captureDevice else {
      throw CameraError.captureDeviceNotFound
    }
    
    guard device.isFocusPointOfInterestSupported else {
      return
    }
    
    do {
      try device.lockForConfiguration()
      
      device.focusPointOfInterest = point
      device.focusMode = .autoFocus
      
      if device.isExposurePointOfInterestSupported {
        device.exposurePointOfInterest = point
        device.exposureMode = .autoExpose
      }
      
      device.unlockForConfiguration()
    } catch {
      print("Could not lock device for configuration: \(error)")
      throw error
    }
  }
  
  private func deviceInputFor(device: AVCaptureDevice?) throws -> AVCaptureDeviceInput {
    guard let device else {
      throw CameraError.deviceNotAvailable
    }
    
    do {
      return try AVCaptureDeviceInput(device: device)
    } catch {
      throw CameraError.deviceInputFailed
    }
  }
  
  private func configureCaptureSession() async throws {
    guard let captureDevice else {
      throw CameraError.captureDeviceNotFound
    }
    
    let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
    
    self.session.beginConfiguration()
    
    defer {
      self.session.commitConfiguration()
    }
    
    let movieFileOutput = AVCaptureMovieFileOutput()
    
    let photoOutput = AVCapturePhotoOutput()
    session.sessionPreset = AVCaptureSession.Preset.photo
    
    let videoOutput = AVCaptureVideoDataOutput()
    videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutputQueue"))
    
    guard session.canAddInput(deviceInput) else {
      throw CameraError.cannotAddInput
    }
    guard session.canAddOutput(photoOutput) else {
      throw CameraError.cannotAddOutput
    }
    guard session.canAddOutput(videoOutput) else {
      throw CameraError.cannotAddOutput
    }
    
    session.addInput(deviceInput)
    session.addOutput(photoOutput)
    session.addOutput(videoOutput)
    session.addOutput(movieFileOutput)
    
    self.deviceInput = deviceInput
    self.photoOutput = photoOutput
    self.videoOutput = videoOutput
    
    photoOutput.maxPhotoQualityPrioritization = .quality
    
    updateVideoOutputConnection()
    
    isSessionConfigured = true
  }
  
  private func checkAuthorization() async -> Bool {
    switch AVCaptureDevice.authorizationStatus(for: .video) {
    case .authorized:
      print("Camera access authorized.")
      return true
    case .notDetermined:
      print("Camera access not determined.")
      return await AVCaptureDevice.requestAccess(for: .video)
    case .denied:
      print("Camera access denied.")
      return false
    case .restricted:
      print("Camera library access restricted.")
      return false
    default:
      return false
    }
  }
  
  private func updateVideoOutputConnection() {
    if let videoOutput, let videoOutputConnection = videoOutput.connection(with: .video) {
      if videoOutputConnection.isVideoMirroringSupported {
        videoOutputConnection.isVideoMirrored = false
      }
    }
  }
}

extension CameraManager: @preconcurrency AVCapturePhotoCaptureDelegate {
  nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    
    if let error = error {
      print("Error capturing photo: \(error.localizedDescription)")
      return
    }
    
    photoStreamContinuation.yield(photo)
  }
}

extension CameraManager: @preconcurrency AVCaptureVideoDataOutputSampleBufferDelegate {
  nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
    connection.videoRotationAngle = RotationAngle.portrait.rawValue
    previewStreamContinuation.yield(CIImage(cvPixelBuffer: pixelBuffer))
  }
}

