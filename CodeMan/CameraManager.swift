//
//  CameraManager.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import Foundation
import AVFoundation
import UIKit

class CameraManager: NSObject {
  private let session = AVCaptureSession()
  
  private var isSessionConfigured = false
  private var deviceInput: AVCaptureDeviceInput?
  private var photoOutput: AVCapturePhotoOutput?
  private var videoOutput: AVCaptureVideoDataOutput?
  private var sessionQueue: DispatchQueue!
  
  private var allCaptureDevices: [AVCaptureDevice] {
    AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera, .builtInDualCamera, .builtInDualWideCamera, .builtInWideAngleCamera, .builtInDualWideCamera], mediaType: .video, position: .unspecified).devices
  }
  
  private var frontCaptureDevices: [AVCaptureDevice] {
    allCaptureDevices
      .filter { $0.position == .front }
  }
  
  private var backCaptureDevices: [AVCaptureDevice] {
    allCaptureDevices
      .filter { $0.position == .back }
  }
  
  private var captureDevices: [AVCaptureDevice] {
    var devices = [AVCaptureDevice]()
    
    if let frontCam = frontCaptureDevices.first {
      devices.append(frontCam)
    }
    
    if let backCam = backCaptureDevices.first {
      devices.append(backCam)
    }
    
    return devices
  }
  
  private var availableDevices: [AVCaptureDevice] {
    captureDevices
      .filter { $0.isConnected }
      .filter { !$0.isSuspended }
  }
  
  private var captureDevice: AVCaptureDevice? {
    didSet {
      guard let captureDevice else { return }
      
      sessionQueue.async {
        self.updateSessionForCaptureDevice(for: captureDevice)
      }
    }
  }
  
  var isRunning: Bool {
    session.isRunning
  }
  
  var isUsingFront: Bool {
    guard let captureDevice else { return false }
    
    return frontCaptureDevices.contains(captureDevice)
  }
  
  var isUsingBack: Bool {
    guard let captureDevice else { return false }
    
    return backCaptureDevices.contains(captureDevice)
  }
  
  private var addToPhotoStream: ((AVCapturePhoto) -> Void)?
  
  lazy var photoStream: AsyncStream<AVCapturePhoto> = {
    AsyncStream { continuation in
      addToPhotoStream  = { photo in
        continuation.yield(photo)
      }
    }
  }()
  
  var isPreviewPaused = false
  
  private var addToPreviewStream: ((CIImage) -> Void)?
  
  lazy var previewStream: AsyncStream<CIImage> = {
    AsyncStream { continuation in
      addToPreviewStream = { photo in
        continuation.yield(photo)
      }
    }
  }()
  
  override init() {
    super.init()
    
    session.sessionPreset = .photo
    
    sessionQueue = DispatchQueue(label: "CodeMan Camera Session Queue")
    
    captureDevice = availableDevices.first ?? AVCaptureDevice.default(for: .video)
  }
  
  func start() async {
    let authorized = await checkAuthorization()
    
    guard authorized else {
      print("Camera use not authorized")
      return
    }
    
    if isSessionConfigured {
      if !session.isRunning {
        sessionQueue.async { [weak self] in
          self?.session.startRunning()
        }
      }
    }
    
    sessionQueue.async { [weak self] in
      self?.configureCaptureSession { success in
        guard success else { return }
        self?.session.startRunning()
      }
    }
  }
  
  func stop() {
    guard isSessionConfigured else { return }
    
    if session.isRunning {
      sessionQueue.async { [weak self] in
        self?.session.stopRunning()
      }
    }
  }
  
  func switchCaptureDevice() {
    if let captureDevice = captureDevice, let index = captureDevices.firstIndex(of: captureDevice) {
      let nextIndex = (index + 1) % captureDevices.count
      self.captureDevice = captureDevices[nextIndex]
    } else {
      self.captureDevice = AVCaptureDevice.default(for: .video)
    }
  }
  
  func takePhoto() {
    guard let photoOutput else { return }
    
    sessionQueue.async {
      var photoSettings = AVCapturePhotoSettings()
      
      if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
        photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
      }
      
      let isFlashAvailable = self.deviceInput?.device.isFlashAvailable ?? false
      photoSettings.flashMode = isFlashAvailable ? .auto : .off
      
      
    }
  }
}
