//
//  CameraView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI

struct CameraView: View {
  @State private var model = CameraModel()
  
  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea(.all)
      
      if let _ = model.photoTaken {
        ConfirmImageView()
          .transition(.opacity)
      } else {
        PreviewView()
          .transition(.opacity)
          .onAppear {
            Task {
              await model.resumePreview()
            }
          }
          .onDisappear {
            Task {
              await model.pausePreview()
            }
          }
      }
      
    }
    .animation(.easeInOut(duration: 0.2), value: model.photoTaken != nil)
    .task {
      do {
        AppDelegate.orientationLock = .portrait
        
        try await model.camera.start()
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
          rootViewController.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
      } catch {
        print("Camera not started")
      }
    }
    .task {
      await model.handleCameraPreviews()
    }
    .task {
      await model.handleCameraPhotos()
    }
    .onDisappear {
      AppDelegate.orientationLock = .all
    }
    .ignoresSafeArea(.all)
    .environment(model)
  }
}
#Preview {
  CameraView()
}
