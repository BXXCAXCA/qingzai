# Preview Builds

Qing Zai can produce installable preview artifacts from GitHub Actions without requiring a local Flutter SDK.

## Build artifacts

The `Build Preview Artifacts` workflow can be started manually from the GitHub Actions page. It uploads these artifacts when the jobs pass:

- `qingzai-android-debug-apk`: Android debug APK for internal testing.
- `qingzai-linux-preview`: Linux release bundle archived as `tar.gz`.
- `qingzai-windows-preview`: Windows release bundle archived as `zip`.

## How to create a preview build

1. Open **GitHub Actions**.
2. Select **Build Preview Artifacts**.
3. Choose **Run workflow** on `main`.
4. Wait for the Android, Linux, and Windows jobs to finish.
5. Download the uploaded artifact for the platform you want to test.

## Android preview install

The Android artifact is a debug APK. Install it on a test device with:

```bash
adb install -r app-debug.apk
```

This APK is not signed for store distribution. It is only for internal testing.

## Windows preview run

1. Download `qingzai-windows-preview`.
2. Extract the zip.
3. Run `qingzai.exe` from the extracted directory.

## Linux preview run

1. Download `qingzai-linux-preview`.
2. Extract the archive:

```bash
tar -xzf qingzai-linux-preview.tar.gz -C qingzai-linux-preview
```

3. Run the app binary from the extracted directory.

## Release limitation

Preview artifacts prove the app can be built, opened, and used for internal testing. They do not replace platform release validation. Before production release, still run the release checklist for:

- Android signing and store packaging.
- Windows installer/signing.
- iOS build/signing on macOS.
- HarmonyOS SDK validation.
- Real WebDAV, LAN, and update-package tests.
