# KXM BlueFire v1.0.0 RC1

**Hardware-aware Windows gaming performance platform for BlueStacks / Free Fire.**

> Detect -> Protect -> Recommend -> Preview -> Apply -> Measure -> Learn -> Restore

## Repositories

This repository is the **public Windows client** for KXM BlueFire.

- **Client:** `userkxm00/KXM-BlueFire`
- **Web / Admin / Backend:** `userkxm00/KXM-BlueFire-Web-` (private)
- **Project website:** served from the private web repository via Vercel

The public client contains no privileged Supabase secret and no private dashboard/server implementation.

## v1.0.0 RC1 highlights

- **Recovery-first baseline**: persistent changes use a baseline snapshot stored under `C:\ProgramData\KXM\BlueFire\Backups\` before changes.
- **Restore Original**: restores captured registry values, removes values that were absent before KXM, restores captured service state, and returns to the original power plan when it still exists.
- **Session Undo**: GAME READY stores session power and BlueStacks process-priority state and can restore it.
- **Hardware-aware recommendations**: CPU, RAM, storage, and SysMain policy are evaluated before a profile is proposed.
- **Thermal Guard**: reads available Windows ACPI thermal telemetry and returns `SAFE`, `WARNING`, `THROTTLING RISK`, or `UNKNOWN` without inventing readings.
- **Driver Health**: reads display-driver provider, version and date.
- **Windows Update Resilience**: reports pending reboot state and drift in tracked KXM policy values.
- **Network diagnostics**: gateway and public endpoint latency plus jitter measurements.
- **Frame-time preparation**: detects PresentMon when available and never invents FPS or frame-time results.
- **Profile export**: portable JSON profile snapshots.
- **Community telemetry**: OFF by default, coarse and privacy-first, with a local queue and explicit opt-in.
- **English / Arabic / French** UI with Arabic RTL.

## Engine build

The public product version is **v1.0.0-rc.1**. The internal engine build lineage remains **26.0** for development traceability.

## Recommendation model

KXM does **not** force one BlueStacks allocation onto every machine.

The safe recommendation model scales with detected CPU cores and physical RAM, then considers storage class for the profile tier. For HDD systems or systems with 8 GB RAM or less, KXM keeps **SysMain AUTO**.

The default guidance is a target, not a promise of rendered FPS:

- **120 FPS target** for supported profiles.
- **240 FPS ceiling** as an optional emulator setting where the game/emulator/display actually supports it.

## Safety boundary

KXM's normal path does not intentionally:

- disable Defender;
- disable Windows Update;
- disable the pagefile;
- force HPET;
- force blind MSI mode;
- remove Edge/WebView2;
- modify game files;
- inject DLLs or bypass anti-cheat;
- purge large groups of Windows services.

Experimental changes must remain explicitly gated, previewed, benchmarked, and reversible.

## Recovery model

The baseline is **targeted configuration recovery**, not a complete disk image.

Before persistent changes, KXM captures the settings it owns, including tracked Registry values, the current active power plan, and tracked service state.

The current baseline pointer is stored at:

`C:\ProgramData\KXM\BlueFire\CURRENT_BASELINE.txt`

Baseline snapshots are stored under:

`C:\ProgramData\KXM\BlueFire\Backups\YYYYMMDD_HHMMSS`

Session snapshots are stored under:

`C:\ProgramData\KXM\BlueFire\Sessions`

A Windows System Restore point may also be attempted when supported. Its availability is reported; it is not treated as a replacement for KXM's own targeted baseline.

## Community data

Community sharing is **OFF by default**.

The telemetry module is designed to use coarse hardware classes and operation outcomes. It excludes names, usernames, passwords, tokens, documents, game account IDs, serial numbers, MAC addresses, registry dumps, file contents, and secret keys.

Online delivery is mediated by the private project backend.

## Validation

GitHub Actions validates the PowerShell project on Windows with:

- Windows PowerShell 5.1 parser validation;
- PSScriptAnalyzer;
- launcher-target validation;
- hardware recommendation regression tests;
- deterministic Registry restore regression coverage.

A release is not considered stable solely because CI is green. Real-device compatibility testing is required.

## Compatibility

- Windows 10 / Windows 11
- Windows PowerShell 5.1
- Administrator rights for system-changing functions
- BlueStacks optional

## Release status

**v1.0.0-rc.1 — Release Candidate**

This is the first public KXM version line. It is intended for compatibility testing and controlled feedback, not as a claim that every Windows configuration is supported.

Before `v1.0.0` stable, validate real devices across:

- Intel / AMD CPUs
- integrated / discrete graphics
- HDD / SSD / NVMe
- multiple RAM tiers
- Windows 10 / Windows 11
- BlueStacks versions and configurations

See `CHANGELOG.md`, `TROUBLESHOOTING.md`, `SECURITY.md`, and `SUPABASE_SETUP.md` for additional details.
