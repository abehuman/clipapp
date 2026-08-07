# ClipApp

ClipApp is a clipboard extension app for macOS, forked from
[Clipy](https://github.com/Clipy/Clipy) (MIT License).

I love Clipy but one thing i did not like much is it requires many steps to paste. It does not fit my workflow.

The main difference from Clipy:
- Clipy requires 4 steps `Command+Shift+V` -> `↓` -> `→` -> `↩` to paste the latest clip because it has numbered subfolders in clipboad menu.
- ClipApp only requires 2 steps `Command+Shift+V` -> `↩`.

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

### Auto Update
Automatic updates are NOT included. The inherited Sparkle integration, feed URL, and public keys have been removed.

### Privacy Policy
Please see [PRIVACY.md](./PRIVACY.md).

### Licence
ClipApp is available under the MIT license. See the LICENSE file for more info.

Source and binary distributions must include [LICENSE](./LICENSE),
[LICENSE_CLIPMENU](./LICENSE_CLIPMENU), and
[THIRD_PARTY_NOTICES](./THIRD_PARTY_NOTICES). To create a distributable ZIP
from a signed and notarized app, run:

```
scripts/create-release-archive.sh /path/to/ClipApp.app <version> [output-directory]
```

ClipApp is based on amazing project [Clipy](https://github.com/Clipy/Clipy), copyright
Clipy Project / Shunsuke Furubayashi, which is itself based on
[ClipMenu](https://github.com/naotaka/ClipMenu). See LICENSE and LICENSE_CLIPMENU.
