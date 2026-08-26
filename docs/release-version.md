# Release Version

## Current APK Version

- `versionCode`: `5713`
- `versionName`: `5713`

## Version Bump Rule

Every task that modifies APK code, resources, configuration, or behavior must bump both Android version fields in `app/build.gradle` before building. All implementation, documentation, and progress-log changes completed in the same task share that single new version:

- Increase `versionCode` by 1.
- Keep `versionName` identical to `versionCode`; for example, `versionCode 5713` uses `versionName "5713"`.
- Do not reuse the previous version after any APK-affecting modification.

Verification command:

```powershell
.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace
```

## Target Scope

The Android package has only the mobile product flavor. Leanback TV source and configuration are not included.
