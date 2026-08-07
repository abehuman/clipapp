# ClipApp

ClipApp is a clipboard extension app for macOS, forked from
[Clipy](https://github.com/Clipy/Clipy) (MIT License).

The main difference from Clipy: pressing the main popup hotkey (default
`Cmd + Shift + V`) shows the clipboard history as one flat list with bare
numeric key equivalents, so you can see every clip immediately and paste
item N by pressing its number — no folder submenus to navigate.

The status
bar menu still follows the user's inline/folder menu preferences. See
[docs/flat-history-popup.md](./docs/flat-history-popup.md) for design notes.

---

__Requirement__: macOS 13 Ventura or later

### Development Environment
* macOS 26 Tahoe
* Xcode 26.5

### How to Build
1. Open `Clipy.xcodeproj` in Xcode.
2. For local builds without a Developer ID, use ad-hoc signing:
    1. Open `Configurations/CodeSigning.xcconfig`.
    2. Make sure `#include "Configurations/CodeSigning-AdHoc.xcconfig"` is uncommented.
3. Build the `ClipApp` scheme (the product is `ClipApp.app`).

Note: macOS ties Accessibility permission to the app's code signature, so
ad-hoc builds may re-prompt for Accessibility permission after every build.
For distribution, sign with your own Developer ID certificate and notarize.

If you want to use Firebase features, place your own `GoogleService-Info.plist`
in `Clipy/GoogleService`. Without this file the Firebase code paths are inert
and nothing is sent anywhere.

### Auto Update
Automatic updates are NOT included. The inherited Sparkle integration, feed URL, and public keys have been removed.

### Privacy Policy
Please see [PRIVACY.md](./PRIVACY.md).

### Licence
ClipApp is available under the MIT license. See the LICENSE file for more info.

ClipApp is based on amazing project [Clipy](https://github.com/Clipy/Clipy), copyright
Clipy Project / Shunsuke Furubayashi, which is itself based on
[ClipMenu](https://github.com/naotaka/ClipMenu). See LICENSE and LICENSE_CLIPMENU.
