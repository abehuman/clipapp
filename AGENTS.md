This is a mac app project called ClipApp which is originally forked from Clipy.

I love Clipy but one thing i did not like much is it requires many steps to paste. It does not fit my workflow.

Main difference from Clipy:
- Clipy requires 4 steps `Command+Shift+V` -> `↓` -> `→` -> `↩` to paste the latest clip because it has numbered subfolders in clipboad menu.
- ClipApp only requires 2 steps `Command+Shift+V` -> `↩`.

## Local macOS testing

- Before asking the user to test paste, do not treat an ad-hoc signed Debug build launched from a temporary/DerivedData directory as Accessibility-ready. macOS TCC can retain a stale or mismatched approval even when a similarly named ClipApp appears enabled.
- Use a stable Apple Development or Developer ID signature and verify its `TeamIdentifier` with `codesign -dvvv` before launching a local build that needs Accessibility.
- If the old Debug permission is stale, reset only `jp.co.aiv.clipApp.debug` with `tccutil reset Accessibility jp.co.aiv.clipApp.debug`, quit only the old ClipApp instance, launch the signed replacement, and open the Accessibility settings pane. The user must explicitly grant the new macOS permission; never claim paste is ready until they have done so.

## Git

- Include detailed message in commit
