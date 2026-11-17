# PENSALO · Gut Check

A native SwiftUI prototype for making quick, instinctive decisions. Save the options you do not want to lose, discard the others, and discover which choice you keep coming back to.

**The current interface is an early prototype and is being redesigned.**

The app is contained in `GutCheck/GutCheck.swift`, including the screen, round engine, and UI components. It uses no external services or third-party dependencies. Options are stored locally on the device.

## Run in Xcode

1. Open `GutCheck.xcodeproj` with Xcode 27.1 or later.
2. Select the `GutCheck` scheme and an iPhone simulator running iOS 27.
3. Press Run. The source also includes a SwiftUI `#Preview`.

The same source supports macOS 26 or later. For a local test on an Apple silicon Mac, run:

```sh
xcrun swiftc -parse-as-library -target arm64-apple-macosx26.0 GutCheck/GutCheck.swift -o /tmp/GutCheck
/tmp/GutCheck
```

## Interactions

- Tap a bubble to save it.
- Flick it away to discard it.
- Hold it for 0.7 seconds to choose it immediately.
- Use the sliders button to edit the options, pace, and timer settings.

## Round engine tests

`Tests/RoundEngineTests.swift` checks saving, pausing and resuming, deadlines, tie-breaking, elimination, direct selection, untimed mode, and option validation. Tests do not write preferences.

```sh
xcrun swiftc -D MODEL_TESTS -parse-as-library -target arm64-apple-macosx26.0 GutCheck/GutCheck.swift Tests/RoundEngineTests.swift -o /tmp/GutCheckTests
/tmp/GutCheckTests
```

## Repository contents

The repository contains the source code, Xcode project, shared scheme, tests, and this README. Local builds, compiled applications, previews, caches, personal Xcode settings, and environment files are excluded from Git.
