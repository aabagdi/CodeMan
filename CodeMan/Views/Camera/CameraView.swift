//
//  CameraView.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import SwiftUI
import PhotosUI

struct CameraView: View {
  @Binding var navigationPath: NavigationPath
  
  @State private var model = CameraModel()
  @State private var showCameraError: Bool = false
  @State private var pickerItem: PhotosPickerItem?
  @State private var latestLibraryImage: UIImage?
  
  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea(.all)
      
      if model.photoTaken != nil {
        ConfirmImageView(navigationPath: $navigationPath)
          .transition(.opacity)
      } else {
        PreviewView()
          .transition(.opacity)
          .overlay(alignment: .bottomLeading) {
            let image = latestLibraryImage
            PhotosPicker(selection: $pickerItem, matching: .images) {
              if let image {
                Image(uiImage: image)
                  .resizable()
                  .scaledToFill()
                  .frame(width: 60, height: 60)
                  .clipShape(RoundedRectangle(cornerRadius: 8))
                  .padding()
              } else {
                RoundedRectangle(cornerRadius: 8)
                  .fill(.gray.opacity(0.3))
                  .frame(width: 60, height: 60)
                  .padding()
              }
            }
            .padding()
          }
      }
    }
    .environment(model)
    .animation(.easeInOut(duration: 0.2), value: model.photoTaken != nil)
    .task {
      latestLibraryImage = await getLatestImage()
    }
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
      .onChange(of: pickerItem) { _, newValue in
        Task {
          guard let newValue,
                let data = try? await newValue.loadTransferable(type: Data.self),
                let uiImage = UIImage(data: data) else {
            return
          }
          
          await model.pausePreview()
          model.photoTaken = PhotoData(
            image: Image(uiImage: uiImage),
            imageData: data,
            imageSize: (width: Int(uiImage.size.width), height: Int(uiImage.size.height))
          )
          pickerItem = nil
        }
      }
      .ignoresSafeArea(.all)
  }
  
  func getLatestImage(targetSize: CGSize = CGSize(width: 120, height: 120)) async -> UIImage? {
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
    
    let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
    
    guard let lastAsset = fetchResult.lastObject else {
      return nil
    }
    
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isSynchronous = false
    
    return await withCheckedContinuation { continuation in
      PHImageManager.default().requestImage(
        for: lastAsset,
        targetSize: PHImageManagerMaximumSize,
        contentMode: .aspectFit,
        options: options
      ) { image, _ in
        continuation.resume(returning: image)
      }
    }
  }
}
