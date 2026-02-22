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
  @State private var showConfirmImage = false
  
  var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea(.all)
      
      PreviewView()
        .overlay(alignment: .bottomLeading) {
          let image = latestLibraryImage
          PhotosPicker(selection: $pickerItem, matching: .images) {
            if let image {
              Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 60, height: 60)
                .clipShape(.rect(cornerRadius: 8))
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
    .environment(model)
    .onChange(of: model.photoTaken != nil) {
      showConfirmImage = model.photoTaken != nil
    }
    .fullScreenCover(isPresented: $showConfirmImage, onDismiss: {
      AppDelegate.orientationLock = .all
      model.photoTaken = nil
      model.resumePreview()
    }) {
      ConfirmImageView(onSave: {
        navigationPath = NavigationPath()
      })
        .environment(model)
        .onAppear {
          AppDelegate.orientationLock = .portrait
        }
    }
    .task {
      latestLibraryImage = await getLatestImage()
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
      "The camera is not starting, try restarting the app or make sure camera permissions for AlgorithmMan are turned on.",
      isPresented: $showCameraError
    ) { }
      .onAppear {
        model.startCameraHandlers()
      }
      .task(id: model.photoTaken != nil) {
        if model.photoTaken != nil {
          model.pausePreview()
        } else {
          model.resumePreview()
        }
      }
      .task(id: pickerItem) {
        guard let pickerItem,
              let data = try? await pickerItem.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else {
          return
        }
        
        model.pausePreview()
        model.photoTaken = PhotoData(
          image: Image(uiImage: uiImage),
          imageData: data,
          imageSize: (width: Int(uiImage.size.width), height: Int(uiImage.size.height))
        )
        self.pickerItem = nil
      }
      .ignoresSafeArea(.all)
  }
  
  func getLatestImage(targetSize: CGSize = CGSize(width: 120, height: 120)) async -> UIImage? {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    if status == .notDetermined {
      let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
      guard newStatus == .authorized || newStatus == .limited else {
        return nil
      }
    } else if status == .denied || status == .restricted {
      return nil
    }
    
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    fetchOptions.fetchLimit = 1
    
    let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
    
    guard let lastAsset = fetchResult.firstObject else {
      return nil
    }
    
    let options = PHImageRequestOptions()
    options.deliveryMode = .highQualityFormat
    options.isSynchronous = false
    
    return await withCheckedContinuation { continuation in
      PHImageManager.default().requestImage(
        for: lastAsset,
        targetSize: targetSize,
        contentMode: .aspectFill,
        options: options
      ) { image, _ in
        continuation.resume(returning: image)
      }
    }
  }
}
