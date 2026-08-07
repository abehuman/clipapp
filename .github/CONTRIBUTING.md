# Contributing to ClipApp

:tada: Thank you for contributing to ClipApp :tada:

## Localization

### Add New Language
<img src="../Resources/new_localization.png" width="600">

After adding the language, please make changes to the various `.strings` files as follows.

### Modify an Existing Language
The files to be localized are as follows.
- Localizable.strings ( `ClipApp/Resources/#{language_name}.lproj/Localizable.strings` )
- Preferences ( `ClipApp/Sources/Preferences/#{language_name}.lproj/*.strings` )
- PreferencesPanels ( `ClipApp/Sources/Preferences/Panels/#{language_name}.lproj/*.strings` )
- SnippetsEditor ( `ClipApp/Sources/Snippets/#{language_name}.lproj/*.strings` )

**English localization only, please edit `.xib` files directly**
