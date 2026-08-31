# KXM BlueFire

Hardware-aware Windows gaming optimizer for GGOS, BlueStacks and Free Fire.

> **Recovery-first:** KXM creates a durable baseline of the settings it owns before the first system-changing action.

## Current release

**v13.0**

## What KXM does

- Read-only Self-Test.
- Hardware Audit: CPU, threads, RAM, GPU, virtualization and HDD/SSD detection.
- Smart recommendations before optimization.
- Recommended and Competitive gaming profiles.
- BlueStacks-focused tuning.
- Network, storage and background modules.
- Benchmark and verification tools.
- Experimental lab kept separate from normal profiles.
- English / العربية / Français UI.
- Windows PowerShell 5.1-compatible engine.
- BAT parser gate before the engine starts.

## Recovery / backup

Before the first system-changing action, KXM creates a baseline under:

`C:\ProgramData\KXM\BlueFire\Backups\YYYYMMDD_HHMMSS`

The baseline is stored outside the portable KXM folder so moving or deleting the app folder does not remove the normal recovery copy.

The baseline records KXM-owned registry values, selected service startup/state, selected TCP values, the BlueStacks GPU preference when detected, the active power scheme, a BCD export, and an attempted Windows restore point.

Use **R — Restore** to restore the captured pre-KXM state.

> This is not a full Windows system image. It restores the settings captured by KXM before its own changes. Personal files are not targeted by normal profiles.

## Recommended workflow

1. Run `KXM_BLUEFIRE.bat` as Administrator.
2. Run Self-Test.
3. Run Hardware Audit.
4. Read the Smart Recommendation.
5. Apply Recommended or Competitive Profile.
6. Reboot.
7. Benchmark and Verify.
8. Use Restore when you want to undo KXM changes.

## Compatibility

The launcher validates the engine with the Windows PowerShell parser before execution. The BAT remains ASCII-compatible; the PowerShell engine is UTF-8.

## Safety policy

Normal profiles do not disable Defender or Windows Update, disable the pagefile, disable memory compression, force MSI mode, force HPET/platform-clock hacks, modify game files, inject DLLs, or bypass anti-cheat.

Experimental options remain opt-in and should be benchmarked one at a time.

## License

MIT
