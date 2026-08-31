# KXM BlueFire Architecture

KXM is designed as a recovery-first, hardware-aware optimization framework.

## Execution flow

```text
Launch
  |
  v
Privilege + environment checks
  |
  v
Hardware detection
  |
  +--> CPU / RAM / GPU / storage / virtualization
  |
  v
Compatibility + conflict checks
  |
  v
Recommendation engine
  |
  +--> Safe / Recommended
  +--> Competitive
  +--> Experimental (explicit opt-in)
  |
  v
Dry-run preview
  |
  v
Recovery baseline / session snapshot
  |
  v
Apply selected changes
  |
  v
Verification + pending-reboot detection
  |
  v
Benchmark / community result (opt-in)
  |
  +--> Keep
  +--> Restore
```

## Detection layer

Detection must prefer stable Windows APIs and have fallbacks. Storage classification, for example, should try modern disk information and fall back to `Win32_DiskDrive` on older systems.

## Recommendation layer

Recommendations are derived from hardware and environment instead of being universal constants. Low-memory/HDD systems should avoid aggressive cache/service changes. GPU-specific features should only be recommended when the hardware supports them and evidence justifies them.

## Recovery layer

The baseline is stored under `C:\ProgramData\KXM\BlueFire\Backups` and is separate from the portable application directory. A baseline records only the configuration areas KXM owns or changes; it is not a complete Windows image.

Session state is separate from the permanent baseline. Temporary game-session changes should be reversible when the session ends.

## Optimization modules

- Power plan
- Game Mode / capture policy
- MMCSS / scheduler policy
- BlueStacks process/profile handling
- Network diagnostics and selected TCP/NIC settings
- Storage / memory policy
- Background controls
- Cleanup
- Experimental lab

Every module should expose what it intends to change and should be verifiable after execution.

## Community evidence layer

Anonymous telemetry is opt-in and should contain only sanitized, non-identifying hardware/profile/result data. Raw device identity, personal files, credentials, IP addresses and account information are out of scope.

Community data must improve recommendation confidence; it must never silently turn on an unsafe tweak.
