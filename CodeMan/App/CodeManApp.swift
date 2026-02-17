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
