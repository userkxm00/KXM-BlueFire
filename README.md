# KXM BlueFire

**Hardware-aware gaming performance suite for GGOS / BlueStacks / Free Fire.**

## Current entry point

Run **`KXM_BLUEFIRE.bat`** as Administrator. The launcher now starts the stable **v21 GUI**.

## v21 highlights

- Modern Windows GUI dashboard.
- Hardware detection with HDD/SSD fallback using both `Get-PhysicalDisk` and `Win32_DiskDrive`.
- Smart Free Fire profile targeting **4 CPU cores / 4 GB RAM / High Performance** when the hardware can support it.
- 240 FPS is presented as an **optional ceiling target**, not a guaranteed FPS result.
- **GAME READY** quick mode for daily play: safe temp cleanup, DNS flush, High Performance activation, BlueStacks detection, and session priority.
- Smart Optimize for persistent KXM-owned performance settings.
- Backup / Restore baseline stored outside the portable folder in `C:\ProgramData\KXM\BlueFire\Backups`.
- English / العربية / Français with live language switching and RTL mode for Arabic.
- Benchmark and Verify tools.

## Recovery-first design

Before the first KXM system-changing action, a baseline is created automatically. The baseline captures the KXM-owned settings that it may change, the original SysMain service state, the active power plan, and command snapshots such as BCD and power-plan listings.

Use **RESTORE ORIGINAL** to return those captured pre-KXM settings.

This is not a full Windows image. Personal files are not targeted by the normal optimizer.

## Profiles

### Free Fire
The UI recommendation is:

- 4 CPU cores
- 4 GB RAM target
- High Performance power mode
- 120 FPS recommended starting point
- 240 FPS optional ceiling target

Actual FPS depends on the game build, emulator, GPU, CPU load, thermal state, and display refresh rate.

### Game Ready
Use this immediately before a gaming session. It is intentionally lighter than Smart Optimize and does not apply experimental kernel/GPU tweaks.

## Safety policy

Normal profiles do not disable Defender or Windows Update, disable the pagefile, disable memory compression, force HPET, force MSI mode, modify game files, inject DLLs, or bypass anti-cheat.

Experimental changes should remain opt-in and be benchmarked individually.

## Project structure

- `KXM_BLUEFIRE.bat` — Administrator launcher and syntax gate.
- `KXM_BLUEFIRE_V21_GUI.ps1` — stable GUI engine.
- `KXM_LANG_V21.json` — multilingual UI text.

Older v14-v20 files may remain in the repository as development history; the BAT launcher does not use them.

## License

MIT
