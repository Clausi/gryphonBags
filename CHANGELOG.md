# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Gold tooltip: the options choose the order of the characters (most gold first, least gold first
  or by name), for each character.

### Fixed

- Reserved bag slots: an empty bag that was put back out of a reserved slot no longer goes into a
  profession bag that holds what the bag holds (e.g. a spare Herb Pouch into a Herb Pouch).

## [0.1.0] - 2026-11-07

### Added

- Addon skeleton for WoW Forever (Interface 16001): namespace, module registry, event dispatcher,
  saved variables (`GryphonBagsDB`, `GryphonBagsCharDB`) and `/gryphonbags` slash command.
- Localization with English base locale, German and French translation.
- Options page in the game settings (Esc > Options > AddOns > GryphonBags) for the automatic
  messages, also opened with `/gryphonbags options`.
- Reserved bag slots: Alt-right-click a slot to mark it with a lock. After "Clean Up Bags", the
  slot gets its item back, and a reserved empty slot is empty again. Stored per character.
  `/gryphonbags reserved` shows the number of reserved slots, `/gryphonbags reserved clear` frees
  them all.
- Progress bar over the bag search box while "Clean Up Bags" runs with reserved slots: first the
  sort, then the slots that are put back.
- Gold tooltip: hovering over the gold display of the bags shows the gold of the known characters
  of the same ruleset and faction, and the sum. Hold Shift to see all characters. Can be turned off
  in the options, for each character.
- Known characters: recorded with their gold on login. `/gryphonbags chars` lists them,
  `/gryphonbags chars remove <number|name>` or the options forget one.

### Fixed

- Error `ADDON_ACTION_FORBIDDEN` (`PurchaseBankTab`) when opening the bank with a free bank tab: the
  addon no longer taints Blizzard's list of bag frames at login.

[Unreleased]: https://github.com/Clausi/gryphonBags/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/Clausi/gryphonBags/releases/tag/v0.1.0
