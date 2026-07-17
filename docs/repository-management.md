# Repository Management

The GitHub repository tracks project source, Gradle configuration, scripts, documentation, and workflows.

The following local-only content is intentionally excluded from version control:

- Android SDK and bundled developer tools (`android-sdk/`, `tools/`)
- Build, export, and temporary verification artifacts (`build/`, `output/`, `tmp/`)
- Local signing material and APK work files (`apkwork/`, `*.p12`, `*.pfx`, `*.pem`)
- Local backup snapshots (`archive/`)
- Machine-specific Gradle configuration (`local.properties`)

Set up a new checkout with a locally installed JDK and Android SDK, then configure the SDK path in `local.properties`. Publish verified APKs through GitHub Releases instead of committing them to the source history.
