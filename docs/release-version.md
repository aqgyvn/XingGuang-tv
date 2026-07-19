# Release Version

## Current APK Version

- `versionCode`: `559`
- `versionName`: `5.5.9`

## Version Bump Rule

Each user-facing APK update must bump both Android version fields in `app/build.gradle` before building:

- Increase `versionCode` by 1.
- Keep `versionName` aligned with `versionCode`; for example, `versionCode 559` uses `versionName 5.5.9`.

Verification command:

```powershell
.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace
```
