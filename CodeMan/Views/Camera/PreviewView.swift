//
//  PreviewView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI

struct PreviewView: View {
  @Environment(CameraModel.self) var model
  
  private let footerHeight: CGFloat = 110.0
  
  @State private var focusLocation: CGPoint?
  @State private var showFocusIndicator = false
  @State private var isCapturing = false
  @State private var deviceOrientation: UIDeviceOrientation = .portrait
  
  var body: some View {
    GeometryReader { geometry in
      ZStack {
        CameraPreviewImage(image: model.previewImage, orientation: deviceOrientation)
          .frame(width: previewSize(for: geometry.size).width,
                 height: previewSize(for: geometry.size).height)
          .rotationEffect(previewRotationAngle)
          .frame(width: geometry.size.width, height: geometry.size.height)
          .clipped()
        
        if showFocusIndicator, let location = focusLocation {
          FocusIndicator()
            .position(location)
        }
      }
      .overlay(alignment: .bottom) {
        buttonsView()
          .frame(height: footerHeight)
          .padding(.bottom, 40)
      }
      .contentShape(Rectangle())
      .onTapGesture { location in
        handleTapToFocus(at: location, in: geometry.size)
      }
    }
    .ignoresSafeArea()
    .sensoryFeedback(.impact, trigger: isCapturing)
    .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
      handleOrientationChange()
    }
    .task { await onTask() }
  }
  
  private var previewRotationAngle: Angle {
    switch deviceOrientation {
    case .landscapeLeft:
      return .degrees(-90)
    case .landscapeRight:
      return .degrees(90)
    case .portraitUpsideDown:
      return .degrees(180)
    default:
      return .degrees(0)
    }
  }
  
  private func previewSize(for containerSize: CGSize) -> CGSize {
    switch deviceOrientation {
    case .landscapeLeft, .landscapeRight:
      return CGSize(width: containerSize.height, height: containerSize.width)
    default:
      return containerSize
    }
  }
  
  private func onTask() async {
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    let currentOrientation = UIDevice.current.orientation
    if currentOrientation.isValidInterfaceOrientation {
      deviceOrientation = currentOrientation
      await model.camera.updateDeviceOrientation(currentOrientation)
    }
  }
  
  private func handleOrientationChange() {
    let newOrientation = UIDevice.current.orientation
    guard newOrientation.isValidInterfaceOrientation,
          newOrientation != deviceOrientation else { return }
    withAnimation(.easeInOut(duration: 0.3)) {
      deviceOrientation = newOrientation
    }
    Task {
      await model.camera.updateDeviceOrientation(newOrientation)
    }
  }
  
  private func handleTapToFocus(at location: CGPoint, in size: CGSize) {
    let normalizedPoint = CGPoint(
      x: location.x / size.width,
      y: location.y / size.height
    )
    
    focusLocation = location
    showFocusIndicator = true
    
    Task {
      await model.focusCamera(at: normalizedPoint)
      
      try? await Task.sleep(for: .seconds(1))
      withAnimation {
        showFocusIndicator = false
      }
    }
  }
  
  private func captureButtonTapped() {
    guard !isCapturing else { return }
    isCapturing = true
    Task {
      try await model.camera.takePhoto()
    }
  }
  
  private func buttonsView() -> some View {
    HStack {
      Spacer()
      
      Button { captureButtonTapped() } label: {
        ZStack {
          Circle()
            .strokeBorder(.white, lineWidth: 3)
            .frame(width: 72, height: 72)
          Circle()
            .fill(isCapturing ? .gray : .white)
            .frame(width: 62, height: 62)
        }
      }
      .buttonStyle(.plain)
      .disabled(isCapturing)
      
      Spacer()
    }
    .padding(.horizontal, 20)
    .frame(maxWidth: .infinity)
  }
}
struct FocusIndicator: View {
  var body: some View {
    ZStack {
      Circle()
        .stroke(.yellow, lineWidth: 2)
        .frame(width: 70, height: 70)
      
      Circle()
        .stroke(.yellow.opacity(0.5), lineWidth: 1)
        .frame(width: 90, height: 90)
    }
    .transition(.scale.combined(with: .opacity))
  }
}

private struct CameraPreviewImage: View {
  let image: Image?
  let orientation: UIDeviceOrientation
  
  var body: some View {
    if let image {
      image
        .resizable()
        .aspectRatio(contentMode: .fill)
    } else {
      Color.black
    }
  }
}

private extension UIDeviceOrientation {
  var isValidInterfaceOrientation: Bool {
    switch self {
    case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
      return true
    default:
      return false
    }
  }
}
