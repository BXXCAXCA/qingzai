# CI Verification PR

This short-lived pull request is used to verify the repository pull-request CI path after the MVP implementation pass.

Expected checks:

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter test integration_test`

Merge guidance:

- Merge only after all checks pass.
- If checks do not start, verify GitHub Actions is enabled for the private repository.
- If checks fail, use the logs to open focused follow-up issues before release.
