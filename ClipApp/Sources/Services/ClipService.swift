//
//  ClipService.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/11/17.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa
import Dependencies
import Foundation
import RxSwift
import RxCocoa

final class ClipService {

    // MARK: - Properties
    private static let copySound = NSSound(named: NSSound.Name("Tink"))

    fileprivate var cachedChangeCount = BehaviorRelay<Int>(value: 0)
    fileprivate var storeTypes = [String: NSNumber]()
    fileprivate let scheduler = SerialDispatchQueueScheduler(qos: .userInteractive)
    fileprivate let lock = NSRecursiveLock(name: "jp.co.aiv.clipApp.ClipUpdatable")
    fileprivate var disposeBag = DisposeBag()
    private var copySoundSuppressedChangeCounts: ClosedRange<Int>?
    private let copySoundPlayer: () -> Void
    private let defaults: () -> UserDefaults

    @Dependency(\.pasteboardHistoryRepository)
    private var pasteboardHistoryRepository
    @Dependency(\.textRecognizer)
    private var textRecognizer

    init(copySoundPlayer: (() -> Void)? = nil,
         defaults: @escaping () -> UserDefaults = { AppEnvironment.current.defaults }) {
        self.copySoundPlayer = copySoundPlayer ?? Self.playSystemCopySound
        self.defaults = defaults
    }

    // MARK: - Clips
    func startMonitoring() {
        disposeBag = DisposeBag()
        let initialChangeCount = NSPasteboard.general.changeCount
        suppressCopySound(for: initialChangeCount...initialChangeCount)
        // Pasteboard observe timer
        Observable<Int>.interval(.milliseconds(500), scheduler: scheduler)
            .map { _ in NSPasteboard.general.changeCount }
            .withLatestFrom(cachedChangeCount.asObservable()) { ($0, $1) }
            .filter { $0 != $1 }
            .subscribe(onNext: { [weak self] changeCount, _ in
                self?.cachedChangeCount.accept(changeCount)
                self?.playCopySoundIfNeeded(for: changeCount)
                self?.create()
            })
            .disposed(by: disposeBag)
        // Store types
        storeTypes = AppEnvironment.current.defaults.object(forKey: Constants.UserDefaults.storeTypes) as? [String: NSNumber] ?? [:]
        AppEnvironment.current.defaults.rx
            .observe([String: NSNumber].self, Constants.UserDefaults.storeTypes)
            .compactMap { $0 }
            .asDriver(onErrorDriveWith: .empty())
            .drive(onNext: { [weak self] in
                self?.storeTypes = $0
            })
            .disposed(by: disposeBag)
    }

    func clearAll() {
        pasteboardHistoryRepository.deleteAll()
        // Clear legacy Realm-backed history caches used through v1.2.1.
        try? FileManager.default.removeItem(atPath: CPYUtilities.applicationSupportFolder())
    }

    func delete(id: PasteboardHistory.ID) {
        pasteboardHistoryRepository.deleteHistory(id: id)
    }

    func incrementChangeCount() {
        cachedChangeCount.accept(cachedChangeCount.value + 1)
    }

    func performInternalPasteboardWrite(to pasteboard: NSPasteboard, _ write: () -> Void) {
        lock.lock(); defer { lock.unlock() }

        let previousChangeCount = pasteboard.changeCount
        write()
        let currentChangeCount = pasteboard.changeCount
        guard currentChangeCount > previousChangeCount else { return }
        suppressCopySound(for: (previousChangeCount + 1)...currentChangeCount)
    }

    func playCopySoundIfNeeded(for changeCount: Int, pasteboard: NSPasteboard = .general) {
        lock.lock(); defer { lock.unlock() }

        if let suppressedChangeCounts = copySoundSuppressedChangeCounts {
            if suppressedChangeCounts.contains(changeCount) {
                if changeCount == suppressedChangeCounts.upperBound {
                    copySoundSuppressedChangeCounts = nil
                }
                return
            }
            copySoundSuppressedChangeCounts = nil
        }

        guard defaults().bool(forKey: Constants.UserDefaults.playSoundOnCopy),
              !(pasteboard.types ?? []).isEmpty else { return }
        copySoundPlayer()
    }

}

private extension ClipService {
    static func playSystemCopySound() {
        DispatchQueue.main.async {
            copySound?.stop()
            copySound?.play()
        }
    }

    func suppressCopySound(for changeCounts: ClosedRange<Int>) {
        lock.lock(); defer { lock.unlock() }
        copySoundSuppressedChangeCounts = changeCounts
    }
}

// MARK: - Create Clip
extension ClipService {
    fileprivate func create() {
        lock.lock(); defer { lock.unlock() }

        let pasteboard = NSPasteboard.general
        // Prefer the root pasteboard types because they are comprehensive and can include root-only
        // fallback types such as .deprecatedFilenames and .tiff. Fall back to item types when needed,
        // then let PasteboardAvailableType filter the storeable types.
        let types = PasteboardAvailableType.availableTypes(
            from: pasteboard.types ?? pasteboard.pasteboardItems?.flatMap(\.types) ?? [],
            storeAvailableTypes: storeTypes.filter { $0.value.boolValue }.compactMap { PasteboardAvailableType(rawValue: $0.key) },
            ignoresConcealedType: AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.ignoreConcealedPasteboardType)
        )
        guard !types.isEmpty else { return }

        // Excluded application
        guard !AppEnvironment.current.excludeAppService.frontProcessIsExcludedApplication() else { return }
        // Special applications
        guard !AppEnvironment.current.excludeAppService.copiedProcessIsExcludedApplications(pasteboard: pasteboard) else { return }

        guard let content = PasteboardContent(pasteboard: pasteboard, types: types) else { return }
        save(content)
    }

    func create(with image: NSImage) {
        lock.lock(); defer { lock.unlock() }

        guard let content = PasteboardContent(image: image) else { return }
        save(content)
    }

    private func save(_ content: PasteboardContent) {
        // Copy already copied history
        let isCopySameHistory = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.copySameHistory)
        let historyID = PasteboardHistory.ID(rawValue: content.hash)
        if pasteboardHistoryRepository.fetchHistory(id: historyID) != nil, !isCopySameHistory { return }

        // Don't save empty string history
        if content.isOnlyStringType && content.stringValue.isEmpty { return }

        // Overwrite same history
        let isOverwriteHistory = AppEnvironment.current.defaults.bool(forKey: Constants.UserDefaults.overwriteSameHistory)
        let savedHash = (isOverwriteHistory) ? content.hash : UUID().uuidString

        let unixTime = Int(Date().timeIntervalSince1970)
        let id = PasteboardHistory.ID(rawValue: savedHash)
        pasteboardHistoryRepository.save(id: id, content: content, updateAt: unixTime)
        textRecognizer.recognizeTextIfNeeded(id: id)
    }
}
