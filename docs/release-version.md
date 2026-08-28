# Release Version

## Current APK Version

- `versionCode`: `5716`
- `versionName`: `5.7.16`

## Version Bump Rule

Each release task may update the Android version fields once. Intermediate fixes, builds, and tests keep the current version. All implementation, documentation, and progress-log changes completed in the same release task share that single version:

- Increase `versionCode` by 1.
- Use a semantic display name derived from the build number; for example, `versionCode 5716` uses `versionName "5.7.16"`.
- Do not reuse the previous version for a new release.

Verification command:

```powershell
.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace
```

## Target Scope

The Android package has only the mobile product flavor. Leanback TV source and configuration are not included.
