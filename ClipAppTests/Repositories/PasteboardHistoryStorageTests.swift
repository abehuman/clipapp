//
//  PasteboardHistoryStorageTests.swift
//
//  ClipApp
//
//  Copyright © 2015-2026 Clipy Project.
//

import AppKit
import Dependencies
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing
@testable import ClipApp

@MainActor
@Suite(
    .dependencies {
        try $0.bootstrapDatabase()
    }
)
struct PasteboardHistoryStorageTests {
    @Dependency(\.defaultDatabase)
    var database

    let repository = PasteboardHistoryRepository()

    @Test
    func saveRejectsAnItemAboveThePerItemByteLimitWithoutChangingHistory() throws {
        let repository = PasteboardHistoryRepository(
            storagePolicy: PasteboardHistoryStoragePolicy(
                maxItemPayloadBytes: 4,
                maxTotalPayloadBytes: 10
            )
        )
        let content = try #require(PasteboardContent.testContent(byteCount: 5, byte: 1))
        let id = PasteboardHistory.ID(rawValue: content.hash)

        let result = repository.save(
            id: id,
            content: content,
            updateAt: 1,
            sortsByCreatedAt: false,
            maxHistorySize: 10
        )

        #expect(result == .rejectedItemTooLarge(maximumBytes: 4))
        #expect(repository.fetchHistory(id: id) == nil)
    }

    @Test
    func saveEvictsOldestHistoriesBeforeTotalPayloadLimitIsExceeded() throws {
        let repository = PasteboardHistoryRepository(
            storagePolicy: PasteboardHistoryStoragePolicy(
                maxItemPayloadBytes: 8,
                maxTotalPayloadBytes: 10
            )
        )
        let first = try #require(PasteboardContent.testContent(byteCount: 4, byte: 1))
        let second = try #require(PasteboardContent.testContent(byteCount: 4, byte: 2))
        let third = try #require(PasteboardContent.testContent(byteCount: 4, byte: 3))
        let firstID = PasteboardHistory.ID(rawValue: first.hash)
        let secondID = PasteboardHistory.ID(rawValue: second.hash)
        let thirdID = PasteboardHistory.ID(rawValue: third.hash)

        #expect(repository.save(
            id: firstID,
            content: first,
            updateAt: 1,
            sortsByCreatedAt: false,
            maxHistorySize: 10
        ) == .saved)
        #expect(repository.save(
            id: secondID,
            content: second,
            updateAt: 2,
            sortsByCreatedAt: false,
            maxHistorySize: 10
        ) == .saved)
        #expect(repository.save(
            id: thirdID,
            content: third,
            updateAt: 3,
            sortsByCreatedAt: false,
            maxHistorySize: 10
        ) == .saved)

        #expect(repository.fetchHistory(id: firstID) == nil)
        #expect(repository.fetchHistory(id: secondID)?.payloadByteCount == 4)
        #expect(repository.fetchHistory(id: thirdID)?.payloadByteCount == 4)
        #expect(
            repository
                .fetchHistoryDetails(sortsByCreatedAt: false, includesThumbnailAsset: false, limit: 10)
                .map(\.history.id) == [thirdID, secondID]
        )

        let assetCount = try database.read { database in
            try PasteboardHistoryAsset.all.fetchAll(database).count
        }
        #expect(assetCount == 2)
    }

    @Test
    func saveEnforcesCountLimitInTheSameTransaction() throws {
        let first = try #require(PasteboardContent.testContent(byteCount: 1, byte: 1))
        let second = try #require(PasteboardContent.testContent(byteCount: 1, byte: 2))
        let third = try #require(PasteboardContent.testContent(byteCount: 1, byte: 3))
        let firstID = PasteboardHistory.ID(rawValue: first.hash)
        let secondID = PasteboardHistory.ID(rawValue: second.hash)
        let thirdID = PasteboardHistory.ID(rawValue: third.hash)

        for (index, value) in [(firstID, first), (secondID, second), (thirdID, third)].enumerated() {
            #expect(repository.save(
                id: value.0,
                content: value.1,
                updateAt: index + 1,
                sortsByCreatedAt: false,
                maxHistorySize: 2
            ) == .saved)
        }

        #expect(repository.fetchHistory(id: firstID) == nil)
        #expect(
            repository
                .fetchHistoryDetails(sortsByCreatedAt: false, includesThumbnailAsset: false, limit: 10)
                .map(\.history.id) == [thirdID, secondID]
        )
    }

    @Test
    func forcedMaintenanceReturnsFreelistPagesToTheFileSystem() throws {
        let repository = PasteboardHistoryRepository(
            storagePolicy: PasteboardHistoryStoragePolicy(
                maxItemPayloadBytes: 3 * 1024 * 1024,
                maxTotalPayloadBytes: 4 * 1024 * 1024,
                reclaimThresholdBytes: 1,
                maximumIncrementalVacuumBytes: 3 * 1024 * 1024
            )
        )
        let content = try #require(
            PasteboardContent.testContent(byteCount: 2 * 1024 * 1024, byte: 7)
        )
        let id = PasteboardHistory.ID(rawValue: content.hash)
        #expect(repository.save(
            id: id,
            content: content,
            updateAt: 1,
            sortsByCreatedAt: false,
            maxHistorySize: 10
        ) == .saved)

        let metricsAfterSave = try #require(repository.storageMetrics())
        #expect(metricsAfterSave.autoVacuumMode == 2)
        repository.deleteAll()
        let metricsAfterDelete = try #require(repository.storageMetrics())
        #expect(metricsAfterDelete.freelistPageCount > 0)

        repository.reclaimUnusedStorage(force: true)

        let metricsAfterReclaim = try #require(repository.storageMetrics())
        #expect(metricsAfterReclaim.pageCount < metricsAfterDelete.pageCount)
        #expect(metricsAfterReclaim.freelistPageCount < metricsAfterDelete.freelistPageCount)
        #expect(metricsAfterReclaim.pageCount <= metricsAfterSave.pageCount)
    }

    @Test
    func routineMaintenanceHonorsThresholdAndUsesABoundedVacuumPass() throws {
        let waitingRepository = PasteboardHistoryRepository(
            storagePolicy: PasteboardHistoryStoragePolicy(
                maxItemPayloadBytes: 3 * 1024 * 1024,
                maxTotalPayloadBytes: 4 * 1024 * 1024,
                reclaimThresholdBytes: 3 * 1024 * 1024,
                maximumIncrementalVacuumBytes: 64 * 1024
            )
        )
        let content = try #require(
            PasteboardContent.testContent(byteCount: 2 * 1024 * 1024, byte: 7)
        )
        let id = PasteboardHistory.ID(rawValue: content.hash)
        #expect(waitingRepository.save(
            id: id,
            content: content,
            updateAt: 1,
            sortsByCreatedAt: false,
            maxHistorySize: 10
        ) == .saved)
        waitingRepository.deleteAll()

        let metricsBeforeMaintenance = try #require(waitingRepository.storageMetrics())
        #expect(metricsBeforeMaintenance.unusedBytes < 3 * 1024 * 1024)
        waitingRepository.reclaimUnusedStorage(force: false)
        #expect(waitingRepository.storageMetrics() == metricsBeforeMaintenance)

        let reclaimingRepository = PasteboardHistoryRepository(
            storagePolicy: PasteboardHistoryStoragePolicy(
                maxItemPayloadBytes: 3 * 1024 * 1024,
                maxTotalPayloadBytes: 4 * 1024 * 1024,
                reclaimThresholdBytes: 1,
                maximumIncrementalVacuumBytes: 64 * 1024
            )
        )
        reclaimingRepository.reclaimUnusedStorage(force: false)

        let metricsAfterMaintenance = try #require(reclaimingRepository.storageMetrics())
        #expect(metricsAfterMaintenance.pageCount < metricsBeforeMaintenance.pageCount)
        #expect(metricsAfterMaintenance.freelistPageCount < metricsBeforeMaintenance.freelistPageCount)
        #expect(metricsAfterMaintenance.freelistPageCount > 0)
    }

    @Test
    func maintenanceConvertsLegacyDatabaseAndPreservesRetainedHistory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "ClipAppStorageTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let databaseURL = directory.appending(path: "sqlite.db")
        let legacyDatabase = try DatabasePool(path: databaseURL.path)
        var migrator = DatabaseMigrator()
        migrator.registerMigration()
        try migrator.migrate(legacyDatabase)

        let initialAutoVacuumMode = try legacyDatabase.read { database in
            try Int.fetchOne(database, sql: "PRAGMA auto_vacuum")
        }
        #expect(initialAutoVacuumMode == 0)

        try withDependencies {
            $0.defaultDatabase = legacyDatabase
        } operation: {
            let repository = PasteboardHistoryRepository(
                storagePolicy: PasteboardHistoryStoragePolicy(
                    maxItemPayloadBytes: 3 * 1024 * 1024,
                    maxTotalPayloadBytes: 4 * 1024 * 1024,
                    reclaimThresholdBytes: 1,
                    maximumIncrementalVacuumBytes: 3 * 1024 * 1024
                )
            )
            let discarded = try #require(
                PasteboardContent.testContent(byteCount: 2 * 1024 * 1024, byte: 7)
            )
            let retained = try #require(PasteboardContent.testContent(byteCount: 256, byte: 8))
            let discardedID = PasteboardHistory.ID(rawValue: discarded.hash)
            let retainedID = PasteboardHistory.ID(rawValue: retained.hash)
            #expect(repository.save(
                id: discardedID,
                content: discarded,
                updateAt: 1,
                sortsByCreatedAt: false,
                maxHistorySize: 10
            ) == .saved)
            #expect(repository.save(
                id: retainedID,
                content: retained,
                updateAt: 2,
                sortsByCreatedAt: false,
                maxHistorySize: 10
            ) == .saved)
            try legacyDatabase.writeWithoutTransaction { database in
                try database.checkpoint(.truncate)
            }
            repository.deleteHistory(id: discardedID)

            let metricsBeforeReclaim = try #require(repository.storageMetrics())
            let bytesBeforeReclaim = try databaseBytes(at: databaseURL)
            #expect(metricsBeforeReclaim.autoVacuumMode == 0)
            #expect(metricsBeforeReclaim.freelistPageCount > 0)

            repository.reclaimUnusedStorage(force: true)

            let metricsAfterReclaim = try #require(repository.storageMetrics())
            let bytesAfterReclaim = try databaseBytes(at: databaseURL)
            #expect(metricsAfterReclaim.autoVacuumMode == 2)
            #expect(metricsAfterReclaim.pageCount < metricsBeforeReclaim.pageCount)
            #expect(bytesAfterReclaim < bytesBeforeReclaim)
            #expect(repository.fetchContent(id: retainedID) == retained)
            let integrity = try legacyDatabase.read { database in
                try String.fetchOne(database, sql: "PRAGMA quick_check")
            }
            #expect(integrity == "ok")
        }
        try legacyDatabase.close()
    }
}

private extension PasteboardContent {
    static func testContent(byteCount: Int, byte: UInt8) -> PasteboardContent? {
        PasteboardContent(
            assets: [PasteboardContent.Asset(type: .rtf, data: Data(repeating: byte, count: byteCount))]
        )
    }
}

private func databaseBytes(at databaseURL: URL) throws -> Int64 {
    try [databaseURL, URL(filePath: databaseURL.path + "-wal"), URL(filePath: databaseURL.path + "-shm")]
        .reduce(into: Int64(0)) { size, url in
            guard FileManager.default.fileExists(atPath: url.path) else { return }
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            size += (attributes[.size] as? NSNumber)?.int64Value ?? 0
        }
}
