# Privacy Policy

Last updated: July 23, 2026

ClipApp is a clipboard extension app for macOS, forked from Clipy. Clipboard
data can contain sensitive information, so ClipApp will never transmit
clipboard contents or snippet contents to external services.

## Summary

- ClipApp does not ask users to provide names, email addresses, account
  information, or other directly identifying personal information.
- ClipApp does not transmit clipboard text, clipboard images, snippets, or
  other copied contents to any server or third-party service.
- As currently distributed, ClipApp performs **no network communication**:
  automatic update support is not included, and the app ships without a
  Firebase configuration file, so the inherited
  Firebase Analytics / Crashlytics code paths are inactive.

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

As currently distributed, ClipApp performs no intentional network
communication.

If a future version enables Sparkle update checks or Firebase
analytics/crash reporting, this policy will be updated first to describe
what is sent and how to opt out.

## Changes

This privacy policy may be updated when ClipApp's behavior or third-party
services change.

## Contact

For privacy or security questions, please open an issue on GitHub.
