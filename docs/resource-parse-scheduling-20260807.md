# Resource Parse Scheduling Optimization

## Scope

This change only optimizes the task scheduling inside `ParseJob`. It targets the wait between selecting an episode and receiving the parsed playback URL.

## Change

- Replace the two-worker executor and its nested task submission with one direct single-worker submission.
- Keep the existing 15-second default parse timeout.
- Cancel the active parse task when it times out or when playback stops.
- Keep callback delivery on the Android main thread.

The parser type branches, parse source order, request URL, request headers, authentication data, WebView detection, fallback behavior, and playback behavior are unchanged.

## Expected Effect

The parse task no longer waits for an outer worker to submit and monitor an inner worker. This removes one scheduling layer and one otherwise occupied worker. The actual end-to-end wait still depends mainly on the selected remote parse service and network response time.

## Verification

- `git diff --check -- app/src/main/java/com/fongmi/android/tv/player/ParseJob.java` passed.
- `gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --no-parallel --max-workers=1 --stacktrace` completed with `BUILD SUCCESSFUL`.
- The generated APK was installed over the existing MuMu application without clearing its data.
- The home and detail screens launched without an application crash.
- A real `parse=1` route started `CustomWebView` correctly. The selected remote iQIYI parse source returned a parse failure, so that attempt verifies route execution but does not prove an end-to-end speed improvement.
- A direct-play resource still entered its detail screen in about 1.6 seconds and returned a direct playback URL in about 2.7 seconds.

## Validation Boundary

The scheduling layer and application integration are verified. A repeatable before-and-after speed figure requires the same remote parse source to return successful results in both builds; the tested remote source did not meet that condition.
