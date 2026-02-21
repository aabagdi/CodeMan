//
//  CameraManager.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import Foundation
@preconcurrency import AVFoundation
import UIKit
import Synchronization

@MainActor
class CameraManager: NSObject {
  private let session = AVCaptureSession()
  
  private var isSessionConfigured = false
  private var deviceInput: AVCaptureDeviceInput?
  private var photoOutput: AVCapturePhotoOutput?
  private var videoOutput: AVCaptureVideoDataOutput?
  
  private var captureDevice: AVCaptureDevice?
  
  private enum RotationAngle: CGFloat {
    case portrait = 90
    case portraitUpsideDown = 270
    case landscapeRight = 180
    case landscapeLeft = 0
    
    init(from deviceOrientation: UIDeviceOrientation) {
      switch deviceOrientation {
      case .landscapeLeft:
        self = .landscapeLeft
      case .landscapeRight:
        self = .landscapeRight
      case .portraitUpsideDown:
        self = .portraitUpsideDown
      default:
        self = .portrait
      }
    }
  }
  
  var isRunning: Bool {
    session.isRunning
  }
  
  private var _currentDeviceOrientation: UIDeviceOrientation = .portrait
  
  func updateDeviceOrientation(_ orientation: UIDeviceOrientation) {
    _currentDeviceOrientation = orientation
  }
  
  private let photoStreamContinuation: AsyncStream<AVCapturePhoto>.Continuation
  let photoStream: AsyncStream<AVCapturePhoto>
  
  private let _isPreviewPaused = Mutex(false)
  
  nonisolated var isPreviewPaused: Bool {
    get { _isPreviewPaused.withLock { $0 } }
    set { _isPreviewPaused.withLock { $0 = newValue } }
  }
  
  private let previewStreamContinuation: AsyncStream<CIImage>.Continuation
  let previewStream: AsyncStream<CIImage>
  
  private let _onPreviewFrame = Mutex<(@Sendable (CIImage) -> Void)?>(nil)
  nonisolated var onPreviewFrame: (@Sendable (CIImage) -> Void)? {
    get { _onPreviewFrame.withLock { $0 } }
    set { _onPreviewFrame.withLock { $0 = newValue } }
  }
  
  private let _onPhotoCaptured = Mutex<(@Sendable (AVCapturePhoto) -> Void)?>(nil)
  nonisolated var onPhotoCaptured: (@Sendable (AVCapturePhoto) -> Void)? {
    get { _onPhotoCaptured.withLock { $0 } }
    set { _onPhotoCaptured.withLock { $0 = newValue } }
  }
  
  override init() {
    let (photoStream, photoContinuation) = AsyncStream.makeStream(of: AVCapturePhoto.self)
    self.photoStream = photoStream
    self.photoStreamContinuation = photoContinuation
    
    let (previewStream, previewContinuation) = AsyncStream.makeStream(of: CIImage.self)
    self.previewStream = previewStream
    self.previewStreamContinuation = previewContinuation
    
    super.init()
    
    session.sessionPreset = .photo
    captureDevice = nil
  }
  
  deinit {
    photoStreamContinuation.finish()
    previewStreamContinuation.finish()
  }
  
  private func ensureCaptureDevice() {
    if captureDevice == nil {
      captureDevice = AVCaptureDevice.default(for: .video)
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
        await startSession(session)
      }
      return
    }
    
    try await configureCaptureSession()
    await startSession(session)
  }
  
  func stop() async throws {
    guard isSessionConfigured else {
      throw CameraError.sessionNotConfigured
    }
    
    if session.isRunning {
      await stopSession(session)
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
      let rotationAngle = RotationAngle(from: _currentDeviceOrientation)
      photoOutputVideoConnection.videoRotationAngle = rotationAngle.rawValue
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
    
    try device.lockForConfiguration()
    defer { device.unlockForConfiguration() }
    
    device.focusPointOfInterest = point
    device.focusMode = .autoFocus
    
    if device.isExposurePointOfInterestSupported {
      device.exposurePointOfInterest = point
      device.exposureMode = .autoExpose
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
      return true
    case .notDetermined:
      return await AVCaptureDevice.requestAccess(for: .video)
    case .denied:
      return false
    case .restricted:
      return false
    default:
      return false
    }
  }
  
  @concurrent
  private func startSession(_ session: AVCaptureSession) async {
    session.startRunning()
  }
  
  @concurrent
  private func stopSession(_ session: AVCaptureSession) async {
    session.stopRunning()
  }
  
  private func updateVideoOutputConnection() {
    if let videoOutput, let videoOutputConnection = videoOutput.connection(with: .video) {
      if videoOutputConnection.isVideoMirroringSupported {
        videoOutputConnection.isVideoMirrored = false
      }
      videoOutputConnection.videoRotationAngle = RotationAngle.portrait.rawValue
    }
  }
}

extension CameraManager: AVCapturePhotoCaptureDelegate {
  nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    if error != nil { return }
    
    photoStreamContinuation.yield(photo)
    onPhotoCaptured?(photo)
  }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
  nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
    guard let pixelBuffer = sampleBuffer.imageBuffer else { return }
    guard !isPreviewPaused else { return }
    let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
    previewStreamContinuation.yield(ciImage)
    onPreviewFrame?(ciImage)
  }
}

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
