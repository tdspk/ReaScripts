# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

# Yet Another Color Picker

## [Unreleased]

### Added

- Added coloring of markers and regions
- Added coloring of takes if there are more than 1 takes per item
- Added color picker (accessible via RMB)
- Added button to reset colors to default (REAPER Color Theme)
- Added button to assign random colors to palette
- Added slider to adjust button count from 1 to 16
- Added setting to auto-save colors to SWS color palette
- Added setting to display rounded buttons
- Added shortcut to apply random colors on selection (Ctrl+Alt+Click)

### Changed

- Changed default background color to REAPER Theme background color
- Changed descriptions in manual
- Changed access to settings with RMB on window
- Changed "Reset settings" to "Reset UI settings" for clarification

### Fixed

- Fixed issue where colors were not updated correctly

## [1.1]

### Added

- Added debug setting to show which action will be applied
- Auto-focus window on open and hover

### Fixed

- Window does not close when docked now

## [1.0.1]

### Added

- Added Left Alt Modifier to reset to default color

### Changed

- A simple mouse click now closes the window
- Shift now applies a color without closing the window

### Removed

- Settings: removed close-on-click checkbox (use modifiers instead!)

## [1.0]

### Added

- 16 colors based on SWS custom color settings
- Settings (accessible via right-click) for button size, padding and more
