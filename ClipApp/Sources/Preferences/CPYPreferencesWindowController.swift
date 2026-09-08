//
//  CPYPreferencesWindowController.swift
//
//  ClipApp
//

import Cocoa
import SwiftUI

final class CPYPreferencesWindowController: NSWindowController {

    static let sharedController = CPYPreferencesWindowController()

    private init() {
        let hostingController = NSHostingController(rootView: ClipAppSettingsView())
        let window = NSWindow(contentViewController: hostingController)
        window.title = settingsLocalized("ClipApp Settings")
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 960, height: 700))
        window.minSize = NSSize(width: 900, height: 600)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.animationBehavior = .documentWindow

        super.init(window: window)

        window.delegate = self
        window.center()
        window.setFrameAutosaveName("ClipAppSettingsWindow")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(sender)
    }
}

extension CPYPreferencesWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window, !window.makeFirstResponder(window) {
            window.endEditing(for: nil)
        }
        NSApp.deactivate()
    }
}
