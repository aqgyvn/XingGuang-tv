# Release Version

## Current APK Version

- `versionCode`: `564`
- `versionName`: `5.6.4`

## Version Bump Rule

Each user-facing APK update must bump both Android version fields in `app/build.gradle` before building:

- Increase `versionCode` by 1.
- Keep `versionName` aligned with `versionCode`; for example, `versionCode 564` uses `versionName 5.6.4`.

Verification command:

```powershell
.\gradlew.bat :app:assembleMobileArm64_v8aDebug --no-daemon --stacktrace
```
