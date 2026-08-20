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

## Layout

This clone is expected to sit **next to the resource folders**, so the tools can
find an `fxmanifest.lua` without being told where it is:

```
FiveM/
  fivem-versionchecker/     <- this repo
    _template/
      versionchecker.lua    <- source of every resource's checker (__NAME__ / __CONFIG__)
    tools/
      add-script.ps1        <- onboard a new resource
      new-release.ps1       <- add a release entry + bump fxmanifest.lua
    fx-fishing.json
    ...
  fx-fishing/
  fx-stash/
  ...
```

## Releasing a new version

The `version '...'` line in the resource and the newest entry here have to match.
`tools/new-release.ps1` does both in one step:

```powershell
.\tools\new-release.ps1 -Name fx-stash -Version 1.1.0 `
    -Changelog "Shared stash member limit is now configurable." `
    -UpdateFiles server/members.lua, config.lua, fxmanifest.lua
```

Add `-Critical` for security fixes (red `[CRITICAL]` tag in the server console),
`-ResourcePath` if the resource folder is not a sibling, `-SkipManifest` to touch
only the JSON. Nothing is committed or pushed — review the diff first.

By hand it is the same two edits: bump `version '...'` in the resource's
`fxmanifest.lua`, append an object to that script's JSON file here.

`raw.githubusercontent.com` caches for roughly 5 minutes, so the new entry takes a
few minutes to reach servers.

## Adding a new script

```powershell
.\tools\add-script.ps1 -Name fx-garage -ResourcePath "..\fx-garage" `
    -Description "advanced garage system (QBCore / Qbox / ESX)."
```

That renders `_template/versionchecker.lua` into the resource and creates
`fx-garage.json`. Use `-TargetFile` when the resource has no `server/` folder
(fx-hud uses `s/`, fx-foodpacket uses the root) and `-ConfigFile` when the
VersionCheck flag lives somewhere other than `config.lua`.

`-ConfigVar` matters more than it looks. The checker's kill switch tests the
resource's config global, and most — but not all — resources call it `Config`;
fx-sound calls it `Sound`. Pass the wrong name and the switch tests a nil global,
so `VersionCheck = false` silently does nothing:

```powershell
.\tools\add-script.ps1 -Name fx-sound -ResourcePath "..\fx-sound" -ConfigVar Sound `
    -Description "3D spatial Web Audio engine."
```

The `fxmanifest.lua` and `config.lua` edits stay manual — every resource orders
its `server_scripts` differently, and splicing a line into someone else's load
order automatically is how you break it silently. The script prints the exact
lines to paste.

## Manifests

| Script | Manifest | Checker |
|---|---|---|
| fx-admin | [fx-admin.json](fx-admin.json) | `server/versionchecker.lua` |
| fx-chat | [fx-chat.json](fx-chat.json) | `server/versionchecker.lua` |
| fx-dj | [fx-dj.json](fx-dj.json) | `server/versionchecker.lua` |
| fx-fishing | [fx-fishing.json](fx-fishing.json) | `server/versionchecker.lua` |
| fx-foodpacket | [fx-foodpacket.json](fx-foodpacket.json) | `versionchecker.lua` |
| fx-gameplaycam | [fx-gameplaycam.json](fx-gameplaycam.json) | `server/versionchecker.lua` |
| fx-garages | [fx-garages.json](fx-garages.json) | `server/versionchecker.lua` |
| fx-hud | [fx-hud.json](fx-hud.json) | `s/versionchecker.lua` |
| fx-lbphone-billing | [fx-lbphone-billing.json](fx-lbphone-billing.json) | `server/versionchecker.lua` |
| fx-lbphone-company | [fx-lbphone-company.json](fx-lbphone-company.json) | `server/versionchecker.lua` |
| fx-lbphone-fansapp | [fx-lbphone-fansapp.json](fx-lbphone-fansapp.json) | `server/versionchecker.lua` |
| fx-lbphone-music | [fx-lbphone-music.json](fx-lbphone-music.json) | `server/versionchecker.lua` |
| fx-lbphone-rentalapp | [fx-lbphone-rentalapp.json](fx-lbphone-rentalapp.json) | `server/versionchecker.lua` |
| fx-multicharacter | [fx-multicharacter.json](fx-multicharacter.json) | `server/versionchecker.lua` |
| fx-ownedshops | [fx-ownedshops.json](fx-ownedshops.json) | `server/versionchecker.lua` |
| fx-policebadge | [fx-policebadge.json](fx-policebadge.json) | `server/versionchecker.lua` |
| fx-showroom | [fx-showroom.json](fx-showroom.json) | `server/versionchecker.lua` |
| fx-sound | [fx-sound.json](fx-sound.json) | `server/versionchecker.lua` |
| fx-stash | [fx-stash.json](fx-stash.json) | `server/versionchecker.lua` |
| fx-tattoos | [fx-tattoos.json](fx-tattoos.json) | `server/versionchecker.lua` |
| fx-traders | [fx-traders.json](fx-traders.json) | `server/versionchecker.lua` |
| fx-uwu | [fx-uwu.json](fx-uwu.json) | `server/versionchecker.lua` |
| fx-weapondamage | [fx-weapondamage.json](fx-weapondamage.json) | `server/versionchecker.lua` |
| fx-weed | [fx-weed.json](fx-weed.json) | `server/versionchecker.lua` |
