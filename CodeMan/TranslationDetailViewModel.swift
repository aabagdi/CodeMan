//
//  TranslationDetailViewModel.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/9/26.
//

import CloudKit
import Dependencies
import Foundation
import IssueReporting
import SQLiteData

@MainActor
@Observable
final class TranslationDetailViewModel {
  @ObservationIgnored @Dependency(\.defaultDatabase) var database
  @ObservationIgnored @Dependency(\.defaultSyncEngine) var syncEngine
  
  var translation: Translation
  var sharedRecord: SharedRecord?
  var isSharing = false
  
  init(translation: Translation) {
    self.translation = translation
  }
  
  func shareButtonTapped() async {
    isSharing = true
    defer { isSharing = false }
    
    let title = translation.title
    
    await withErrorReporting {
      sharedRecord = try await syncEngine.share(record: translation) { share in
        share[CKShare.SystemFieldKey.title] = title as CKRecordValue
      }
    }
  }
}
