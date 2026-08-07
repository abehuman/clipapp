//
//  CPYPreferencesWindowController.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Econa77 on 2016/02/25.
//
//  Copyright © 2015-2018 Clipy Project.
//

import Cocoa

final class CPYPreferencesWindowController: NSWindowController {

    // MARK: - Properties
    static let sharedController = CPYPreferencesWindowController(windowNibName: "CPYPreferencesWindowController")
    @IBOutlet private weak var toolBar: NSView!
    // ImageViews
    @IBOutlet private weak var generalImageView: NSImageView!
    @IBOutlet private weak var menuImageView: NSImageView!
    @IBOutlet private weak var typeImageView: NSImageView!
    @IBOutlet private weak var excludeImageView: NSImageView!
    @IBOutlet private weak var shortcutsImageView: NSImageView!
    @IBOutlet private weak var betaImageView: NSImageView!
    // Labels
    @IBOutlet private weak var generalTextField: NSTextField!
    @IBOutlet private weak var menuTextField: NSTextField!
    @IBOutlet private weak var typeTextField: NSTextField!
    @IBOutlet private weak var excludeTextField: NSTextField!
    @IBOutlet private weak var shortcutsTextField: NSTextField!
    @IBOutlet private weak var betaTextField: NSTextField!
    // Buttons
    @IBOutlet private weak var generalButton: NSButton!
    @IBOutlet private weak var menuButton: NSButton!
    @IBOutlet private weak var typeButton: NSButton!
    @IBOutlet private weak var excludeButton: NSButton!
    @IBOutlet private weak var shortcutsButton: NSButton!
    @IBOutlet private weak var betaButton: NSButton!
    // ViewController
    private let viewController = [NSViewController(nibName: "CPYGeneralPreferenceViewController", bundle: nil),
                                  NSViewController(nibName: "CPYMenuPreferenceViewController", bundle: nil),
                                  CPYTypePreferenceViewController(nibName: "CPYTypePreferenceViewController", bundle: nil),
                                  CPYExcludeAppPreferenceViewController(nibName: "CPYExcludeAppPreferenceViewController", bundle: nil),
                                  CPYShortcutsPreferenceViewController(nibName: "CPYShortcutsPreferenceViewController", bundle: nil),
                                  CPYBetaPreferenceViewController(nibName: "CPYBetaPreferenceViewController", bundle: nil)]

    // MARK: - Window Life Cycle
    override func windowDidLoad() {
        super.windowDidLoad()
        // Temporarily disable Dark Mode until this window is migrated to SwiftUI.
        self.window?.appearance = NSAppearance(named: .aqua)
        self.window?.backgroundColor = NSColor(white: 0.99, alpha: 1)
        self.window?.titlebarAppearsTransparent = true
        toolBarItemTapped(generalButton)
        generalButton.sendAction(on: .leftMouseDown)
        menuButton.sendAction(on: .leftMouseDown)
        typeButton.sendAction(on: .leftMouseDown)
        excludeButton.sendAction(on: .leftMouseDown)
        shortcutsButton.sendAction(on: .leftMouseDown)
        betaButton.sendAction(on: .leftMouseDown)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.orderFrontRegardless()
    }
}

// MARK: - IBActions
extension CPYPreferencesWindowController {
    @IBAction private func toolBarItemTapped(_ sender: NSButton) {
        selectedTab(sender.tag)
        switchView(sender.tag)
    }
}

// MARK: - NSWindow Delegate
extension CPYPreferencesWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        NSApp.deactivate()
    }
}

// MARK: - Layout
private extension CPYPreferencesWindowController {
    func resetImages() {
        generalImageView.image = preferenceSymbol(named: "gearshape")
        menuImageView.image = preferenceSymbol(named: "list.bullet")
        typeImageView.image = preferenceSymbol(named: "doc.on.clipboard")
        excludeImageView.image = preferenceSymbol(named: "nosign")
        shortcutsImageView.image = preferenceSymbol(named: "keyboard")
        betaImageView.image = preferenceSymbol(named: "wrench.and.screwdriver")

        [generalImageView, menuImageView, typeImageView, excludeImageView,
         shortcutsImageView, betaImageView].forEach {
            $0?.contentTintColor = NSColor(resource: .tabTitle)
        }

        generalTextField.textColor = NSColor(resource: .tabTitle)
        menuTextField.textColor = NSColor(resource: .tabTitle)
        typeTextField.textColor = NSColor(resource: .tabTitle)
        excludeTextField.textColor = NSColor(resource: .tabTitle)
        shortcutsTextField.textColor = NSColor(resource: .tabTitle)
        betaTextField.textColor = NSColor(resource: .tabTitle)
    }

    func preferenceSymbol(named name: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }

    func selectedTab(_ index: Int) {
        resetImages()

        switch index {
        case 0:
            generalImageView.contentTintColor = NSColor(resource: .clipy)
            generalTextField.textColor = NSColor(resource: .clipy)
        case 1:
            menuImageView.contentTintColor = NSColor(resource: .clipy)
            menuTextField.textColor = NSColor(resource: .clipy)
        case 2:
            typeImageView.contentTintColor = NSColor(resource: .clipy)
            typeTextField.textColor = NSColor(resource: .clipy)
        case 3:
            excludeImageView.contentTintColor = NSColor(resource: .clipy)
            excludeTextField.textColor = NSColor(resource: .clipy)
        case 4:
            shortcutsImageView.contentTintColor = NSColor(resource: .clipy)
            shortcutsTextField.textColor = NSColor(resource: .clipy)
        case 5:
            betaImageView.contentTintColor = NSColor(resource: .clipy)
            betaTextField.textColor = NSColor(resource: .clipy)
        default: break
        }
    }

    func switchView(_ index: Int) {
        let newView = viewController[index].view
        // Remove current views without toolbar
        window?.contentView?.subviews.forEach { view in
            if view != toolBar {
                view.removeFromSuperview()
            }
        }
        // Resize view
        let frame = window!.frame
        var newFrame = window!.frameRect(forContentRect: newView.frame)
        newFrame.origin = frame.origin
        newFrame.origin.y += frame.height - newFrame.height - toolBar.frame.height
        newFrame.size.height += toolBar.frame.height
        window?.setFrame(newFrame, display: true)
        window?.contentView?.addSubview(newView)
    }
}
