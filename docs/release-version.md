# Release Version

## Current APK Version

- `versionCode`: `569`
- `versionName`: `5.6.9`

## Version Bump Rule

Each user-facing APK update must bump both Android version fields in `app/build.gradle` before building:

- Increase `versionCode` by 1.
- Keep `versionName` aligned with `versionCode`; for example, `versionCode 569` uses `versionName 5.6.9`.

Verification command:

```powershell
.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace
```

## Target Scope

The Android package has only the mobile product flavor. Leanback TV source and configuration are not included.
