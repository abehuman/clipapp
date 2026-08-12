# Privacy Policy

Last updated: August 12, 2026

ClipApp is a clipboard extension app for macOS, forked from Clipy. Clipboard
data can contain sensitive information, so ClipApp will never transmit
clipboard contents or snippet contents to external services.

## Summary

- ClipApp does not ask users to provide names, email addresses, account
  information, or other directly identifying personal information.
- ClipApp does not transmit clipboard text, clipboard images, snippets, or
  other copied contents to any server or third-party service.
- ClipApp communicates with GitHub only to check for and download application
  updates. Analytics and crash-reporting SDKs are not included.

## Data Stored Locally

ClipApp stores clipboard history, snippets, preferences, and related app data
locally on your Mac.

Clipboard contents and snippets are not sent to external services by ClipApp.
However, clipboard managers can store sensitive information locally. We
recommend excluding password managers and other sensitive apps from ClipApp's
history recording when possible.

ClipApp does not currently claim that locally stored clipboard history is
encrypted. If your Mac contains sensitive data, we recommend enabling FileVault
and using macOS security features appropriately.

## Network Communication

ClipApp uses Sparkle to retrieve a signed update feed from GitHub Pages and to
download signed application archives from GitHub Releases. You can check
manually from **Check for Updates…**. Sparkle asks before enabling scheduled
update checks.

Sparkle system profiling is disabled. ClipApp does not add hardware details,
clipboard contents, snippets, or other app data to update requests. As with an
ordinary web request, GitHub may receive network metadata such as your IP
address and user agent under GitHub's own privacy practices.

ClipApp does not include analytics or crash-reporting services. If a future
version adds another network-enabled feature, this policy will be updated first
to describe what is sent and how to control it.

## Changes

This privacy policy may be updated when ClipApp's behavior or third-party
services change.

## Contact

For privacy or security questions, please open an issue on GitHub.
