//
//  ClipAppSettingsCaptureAdvanced.swift
//
//  ClipApp
//

import Cocoa
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Capture and privacy

final class ClipboardTypeSettingsModel: ObservableObject {
    @Published private(set) var values: [String: Bool]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppEnvironment.current.defaults) {
        self.defaults = defaults
        let storedValues = defaults.dictionary(forKey: Constants.UserDefaults.storeTypes)
        values = Dictionary(uniqueKeysWithValues: PasteboardAvailableType.allCases.map { type in
            let value = storedValues.map {
                ($0[type.rawValue] as? NSNumber)?.boolValue ?? false
            } ?? true
            return (type.rawValue, value)
        })
    }

    func binding(for type: PasteboardAvailableType) -> Binding<Bool> {
        Binding(
            get: { [weak self] in self?.values[type.rawValue] ?? true },
            set: { [weak self] isEnabled in
                guard let self else { return }
                var updatedValues = self.values
                updatedValues[type.rawValue] = isEnabled
                self.values = updatedValues
                self.defaults.set(updatedValues, forKey: Constants.UserDefaults.storeTypes)
                self.defaults.synchronize()
            }
        )
    }
}

struct CapturePrivacySettingsView: View {
    @StateObject private var typeSettings = ClipboardTypeSettingsModel()
    @AppStorage(Constants.UserDefaults.ignoreConcealedPasteboardType) private var ignoresSensitiveContent = false
    @State private var excludedApplications = AppEnvironment.current.excludeAppService.applications
    @State private var selectedApplicationID: ExcludedApplicationSettingsID?

    private let typeColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        SettingsPage(
            title: settingsLocalized("Capture & Privacy"),
            subtitle: settingsLocalized("Choose what ClipApp saves and where history should be paused.")
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text(settingsLocalized("Saved Content"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)

                LazyVGrid(columns: typeColumns, spacing: 10) {
                    ForEach(PasteboardAvailableType.allCases, id: \.rawValue) { type in
                        ClipboardTypeTile(
                            title: type.settingsTitle,
                            systemImage: type.settingsSystemImage,
                            isOn: typeSettings.binding(for: type)
                        )
                    }
                }
            }

            SettingsCard(settingsLocalized("Privacy")) {
                SettingsToggleRow(
                    settingsLocalized("Ignore Sensitive Clipboard Data"),
                    subtitle: settingsLocalized("Do not save content marked as confidential by password managers and other apps."),
                    isOn: $ignoresSensitiveContent
                )
            }

            excludedApplicationsCard
        }
    }

    private var excludedApplicationsCard: some View {
        SettingsCard(settingsLocalized("Excluded Applications")) {
            VStack(alignment: .leading, spacing: 4) {
                SettingsRowLabel(
                    settingsLocalized("Pause History in Selected Apps"),
                    subtitle: settingsLocalized("Clipboard changes are not saved while one of these apps is active.")
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

                Divider()

                if excludedApplications.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "app.dashed")
                            .font(.system(size: 24))
                            .foregroundStyle(.tertiary)
                        Text(settingsLocalized("No excluded applications"))
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 116)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(excludedApplications, id: \.settingsID) { application in
                                excludedApplicationRow(application)
                            }
                        }
                        .padding(6)
                    }
                    .frame(height: 150)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.7))
                }

                Divider()

                HStack(spacing: 8) {
                    Button {
                        addExcludedApplications()
                    } label: {
                        Label(settingsLocalized("Add Application…"), systemImage: "plus")
                    }

                    Button {
                        removeSelectedApplication()
                    } label: {
                        Label(settingsLocalized("Remove"), systemImage: "minus")
                    }
                    .disabled(selectedApplicationID == nil)

                    Spacer()
                }
                .controlSize(.regular)
                .padding(12)
            }
        }
    }

    private func excludedApplicationRow(_ application: CPYAppInfo) -> some View {
        Button {
            selectedApplicationID = application.settingsID
        } label: {
            HStack(spacing: 10) {
                applicationIcon(application)
                VStack(alignment: .leading, spacing: 1) {
                    Text(application.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    Text(application.identifier)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedApplicationID == application.settingsID {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(settingsAccentColor)
                }
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        selectedApplicationID == application.settingsID
                            ? settingsAccentColor.opacity(0.13)
                            : Color.clear
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(application.name), \(application.identifier)")
    }

    @ViewBuilder
    private func applicationIcon(_ application: CPYAppInfo) -> some View {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: application.identifier) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
        } else {
            Image(systemName: "app")
                .font(.system(size: 20))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
        }
    }

    private func addExcludedApplications() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.applicationBundle]
        openPanel.allowsMultipleSelection = true
        openPanel.resolvesAliases = true
        openPanel.prompt = settingsLocalized("Add")
        openPanel.directoryURL = FileManager.default.urls(
            for: .applicationDirectory,
            in: .localDomainMask
        ).first

        guard openPanel.runModal() == .OK else { return }

        openPanel.urls.forEach { url in
            guard
                let bundle = Bundle(url: url),
                let info = bundle.infoDictionary,
                let application = CPYAppInfo(info: info as [String: AnyObject])
            else {
                return
            }
            AppEnvironment.current.excludeAppService.add(with: application)
        }
        excludedApplications = AppEnvironment.current.excludeAppService.applications
    }

    private func removeSelectedApplication() {
        guard
            let selectedApplicationID,
            let application = excludedApplications.first(where: {
                $0.settingsID == selectedApplicationID
            })
        else {
            return
        }

        AppEnvironment.current.excludeAppService.delete(with: application)
        excludedApplications = AppEnvironment.current.excludeAppService.applications
        self.selectedApplicationID = nil
    }
}

struct ExcludedApplicationSettingsID: Hashable {
    let identifier: String
    let name: String
}

private extension CPYAppInfo {
    var settingsID: ExcludedApplicationSettingsID {
        ExcludedApplicationSettingsID(identifier: identifier, name: name)
    }
}

private struct ClipboardTypeTile: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(settingsAccentColor)
                    .frame(width: 22)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .toggleStyle(.checkbox)
        .controlSize(.regular)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
    }
}

private extension PasteboardAvailableType {
    var settingsTitle: String {
        switch self {
        case .string:
            settingsLocalized("Plain Text")
        case .rtf:
            settingsLocalized("Rich Text")
        case .rtfd:
            settingsLocalized("Rich Text with Attachments")
        case .pdf:
            settingsLocalized("PDF")
        case .filenames:
            settingsLocalized("Files")
        case .url:
            settingsLocalized("Links")
        case .tiff:
            settingsLocalized("Images")
        }
    }

    var settingsSystemImage: String {
        switch self {
        case .string:
            "text.alignleft"
        case .rtf:
            "textformat"
        case .rtfd:
            "doc.richtext"
        case .pdf:
            "doc.text"
        case .filenames:
            "folder"
        case .url:
            "link"
        case .tiff:
            "photo"
        }
    }
}

// MARK: - Advanced

struct AdvancedSettingsView: View {
    @AppStorage(Constants.Beta.pastePlainText) private var pastePlainText = true
    @AppStorage(Constants.Beta.pastePlainTextModifier) private var pastePlainTextModifier = 0
    @AppStorage(Constants.Beta.deleteHistory) private var deleteHistory = false
    @AppStorage(Constants.Beta.deleteHistoryModifier) private var deleteHistoryModifier = 0
    @AppStorage(Constants.Beta.pasteAndDeleteHistory) private var pasteAndDeleteHistory = false
    @AppStorage(Constants.Beta.pasteAndDeleteHistoryModifier) private var pasteAndDeleteHistoryModifier = 0
    @AppStorage(Constants.Beta.observerScreenshot) private var saveScreenshots = false

    var body: some View {
        SettingsPage(
            title: settingsLocalized("Advanced"),
            subtitle: settingsLocalized("Configure optional actions and experimental features.")
        ) {
            SettingsInfoBanner(
                icon: "flask",
                title: settingsLocalized("Experimental Features"),
                message: settingsLocalized("These options may change or move in a future version."),
                color: .orange
            )

            SettingsCard(settingsLocalized("Paste Actions")) {
                ExperimentalActionRow(
                    title: settingsLocalized("Paste as Plain Text"),
                    subtitle: settingsLocalized("Hold a modifier while choosing an item to remove formatting."),
                    isOn: $pastePlainText,
                    modifier: $pastePlainTextModifier
                )
                SettingsDivider()
                ExperimentalActionRow(
                    title: settingsLocalized("Delete from History"),
                    subtitle: settingsLocalized("Hold a modifier while choosing an item to remove it from history."),
                    isOn: $deleteHistory,
                    modifier: $deleteHistoryModifier
                )
                SettingsDivider()
                ExperimentalActionRow(
                    title: settingsLocalized("Paste and Delete"),
                    subtitle: settingsLocalized("Hold a modifier to paste an item and remove it from history."),
                    isOn: $pasteAndDeleteHistory,
                    modifier: $pasteAndDeleteHistoryModifier
                )
            }

            SettingsCard(settingsLocalized("Screenshots")) {
                SettingsToggleRow(
                    settingsLocalized("Save Screenshots"),
                    subtitle: settingsLocalized("Add new screenshots to clipboard history automatically."),
                    isOn: $saveScreenshots
                )
            }
        }
    }
}

private struct ExperimentalActionRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    @Binding var modifier: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            if isOn {
                HStack {
                    Text(settingsLocalized("Modifier"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    ModifierPicker(selection: $modifier)
                }
                .padding(.leading, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .animation(.easeInOut(duration: 0.16), value: isOn)
    }
}

private struct ModifierPicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("", selection: $selection) {
            Text("⌘ \(settingsLocalized("Command"))").tag(0)
            Text("⇧ \(settingsLocalized("Shift"))").tag(1)
            Text("⌃ \(settingsLocalized("Control"))").tag(2)
            Text("⌥ \(settingsLocalized("Option"))").tag(3)
        }
        .labelsHidden()
        .frame(width: 150)
    }
}
