//
//  SQLiteDataMigratorTests+V5.swift
//
//  ClipApp
//
//  Copyright © 2015-2026 Clipy Project.
//

import Foundation
import SQLiteData
import Testing
@testable import ClipApp

extension SQLiteDataMigratorTests {
    @Test
    func migrationV5BackfillsPayloadByteCount() throws {
        let database = try DatabaseQueue()
        var migrator = DatabaseMigrator()
        migrator.registerMigrationV1()
        migrator.registerMigrationV2()
        migrator.registerMigrationV3()
        migrator.registerMigrationV4()
        try migrator.migrate(database)

        try database.write { database in
            try database.execute(
                sql: """
                INSERT INTO "pasteboardHistories"
                  ("id", "title", "ocrText", "pasteboardTypes", "createdAt", "updateAt")
                VALUES (?, ?, NULL, ?, ?, ?)
                """,
                arguments: ["history", "History", "[]", 1, 1]
            )
            try database.execute(
                sql: """
                INSERT INTO "pasteboardHistoryAssets"
                  ("pasteboardHistoryID", "index", "pasteboardType", "data")
                VALUES (?, ?, ?, ?), (?, ?, ?, ?)
                """,
                arguments: [
                    "history", 0, "public.utf8-plain-text", Data(repeating: 1, count: 7),
                    "history", 1, "public.rtf", Data(repeating: 2, count: 11)
                ]
            )
            try database.execute(
                sql: """
                INSERT INTO "pasteboardHistoryThumbnailAssets"
                  ("pasteboardHistoryID", "kind", "data")
                VALUES (?, ?, ?)
                """,
                arguments: ["history", "image", Data(repeating: 3, count: 13)]
            )
        }

        migrator.registerMigrationV5()
        try migrator.migrate(database)

        try database.read { database in
            #expect(
                try columnNames(of: "pasteboardHistories", database: database) == [
                    "createdAt",
                    "deviceID",
                    "id",
                    "ocrText",
                    "pasteboardTypes",
                    "payloadByteCount",
                    "title",
                    "updateAt"
                ]
            )
            let payloadByteCount = try #sql(
                """
                SELECT "payloadByteCount"
                FROM "pasteboardHistories"
                WHERE "id" = 'history'
                """,
                as: Int64.self
            )
            .fetchOne(database)
            #expect(payloadByteCount == 31)
        }
    }
}
