//
//  NSMenu+Highlight.swift
//
//  Clipy
//  GitHub: https://github.com/clipy
//  HP: https://clipy-app.com
//
//  Created by Shunsuke Furubayashi on 2026/06/29.
//
//  Copyright © 2015-2026 Clipy Project.
//

import AppKit

/// Uses a private NSMenu API to highlight the first selectable item by default.
/// ref: https://kazakov.life/2017/05/18/hacking-nsmenu-keyboard-navigation/
extension NSMenu {
    var firstSelectableItem: NSMenuItem? {
        items.first(where: { !$0.isSeparatorItem && !$0.isHidden && $0.isEnabled })
    }

    @discardableResult
    func popUpHighlightingFirstItem(at location: NSPoint) -> Bool {
        guard let firstItem = firstSelectableItem else {
            return popUp(positioning: nil, at: location, in: nil)
        }

        let selector = Selector(("highlightItem:"))
        guard responds(to: selector) else {
            return popUp(positioning: nil, at: location, in: nil)
        }

        let highlightFirstItem: () -> Void = { [weak self, weak firstItem] in
            _ = self?.perform(selector, with: firstItem)
        }

        // A popup opened from a global shortcut starts tracking while its modifier keys are
        // still held. Depending on the previously focused app, the subsequent key-up events
        // can clear the initial highlight. Re-assert it briefly after all shortcut modifiers
        // are released, unless the user has already moved the highlight to another item.
        var postReleaseTicksRemaining: Int?
        let shortcutModifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        let postReleaseHighlighter = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self, weak firstItem] timer in
            guard let self, let firstItem else {
                timer.invalidate()
                return
            }
            if let highlightedItem, highlightedItem !== firstItem {
                timer.invalidate()
                return
            }
            guard NSEvent.modifierFlags.isDisjoint(with: shortcutModifiers) else { return }

            postReleaseTicksRemaining = postReleaseTicksRemaining ?? 3
            if highlightedItem == nil {
                _ = perform(selector, with: firstItem)
            }
            postReleaseTicksRemaining? -= 1
            if postReleaseTicksRemaining == 0 {
                timer.invalidate()
            }
        }
        RunLoop.current.add(postReleaseHighlighter, forMode: .eventTracking)
        RunLoop.current.perform(inModes: [.eventTracking], block: highlightFirstItem)

        defer { postReleaseHighlighter.invalidate() }
        return popUp(positioning: nil, at: location, in: nil)
    }
}
