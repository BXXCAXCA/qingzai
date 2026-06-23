# Update Manifest Reference

Qing Zai uses a JSON manifest for self-hosted update checks. The parser is implemented by `UpdateManifest.fromJson` and `UpdatePackage.fromJson`.

## Manifest location

The manifest must be served over HTTPS when used by production builds.

Example:

```text
https://updates.example.com/qingzai/update_manifest.json
```

## Top-level fields

| Field | Required | Description |
| --- | --- | --- |
| `version` | yes | Target version advertised by the manifest. |
| `releaseDate` | yes | ISO-8601 release timestamp. |
| `releaseNotes` | no | Human-readable release notes. `notes` is accepted as a fallback. |
| `packages` | yes | Object keyed by platform, with each value parsed as an update package. |
| `fileChecksums` | no | Optional map of artifact paths to SHA-256 checksums. |
| `patches` | no | Optional list of patch edges for patch-path calculation. |
| `isForceUpdate` | no | Whether the update should be treated as required. |

## Package fields

| Field | Required | Description |
| --- | --- | --- |
| `platform` | recommended | Platform string such as `android`, `ios`, or `windows`. |
| `channel` | no | Release channel, defaults to `stable`. |
| `downloadUrl` | yes for self-hosted | HTTPS URL for a downloadable package. `url` is accepted as a fallback. |
| `sha256` | yes for self-hosted | 64-character SHA-256 checksum. `checksum` is accepted as a fallback. |
| `size` | no | Package size in bytes. |
| `storeUrl` | yes for store redirect | App Store, Play Store, or other store listing URL. |
| `signature` | no | Reserved for future signature verification. |
| `supportsPatch` | no | Whether patch update paths may be used. |

## Patch fields

| Field | Required | Description |
| --- | --- | --- |
| `fromVersion` | yes | Version at the start of this patch edge. |
| `toVersion` | yes | Version after applying this patch. |
| `patchUrl` | yes | HTTPS patch artifact URL. `url` is accepted as a fallback. |
| `sha256` | yes | 64-character SHA-256 checksum. `checksum` is accepted as a fallback. |
| `size` | yes | Patch size in bytes. Used as the path cost for shortest-path calculation. |

## Security requirements

- Production manifest URLs must use HTTPS.
- Production self-hosted artifact URLs must use HTTPS.
- SHA-256 checksums must be present and 64 lowercase or uppercase hex characters.
- Do not include credentials in manifest or artifact URLs.
- Keep old manifests and artifacts available until rollback is no longer needed.

## Example

See `config/update_manifest.example.json`.
