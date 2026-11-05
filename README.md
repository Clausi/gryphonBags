# GryphonBags

A World of Warcraft addon that extends the default bags with additional options.

## Features

- **Options:** automatic messages, on an own page in the game options
  (Esc > Options > AddOns > GryphonBags).

## Supported clients

| Client  | Interface | Status    |
| ------- | --------- | --------- |
| Forever | 16001     | Supported |

## Installation

Copy (or symlink) the `GryphonBags` folder into the client's AddOns folder:

```
World of Warcraft\_forever_\Interface\AddOns\GryphonBags
```

## Releasing

1. Move the `[Unreleased]` entries in `CHANGELOG.md` to a new version section and bump
   `## Version` in `GryphonBags.toc`, then merge that into `main`.
2. Tag the merge commit on `main` and push the tag:

   ```
   git tag v0.1.0
   git push origin v0.1.0
   ```

3. The `Release` workflow runs luacheck, builds the package with the
   [BigWigs packager](https://github.com/BigWigsMods/packager) and uploads it as a GitHub release.
   CurseForge, Wago Addons and WoWInterface are added with `X-Curse-Project-ID`, `X-Wago-ID` and
   `X-WoWI-ID` in the TOC and the repository secrets `CF_API_KEY`, `WAGO_API_TOKEN` and
   `WOWI_API_TOKEN`.

## Structure

```
GryphonBags/
├── .github/workflows/
│   ├── luacheck.yml       # luacheck on pushes to main and on pull requests
│   └── release.yml        # Builds and uploads a release on version tags (BigWigs packager)
├── .pkgmeta               # Packager config: changelog and files left out of the package
├── GryphonBags.toc        # Addon manifest, defines load order
├── LICENSE                # MIT license
├── Locales/
│   ├── enUS.lua           # Base locale (fallback, all keys)
│   ├── deDE.lua           # German translation
│   └── frFR.lua           # French translation
├── Core/
│   ├── Init.lua           # Namespace, module registry, event dispatcher
│   ├── Util.lua           # Print/Debug helpers, debug memory output, defaults
│   └── Main.lua           # Bootstrap: saved variables, module lifecycle, slash commands
└── Modules/
    └── Options.lua        # Options page in the game settings ("/gryphonbags options")
```

## Adding a module

1. Create `Modules/MyModule.lua`:

   ```lua
   local _, ns = ...
   local MyModule = ns:RegisterModule("MyModule")

   function MyModule:OnInitialize() end -- saved variables available
   function MyModule:OnEnable() end     -- PLAYER_LOGIN
   ```

2. Add it to `GryphonBags.toc` above `Core\Main.lua`.

## Localization

All strings live in `Locales/`. Add new keys to `enUS.lua` first; other locales
only override what they translate. Missing keys fall back to English.

## Development

Lint with [luacheck](https://github.com/lunarmodules/luacheck). Place `luacheck.exe` in `.tools/`
(ignored by git) and run from the repo root:

```
./.tools/luacheck.exe .
```

## Slash commands

- `/gryphonbags` – help
- `/gryphonbags version` – show version
- `/gryphonbags options` – open the options page
- `/gryphonbags notify on|off` – automatic messages of the current character, default on
- `/gryphonbags debug` – toggle debug output (after a `/reload`, also the memory each module keeps)

Modules add subcommands with `ns:RegisterCommand(name, handler, helpLines)`.

## License

[MIT](LICENSE)
