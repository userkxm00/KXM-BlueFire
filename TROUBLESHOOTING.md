# KXM BlueFire Troubleshooting

## KXM does not start

Run `KXM_BLUEFIRE.bat` as Administrator. Do not launch an older script copied from an earlier release.

If Windows PowerShell blocks execution, the launcher uses a process-local `ExecutionPolicy Bypass`; it does not change the machine's permanent execution-policy setting.

## BlueStacks is not detected

KXM checks common BlueStacks executable locations. If your installation is elsewhere, record the exact `HD-Player.exe` path in a compatibility report.

Also verify that BlueStacks is installed and that the process name has not changed in your build.

## Storage is shown as Unknown

KXM tries modern physical-disk information first and then a `Win32_DiskDrive` fallback. Some firmware/controller combinations can still report unknown media type. Do not force an HDD/SSD classification manually without evidence.

## Arabic UI problem

The GUI uses native WinForms Unicode controls. If Arabic still renders incorrectly, report the Windows build, system display language and a screenshot. Do not change registry code pages as a workaround unless instructed by a maintainer.

## Restore did not return a setting

Open KXM's Recovery/Backup Center and check whether a valid baseline exists under:

`C:\ProgramData\KXM\BlueFire\Backups`

KXM restores only the configuration areas it captured and manages. It is not a full Windows image restore.

## GAME READY session

GAME READY is intended for session preparation. Close or end the session using the KXM session control so session-only state can be restored. Permanent profiles and experimental changes are separate.

## Performance result is unchanged

That is a valid result. Disable assumptions that every tweak must increase FPS. Run the same in-game test path before and after, record frame-time/FPS, and compare.

## Collecting diagnostics

Useful information for a report:

- Windows version/build
- CPU / RAM / GPU
- HDD / SSD / NVMe
- BlueStacks version
- KXM profile
- whether a reboot was performed
- `C:\ProgramData\KXM\BlueFire\Logs\KXM.log`

Remove personal information and credentials before sharing logs.
