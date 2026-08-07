//
//  CPYSnippetsEditorWindowController+Symbols.swift
//  ClipApp
//

import Cocoa

extension CPYSnippetsEditorWindowController {
    func configureSymbols() {
        setSymbol("doc.badge.plus", on: addSnippetButton)
        setSymbol("folder.badge.plus", on: addFolderButton)
        setSymbol("trash", on: deleteButton)
        setSymbol("checkmark.circle", on: changeStatusButton)
        setSymbol("square.and.arrow.down", on: importButton)
        setSymbol("square.and.arrow.up", on: exportButton)

        folderSettingImageView.image = symbol(named: "folder.fill")
        folderSettingImageView.contentTintColor = NSColor(resource: .clipApp)
    }
}

private extension CPYSnippetsEditorWindowController {
    func setSymbol(_ name: String, on button: NSButton) {
        button.image = symbol(named: name)
        button.alternateImage = nil
        button.contentTintColor = NSColor(resource: .clipApp)
    }

    func symbol(named name: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }
}
