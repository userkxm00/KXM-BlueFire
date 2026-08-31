# KXM BlueFire

**Hardware-aware Windows gaming optimizer for GGOS / BlueStacks / Free Fire.**

## Official release

**v24 — Community Release candidate**

The repository intentionally keeps **one public engine** on `main` so users do not accidentally launch an obsolete development build.

### Main features

- **GAME READY session mode**: prepares a gaming session with safe cleanup, DNS refresh, High Performance power plan and BlueStacks process preparation.
- **Session restore**: returns session-only settings such as the previous power plan when the session ends.
- **Hardware-aware detection**: CPU, RAM, GPU, virtualization and HDD/SSD detection with fallback logic for older systems.
- **Free Fire profile**: 4 CPU cores + 4 GB RAM + High Performance as the default BlueStacks target; 120 FPS is the recommended target and 240 FPS is only an optional ceiling, not a guarantee.
- **Conflict detection**: checks for common software/virtualization conditions that may affect aggressive tuning.
- **Before/after snapshots**: records measurable system state without inventing FPS results.
- **Pending reboot detection**: flags Windows states that commonly require a restart.
- **Recovery baseline**: stored outside the portable app under `C:\ProgramData\KXM\BlueFire\Backups`.
- **Restore**: restores KXM-managed settings captured before its first modification.
- **Experimental Lab**: advanced settings remain separate and opt-in.
- **Multilingual UI**: English / العربية / Français.

## Safety policy

Normal KXM profiles do not disable Defender or Windows Update, disable the Windows pagefile, disable memory compression, inject DLLs, modify game files, or bypass anti-cheat protections.

## Compatibility

The GUI targets Windows PowerShell 5.1 and Windows Forms. The repository includes a Windows CI workflow that parses PowerShell with Windows PowerShell 5.1 so syntax regressions can be caught before release.

## Usage

1. Download/clone the repository.
2. Run `KXM_BLUEFIRE.bat` as Administrator.
3. Use **Hardware Audit** first.
4. Use **Smart Optimize** for a persistent profile or **GAME READY** for a quick gaming session.
5. Use **Restore Original** when you want to return KXM-managed settings to the captured pre-KXM state.

## Repository policy

Development builds are not kept in the root of `main`. Historical development work belongs in Git history, branches or Releases—not in the main user-facing download path.
