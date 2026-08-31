# KXM BlueFire v25

**Hardware-aware Windows gaming performance platform for BlueStacks / Free Fire.**

> Detect -> Protect -> Recommend -> Preview -> Apply -> Measure -> Learn -> Restore

## Repositories

This is the **public Windows client** repository.

The companion website, private admin dashboard, community analytics and privileged server-side integration live separately in **KXM-BlueFire-Web-**.

## v25 highlights

- **Session Undo**: GAME READY saves the previous power state and supports `UNDO LAST SESSION`.
- **Thermal Guard**: reads available Windows ACPI thermal telemetry and returns `SAFE`, `WARNING`, `THROTTLING RISK`, or `UNKNOWN`.
- **Driver Health**: reads display-driver provider, version and date.
- **Windows Update Resilience**: checks important KXM values for drift and reports pending reboot state.
- **Dynamic Free Fire profile**: hardware-aware 4-core / 4-GB baseline with safe downscaling on smaller systems.
- **120 FPS recommended / 240 FPS ceiling**: configuration targets, not guarantees of rendered FPS.
- **Network diagnostics**: gateway/public endpoint latency and jitter tools.
- **Frame-time preparation**: detects PresentMon when available and keeps measurement provenance explicit.
- **Conflict checks**: Discord / RTSS / Hyper-V style conflicts are surfaced before sensitive work.
- **Profile export**: portable JSON profile snapshots.
- **Community Insights**: opt-in, privacy-first, coarse hardware classes + operation outcomes.
- **Arabic RTL**, English and French UI.

## Free Fire policy

When hardware can support it, KXM recommends **4 CPU cores + 4 GB RAM** for the emulator and **High Performance** power policy. On smaller systems it scales down rather than forcing the same values everywhere.

For HDD or systems with 8 GB RAM or less, KXM keeps **SysMain AUTO**.

## Safety

KXM's safe path does not intentionally:
- disable Defender;
- disable Windows Update;
- disable the pagefile;
- force HPET;
- force MSI mode blindly;
- remove Edge/WebView2;
- modify game files;
- inject DLLs or bypass anti-cheat;
- purge large groups of Windows services.

Experimental changes must remain explicitly gated and benchmarked.

## Recovery

Persistent configuration changes use a baseline outside the portable folder:

`C:\ProgramData\KXM\BlueFire\Backups\YYYYMMDD_HHMMSS`

GAME READY session state is stored under:

`C:\ProgramData\KXM\BlueFire\Sessions`

This is configuration recovery, **not** a full disk image.

## Community data

Community sharing is **OFF by default**. Only coarse hardware classes and operation outcomes are intended to be collected. The public client contains no privileged Supabase secret. Online sending is mediated by the project backend.

## Compatibility

- Windows 10 / Windows 11
- Windows PowerShell 5.1
- Administrator rights for system-changing functions
- BlueStacks optional

## Status

**v25.0 — Reliability / Measurement release candidate**

Stable release requires real-device compatibility reports across Intel / AMD / NVIDIA, HDD / SSD / NVMe and multiple RAM tiers.
