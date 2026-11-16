# Windows Android setup

The portable, non-admin tool locations used for this machine are:

- Java 17: `D:\luma-devtools\jdk-17`
- Android SDK: `D:\luma-devtools\android-sdk`
- Android command-line tools: `D:\luma-devtools\android-sdk\cmdline-tools\latest`

User-level variables configured:

```text
JAVA_HOME=D:\luma-devtools\jdk-17
ANDROID_HOME=D:\luma-devtools\android-sdk
ANDROID_SDK_ROOT=D:\luma-devtools\android-sdk
```

Verified on 2026-11-16:

- Temurin `17.0.21` runs successfully.
- `adb`/Platform-Tools `37.0.1` runs successfully.
- Android platform and build-tools packages are still pending because their
  downloads stalled in the current network environment.
- Flutter stable `3.50.0` was not installed; the official Windows archive is
  approximately 1.87 GB and only a partial download exists outside the repo.

After Flutter is available, open a new PowerShell session and run from the
repository root:

```powershell
flutter doctor -v
flutter create --platforms=android,ios .
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

The app’s production API default remains `https://lumaword.app/api/v1` in
`lib/core/config.dart`; no credentials belong in this repository.
