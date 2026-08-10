# Flat clipboard history menus

## Goal

Clipboard history is always shown as one flat list. The primary flow is:

- Paste newest: `⌘⇧V` `↩`
- Paste 3rd with the default one-based numbering: `⌘⇧V` `3`

History range folders such as `1 - 10` and `11 - 20` are not supported. They
add navigation steps and conflict with ClipApp's two-keystroke paste flow.

## Menu behavior

- The menu-bar status item and `⌘⇧V` use the same main `NSMenu` instance.
- `⌘⌃V` uses a history-only menu built by the same flat history code.
- The first ten clips always receive bare numeric key equivalents. The default
  one-based numbering uses `1…9, 0`; the optional zero-based numbering uses
  `0…9`.
- A hotkey-opened menu highlights its first selectable clip so `Return` pastes
  the newest history item immediately.
- A history longer than the screen uses `NSMenu`'s native scrolling.
- Snippet folders remain submenus; they are a separate organizational feature.

## Implementation

`MenuManager.createClipMenu()` builds one main `clipMenu`, assigns it to the
status item, and reuses it for `.main` hotkey popups. `addHistoryItems(_:)`
fetches up to `maxHistorySize` records and appends every clip directly to its
menu. There are no inline-count or history-folder settings.

Menus are rebuilt reactively when history, snippets, or relevant display
preferences change. `NSMenu.popUpHighlightingFirstItem(at:)` handles the
hotkey-specific initial highlight and its modifier-key release timing.

## Manual QA

1. Copy more than ten items.
2. Open the menu-bar menu and confirm every history item is in one flat list.
3. Press `⌘⇧V`, then `Return`, and confirm the newest item is pasted.
4. Press `⌘⇧V`, then `3`, and confirm the third item is pasted.
5. Press `⌘⌃V` and confirm the history-only menu is also flat.
6. Confirm snippet folders still open their snippet submenus.
