# Source Docs Summary

This file summarizes the original Qing Zai planning documents for future handoff.

## Product goal

Qing Zai is a Flutter cross-platform productivity app for todos, clipboard items, notes, memos, Pomodoro sessions, WebDAV sync, LAN transfer, and app updates.

## Target platforms

Android, iOS, Windows, HarmonyOS phone, HarmonyOS tablet, and HarmonyOS watch.

## Main technical choices

- Flutter and Dart
- Material Design 3
- Riverpod
- Hive local storage
- WebDAV sync
- AES-GCM encryption
- Offline-first sync queue
- TCP LAN file transfer
- GitHub Actions CI and preview builds

## Implementation plan completed so far

The repository now includes the app shell, data models, storage, encryption, WebDAV, sync manager, LAN transfer, version service, providers, UI screens, offline support, platform service, performance helpers, security helpers, tests, docs, CI, and preview build workflow.

## Remaining validation

Real device smoke tests, real WebDAV sync, real LAN transfer, iOS and HarmonyOS platform work, and production release checks are still required.
