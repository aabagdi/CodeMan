//
//  CodeManApp.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import CloudKit
import Dependencies
import SwiftUI
import SQLiteData

@main
struct CodeManApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  init() {
    PythonRunner.shared.initialize()
    
    prepareDependencies {
      try! $0.bootstrapDatabase()
    }
  }
  
  var body: some Scene {
    WindowGroup {
      TranslationGridView()
    }
  }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
  static var orientationLock = UIInterfaceOrientationMask.all
  
  func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return AppDelegate.orientationLock
  }
  
  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let configuration = UISceneConfiguration(
      name: "Default Configuration",
      sessionRole: connectingSceneSession.role
    )
    configuration.delegateClass = SceneDelegate.self
    return configuration
  }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
  @Dependency(\.defaultSyncEngine) var syncEngine
  
  func windowScene(
    _ windowScene: UIWindowScene,
    userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
  ) {
    Task {
      try await syncEngine.acceptShare(metadata: cloudKitShareMetadata)
    }
  }
  
  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let cloudKitShareMetadata = connectionOptions.cloudKitShareMetadata
    else { return }
    Task {
      try await syncEngine.acceptShare(metadata: cloudKitShareMetadata)
    }
  }
}

