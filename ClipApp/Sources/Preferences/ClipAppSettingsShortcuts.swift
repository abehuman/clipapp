//
//  ClipAppSettingsShortcuts.swift
//
//  ClipApp
//

import Cocoa
import KeyHolder
import Magnet
import SwiftUI

// MARK: - Shortcuts

private final class ShortcutSettingsModel: ObservableObject {
    @Published var mainKeyCombo: KeyCombo?
    @Published var historyKeyCombo: KeyCombo?
    @Published var snippetKeyCombo: KeyCombo?
    @Published var clearHistoryKeyCombo: KeyCombo?

    private let hotKeyService: HotKeyService

    init(hotKeyService: HotKeyService = AppEnvironment.current.hotKeyService) {
        self.hotKeyService = hotKeyService
        mainKeyCombo = hotKeyService.mainKeyCombo
        historyKeyCombo = hotKeyService.historyKeyCombo
        snippetKeyCombo = hotKeyService.snippetKeyCombo
        clearHistoryKeyCombo = hotKeyService.clearHistoryKeyCombo
    }

    func update(_ kind: ShortcutKind, keyCombo: KeyCombo?) {
        switch kind {
        case .main:
            mainKeyCombo = keyCombo
            hotKeyService.change(with: .main, keyCombo: keyCombo)
        case .history:
            historyKeyCombo = keyCombo
            hotKeyService.change(with: .history, keyCombo: keyCombo)
        case .snippets:
            snippetKeyCombo = keyCombo
            hotKeyService.change(with: .snippet, keyCombo: keyCombo)
        case .clearHistory:
            clearHistoryKeyCombo = keyCombo
            hotKeyService.changeClearHistoryKeyCombo(keyCombo)
        }
    }
}

private enum ShortcutKind {
    case main
    case history
    case snippets
    case clearHistory
}

struct ShortcutSettingsView: View {
    @StateObject private var model = ShortcutSettingsModel()

    var body: some View {
        SettingsPage(
            title: settingsLocalized("Shortcuts"),
            subtitle: settingsLocalized("Set the keys you use to open ClipApp and manage history.")
        ) {
            SettingsInfoBanner(
                icon: "keyboard",
                title: settingsLocalized("Record a Shortcut"),
                message: settingsLocalized("Click a shortcut field, then press the key combination you want to use.")
            )

            SettingsCard(settingsLocalized("Menu Shortcuts")) {
                shortcutRow(
                    title: settingsLocalized("Open ClipApp"),
                    subtitle: settingsLocalized("Show history and snippets in one menu."),
                    keyCombo: $model.mainKeyCombo,
                    kind: .main
                )
                SettingsDivider()
                shortcutRow(
                    title: settingsLocalized("Open History"),
                    subtitle: settingsLocalized("Show clipboard history only."),
                    keyCombo: $model.historyKeyCombo,
                    kind: .history
                )
                SettingsDivider()
                shortcutRow(
                    title: settingsLocalized("Open Snippets"),
                    subtitle: settingsLocalized("Show saved snippets only."),
                    keyCombo: $model.snippetKeyCombo,
                    kind: .snippets
                )
            }

            SettingsCard(settingsLocalized("History Actions")) {
                shortcutRow(
                    title: settingsLocalized("Clear History"),
                    subtitle: settingsLocalized("Open the confirmation for clearing all history."),
                    keyCombo: $model.clearHistoryKeyCombo,
                    kind: .clearHistory
                )
            }
        }
    }

    private func shortcutRow(
        title: String,
        subtitle: String,
        keyCombo: Binding<KeyCombo?>,
        kind: ShortcutKind
    ) -> some View {
        SettingsValueRow(title, subtitle: subtitle) {
            ShortcutRecorderView(
                keyCombo: keyCombo,
                accessibilityLabel: title,
                onChange: { model.update(kind, keyCombo: $0) }
            )
            .frame(width: 245, height: 38)
        }
    }
}

private struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var keyCombo: KeyCombo?
    let accessibilityLabel: String
    let onChange: (KeyCombo?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> RecordView {
        let view = RecordView(frame: .zero)
        view.delegate = context.coordinator
        view.backgroundColor = .textBackgroundColor
        view.tintColor = NSColor(resource: .clipApp)
        view.borderColor = .separatorColor
        view.borderWidth = 1
        view.cornerRadius = 8
        view.clearButtonMode = .whenRecorded
        view.keyCombo = keyCombo
        view.setAccessibilityRole(.textField)
        view.setAccessibilityLabel(accessibilityLabel)
        view.setAccessibilityHelp(settingsLocalized("Click the field, then press a key combination."))
        return view
    }

    func updateNSView(_ view: RecordView, context: Context) {
        context.coordinator.parent = self
        view.setAccessibilityLabel(accessibilityLabel)
        guard !view.isRecording else { return }
        if !keyCombosMatch(view.keyCombo, keyCombo) {
            view.keyCombo = keyCombo
        }
    }

    private func keyCombosMatch(_ lhs: KeyCombo?, _ rhs: KeyCombo?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return lhs.isEqual(rhs)
        default:
            return false
        }
    }

    final class Coordinator: NSObject, RecordViewDelegate {
        var parent: ShortcutRecorderView

        init(_ parent: ShortcutRecorderView) {
            self.parent = parent
        }

        func recordViewShouldBeginRecording(_ recordView: RecordView) -> Bool {
            true
        }

        func recordView(_ recordView: RecordView, canRecordKeyCombo keyCombo: KeyCombo) -> Bool {
            true
        }

        func recordView(_ recordView: RecordView, didChangeKeyCombo keyCombo: KeyCombo?) {
            parent.keyCombo = keyCombo
            parent.onChange(keyCombo)
        }

        func recordViewDidEndRecording(_ recordView: RecordView) {}
    }
}
