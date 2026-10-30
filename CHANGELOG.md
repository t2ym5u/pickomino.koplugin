# Changelog

All notable changes to this project will be documented in this file.

Reconstructed from this repository's git history: each release lists the
feature and fix commits it carried. Version bumps, screenshot additions
and CI syncs are left out.

## [1.2.0] - 2026-10-30

### Added
- "New game" once the game is over: the action bar shows it in place of
  Roll and Stop, so the next game no longer needs the menu.

### Changed
- Redesigned play screen, in line with the other games: a full-width action
  bar and a board that fills the available room, with one frame hugging it.
  The status line reads "Round: n/m · Sum: n · Score: n" and wraps in
  landscape instead of being cut off.
- The 16 tiles are laid out as two rows of eight instead of one cramped row,
  and each tile shows its worm count as a row of dots under its number.
  Dice, the "Kept" line and the tiles are sized to fit together, with their
  text fitted to the boxes it sits in.
- New README screenshot.

### Fixed
- Tapping a die face that can't be kept showed no explanation: the "Cannot
  keep …" message was overwritten by the regular status straight away.

## [1.1.14] - 2026-10-07

### Fixed
- The Tools menu entry is translated again. `main.lua` took `_` from
  KOReader's `gettext`, which knows nothing of this plugin's strings, so the
  menu label stayed English while the game's own screen, which goes through
  `i18n`, was translated. `_` now comes from `i18n` here too.


## [1.1.13] - 2026-10-01

### Fixed
- Picks up game-common v1.5.0. Play statistics were recorded under a key no
  tool could match: `ReaderUI`/`FileManager:registerModule()` rewrite a plugin
  instance's `name` to `reader<id>` / `filemanager<id>` right after it is
  built, so this game's sessions were split across two rows and neither
  carried its plugin id. Rows written under the old keys are merged back on
  first read. The same release brings the `stopPlugin()` /
  `deletePluginSettings()` hooks KOReader 2026.07 calls when a plugin is
  deleted from the device (PR #15240).

  No change to this plugin's own code -- it inherits all of it from the
  shared library.

## [1.1.12] - 2026-08-05

### Added
- Add ES and DE translations

### Changed
- Add issue/PR templates and CONTRIBUTING.md

## [1.1.11] - 2026-08-04

### Changed
- Symlink common/ to shared game-common

## [1.1.9] - 2026-07-29

### Fixed
- Drop deprecated name field from _meta.lua

## [1.1.6] - 2026-07-28

### Changed
- Add GPL-3.0 LICENSE

## [1.1.3] - 2026-07-21

### Added
- Own translations locally instead of via game-common

## [1.1.1] - 2026-07-15

### Added
- Adopt TitleBar header, sync common/ with game-common

### Changed
- Remove ../game-common/ fallback from package.path

## [1.1.0] - 2026-07-08

### Added
- I18n FR/EN translation + bump to 1.1.0

## [1.0.1] - 2026-07-07

### Changed
- Remove redundant variable alignment in buildLayout
