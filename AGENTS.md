This is a mac app project called ClipApp which is originally forked from Clipy.

I love Clipy but one thing i did not like much is it requires many steps to paste. It does not fit my workflow.

Main difference from Clipy:
- Clipy requires 4 steps `Command+Shift+V` -> `↓` -> `→` -> `↩` to paste the latest clip because it has numbered subfolders in clipboad menu.
- ClipApp only requires 2 steps `Command+Shift+V` -> `↩`.

## Clipboard menu behavior

- `Command+Shift+V` must open the menu with the first selectable item already highlighted; separators and hidden or disabled items do not count.
- `ClipApp/Sources/Extensions/NSMenu+Highlight.swift` uses the private `NSMenu.highlightItem:` selector during `.eventTracking`. Keep the short retry after shortcut modifiers are released; a one-shot highlight can be cleared by later key-up events. Stop retrying if the user highlights another item.
- After changing menu popup or hotkey handling, manually verify both the initial highlight and `Return` paste in a Chrome/Edge address bar, GitHub repository search, the Codex prompt, and GitHub “Go to file”. The last two have historically exposed timing regressions.

## Local macOS testing

- Before asking the user to test paste, do not treat an ad-hoc signed Debug build launched from a temporary/DerivedData directory as Accessibility-ready. macOS TCC can retain a stale or mismatched approval even when a similarly named ClipApp appears enabled.
- Use a stable Apple Development or Developer ID signature, reuse a stable app path such as `~/Applications/ClipAppLocalBuild/ClipApp.app`, and verify its `TeamIdentifier` with `codesign -dvvv` before launching a local build that needs Accessibility.
- Do not assume the identifier in parentheses in a certificate name is its development team. Obtain the Team ID from the certificate subject's `OU` or the built app's `TeamIdentifier`; do not hardcode a developer's certificate or Team ID in the repository.
- If the old Debug permission is stale, reset only `jp.co.aiv.clipApp.debug` with `tccutil reset Accessibility jp.co.aiv.clipApp.debug`, quit only the old ClipApp instance, launch the signed replacement, and open the Accessibility settings pane. The user must explicitly grant the new macOS permission; never claim paste is ready until they have done so.

## Project compatibility

- Current paths are `ClipApp/`, `ClipAppTests/`, `ClipApp.xcodeproj`, and `Configurations/ClipApp.xcconfig`.
- Remaining `Clipy` references, `CPY`-prefixed types, attribution, licenses, and compatibility identifiers may be intentional. Do not rename or remove them in bulk without checking their purpose.

## Git

- `origin` is the ClipApp fork and `upstream` is the original Clipy repository. Confirm remote URLs before pushing and never push changes to `upstream`.
- Include a detailed message in commits.
