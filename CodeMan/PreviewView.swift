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
  
  var body: some View {
    GeometryReader { geometry in
      ImageView(image: model.previewImage)
        .frame(width: geometry.size.width, height: geometry.size.height)
        .overlay {
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
  
  private func buttonsView() -> some View {
    HStack {
      Spacer()
      
      Button {
        guard !isCapturing else { return }
        isCapturing = true
        Task {
          try await model.camera.takePhoto()
        }
      } label: {
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
        .stroke(Color.yellow, lineWidth: 2)
        .frame(width: 70, height: 70)
      
      Circle()
        .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
        .frame(width: 90, height: 90)
    }
    .transition(.scale.combined(with: .opacity))
  }
}
