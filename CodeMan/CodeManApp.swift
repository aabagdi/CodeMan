//
//  CodeManApp.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import Dependencies
import SwiftUI
import SQLiteData
import PythonKit

@main
struct CodeManApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  init() {
    if let stdlibPath = Bundle.main.path(forResource: "python3.13", ofType: nil, inDirectory: "lib") {
      let libPath = (stdlibPath as NSString).deletingLastPathComponent
      setenv("PYTHONHOME", libPath, 1)
    }
    
    if let frameworkPath = Bundle.main.path(forResource: "Python", ofType: nil, inDirectory: "Frameworks/Python.framework") {
      PythonLibrary.useLibrary(at: frameworkPath)
    }
    
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
