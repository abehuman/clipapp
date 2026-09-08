//
//  ClipAppSettingsView.swift
//
//  ClipApp
//

import Cocoa
import SwiftUI

func settingsLocalized(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: "Settings")
}

private func appLocalized(_ key: String) -> String {
    Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

var settingsAccentColor: Color {
    Color(nsColor: NSColor(resource: .clipApp))
}

var settingsSwitchOnColor: Color {
    Color(nsColor: .systemGreen)
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case historyAndMenu
    case shortcuts
    case captureAndPrivacy
    case advanced

    static let storageKey = "ClipApp.selectedSettingsPane"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            settingsLocalized("General")
        case .historyAndMenu:
            settingsLocalized("History & Menu")
        case .shortcuts:
            settingsLocalized("Shortcuts")
        case .captureAndPrivacy:
            settingsLocalized("Capture & Privacy")
        case .advanced:
            settingsLocalized("Advanced")
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            "gearshape"
        case .historyAndMenu:
            "clock.arrow.circlepath"
        case .shortcuts:
            "keyboard"
        case .captureAndPrivacy:
            "hand.raised"
        case .advanced:
            "slider.horizontal.3"
        }
    }
}

struct ClipAppSettingsView: View {
    @AppStorage(SettingsPane.storageKey) private var selectedPaneRawValue = SettingsPane.general.rawValue
    @SwiftUI.Environment(\.colorScheme) private var colorScheme

    private var selectedPane: SettingsPane {
        SettingsPane(rawValue: selectedPaneRawValue) ?? .general
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                VStack(spacing: 4) {
                    ForEach(SettingsPane.allCases) { pane in
                        SettingsSidebarRow(
                            pane: pane,
                            isSelected: selectedPane == pane
                        ) {
                            selectedPaneRawValue = pane.rawValue
                        }
                    }
                }
                .padding(12)

                Spacer(minLength: 16)
                SettingsAppIdentity()
            }
            .frame(width: 205)
            .background {
                Color(nsColor: .windowBackgroundColor)
                    .overlay(Color.primary.opacity(0.035))
            }

            Rectangle()
                .fill(colorScheme == .dark ? Color(white: 0.23) : Color(white: 0.90))
                .frame(width: 1)
                .accessibilityHidden(true)
            settingsDetail
        }
        .frame(minWidth: 900, minHeight: 600)
        .tint(settingsAccentColor)
    }

    @ViewBuilder
    private var settingsDetail: some View {
        switch selectedPane {
        case .general:
            GeneralSettingsView()
        case .historyAndMenu:
            HistoryMenuSettingsView()
        case .shortcuts:
            ShortcutSettingsView()
        case .captureAndPrivacy:
            CapturePrivacySettingsView()
        case .advanced:
            AdvancedSettingsView()
        }
    }
}

private struct SettingsSidebarRow: View {
    let pane: SettingsPane
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: pane.systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? settingsAccentColor : Color.secondary)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(pane.title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? settingsAccentColor.opacity(0.14) : Color.clear)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pane.title)
    }
}

private struct SettingsAppIdentity: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("ClipApp")
                        .font(.system(size: 13, weight: .semibold))
                    if !version.isEmpty {
                        Text("v\(version)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Color.clear)
    }
}

// MARK: - Shared layout

struct SettingsPage<Content: View>: View {
    let title: String
    let subtitle: String
    private let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 26, weight: .bold))
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                content
            }
            .frame(maxWidth: 650, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct SettingsCard<Content: View>: View {
    let title: String?
    private let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }

            VStack(spacing: 0) {
                content
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
            }
        }
    }
}

struct SettingsRowLabel: View {
    let title: String
    let subtitle: String?

    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.subtitle = subtitle
        _isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack {
                SettingsRowLabel(title, subtitle: subtitle)
                Spacer(minLength: 24)
            }
            .contentShape(Rectangle())
        }
        .toggleStyle(.switch)
        .tint(settingsSwitchOnColor)
        .controlSize(.regular)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

struct SettingsValueRow<Control: View>: View {
    let title: String
    let subtitle: String?
    private let control: Control

    init(
        _ title: String,
        subtitle: String? = nil,
        @ViewBuilder control: () -> Control
    ) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            SettingsRowLabel(title, subtitle: subtitle)
            Spacer(minLength: 16)
            control
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 16)
    }
}

struct NumberSettingControl: View {
    @Binding var value: Int
    let minimum: Int
    let step: Int
    let unit: String

    private var clampedValue: Binding<Int> {
        Binding(
            get: { value },
            set: { value = max(minimum, $0) }
        )
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("", value: clampedValue, format: .number)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.trailing)
                .frame(width: 62)
                .accessibilityLabel(unit)
            Stepper("", value: clampedValue, step: step)
                .labelsHidden()
            Text(unit)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

struct SettingsInfoBanner: View {
    let icon: String
    let title: String
    let message: String
    var color: Color = settingsAccentColor

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.22), lineWidth: 1)
        }
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @AppStorage(Constants.UserDefaults.loginItem) private var launchAtLogin = false
    @AppStorage(Constants.UserDefaults.inputPasteCommand) private var pasteAutomatically = true
    @AppStorage(Constants.UserDefaults.playSoundOnCopy) private var playCopySound = true
    @AppStorage(Constants.UserDefaults.showStatusItem) private var showInMenuBar = true
    @AppStorage(Constants.UserDefaults.didShowMenuBarHiddenNotice) private var didShowMenuBarHiddenNotice = false

    private var showInMenuBarBinding: Binding<Bool> {
        Binding(
            get: { showInMenuBar },
            set: { newValue in
                guard newValue != showInMenuBar else { return }
                if !newValue && !didShowMenuBarHiddenNotice {
                    let alert = NSAlert()
                    alert.alertStyle = .informational
                    alert.messageText = appLocalized("Hide ClipApp from the menu bar?")
                    alert.informativeText = appLocalized(
                        "You can still open your clipboard history with your keyboard shortcut. To show ClipApp in the menu bar again, open ClipApp from Spotlight or the Applications folder, then enable it in Preferences."
                    )
                    alert.addButton(withTitle: appLocalized("Hide"))
                    alert.addButton(withTitle: appLocalized("Cancel"))

                    guard alert.runModal() == .alertFirstButtonReturn else { return }
                    didShowMenuBarHiddenNotice = true
                }
                showInMenuBar = newValue
                UserDefaults.standard.synchronize()
            }
        )
    }

    var body: some View {
        SettingsPage(
            title: settingsLocalized("General"),
            subtitle: settingsLocalized("Choose how ClipApp starts and behaves.")
        ) {
            SettingsCard(settingsLocalized("Startup")) {
                SettingsToggleRow(
                    settingsLocalized("Launch at Login"),
                    subtitle: settingsLocalized("Open ClipApp automatically when you sign in."),
                    isOn: $launchAtLogin
                )
                SettingsDivider()
                SettingsToggleRow(
                    settingsLocalized("Show in Menu Bar"),
                    subtitle: settingsLocalized("Keep ClipApp available from the menu bar."),
                    isOn: showInMenuBarBinding
                )
            }

            SettingsCard(settingsLocalized("Behavior")) {
                SettingsToggleRow(
                    settingsLocalized("Paste Automatically"),
                    subtitle: settingsLocalized("Paste the selected item without pressing Command-V."),
                    isOn: $pasteAutomatically
                )
                SettingsDivider()
                SettingsToggleRow(
                    settingsLocalized("Play Copy Sound"),
                    subtitle: settingsLocalized("Play a sound when new content is copied."),
                    isOn: $playCopySound
                )
            }
        }
    }
}
