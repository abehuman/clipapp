//
//  ClipAppSettingsHistoryMenu.swift
//
//  ClipApp
//

import SwiftUI

// MARK: - History and menu

private enum DuplicateHistoryBehavior: String, CaseIterable, Identifiable {
    case ignore
    case moveToTop
    case keepSeparate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ignore:
            settingsLocalized("Ignore the Copy")
        case .moveToTop:
            settingsLocalized("Move Existing Item to Top")
        case .keepSeparate:
            settingsLocalized("Keep as New Item")
        }
    }
}

struct HistoryMenuSettingsView: View {
    @AppStorage(Constants.UserDefaults.maxHistorySize) private var maxHistorySize = 30
    @AppStorage(Constants.UserDefaults.reorderClipsAfterPasting) private var sortByLastUsed = true
    @AppStorage(Constants.UserDefaults.copySameHistory) private var copySameHistory = true
    @AppStorage(Constants.UserDefaults.overwriteSameHistory) private var overwriteSameHistory = true
    @AppStorage(Constants.UserDefaults.maxMenuItemTitleLength) private var titleLength = 20
    @AppStorage(Constants.UserDefaults.menuItemsAreMarkedWithNumbers) private var showNumbers = true
    @AppStorage(Constants.UserDefaults.menuItemsTitleStartWithZero) private var startsWithZero = false
    @AppStorage(Constants.UserDefaults.showIconInTheMenu) private var showIcons = true
    @AppStorage(Constants.UserDefaults.showColorPreviewInTheMenu) private var showColorPreviews = true
    @AppStorage(Constants.UserDefaults.showImageInTheMenu) private var showImagePreviews = true
    @AppStorage(Constants.UserDefaults.showToolTipOnMenuItem) private var showTooltips = true
    @AppStorage(Constants.UserDefaults.maxLengthOfToolTip) private var tooltipLength = 200
    @AppStorage(Constants.UserDefaults.thumbnailWidth) private var imageWidth = 100
    @AppStorage(Constants.UserDefaults.thumbnailHeight) private var imageHeight = 32
    @AppStorage(Constants.UserDefaults.addClearHistoryMenuItem) private var showClearHistory = true
    @AppStorage(Constants.UserDefaults.showAlertBeforeClearHistory) private var confirmBeforeClearing = true
    @State private var showsAdvancedOptions = false

    private var duplicateBehavior: Binding<DuplicateHistoryBehavior> {
        Binding(
            get: {
                guard copySameHistory else { return .ignore }
                return overwriteSameHistory ? .moveToTop : .keepSeparate
            },
            set: { behavior in
                switch behavior {
                case .ignore:
                    copySameHistory = false
                case .moveToTop:
                    copySameHistory = true
                    overwriteSameHistory = true
                case .keepSeparate:
                    copySameHistory = true
                    overwriteSameHistory = false
                }
            }
        )
    }

    var body: some View {
        SettingsPage(
            title: settingsLocalized("History & Menu"),
            subtitle: settingsLocalized("Adjust how clipboard history is stored and displayed.")
        ) {
            SettingsCard(settingsLocalized("History")) {
                SettingsValueRow(settingsLocalized("History Limit")) {
                    NumberSettingControl(
                        value: $maxHistorySize,
                        minimum: 1,
                        step: 10,
                        unit: settingsLocalized("items")
                    )
                }
                SettingsDivider()
                SettingsValueRow(settingsLocalized("Sort Order")) {
                    Picker("", selection: $sortByLastUsed) {
                        Text(settingsLocalized("Last Used")).tag(true)
                        Text(settingsLocalized("Date Created")).tag(false)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
                SettingsDivider()
                SettingsValueRow(
                    settingsLocalized("Duplicate Copies"),
                    subtitle: settingsLocalized("Choose what happens when the same content is copied again.")
                ) {
                    Picker("", selection: duplicateBehavior) {
                        ForEach(DuplicateHistoryBehavior.allCases) { behavior in
                            Text(behavior.title).tag(behavior)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .controlSize(.large)
                    .frame(width: 225)
                }
            }

            SettingsCard(settingsLocalized("Menu Preview")) {
                SettingsMenuPreview(
                    titleLength: titleLength,
                    showNumbers: showNumbers,
                    startsWithZero: startsWithZero,
                    showIcons: showIcons,
                    showColorPreviews: showColorPreviews,
                    showImagePreviews: showImagePreviews,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight,
                    showClearHistory: showClearHistory
                )
                .padding(16)
            }

            SettingsCard(settingsLocalized("Appearance")) {
                SettingsValueRow(settingsLocalized("Title Length")) {
                    NumberSettingControl(
                        value: $titleLength,
                        minimum: 1,
                        step: 1,
                        unit: settingsLocalized("characters")
                    )
                }
                SettingsDivider()
                SettingsToggleRow(settingsLocalized("Number Menu Items"), isOn: $showNumbers)
                SettingsDivider()
                SettingsToggleRow(settingsLocalized("Show Icons"), isOn: $showIcons)
                SettingsDivider()
                SettingsToggleRow(settingsLocalized("Show Color Previews"), isOn: $showColorPreviews)
                SettingsDivider()
                SettingsToggleRow(settingsLocalized("Show Image Previews"), isOn: $showImagePreviews)
                SettingsDivider()
                SettingsToggleRow(settingsLocalized("Show Tooltips"), isOn: $showTooltips)
            }

            SettingsCard(settingsLocalized("Commands")) {
                SettingsToggleRow(
                    settingsLocalized("Show Clear History Command"),
                    isOn: $showClearHistory
                )
                if showClearHistory {
                    SettingsDivider()
                    SettingsToggleRow(
                        settingsLocalized("Confirm Before Clearing"),
                        isOn: $confirmBeforeClearing
                    )
                }
            }

            advancedMenuOptions
        }
    }

    private var advancedMenuOptions: some View {
        SettingsCard {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showsAdvancedOptions.toggle()
                }
            } label: {
                HStack {
                    SettingsRowLabel(
                        settingsLocalized("Advanced Menu Options"),
                        subtitle: settingsLocalized("Fine-tune numbering, tooltips, and image dimensions.")
                    )
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(showsAdvancedOptions ? 90 : 0))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if showsAdvancedOptions {
                if showNumbers {
                    SettingsDivider()
                    SettingsValueRow(settingsLocalized("Starting Number")) {
                        Picker("", selection: $startsWithZero) {
                            Text("1").tag(false)
                            Text("0").tag(true)
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 90)
                    }
                }
                if showTooltips {
                    SettingsDivider()
                    SettingsValueRow(settingsLocalized("Tooltip Length")) {
                        NumberSettingControl(
                            value: $tooltipLength,
                            minimum: 1,
                            step: 10,
                            unit: settingsLocalized("characters")
                        )
                    }
                }
                if showImagePreviews {
                    SettingsDivider()
                    SettingsValueRow(settingsLocalized("Image Width")) {
                        NumberSettingControl(
                            value: $imageWidth,
                            minimum: 1,
                            step: 4,
                            unit: settingsLocalized("pixels")
                        )
                    }
                    SettingsDivider()
                    SettingsValueRow(settingsLocalized("Image Height")) {
                        NumberSettingControl(
                            value: $imageHeight,
                            minimum: 1,
                            step: 4,
                            unit: settingsLocalized("pixels")
                        )
                    }
                }
            }
        }
    }
}

private struct SettingsMenuPreview: View {
    let titleLength: Int
    let showNumbers: Bool
    let startsWithZero: Bool
    let showIcons: Bool
    let showColorPreviews: Bool
    let showImagePreviews: Bool
    let imageWidth: Int
    let imageHeight: Int
    let showClearHistory: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(settingsLocalized("History"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 6)

            previewRow(index: 0, title: settingsLocalized("Project notes and next steps"), kind: .text)
            previewRow(index: 1, title: settingsLocalized("Brand color #2A84D2"), kind: .color)
            previewRow(index: 2, title: settingsLocalized("Screenshot from today"), kind: .image)

            if showClearHistory {
                Divider()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                HStack(spacing: 8) {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    Text(settingsLocalized("Clear History"))
                        .font(.system(size: 13))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(settingsLocalized("Menu Preview"))
    }

    private enum PreviewKind {
        case text
        case color
        case image
    }

    private func previewRow(index: Int, title: String, kind: PreviewKind) -> some View {
        HStack(spacing: 8) {
            previewImage(kind)
            Text(numberedTitle(index: index, title: title))
                .font(.system(size: 13))
                .lineLimit(1)
            Spacer()
            if index < 3 {
                Text("\(index + 1)")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: max(30, min(CGFloat(imageHeight + 8), 54)))
    }

    @ViewBuilder
    private func previewImage(_ kind: PreviewKind) -> some View {
        switch kind {
        case .text:
            if showIcons {
                Image(systemName: "doc.text")
                    .foregroundStyle(settingsAccentColor)
                    .frame(width: 18)
            }
        case .color:
            if showColorPreviews {
                RoundedRectangle(cornerRadius: 4)
                    .fill(settingsAccentColor)
                    .frame(width: 18, height: 18)
            } else if showIcons {
                Image(systemName: "number")
                    .foregroundStyle(settingsAccentColor)
                    .frame(width: 18)
            }
        case .image:
            if showImagePreviews {
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [settingsAccentColor, .purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(
                        width: max(18, min(CGFloat(imageWidth) * 0.32, 48)),
                        height: max(18, min(CGFloat(imageHeight), 40))
                    )
            } else if showIcons {
                Image(systemName: "photo")
                    .foregroundStyle(settingsAccentColor)
                    .frame(width: 18)
            }
        }
    }

    private func numberedTitle(index: Int, title: String) -> String {
        let prefix = showNumbers ? "\(index + (startsWithZero ? 0 : 1)). " : ""
        return prefix + shortened(title)
    }

    private func shortened(_ title: String) -> String {
        let safeLength = max(titleLength, 3)
        guard title.count > safeLength else { return title }
        return String(title.prefix(safeLength - 3)) + "..."
    }
}
