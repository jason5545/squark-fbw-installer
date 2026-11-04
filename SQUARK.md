# FlyByWire Installer for macOS (Squark)

A fork of [flybywiresim/installer](https://github.com/flybywiresim/installer) that runs natively on Apple Silicon Macs
and installs FlyByWire add-ons into Microsoft Flight Simulator running under
[Squark](https://github.com/jason5545/squark) (Steam + Wine).

## What is different from upstream

- **Path detection on macOS.** The simulator lives in Steam's compat prefix
  (`~/Library/Application Support/Steam/steamapps/compatdata/<appid>/pfx`). Every Steam library in
  `libraryfolders.vdf` is checked, and the `C:\` path in `UserCfg.opt` is mapped onto the prefix's `drive_c`,
  the same way upstream already does it for Proton on Linux.
- **Background services** (SimBridge) are Windows programs, so on macOS the installer does not offer
  start/stop or autostart, just like on Linux. Start them yourself inside the prefix if you need them.
- **macOS packaging**: `npm run package:mac` builds an unsigned-for-distribution arm64 `.app` in `dist/mac-arm64`.

## Signed and notarized build

`scripts/release-mac.sh` builds the app, wraps it in an `.xcarchive` and lets Xcode sign it with a cloud-managed
Developer ID certificate and notarize it, using the account signed in to Xcode:

```sh
TEAM=<team id> SIGN_ID=<local codesigning identity or SHA-1> scripts/release-mac.sh
```

The notarized app ends up in `dist/release/notarized/`.

## Staying in sync

```sh
git fetch upstream && git merge upstream/master
```
