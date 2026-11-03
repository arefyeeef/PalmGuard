# PalmGuard 0.2.0 — experimental window-level filter

A rootless Theos tweak prototype for Apple Notes. It examines the touch being hit-tested at the app window and can reject that one initial contact when UIKit reports a sufficiently large `UITouch.majorRadius`.

## Important limitations

A passive capacitive stylus is normally reported by iPadOS as a direct touch, like a finger. PalmGuard cannot identify the stylus as Apple Pencil and cannot provide Apple's native palm-rejection system. It uses contact radius as a heuristic. If the radius values for your stylus and palm overlap, no threshold can reliably separate them.

## What changed in 0.2.0

- Moved filtering from `UIView pointInside:withEvent:` to `UIWindow hitTest:withEvent:`.
- The filter now considers only the touch whose location matches the current hit-test point.
- Added a startup log showing whether filtering is enabled and the active threshold.
- Added a log entry whenever a touch is rejected.

## Defaults and configuration

Filtering remains OFF unless explicitly enabled. Logging is ON by default. The tweak is injected into Apple Notes only (`com.apple.mobilenotes`).

Preferences file:

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

After changing the file, fully close and reopen Notes. Threshold range: 8–80 points. Lower values reject more contacts; higher values reject fewer.

## Log

`/var/mobile/Library/Logs/PalmGuard.log`

The log includes touch type, phase, major radius, radius tolerance, active threshold, and whether a contact was filtered. It does not record coordinates.

## Build

```sh
make clean package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless
```

The GitHub Actions workflow builds and uploads the rootless `.deb`.
