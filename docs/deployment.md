# Qing Zai Deployment Guide

This document prepares the project for release packaging. It focuses on repeatable steps and release gates rather than store-specific legal or account setup.

## Release channels

Qing Zai currently supports these release paths:

- Android: APK or app bundle after Android project configuration is generated.
- iOS: App Store / TestFlight after iOS project configuration is generated.
- Windows: self-hosted signed package or installer.
- HarmonyOS: blocked until a validated Flutter-HarmonyOS SDK and platform project are added.

## Release prerequisites

Before creating a candidate build:

1. Confirm `flutter analyze` passes.
2. Confirm `flutter test` passes.
3. Confirm the update manifest is valid and hosted over HTTPS.
4. Confirm self-hosted update files have SHA-256 checksums.
5. Confirm no logs or UI errors expose secrets.
6. Confirm WebDAV sync works against a test account.
7. Confirm encryption is initialized with a strong password.
8. Confirm manual smoke tests in `docs/development.md` pass.

## Versioning

The version lives in `pubspec.yaml`:

```yaml
version: 0.1.0+1
```

Use semantic versioning for the user-visible version and an increasing build number after `+`.

Examples:

- `0.1.0+1`: first internal candidate.
- `0.1.1+2`: patch candidate.
- `1.0.0+100`: first stable release.

## Android build outline

Generate platform folders when ready:

```bash
flutter create . --platforms=android
flutter pub get
flutter build apk --release
# or
flutter build appbundle --release
```

Before external distribution, configure:

- Application ID, signing config, and keystore storage.
- App icon and launch assets.
- Network permissions for WebDAV and LAN transfer.
- Backup policy for encrypted local data.
- Store metadata and privacy disclosures.

Do not commit private keystores or passwords.

## iOS build outline

Generate platform folders when ready:

```bash
flutter create . --platforms=ios
flutter pub get
flutter build ios --release
```

Before TestFlight/App Store distribution, configure:

- Bundle identifier and signing team.
- App icon and launch assets.
- Network permissions and local-network usage descriptions.
- Keychain access behavior for device ID and encrypted credentials.
- Privacy nutrition labels.

## Windows build outline

Generate platform folders when ready:

```bash
flutter create . --platforms=windows
flutter pub get
flutter build windows --release
```

Before distribution, configure:

- Installer or archive packaging.
- Code signing certificate.
- Update manifest URL and self-hosted package URLs.
- LAN firewall prompts and documentation.

## HarmonyOS build outline

HarmonyOS remains a verification task. Before release preparation:

1. Validate the Flutter-HarmonyOS SDK and target devices.
2. Generate platform folders using the selected toolchain.
3. Map platform identifiers to `QingZaiPlatform.harmonyPhone`, `harmonyTablet`, or `harmonyWatch`.
4. Re-run platform-service tests and manual device smoke tests.
5. Add store-specific package/signing instructions.

## Self-hosted update manifest

Use `config/update_manifest.example.json` as the starting point. Every self-hosted package should include:

- `version`
- `publishedAt`
- platform-specific package URL
- `sha256`
- package size
- optional patch graph

All URLs used by `SecureVersionService` must use HTTPS.

## Rollback plan

For self-hosted releases:

1. Keep the previous manifest and packages available.
2. Publish a fixed manifest that points users to the previous stable package.
3. If a package checksum was wrong, remove the bad package and publish a corrected manifest.
4. Record the incident and update release notes.

For app-store releases, use the store's phased release, halt, or rollback mechanisms where available.
