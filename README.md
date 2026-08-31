# KXM BlueFire

Hardware-aware Windows gaming optimizer for GGOS / BlueStacks / Free Fire.

## Current generation

The launcher targets the v23 GUI engine.

### Added in v23

- **GAME READY session mode**: creates/uses the recovery baseline, cleans temporary directories, flushes DNS, switches to High Performance, and prepares a running BlueStacks process.
- **Session restore**: the original power plan is stored for the gaming session and restored when the session ends or the GUI closes.
- **Hardware-aware storage detection**: uses PhysicalDisk first and Win32_DiskDrive as a fallback so older HDD systems are not misclassified.
- **Free Fire profiles**: 4 CPU cores + 4 GB RAM + High Performance as the default BlueStacks target; 120 FPS is the recommended target and 240 FPS is treated only as an optional ceiling.
- **Conflict checks**: detects common background/virtualization tools such as Discord, RTSS, Hyper-V and Docker.
- **Before/after benchmark snapshots**: stores system snapshots for comparison. It does not invent FPS results; actual in-game FPS remains a user measurement.
- **Reboot status**: checks common Windows pending-reboot locations.
- **Live system panel**: CPU load, RAM use, BlueStacks state and hardware/storage status.
- **Recovery baseline**: stored outside the portable app under `C:\ProgramData\KXM\BlueFire\Backups`.
- **Restore**: restores the KXM-managed settings captured before the first modification.
- **Experimental options remain opt-in** and are kept separate from the normal gaming path.

## Safety policy

Normal profiles do not disable Defender or Windows Update, disable the Windows pagefile, disable memory compression, inject DLLs, modify game files, or bypass anti-cheat.

## Compatibility

Designed for Windows PowerShell 5.1 and Windows Forms. The repository includes a Windows CI workflow that parses every PowerShell file with Windows PowerShell 5.1 so syntax regressions are caught before release.

## Usage

Run `KXM_BLUEFIRE.bat` as Administrator. Start with the Hardware Audit, then use the Smart Optimize or GAME READY actions.
