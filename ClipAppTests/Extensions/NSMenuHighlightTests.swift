//
//  NSMenuHighlightTests.swift
//
//  ClipApp
//

import AppKit
import Testing
@testable import ClipApp

@MainActor
@Suite
struct NSMenuHighlightTests {
    @Test
    func firstSelectableItemSkipsNonSelectableItems() throws {
        let menu = NSMenu()

        let labelItem = NSMenuItem(title: "History", action: nil, keyEquivalent: "")
        labelItem.isEnabled = false
        menu.addItem(labelItem)
        menu.addItem(.separator())

        let hiddenItem = NSMenuItem(title: "Hidden", action: nil, keyEquivalent: "")
        hiddenItem.isHidden = true
        menu.addItem(hiddenItem)

        let firstItem = NSMenuItem(title: "Latest clip", action: nil, keyEquivalent: "")
        firstItem.isEnabled = true
        menu.addItem(firstItem)
        menu.addItem(NSMenuItem(title: "Older clip", action: nil, keyEquivalent: ""))

        #expect(try #require(menu.firstSelectableItem) === firstItem)
    }

    @Test
    func firstSelectableItemIsNilWhenMenuHasNoSelectableItems() {
        let menu = NSMenu()
        let labelItem = NSMenuItem(title: "History", action: nil, keyEquivalent: "")
        labelItem.isEnabled = false
        menu.addItem(labelItem)
        menu.addItem(.separator())

        #expect(menu.firstSelectableItem == nil)
    }
}
