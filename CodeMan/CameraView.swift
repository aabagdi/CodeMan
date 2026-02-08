//
//  CameraView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI

struct CameraView: View {
  @Binding var navigationPath: NavigationPath
  
  @State private var model = CameraModel()
  @State private var showCameraError: Bool = false
  
  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea(.all)
      
      if let _ = model.photoTaken {
        ConfirmImageView(navigationPath: $navigationPath)
          .transition(.opacity)
      } else {
        PreviewView()
          .transition(.opacity)
      }
    }
    .environment(model)
    .animation(.easeInOut(duration: 0.2), value: model.photoTaken != nil)
    .onAppear {
      AppDelegate.orientationLock = .portrait
      
      if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
         let rootViewController = windowScene.windows.first?.rootViewController {
        rootViewController.setNeedsUpdateOfSupportedInterfaceOrientations()
      }
    }
    .task {
      try? await Task.sleep(for: .milliseconds(100))
      do {
        try await model.camera.start()
      } catch {
        showCameraError = true
      }
    }
    .alert(
      "The camera is not starting, try restarting the app or make sure camera permissions for CodeMan are turned on.",
      isPresented: $showCameraError
    ) { }
    .task {
      await model.handleCameraPreviews()
    }
    .task {
      await model.handleCameraPhotos()
    }
    .onDisappear {
      AppDelegate.orientationLock = .all
    }
    .onChange(of: model.photoTaken != nil) { oldValue, newValue in
      Task {
        if newValue {
          await model.pausePreview()
        } else {
          await model.resumePreview()
        }
      }
    }
    .ignoresSafeArea(.all)
  }
}
