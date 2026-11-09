# GryphonBags

World of Warcraft addon that extends the default bags with additional options.

**Load the `wow-lua` skill (`.claude/skills/wow-lua/`) before working on code.** It holds the rules
shared by all WoW addons (luacheck, locales, addon structure, Blizzard UI, secret values, names,
compatibility, changelog). The git workflow and commit messages are in the global `CLAUDE.md`. This
file only adds what is specific to GryphonBags.

## Target clients

- **Forever** only (`## Interface: 16001`, `forever` branch of wow-ui-source), so there are no client
  checks. `Core/Compat.lua` only holds `HasRealmNames()` for `Core/Names.lua`. Retail may follow later:
  extend `Core/Compat.lua` then (structure from GryphonMail), with `120105` in the `.toc`. Forever
  differs from Retail in many places.
- Bag code on Forever: `Blizzard_UIPanels_Game/Mainline/ContainerFrame.lua` and `.xml`, plus the
  small overrides in `Blizzard_UIPanels_Game/Camelot/ContainerFrame.lua`. Bag buttons:
  `Blizzard_MainMenuBarBagButtons/` (`Shared/`, `Camelot/`). The `Camelot` folders only exist on the
  `forever` branch, so a checkout of `live` does not show them.
- `Core/Names.lua` is the one from GryphonMail, unchanged. `Modules/Characters.lua` is a reduced
  copy of GryphonMail's (no mail targets, plus the gold of each character).

## Locales

`enUS` (base), `deDE`, `frFR`.

## Saved variables

`GryphonBagsDB` (account-wide) and `GryphonBagsCharDB` (per character).

## Reserved slots

`C_Container.SortBags()` takes no arguments and only has per-bag exclusions. With an item locked by
`C_Item.LockItem` before or right after the call, nothing gets sorted at all on Forever (seen
in-game), not only the locked item stays in place. So `Modules/ReservedSlots.lua` lets the sort run
and then moves the content of the reserved slots back.

## Commit scopes

`reserved-slots`, `sort`, `characters`, `gold-tooltip`, `options`, `core`, `locales`, `toc`.
