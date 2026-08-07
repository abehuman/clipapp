# Flat history popup on ⌘⇧V — design & implementation notes

**Goal:** pressing `Cmd + Shift + V` shows the clipboard history as one flat,
immediately visible list, instead of the "1 - 10", "11 - 20", "21 - 30"
folder submenus that force `↓` and `→` navigation before you can even see an
item. Target flows:

- Paste newest: `⌘⇧V` `↩`
- Paste 3rd: `⌘⇧V` `↓` `↓` `↩` **or** `⌘⇧V` `3`

**Status: implemented** in `MenuManager.swift` (see §3). No hotkey bindings were
touched — `⌘⇧V` keeps triggering the main-menu popup; only the popup's *layout*
changed. Pending: build verification in Xcode (this machine has only Command
Line Tools; the diff passes `swiftc -parse`).

This was never solvable by switching to the history-only shortcut (`⌘⌃V`): the
hotkey only chooses *which* menu pops up, not its shape. Both menus were built
by the same layout code (`createClipMenu()` → `addHistoryItems`), so the
history menu showed the same "1 - 10" folders.

---

## 1. Project basics

ClipApp is a menu-bar (status item) clipboard history manager for macOS 13+,
written in Swift and forked from Clipy. There is no main window — everything happens through `NSMenu`
popups and a preferences window.

| Area | File | Role |
|---|---|---|
| App entry | `ClipApp/Sources/ClipApp.swift` | SwiftUI `@main` shell; bootstraps the SQLite DB, hosts the AppKit `AppDelegate` |
| App lifecycle | `ClipApp/Sources/AppDelegate.swift` | Registers default settings, starts services, handles menu item actions (`selectClipMenuItem` → paste) |
| Menu construction | `ClipApp/Sources/Managers/MenuManager.swift` | Builds the `NSMenu`s (status bar / popup / history / snippet) and pops them up |
| Global hotkeys | `ClipApp/Sources/Services/HotKeyService.swift` | Registers hotkeys via the [Magnet](https://github.com/Clipy/Magnet) framework |
| Hotkey ↔ menu mapping | `ClipApp/Sources/Enums/MenuType.swift` | `.main` / `.history` / `.snippet` → selector + UserDefaults key |
| Clipboard monitoring | `ClipApp/Sources/Services/ClipService.swift` | Watches `NSPasteboard`, writes history to the repository |
| History storage | `ClipApp/Sources/Repositories/PasteboardHistoryRepository.swift` | SQLiteData-backed store (migrated from Realm) |
| Pasting | `ClipApp/Sources/Services/PasteService.swift` | Puts a clip on the pasteboard and synthesizes ⌘V |
| Settings keys | `ClipApp/Sources/Constants.swift` | All `UserDefaults` key names |
| Default settings | `ClipApp/Sources/Utility/CPYUtilities.swift` (`registerUserDefaultKeys`) | Default values registered at launch |
| Preferences UI | `ClipApp/Sources/Preferences/` | Window + panels; the **Menu** panel is a bindings-only XIB (plain `NSViewController`, no Swift class) |

### Flow when you press ⌘⇧V

```
⌘⇧V (Magnet HotKey)
  → HotKeyService.popupMainMenu()
  → MenuManager.popUpMenu(.main)
  → popupClipMenu.popUp(at: NSEvent.mouseLocation)   (first clip pre-highlighted)
  → user picks an item (↩ / arrows / digit)
  → AppDelegate.selectClipMenuItem(_:)
  → PasteService.paste(id:content:)                  (copies to pasteboard + synthesizes ⌘V)
```

Default hotkeys (`HotKeyService.defaultKeyCombos`): `⌘⇧V` = main menu,
`⌘⌃V` = history-only menu, `⌘⇧B` = snippets. The menus are rebuilt reactively
(`MenuManager.bind()`) whenever history, snippets, or menu-related preferences
change — not on popup — so all popup paths pick up layout changes automatically.

---

## 2. Why the "1 - 10" folders appeared

`MenuManager.addHistoryItems(_:)` lays out history using two settings:

- `numberOfItemsPlaceInline` — how many items appear directly in the menu.
  **Default: `0`** (CPYUtilities.swift).
- `numberOfItemsPlaceInsideFolder` — chunk size for the overflow submenus.
  **Default: `10`**.

The first `placeInLine` items go inline; everything else is grouped into
submenus titled `"\(start) - \(end)"`. With the default `placeInLine = 0`,
**every** item landed in a folder — hence the `↓` `→` dance, in the status-bar
menu and both hotkey popups alike.

---

## 3. Implemented change (all in `MenuManager.swift`)

### 3.1 Principle

- The **status-bar menu** keeps respecting the inline/folder settings (mouse
  users may legitimately prefer compact folders there).
- Every **keyboard-invoked popup** is always flat and numbers its first 10
  items. A popup summoned by a hotkey is a keyboard flow; folders only add
  keystrokes there.
- `NSMenu` handles overflow natively — a flat menu taller than the screen
  scrolls automatically.

### 3.2 What changed

1. **A second main-menu instance for the popup.** `createClipMenu()` now builds
   both menus through a shared `makeMainMenu(forcesFlatHistory:)` helper:
   `clipMenu` (settings-driven, assigned to the status item) and
   `popupClipMenu` (flat history). `popUpMenu(.main)` pops `popupClipMenu`.
   Content is otherwise identical (history, snippets, Clear History /
   Edit Snippets / Preferences / Quit).

2. **`addHistoryItems(_:forcesFlatHistory:)`.** When forced flat, the inline
   count is set to `maxHistorySize` instead of reading
   `numberOfItemsPlaceInline`. `maxHistory` is used rather than `Int.max`
   because the layout loop computes `subMenuCount + placeInsideFolder`, which
   would overflow and crash with `Int.max`; the fetch is already capped by
   `limit: maxHistory`, so this guarantees zero folders.

3. **Forced numeric key equivalents with a bare digit.**
   `makeClipMenuItem(..., forcesNumericKeyEquivalent:)` assigns `1…9, 0` to the
   first 10 items regardless of the `addNumericKeyEquivalents` setting, and —
   the important detail — sets `keyEquivalentModifierMask = []`. `NSMenuItem`'s
   default mask is `⌘`, so without this the shortcut would be `⌘3`, not plain
   `3`. (The pre-existing settings-driven path is untouched and still uses the
   default mask.)

4. **The `⌘⌃V` history-only popup is also flat**, for consistency — it shares
   `addHistoryItems(historyMenu!, forcesFlatHistory: true)`. Unused in the
   target flow, but there was no reason to leave one popup foldered.

No changes to hotkey registration, defaults registration, storage, or paste
logic. Existing user preferences are untouched.

### 3.3 Resulting keyboard flow

`popUpMenu` pre-highlights the first *enabled* item (the disabled "History"
label is skipped — `Extensions/NSMenu+Highlight.swift`), which is the newest
clip:

| Action | Before | After |
|---|---|---|
| Paste newest item | `⌘⇧V` `↓` `→` `↩` | `⌘⇧V` `↩` |
| Paste 3rd item | `⌘⇧V` `↓` `→` `↓` `↓` `↩` | `⌘⇧V` `↓` `↓` `↩` |
| Paste 3rd item, no arrows | — | `⌘⇧V` `3` |
| Paste 10th item | `⌘⇧V` `↓` `→` `↓`×9 `↩` | `⌘⇧V` `0` |
| Paste item 11+ | folders | `⌘⇧V` + arrows (list scrolls natively) |

No `→` anywhere — there are no submenus left to enter.

### 3.4 Known trade-off: digits vs. type-select

While the popup is open, digits are consumed as key equivalents, so `NSMenu`'s
type-select can no longer be driven by the leading number marks ("14" would
fire item 1 first). Items 11+ are reached with arrows. If that ever becomes
annoying, options: disable `menuItemsAreMarkedWithNumbers` and type text
prefixes instead, or go to the search palette (§4 D).

---

## 4. Alternatives considered

| Option | Change | Verdict |
|---|---|---|
| **A. Settings only** (inline count = max in Preferences → Menu) | none | Works, but must be discovered, affects the status-bar menu too, and can't give bare-digit paste (settings path uses the `⌘`-masked equivalents) |
| **B. Change the default `numberOfItemsPlaceInline` 0 → 30** | 1 line | `register(defaults:)` values apply to every user who never touched the setting — would silently restructure the status-bar menu for existing users on update |
| **C. Always-flat hotkey popup** | ~30 lines | **Implemented** (§3). Scoped to the keyboard flow, no preference migration, status-bar behavior untouched |
| **D. Dedicated search palette** (Spotlight/Maccy-style `NSPanel` with search field + list) | new feature | The long-term answer (type-to-filter, previews, pinning), but a much bigger effort: window controller, key handling, focus management. §3 loses no work if D lands later |

---

## 5. Edge cases & notes

- **Long histories:** with `maxHistorySize` set high, the flat popup exceeds
  screen height; `NSMenu` scrolls natively. The status-bar menu still offers
  folders for anyone who wants them.
- **Reactive rebuilds:** layout is decided inside `createClipMenu()`, which
  re-runs on every history/settings change, so `popupClipMenu` never goes
  stale and no extra invalidation is needed.
- **Overflow guard:** forced-flat mode must keep using `maxHistory` as the
  inline count (see §3.2-2) — do not "simplify" it to `Int.max`.
- **Numbering base:** with `menuItemsTitleStartWithZero` off (default), item
  marks and digit equivalents agree: "3" is the 3rd item. If a user turns that
  setting on, marks and digits both shift to 0-based together
  (`makeClipMenuItem` derives both from the same index).
- **Images/colors:** thumbnails render identically in a flat list; only
  nesting changed.

## 6. Testing

- **Unit:** `ClipAppTests/HotKeyServiceTests.swift` covers combo registration and
  is unaffected. Menu layout has no tests today; a useful first one would
  assert that a menu built with `forcesFlatHistory: true` contains N clip items,
  zero submenu items, and bare-digit key equivalents on the first 10.
- **Manual QA:**
  1. Build per README (Xcode 26.5; switch `Configurations/CodeSigning.xcconfig`
     to the ad-hoc include first) and grant Accessibility permission.
  2. Copy 25+ items. `⌘⇧V` → flat list, newest clip highlighted, `↩` pastes it.
  3. `⌘⇧V` `3` → pastes the 3rd item without arrows; `0` pastes the 10th.
  4. Status-bar icon click → menu still uses "1 - 10" folders (unless the
     inline setting says otherwise) and digit shortcuts there still show as
     `⌘digit` only when *Add numeric key equivalents* is enabled.
  5. Change *Number of items to place inline* / *max history size* in
     Preferences → popup stays flat; status menu follows the settings.
