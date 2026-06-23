# Qing Zai Release Checklist

Use this checklist for every release candidate.

## 1. Code quality gate

- [ ] `flutter pub get` completes.
- [ ] `flutter analyze` passes.
- [ ] `flutter test` passes.
- [ ] New or changed behavior has tests.
- [ ] README and docs are up to date.
- [ ] CI has run for the release commit.

## 2. Security gate

- [ ] Strong-password policy is enabled for encryption initialization.
- [ ] Errors shown in UI are passed through `SensitiveValueRedactor` when they may contain user input or service details.
- [ ] WebDAV server URLs use HTTPS and do not embed credentials.
- [ ] WebDAV remote paths are relative and cannot escape the configured root.
- [ ] Self-hosted update package URLs use HTTPS.
- [ ] Self-hosted update packages include 64-character SHA-256 checksums.
- [ ] No keystores, provisioning profiles, secrets, or `.env` files are committed.

## 3. Data and sync gate

- [ ] Local CRUD works for Todo, Clipboard, Notes, Pomodoro, and Memo.
- [ ] Tombstone deletes are preserved for syncable data.
- [ ] WebDAV connection succeeds against a staging account.
- [ ] Initial sync uploads encrypted payloads.
- [ ] Remote changes download and merge correctly.
- [ ] Offline changes are queued and replay when online.
- [ ] Conflict resolution remains deterministic across repeated runs.

## 4. Platform gate

- [ ] Android build configuration is generated and signing is configured before Android release.
- [ ] iOS build configuration is generated and signing is configured before iOS release.
- [ ] Windows build configuration is generated and signing/installer flow is configured before Windows release.
- [ ] HarmonyOS toolchain is verified before HarmonyOS release work begins.
- [ ] Platform capability switches match the release target.

## 5. Manual smoke gate

- [ ] Start app in light and dark mode.
- [ ] Create, edit, and delete a todo.
- [ ] Add and favorite a clipboard item.
- [ ] Create, search, pin, and delete a note.
- [ ] Create and delete a memo with an attachment path.
- [ ] Start and complete a Pomodoro session.
- [ ] Configure WebDAV and perform sync.
- [ ] Start LAN receiving mode and send a test file.
- [ ] Check update manifest handling.

## 6. Release publication gate

- [ ] Version in `pubspec.yaml` is bumped.
- [ ] Release notes are written.
- [ ] Update manifest is updated and validated.
- [ ] Release artifacts are uploaded to the selected channel.
- [ ] Checksums are published for self-hosted artifacts.
- [ ] Rollback package/manifest is preserved.

## 7. Post-release gate

- [ ] Monitor crash/error reports if available.
- [ ] Confirm update manifest remains reachable over HTTPS.
- [ ] Confirm WebDAV sync smoke test still passes with production endpoint.
- [ ] Record known issues for the next iteration.
