# Releasing ClipApp outside the Mac App Store

ClipApp is distributed as a Developer ID-signed and Apple-notarized ZIP through
GitHub Releases. Notarize and staple `ClipApp.app` before creating the final ZIP.

## Prerequisites

- An active Apple Developer Program membership.
- A `Developer ID Application` certificate created in Xcode.
- The release commit and version pushed to `origin`. Never push to `upstream`.
- Manual verification on every supported macOS and CPU architecture.

## One-time local signing setup

Copy the example configuration and replace `YOUR_TEAM_ID` with the Team ID shown
by Xcode. Never commit the local file, certificate, private key, or exported
`.p12` file.

```sh
cp Configurations/CodeSigning-Local.xcconfig.example \
  Configurations/CodeSigning-Local.xcconfig
```

The shared configuration keeps Debug builds ad-hoc and signs Release builds
with the generic `Developer ID Application` identity. Xcode selects the matching
certificate for the configured team.

## Prepare a release

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in
   `Configurations/ClipApp.xcconfig`.
2. Run the complete test suite and confirm the worktree contains only the
   intended release changes.
3. In Xcode, select the `ClipApp` scheme and `Any Mac`, then choose
   **Product > Archive**.
4. Open **Window > Organizer**, select the archive, and choose
   **Distribute App > Developer ID > Upload**.
5. Review the signing options and upload the archive to Apple's notary service.
6. After notarization is accepted, export the notarized app from Organizer.
   Use the newly exported app; do not package the pre-notarization copy.

Notarization is not complete until the exported app contains a stapled ticket.
Review Apple's notary log even when the submission succeeds.

## Verify the exported app

Set `app_path` to the exported notarized application and run:

```sh
app_path=/path/to/ClipApp.app
codesign --verify --deep --strict --verbose=2 "$app_path"
xcrun stapler validate "$app_path"
spctl --assess --type execute --verbose=4 "$app_path"
lipo -archs "$app_path/Contents/MacOS/ClipApp"
```

The Gatekeeper assessment must be accepted as `Notarized Developer ID`. Publish
only the architectures actually reported by `lipo`; a universal release should
contain both `arm64` and `x86_64`.

## Create the release archive

Run the repository script against the verified, notarized app:

```sh
scripts/create-release-archive.sh "$app_path" 1.4.0 /path/to/output
cd /path/to/output
shasum -a 256 ClipApp-1.4.0.zip > ClipApp-1.4.0.zip.sha256
```

The archive includes `LICENSE`, `LICENSE_CLIPMENU`, and
`THIRD_PARTY_NOTICES`. Do not modify the application after signing or before
packaging because that invalidates its signature.

## Test the downloadable artifact

Create a draft GitHub Release and attach the ZIP and checksum. Download the ZIP
through a browser so that macOS applies quarantine metadata, then verify:

- Dragging `ClipApp.app` to `/Applications` and opening it normally.
- The first-launch Gatekeeper and Accessibility permission flows.
- `Command+Shift+V`, initial selection, and Return paste in a Chrome or Edge
  address bar, GitHub repository search, the Codex prompt, and GitHub Go to file.
- Login-item registration and launch after signing out or restarting.
- Relaunch and replacement of the previous public version.
- The declared minimum macOS version and every advertised CPU architecture.

Publish the GitHub Release only after the downloaded artifact passes these
checks. Use a new version and new notarization submission for any changed binary;
never replace a published release asset with different contents.
