# KXM BlueFire

Hardware-aware Windows gaming optimizer for GGOS / BlueStacks / Free Fire.

## v24 — Official Community Release Candidate

The `main` branch intentionally contains one user-facing engine only: **KXM BlueFire v24**.

### Core features

- Hardware-aware CPU / RAM / GPU / HDD / SSD detection.
- Free Fire profile guidance: 4 CPU cores + 4 GB RAM, High Performance power, 120 FPS recommended; 240 FPS is an optional ceiling, not a performance guarantee.
- GAME READY session mode for pre-game cleanup and session performance settings.
- Recovery-first baseline stored outside the portable application under `C:\ProgramData\KXM\BlueFire\Backups`.
- Restore of KXM-managed settings captured before modification.
- Verified KXM Maximum FPS power-plan workflow.
- Ping / jitter testing.
- Conflict and dependency checks.
- Pending-reboot detection.
- Before / after system snapshots without inventing FPS results.
- Experimental options kept separate from the normal gaming path.
- English / Arabic / French UI support.

## Safety policy

KXM does not make aggressive system removals part of the normal profile. It does not intentionally disable Defender or Windows Update, disable the Windows pagefile, force HPET, blindly force MSI mode, inject DLLs, modify game files, or bypass anti-cheat.

## Usage

Run `KXM_BLUEFIRE.bat` as Administrator. Start with the hardware audit, review the recommendation, and create/verify a recovery baseline before system-changing profiles.

Use **GAME READY** for the lightweight pre-game session workflow.

## Repository policy

Old development engine files are intentionally removed from the public working tree. They remain available through Git history if needed for development archaeology.

The repository includes a Windows CI workflow that checks PowerShell syntax so broken parser builds do not become release candidates.
