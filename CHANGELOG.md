# Changelog

All notable changes to this project will be documented in this file.

## [1.0.1] - 2026-04-25

### Added
- Home screen filtering and sorting controls for faster event discovery.
- A dedicated filtered events provider to keep search, category, and sorting state centralized.
- Expanded event card presentation with grid support and adaptive density behavior.

### Changed
- Moved signed-in cloud restore into the home experience to keep app startup lighter while preserving local visibility.
- Requested notification permissions after first frame during startup-related flows to reduce critical-path work.
- Updated Android configuration for `compileSdk 35`, `targetSdk 34`, and back-invoked callback support.

### Improved
- Polished the events board and card layouts for a cleaner, more flexible browsing experience.
- Reduced startup overhead and release readiness friction for modern Android builds.

