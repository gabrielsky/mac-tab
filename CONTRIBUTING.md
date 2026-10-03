# Contributing

Requires macOS 14 or later and Xcode 15 or later. Code comments and script messages are currently in Chinese.

## Build and run

```bash
./scripts/build-app.sh
```

This builds a universal release (Apple silicon and Intel), signs it, installs it to `~/Applications/MacTab.app`, and launches it. On first launch, turn on MacTab in System Settings → Privacy & Security → Accessibility.

## Signing certificate (optional)

Accessibility access is tied to the app's code signature. Without a certificate the script signs ad hoc, so every build gets a new signature, macOS treats it as a new app, and you have to grant access again. Run this once:

```bash
./scripts/setup-cert.sh
```

It creates a self-signed certificate named "MacTab Local" (valid for 10 years) in your login keychain. Builds signed with it keep their accessibility access. After switching from ad hoc signing to the certificate, run `tccutil reset Accessibility local.mactab` to clear the old entry, then grant access once more.

## Localization

UI text is written in English in the code, through `String(localized:)` and SwiftUI string literals. Simplified Chinese translations are in `Resources/zh-Hans.lproj/Localizable.strings`, and `swift test` checks that the file parses and that every theme is translated. To add a language, add `Resources/<language>.lproj/Localizable.strings`.

## Tests and logs

```bash
swift test
/usr/bin/log show --last 2m --style compact --predicate 'subsystem == "local.mactab"'
```

## Theme previews

After changing a theme, run `./scripts/theme-shots.sh` to regenerate the GIFs in the README. It needs ffmpeg.
