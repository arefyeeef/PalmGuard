# PalmGuard 0.1.1 — diagnostic-first prototype

A rootless Theos tweak prototype for testing whether UIKit touch-radius measurements can distinguish a passive capacitive stylus tip from a hand on an iPad.

## Important limitations

A passive capacitive stylus is ordinarily reported by iPadOS as a normal direct touch, like a finger. This tweak cannot turn it into an Apple Pencil or create true system-wide Palm Rejection. It only experiments with `UITouch.majorRadius`, a measurement in points. A large finger/thumb can be rejected too, and different apps may handle hit-testing differently.

## Safety defaults

- **Filtering is OFF by default.** The first install is diagnostic only.
- The tweak is injected into **Apple Notes only** (`com.apple.mobilenotes`) to avoid affecting SpringBoard and every other app.
- Logging is ON by default.
- Apple Pencil (`UITouchTypePencil`) is excluded.

## Log file

`/var/mobile/Library/Logs/PalmGuard.log`

Each initial direct touch is logged with its type, phase, `majorRadius` and `majorRadiusTolerance`. The log does not include touch coordinates.

## Enable filtering after reviewing measurements

Use Filza to create or edit:

`/var/mobile/Library/Preferences/com.palmguard.tweak.plist`

Example:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Enabled</key><true/>
    <key>RadiusThreshold</key><real>25.0</real>
    <key>LogTouches</key><true/>
</dict>
</plist>
```

Fully close and reopen Notes after changing the file. Lower threshold rejects more touches; higher threshold is less aggressive. Supported threshold range: 8–80 points. Set `Enabled` to false to disable blocking.

## Build

Requires Theos and an iOS SDK. From this directory:

```sh
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

The `.deb` should appear in `packages/`. Install through Sileo/Filza. Remove PalmGuard from Sileo to roll back.

A GitHub Actions workflow is included as a convenience, but this prototype has **not** been built or tested on the target iPad yet. Review third-party build actions before running them.

## Test plan

1. Install the diagnostic build.
2. Open Apple Notes and tap once with the passive stylus.
3. Tap separately with a fingertip.
4. Rest your palm on the screen.
5. Read the three `majorRadius` values from the log.
6. Only enable filtering if stylus readings and palm readings are meaningfully separated.

If the stylus and palm readings overlap, a radius threshold will not solve the problem reliably.
