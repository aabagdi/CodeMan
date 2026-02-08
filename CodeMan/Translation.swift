//
//  Translation.swift
//  CodeMan
//
//  Created by Aadit Bagdi on 2/7/26.
//

import Dependencies
import Foundation
import SQLiteData
import OSLog

@Table
struct Translation: Identifiable, Hashable {
  let id: UUID
  var title: String
  let image: Data?
  let originalText: String
  var translatedCode: String?
  @Column(as: AttributedString?.JSONRepresentation.self)
  var prettifiedCode: AttributedString?
}

extension DependencyValues {
  mutating func bootstrapDatabase() throws {
    @Dependency(\.context) var context
    
    var configuration = Configuration()
    
#if DEBUG
    configuration.prepareDatabase { db in
      db.trace(options: .profile) {
        guard !$0.expandedDescription.hasPrefix("--") else { return }
        switch context {
        case .live:
          logger.debug("\($0.expandedDescription)")
        case .preview:
          print("\($0.expandedDescription)")
        case .test:
          break
        }
      }
    }
#endif
    
    let database = try SQLiteData.defaultDatabase(configuration: configuration)
    logger.info("open '\(database.path)'")
    
    var migrator = DatabaseMigrator()
#if DEBUG
    migrator.eraseDatabaseOnSchemaChange = true
#endif
    
    migrator.registerMigration("Create 'translations' table") { db in
      try #sql("""
        CREATE TABLE "translations" (
          "id" TEXT PRIMARY KEY NOT NULL ON CONFLICT REPLACE DEFAULT (uuid()),
          "title" TEXT NOT NULL DEFAULT '',
          "image" BLOB,
          "originalText" TEXT NOT NULL DEFAULT '',
          "translatedCode" TEXT,
          "prettifiedCode" TEXT
        ) STRICT
        """)
        .execute(db)
    }
    
    try migrator.migrate(database)
    defaultDatabase = database
  }
}

private nonisolated let logger = Logger(subsystem: "CodeMan", category: "DB")
