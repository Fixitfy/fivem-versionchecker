# fivem-versionchecker

Release manifests for Fixitfy FiveM resources. Each script reads its own JSON file
from this branch on startup and prints an update notice in the server console.

Raw URL pattern (branch: `Fixitfy`):

```
https://raw.githubusercontent.com/Fixitfy/fivem-versionchecker/refs/heads/Fixitfy/<script-name>.json
```

## Format

A plain JSON array of release objects. **Order does not matter** — versions are
compared numerically, so `1.0.10` is correctly newer than `1.0.9`.

```json
[
  {
    "version": "1.1.0",
    "date": "2026-08-10",
    "critical": true,
    "changelog": [
      "What changed in this release."
    ],
    "updateFiles": [
      "server/main.lua",
      "fxmanifest.lua"
    ]
  }
]
```

| Field | Required | Description |
|---|---|---|
| `version` | yes | Must match the `version '...'` line in that release's `fxmanifest.lua`. |
| `changelog` | no | Lines shown to the server owner. Long lines are word-wrapped by the checker. |
| `updateFiles` | no | Files the owner has to replace. Merged and de-duplicated across every release the owner is behind. |
| `date` | no | Shown next to the version number. |
| `critical` | no | `true` adds a red `[CRITICAL]` tag. Use for security fixes. |

## Releasing a new version

1. Bump `version '...'` in the resource's `fxmanifest.lua`.
2. Append a new object to that script's JSON file here and push.

`raw.githubusercontent.com` caches for roughly 5 minutes, so the new entry takes a
few minutes to reach servers.

## Manifests

| Script | Manifest |
|---|---|
| fx-fishing | [fx-fishing.json](fx-fishing.json) |
