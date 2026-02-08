//
//  CodeManApp.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import Dependencies
import SwiftUI
import SQLiteData

@main
struct CodeManApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  init() {
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

class AppDelegate: NSObject, UIApplicationDelegate {
  static var orientationLock = UIInterfaceOrientationMask.all
  
  func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    return AppDelegate.orientationLock
  }
}
