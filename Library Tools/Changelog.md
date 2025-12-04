# ReaSoundly Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.1]

### Fixed

- Fix crash when navigating targets with buttons

## [1.3]

### Added

- Startup: improve missing package behaviour, search automatically for ReaImGui and JS_ReaScript API when dependencies are missing

### Changed

- Used new ImGui font API
- Changed font to default font provided by ReaImGui
- Changed default font size to 12
- Moved menu to menu bar
- Set default window height to 680px
- Settings: remove start prompt for font size change
- Use Project State Count instead of poll interval for gui updates

### Removed

- Removed dock button

## [1.2.5]

### Fixed

- Fixed bug caused by new ImGui Font API

## [1.2.4]

### Added

- Add button to copy generated UCS names to clipboard
- Introduce setting to ignore the Media Explorer while renaming

## [1.2.3]

### Added

- Refresh Media Explorer after renaming files

## [1.2.2]

### Added

- Save FX name when closing UCS Toolkit
- Introduce action to focus UCS Toolkit window and target search box

## [1.2.]

### Added

- Show UCS explanations and synonmys as tooltip in search box

## [1.1]

### Fixed

- Fixed typo in window title

## [1.0]

### Added

- Initial Release