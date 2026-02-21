//
//  CodeManApp.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/2/26.
//

import Dependencies
import SwiftUI
import SQLiteData
import TipKit

@main
struct CodeManApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
  
  init() {
    PythonRunner.shared.initialize()
    
    prepareDependencies {
      try! $0.bootstrapDatabase()
    }
    
    try? Tips.configure([.displayFrequency(.immediate)])
  }
  
  var body: some Scene {
    WindowGroup {
      TranslationGridView()
    }
  }
}
