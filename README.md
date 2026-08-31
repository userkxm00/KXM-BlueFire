# KXM BlueFire

Hardware-aware Windows gaming optimizer for GGOS, BlueStacks and Free Fire.

> **Recovery-first:** KXM is designed to capture the pre-change settings it owns before applying optimizations, so the user can restore them later.

## Current release

**v12.0**

## What KXM does

- Hardware audit: CPU, threads, RAM, GPU, virtualization and storage type.
- Smart recommendations based on detected hardware.
- Recommended and Competitive performance profiles.
- BlueStacks-focused tuning.
- Network, storage and background optimization modules.
- Benchmark and verification tools.
- Experimental lab kept separate from normal profiles.
- English / العربية / Français UI.
- PowerShell 5.1-compatible engine with a syntax gate in the BAT launcher.

## Recovery / backup

Before the first system-changing action, KXM creates a baseline under:

`C:\ProgramData\KXM\BlueFire\Backups\YYYYMMDD_HHMMSS`

The portable KXM folder is not the only copy. The baseline is stored in Windows ProgramData so deleting or moving the portable app does not remove the recovery data.

The baseline records the KXM-owned registry values it may change, selected service state/start mode, selected TCP values, BlueStacks GPU preference when detected, the active power scheme, a BCD export, and an attempted Windows restore point.

Use **R — Restore** to restore the captured pre-KXM state.

> This is not a complete Windows disk image. It restores the settings captured by KXM before its changes. Personal files are not targeted by normal profiles.

## Recommended workflow

1. Run `KXM_BLUEFIRE.bat` as Administrator.
2. Run Self-Test.
3. Run Hardware Audit.
4. Read the Smart Recommendation.
5. Apply Recommended Profile or Competitive Profile.
6. Reboot.
7. Benchmark and Verify.
8. Use Restore if you want to undo KXM changes.

## Compatibility

Designed for Windows PowerShell 5.1 syntax. The launcher performs a PowerShell parser check before execution.

The BAT launcher is ASCII-compatible. The PowerShell engine is UTF-8 for multilingual UI.

## Safety policy

Normal profiles intentionally avoid:

- disabling Windows Defender or Windows Update;
- disabling the Windows pagefile;
- disabling memory compression;
- forced MSI mode hacks;
- forced HPET/platform-clock hacks;
- game-file modification;
- DLL injection or anti-cheat bypass.

Experimental options remain opt-in and should be benchmarked one at a time.

## License

MIT
