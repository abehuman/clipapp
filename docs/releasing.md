# Releasing ClipApp outside the Mac App Store

ClipApp is distributed as a Developer ID-signed, Apple-notarized application
through GitHub Releases. Sparkle reads the signed update feed at
`https://abehuman.github.io/clipapp/appcast.xml` and downloads update archives
from the matching GitHub Release.

Never publish an appcast entry before its referenced release assets are
available. Never replace a published asset with different contents; increment
the version, notarize again, and publish a new release.

## Prerequisites

- An active Apple Developer Program membership.
- A `Developer ID Application` certificate created in Xcode.
- The release commit and version pushed to `origin`. Never push to `upstream`.
- The Sparkle private key in the login Keychain under account
  `jp.co.aiv.clipApp`.
- Manual verification on every supported macOS and CPU architecture.

## One-time local signing setup

Copy the example configuration and replace `YOUR_TEAM_ID` with the Team ID
shown by Xcode. Never commit the local file, certificate, private signing key,
or an exported `.p12` file.

```sh
cp Configurations/CodeSigning-Local.xcconfig.example \
  Configurations/CodeSigning-Local.xcconfig
```

The shared configuration keeps Debug builds ad-hoc and signs Release builds
with the generic `Developer ID Application` identity. Xcode selects the
matching certificate for the configured team.

## One-time Sparkle setup

The public EdDSA key is committed in `ClipApp/Supporting Files/Info.plist`.
The corresponding private key must remain outside the repository. It was
created with Sparkle's `generate_keys` utility and stored in the login Keychain
under account `jp.co.aiv.clipApp`.

Back up that private key to encrypted offline storage. Losing it prevents
existing installations from accepting future updates. The utility supports an
explicit export when a backup is required:

```sh
build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys \
  --account jp.co.aiv.clipApp \
  -x /path/on/encrypted-storage/clipapp-sparkle-private-key
```

Treat the exported file like a password. Never commit, upload, log, or share
its contents.

In the GitHub repository, open **Settings > Pages** and configure:

- Source: **Deploy from a branch**
- Branch: `main`
- Folder: `/docs`

The repository contains `docs/.nojekyll` so GitHub Pages serves the signed XML
unchanged. `docs/appcast.xml` is generated from a real release archive and is
therefore intentionally absent until the first release is prepared.

## Prepare and notarize a release

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in
   `Configurations/ClipApp.xcconfig`. Both must increase for every release.
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

The Gatekeeper assessment must be accepted as `Notarized Developer ID`.
Publish only the architectures reported by `lipo`; a universal release should
contain both `arm64` and `x86_64`.

Also confirm that `ClipApp.app/Contents/Frameworks/Sparkle.framework` exists
and that its nested helpers pass the deep code-signature verification above.

## Create the two ZIP archives

Use separate output directories. The general distribution archive contains a
folder with the app and license files. Sparkle requires an app-only archive and
must not scan the general distribution ZIP.

```sh
version=1.4.0
distribution_dir=/path/to/release/distribution
updates_dir=/path/to/release/sparkle-archives

scripts/create-release-archive.sh \
  "$app_path" "$version" "$distribution_dir"
scripts/create-update-archive.sh \
  "$app_path" "$version" "$updates_dir"
```

This creates:

- `ClipApp-1.4.0-distribution.zip` for people downloading manually.
- `ClipApp-1.4.0.zip` for Sparkle.

Keep each old `ClipApp-<version>.zip` in `updates_dir`. Sparkle can use the old
archives to generate smaller delta updates. Do not place
`*-distribution.zip` in that directory.

To include release notes in Sparkle, place Markdown, HTML, or plain text next
to the update archive with the same base name, for example
`ClipApp-1.4.0.md`.

## Generate the signed appcast

Resolve packages once if `build/SourcePackages` has not been populated, then
generate the feed using the private key from the Keychain:

```sh
xcodebuild -resolvePackageDependencies \
  -project ClipApp.xcodeproj \
  -scheme ClipApp \
  -clonedSourcePackagesDirPath build/SourcePackages

scripts/generate-appcast.sh "$updates_dir" "$version"
```

Run this from an interactive local Terminal. On the first signing run, macOS
may ask whether `generate_appcast` can access the Sparkle private key; approve
that request. A non-interactive process can otherwise wait indefinitely for
Keychain authorization.

The script updates `docs/appcast.xml`, preserving prior feed entries. It may
also create `.delta` files in `updates_dir`. Do not hand-edit the generated XML
or signed release notes; rerun the generator after any change.

Review the generated appcast and confirm that every enclosure URL uses the
expected release tag, such as:

```text
https://github.com/abehuman/clipapp/releases/download/v1.4.0/...
```

Create checksums for the two full archives and any generated delta files:

```sh
cd "$distribution_dir"
shasum -a 256 "ClipApp-$version-distribution.zip" \
  > "ClipApp-$version-distribution.zip.sha256"

cd "$updates_dir"
shasum -a 256 "ClipApp-$version.zip" > "ClipApp-$version.zip.sha256"
for delta in ./*.delta(N); do
  shasum -a 256 "$delta" > "$delta.sha256"
done
```

The final loop uses zsh's null-glob qualifier and is safe when no deltas were
created.

## Publish without exposing a broken update

1. Create a **draft** GitHub Release with tag `v<version>`.
2. Attach both ZIPs, their checksums, and every newly generated `.delta` file
   plus its checksum.
3. Download the draft assets where possible and complete the artifact tests
   below.
4. Publish the GitHub Release so every URL referenced by the appcast exists.
5. Commit and push the generated `docs/appcast.xml` immediately after the
   release assets are public.
6. Wait for GitHub Pages deployment, then retrieve the live appcast and verify
   that its enclosure and release-note URLs return successfully.
7. From an older public ClipApp version, run **Check for Updates…**, install the
   update, and verify the relaunched version and signature.

For the first release there is no older public version with Sparkle to update,
so step 7 becomes mandatory when preparing the second release. Before announcing
the first release, at minimum verify the live feed, signatures, download, and
manual installation from the public assets.

## Test the downloadable artifact

Download the distribution ZIP through a browser so macOS applies quarantine
metadata, then verify:

- Dragging `ClipApp.app` to `/Applications` and opening it normally.
- The first-launch Gatekeeper and Accessibility permission flows.
- `Command+Shift+V`, initial selection, and Return paste in a Chrome or Edge
  address bar, GitHub repository search, the Codex prompt, and GitHub Go to
  file.
- **Check for Updates…** can read the live appcast without a signature error.
- Login-item registration and launch after signing out or restarting.
- Relaunch and replacement of the previous public version.
- The declared minimum macOS version and every advertised CPU architecture.

Use a new version and new notarization submission for any changed binary.
