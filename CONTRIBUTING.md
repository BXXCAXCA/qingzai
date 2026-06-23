# Contributing to Qing Zai

Thanks for improving Qing Zai. This project is still in an engineering-skeleton stage, so changes should keep the architecture testable and incremental.

## Branch and commit guidance

- Prefer small, focused changes.
- Keep generated platform files out of unrelated commits.
- Use clear commit messages, for example:
  - `feat: add offline queue replay`
  - `fix: redact WebDAV errors in settings`
  - `test: cover sync conflict tie breaker`
  - `docs: update release checklist`

## Code style

- Follow Flutter/Dart idioms and `flutter_lints`.
- Keep core services behind interfaces where possible.
- Prefer dependency injection through Riverpod providers.
- Avoid storing secrets in plain text.
- Keep UI components simple and split large widgets when they grow.

## Testing expectations

Every behavior-changing PR should include one of the following:

- Unit tests for pure logic and services.
- Provider tests for business state.
- Widget tests for interactive UI.
- A documented manual test when automation is not yet practical.

Before submitting:

```bash
flutter pub get
flutter analyze
flutter test
```

## Security expectations

- Do not commit passwords, tokens, credentials, signing keys, or provisioning files.
- Redact caught errors before showing them in UI when they may contain user input, URLs, credentials, or headers.
- Use HTTPS for WebDAV and update endpoints.
- Add tests when touching encryption, sync, updates, WebDAV path parsing, or credential handling.

## Documentation expectations

Update docs when changing:

- Setup or build commands.
- Release steps.
- Update manifest format.
- Security requirements.
- Sync semantics or data model compatibility.

## Review checklist

Reviewers should look for:

- Deterministic sync behavior.
- Safe credential handling.
- Stable provider dependencies.
- Tests that cover the changed logic.
- No new platform-specific assumptions hidden in shared code.
