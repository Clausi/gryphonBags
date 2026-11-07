# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

### Fixed

- Error `ADDON_ACTION_FORBIDDEN` (`PurchaseBankTab`) when opening the bank with a free bank tab: the
  addon no longer taints Blizzard's list of bag frames at login.
