# Changelog

## v26.0-rc.1 - Recovery hardening and truthful diagnostics

### Recovery

- Implemented `RestoreBaseline` using the stored baseline snapshot.
- Restores captured Registry values and removes tracked values that were absent before KXM.
- Restores tracked service startup mode and running state.
- Restores the original active power plan when it still exists.
- Removes the KXM-created Maximum FPS power plan during baseline restore when applicable.
- Writes an explicit restore result to the baseline directory.
- Added an optional Windows System Restore point attempt before persistent changes, with an explicit availability result.

### Session safety

- Added deterministic GAME READY session snapshots.
- Stores the original active power plan and BlueStacks process priority when available.
- `UNDO LAST SESSION` restores the stored session state.
- Session cleanup remains limited to temporary files and DNS cache flushing.

### Hardware intelligence

- Recommendations now use CPU cores, logical processors, physical RAM, and storage class.
- SysMain remains `KEEP AUTO` for HDD systems and systems with 8 GB RAM or less.
- BlueStacks CPU/RAM guidance scales down on smaller systems instead of forcing a fixed allocation.
- 120 FPS is treated as guidance and 240 FPS as an optional ceiling, never as a rendered-FPS guarantee.

### Diagnostics

- Thermal Guard reports available ACPI thermal telemetry or `UNKNOWN` without fabricating readings.
- Driver Health reports display-driver provider, version, and date where available.
- Windows Update resilience reports pending reboot state and tracked configuration drift.
- Network diagnostics perform gateway/public endpoint ping samples and report average, minimum, maximum, and jitter.
- PresentMon is detected when available; KXM does not invent frame-time or FPS data.
- Conflict checks cover common Discord, RTSS, and Hyper-V style conflicts.

### Community telemetry

- Unified the intended telemetry path through `KXM_TELEMETRY.ps1`.
- Community sharing remains OFF by default and requires explicit opt-in.
- Telemetry uses coarse hardware classes and operation outcomes only.
- Local queueing and retry behavior are retained for transient connectivity failures.

### Quality

- Added Windows PowerShell 5.1 syntax validation in GitHub Actions.
- Added PSScriptAnalyzer validation.
- Added launcher-target validation.
- Added regression tests for hardware recommendation rules and deterministic Registry restore behavior.
- Replaced shared loop-state diagnostics handlers with explicit closures.
- Hardened critical error handling and logging.

## v25.0

Previous reliability and measurement release candidate. Superseded by v26.0-rc.1.

## v24.0

Previous community release candidate. See Git history for development iterations.
