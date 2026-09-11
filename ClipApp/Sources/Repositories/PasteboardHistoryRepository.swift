//
//  PasteboardHistoryRepository.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Shunsuke Furubayashi on 2026/05/28.
//
//  Copyright © 2015-2026 Clipy Project.
//

import AppKit
import Combine
import Dependencies
import SQLiteData

struct PasteboardHistoryStoragePolicy: Equatable {
    static let standard = PasteboardHistoryStoragePolicy(
        maxItemPayloadBytes: 128 * 1024 * 1024,
        maxTotalPayloadBytes: 1024 * 1024 * 1024
    )

    let maxItemPayloadBytes: Int64
    let maxTotalPayloadBytes: Int64
    let reclaimThresholdBytes: Int64
    let maximumIncrementalVacuumBytes: Int64

    init(
        maxItemPayloadBytes: Int64,
        maxTotalPayloadBytes: Int64,
        reclaimThresholdBytes: Int64? = nil,
        maximumIncrementalVacuumBytes: Int64? = nil
    ) {
        self.maxItemPayloadBytes = max(1, maxItemPayloadBytes)
        self.maxTotalPayloadBytes = max(1, maxTotalPayloadBytes)
        self.reclaimThresholdBytes = max(1, reclaimThresholdBytes ?? maxItemPayloadBytes)
        self.maximumIncrementalVacuumBytes = max(1, maximumIncrementalVacuumBytes ?? maxItemPayloadBytes)
    }
}

enum PasteboardHistorySaveResult: Equatable {
    case saved
    case rejectedItemTooLarge(maximumBytes: Int64)
    case historyDisabled
    case failed
}

struct PasteboardHistoryStorageMetrics: Equatable {
    let autoVacuumMode: Int
    let pageSize: Int64
    let pageCount: Int64
    let freelistPageCount: Int64

    var unusedBytes: Int64 {
        freelistPageCount * pageSize
    }
}

protocol PasteboardHistoryRepositoryProtocol {
    func observeHistories() -> AnyPublisher<[PasteboardHistory], Never>
    func hasHistories() -> Bool
    func fetchHistoryDetails(
        sortsByCreatedAt: Bool,
        includesThumbnailAsset: Bool,
        limit: Int,
    ) -> [PasteboardHistoryDetail]
    func fetchHistory(id: PasteboardHistory.ID) -> PasteboardHistory?
    func fetchContent(id: PasteboardHistory.ID) -> PasteboardContent?

    @discardableResult
    func save(
        id: PasteboardHistory.ID,
        content: PasteboardContent,
        updateAt: Int,
        sortsByCreatedAt: Bool,
        maxHistorySize: Int
    ) -> PasteboardHistorySaveResult
    func updateOCRText(id: PasteboardHistory.ID, ocrText: String)
    func deleteHistory(id: PasteboardHistory.ID)
    func deleteAll()
    func deleteOverflowingHistories(sortsByCreatedAt: Bool, maxHistorySize: Int)
    func reclaimUnusedStorage(force: Bool)
}

final class PasteboardHistoryRepository: PasteboardHistoryRepositoryProtocol {
    @Dependency(\.defaultDatabase)
    private var database

    @FetchAll(PasteboardHistory.all.order { $0.updateAt.desc() })
    private var histories

    private let storagePolicy: PasteboardHistoryStoragePolicy
    private let storageMaintenanceLock = NSLock()
    private var hasAttemptedLegacyAutoVacuumUpgrade = false

    init(storagePolicy: PasteboardHistoryStoragePolicy = .standard) {
        self.storagePolicy = storagePolicy
    }

    func observeHistories() -> AnyPublisher<[PasteboardHistory], Never> {
        _histories.publisher.eraseToAnyPublisher()
    }

    func hasHistories() -> Bool {
        withErrorReporting {
            try database.read { database in
                try PasteboardHistory
                    .select { $0.id }
                    .limit(1)
                    .fetchOne(database) != nil
            }
        } ?? false
    }

    func fetchHistoryDetails(
        sortsByCreatedAt: Bool,
        includesThumbnailAsset: Bool,
        limit: Int
    ) -> [PasteboardHistoryDetail] {
        withErrorReporting {
            try database.read { database in
                let histories = PasteboardHistory
                    .all
                    .order { columns in
                        if sortsByCreatedAt {
                            columns.createdAt.desc()
                        } else {
                            columns.updateAt.desc()
                        }
                    }
                    .limit(limit)

                guard includesThumbnailAsset else {
                    return try histories
                        .fetchAll(database)
                        .map { PasteboardHistoryDetail(history: $0, thumbnailAsset: nil) }
                }

                return try histories
                    .leftJoin(PasteboardHistoryThumbnailAsset.all) { $0.id.eq($1.pasteboardHistoryID) }
                    .select { PasteboardHistoryDetail.Columns(history: $0, thumbnailAsset: $1) }
                    .fetchAll(database)
            }
        } ?? []
    }

    func fetchHistory(id: PasteboardHistory.ID) -> PasteboardHistory? {
        withErrorReporting {
            try database.read { database in
                try PasteboardHistory.find(id).fetchOne(database)
            }
        }
    }

    func fetchContent(id: PasteboardHistory.ID) -> PasteboardContent? {
        withErrorReporting {
            try database.read { database in
                let assets = try PasteboardHistoryAsset
                    .where { $0.pasteboardHistoryID.eq(id) }
                    .order(by: \.index)
                    .fetchAll(database)
                return PasteboardContent(
                    assets: assets.map {
                        PasteboardContent.Asset(type: $0.pasteboardType, data: $0.data)
                    }
                )
            }
        }
    }

    @discardableResult
    func save(
        id: PasteboardHistory.ID,
        content: PasteboardContent,
        updateAt: Int,
        sortsByCreatedAt: Bool,
        maxHistorySize: Int
    ) -> PasteboardHistorySaveResult {
        guard maxHistorySize > 0 else { return .historyDisabled }
        guard content.payloadByteCount <= storagePolicy.maxItemPayloadBytes,
              content.payloadByteCount <= storagePolicy.maxTotalPayloadBytes else {
            return .rejectedItemTooLarge(
                maximumBytes: min(storagePolicy.maxItemPayloadBytes, storagePolicy.maxTotalPayloadBytes)
            )
        }

        let thumbnailAsset = thumbnailAsset(from: content, id: id)
        let thumbnailByteCount = Int64(thumbnailAsset?.data.count ?? 0)
        let (newPayloadByteCount, overflow) = content.payloadByteCount.addingReportingOverflow(thumbnailByteCount)
        guard !overflow,
              newPayloadByteCount <= storagePolicy.maxItemPayloadBytes,
              newPayloadByteCount <= storagePolicy.maxTotalPayloadBytes else {
            return .rejectedItemTooLarge(
                maximumBytes: min(storagePolicy.maxItemPayloadBytes, storagePolicy.maxTotalPayloadBytes)
            )
        }

        return withErrorReporting {
            try database.write { database in
                let existingHistory = try PasteboardHistory
                    .find(id)
                    .fetchOne(database)

                // For new content, evict the oldest rows before inserting the BLOBs. The delete
                // and insert share one transaction, so failed inserts restore every evicted row.
                if existingHistory == nil {
                    try trimHistories(
                        in: database,
                        sortsByCreatedAt: sortsByCreatedAt,
                        maxHistorySize: maxHistorySize,
                        reservedHistoryCount: 1,
                        reservedPayloadBytes: newPayloadByteCount
                    )
                }

                let history = PasteboardHistory(
                    id: id,
                    title: String(content.stringValue.prefix(10000)),
                    ocrText: existingHistory?.ocrText,
                    pasteboardTypes: content.types,
                    payloadByteCount: existingHistory?.payloadByteCount ?? newPayloadByteCount,
                    createdAt: existingHistory?.createdAt ?? updateAt,
                    updateAt: updateAt,
                    deviceID: CPYUtilities.deviceID
                )
                try PasteboardHistory
                    .upsert { history }
                    .execute(database)
                // When a history already exists, its ID is derived from the content hash,
                // so the assets are guaranteed to be identical and do not need to be inserted again.
                if existingHistory == nil {
                    let assets = content.assets.enumerated().map { index, asset in
                        PasteboardHistoryAsset.Draft(
                            pasteboardHistoryID: id,
                            index: index,
                            pasteboardType: asset.type,
                            data: asset.data
                        )
                    }
                    try PasteboardHistoryAsset.insert { assets }.execute(database)
                    if let thumbnailAsset {
                        try PasteboardHistoryThumbnailAsset.insert { thumbnailAsset }.execute(database)
                    }
                }

                if existingHistory != nil {
                    try trimHistories(
                        in: database,
                        sortsByCreatedAt: sortsByCreatedAt,
                        maxHistorySize: maxHistorySize
                    )
                }
                return PasteboardHistorySaveResult.saved
            }
        } ?? .failed
    }

    func updateOCRText(id: PasteboardHistory.ID, ocrText: String) {
        withErrorReporting {
            try database.write { database in
                try PasteboardHistory
                    .find(id)
                    .update { $0.ocrText = #bind(ocrText) }
                    .execute(database)
            }
        }
    }

    func deleteHistory(id: PasteboardHistory.ID) {
        withErrorReporting {
            try database.write { database in
                try PasteboardHistory
                    .delete()
                    .where { $0.id.eq(id) }
                    .execute(database)
            }
        }
    }

    func deleteAll() {
        withErrorReporting {
            try database.write { database in
                try PasteboardHistory.delete().execute(database)
            }
        }
    }

    func deleteOverflowingHistories(sortsByCreatedAt: Bool, maxHistorySize: Int) {
        withErrorReporting {
            try database.write { database in
                try trimHistories(
                    in: database,
                    sortsByCreatedAt: sortsByCreatedAt,
                    maxHistorySize: maxHistorySize
                )
            }
        }
    }

    func storageMetrics() -> PasteboardHistoryStorageMetrics? {
        withErrorReporting {
            try database.read { database in
                PasteboardHistoryStorageMetrics(
                    autoVacuumMode: try #sql("PRAGMA auto_vacuum", as: Int.self).fetchOne(database) ?? 0,
                    pageSize: try #sql("PRAGMA page_size", as: Int64.self).fetchOne(database) ?? 0,
                    pageCount: try #sql("PRAGMA page_count", as: Int64.self).fetchOne(database) ?? 0,
                    freelistPageCount: try #sql("PRAGMA freelist_count", as: Int64.self).fetchOne(database) ?? 0
                )
            }
        }
    }

    func reclaimUnusedStorage(force: Bool) {
        storageMaintenanceLock.lock()
        defer { storageMaintenanceLock.unlock() }

        withErrorReporting {
            guard var metrics = storageMetrics() else { return }

            // Databases created before this migration use auto_vacuum=NONE. A one-time VACUUM
            // safely rebuilds the file and switches it to incremental reclamation. If SQLite
            // cannot allocate its temporary file, VACUUM rolls back and the source stays intact.
            if metrics.autoVacuumMode == 0 {
                // If the disk is too full for the rebuild, do not retry every minute. A new app
                // launch creates a fresh repository and makes one more recovery attempt.
                guard !hasAttemptedLegacyAutoVacuumUpgrade else { return }
                hasAttemptedLegacyAutoVacuumUpgrade = true
                try database.writeWithoutTransaction { database in
                    try database.execute(sql: "PRAGMA auto_vacuum = INCREMENTAL")
                    try database.execute(sql: "VACUUM")
                    try database.checkpoint(.truncate)
                }
                metrics = storageMetrics() ?? metrics
            }

            guard metrics.autoVacuumMode == 2, metrics.freelistPageCount > 0 else { return }
            guard force || metrics.unusedBytes >= storagePolicy.reclaimThresholdBytes else { return }
            guard metrics.pageSize > 0 else { return }

            try database.writeWithoutTransaction { database in
                if force {
                    try database.execute(sql: "PRAGMA incremental_vacuum")
                    try database.checkpoint(.truncate)
                } else {
                    let maximumPages = max(1, storagePolicy.maximumIncrementalVacuumBytes / metrics.pageSize)
                    let pageCount = min(metrics.freelistPageCount, maximumPages)
                    try database.execute(sql: "PRAGMA incremental_vacuum(\(pageCount))")
                    try database.checkpoint(.passive)
                }
            }
        }
    }
}

private extension PasteboardHistoryRepository {
    func trimHistories(
        in database: Database,
        sortsByCreatedAt: Bool,
        maxHistorySize: Int,
        reservedHistoryCount: Int = 0,
        reservedPayloadBytes: Int64 = 0
    ) throws {
        let histories = try PasteboardHistory
            .order { columns in
                if sortsByCreatedAt {
                    columns.createdAt.desc()
                } else {
                    columns.updateAt.desc()
                }
            }
            .fetchAll(database)
        let retainedHistoryLimit = max(0, maxHistorySize - reservedHistoryCount)
        let retainedPayloadLimit = max(0, storagePolicy.maxTotalPayloadBytes - reservedPayloadBytes)
        var retainedHistoryCount = 0
        var retainedPayloadBytes: Int64 = 0
        var reachedLimit = false
        var deletingIDs = [PasteboardHistory.ID]()

        for history in histories {
            let payloadByteCount = max(0, history.payloadByteCount)
            let fitsCount = retainedHistoryCount < retainedHistoryLimit
            let fitsPayload = payloadByteCount <= retainedPayloadLimit - retainedPayloadBytes
            if !reachedLimit, fitsCount, fitsPayload {
                retainedHistoryCount += 1
                retainedPayloadBytes += payloadByteCount
            } else {
                // Keep a contiguous newest-first prefix. Once a row does not fit, every older
                // row is evicted instead of retaining surprising holes in clipboard history.
                reachedLimit = true
                deletingIDs.append(history.id)
            }
        }

        guard !deletingIDs.isEmpty else { return }
        try PasteboardHistory
            .delete()
            .where { $0.id.in(deletingIDs) }
            .execute(database)
    }

    func thumbnailAsset(from content: PasteboardContent, id: PasteboardHistory.ID) -> PasteboardHistoryThumbnailAsset? {
        var asset: PasteboardHistoryThumbnailAsset?
        if let thumbnailImage = content.thumbnailImage, let thumbnailData = thumbnailImage.tiffRepresentation {
            asset = PasteboardHistoryThumbnailAsset(
                pasteboardHistoryID: id,
                kind: .image,
                data: thumbnailData
            )
        }
        if let colorCodeImage = content.colorCodeImage, let colorCodeData = colorCodeImage.tiffRepresentation {
            asset = PasteboardHistoryThumbnailAsset(
                pasteboardHistoryID: id,
                kind: .colorCode,
                data: colorCodeData
            )
        }
        return asset
    }
}

extension PasteboardHistoryRepositoryProtocol {
    @discardableResult
    func save(
        id: PasteboardHistory.ID,
        content: PasteboardContent,
        updateAt: Int
    ) -> PasteboardHistorySaveResult {
        save(
            id: id,
            content: content,
            updateAt: updateAt,
            sortsByCreatedAt: false,
            maxHistorySize: .max
        )
    }
}

private enum PasteboardHistoryRepositoryKey: DependencyKey {
    static let liveValue: any PasteboardHistoryRepositoryProtocol = PasteboardHistoryRepository()
}

extension DependencyValues {
    var pasteboardHistoryRepository: PasteboardHistoryRepositoryProtocol {
        get { self[PasteboardHistoryRepositoryKey.self] }
        set { self[PasteboardHistoryRepositoryKey.self] = newValue }
    }
}
