//
//  SQLiteDataMigrator+V5.swift
//
//  ClipApp
//
//  Copyright © 2015-2026 Clipy Project.
//

import SQLiteData

extension DatabaseMigrator {
    mutating func registerMigrationV5() {
        registerMigration("Add payload byte count to histories") { database in
            try #sql(
                """
                ALTER TABLE "pasteboardHistories"
                ADD COLUMN "payloadByteCount" INTEGER NOT NULL ON CONFLICT REPLACE DEFAULT 0
                """
            )
            .execute(database)

            // Backfill existing rows from the actual BLOB sizes. Thumbnail bytes count too,
            // because both tables occupy the same history storage budget.
            try #sql(
                """
                UPDATE "pasteboardHistories"
                SET "payloadByteCount" =
                  coalesce((
                    SELECT sum(length("data"))
                    FROM "pasteboardHistoryAssets"
                    WHERE "pasteboardHistoryID" = "pasteboardHistories"."id"
                  ), 0)
                  + coalesce((
                    SELECT length("data")
                    FROM "pasteboardHistoryThumbnailAssets"
                    WHERE "pasteboardHistoryID" = "pasteboardHistories"."id"
                  ), 0)
                """
            )
            .execute(database)
        }
    }
}
