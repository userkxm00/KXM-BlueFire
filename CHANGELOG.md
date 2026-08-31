# Changelog

## v26.0 - Recovery hardening / truthful diagnostics

- Implemented RestoreBaseline using the stored baseline snapshot.
- Restores captured registry values, absent values, service startup/state, and the original active power plan.
- Removes the KXM-created Maximum FPS power plan during baseline restore when applicable.
- Added deterministic session snapshots for power state and BlueStacks process priority.
- Improved Undo Last Session to restore the saved session state instead of only the power plan.
- Added an optional Windows System Restore point attempt before persistent changes, with an explicit availability result.
- Replaced the placeholder network-latency screen with real gateway/public ping and jitter diagnostics.
- Kept FPS and frame-time reporting truthful: PresentMon presence is reported, but no synthetic FPS numbers are generated.
- Unified community telemetry through KXM_TELEMETRY.ps1 when the user explicitly opts in.
- Removed the duplicate in-core community telemetry path from the intended flow.
- Added hardware-aware recommendation rules for CPU, RAM, storage, and SysMain behavior.
- Tightened error handling around critical operations while keeping safe fallbacks for optional diagnostics.
- Replaced the diagnostic-button closure pattern with explicit per-button closures to avoid shared-loop state bugs.
- Added Windows PowerShell 5.1 parser validation and PSScriptAnalyzer validation to CI.
- Added regression tests for hardware recommendations and deterministic registry restore behavior.
- Updated the launcher to identify the v26 engine.

## v25.0 - Reliability / Measurement release candidate

- Hardened GAME READY session lifecycle.
- Added Undo Last Session.
- Added thermal telemetry with safe UNKNOWN fallback.
- Added display-driver health inspection.
- Added Windows Update drift and pending-reboot checks.
- Added dynamic Free Fire profile metadata and profile export.
- Added network latency / jitter diagnostics foundation.
- Added benchmark snapshot and PresentMon detection.
- Added conflict/dependency checks.
- Added privacy-first local Community Insights and opt-in evidence events.
- Added issue templates and expanded project documentation.

## v24.0

Previous community release candidate. See Git history for development iterations.
