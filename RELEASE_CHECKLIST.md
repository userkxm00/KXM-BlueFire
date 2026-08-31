# KXM BlueFire release checklist

Use this checklist before creating a public GitHub Release.

## Source integrity

- [ ] `VERSION` matches the intended release tag.
- [ ] `KXM_BLUEFIRE.ps1` version matches `VERSION` major/minor.
- [ ] `KXM_CONFIG.ini` version matches `VERSION` major/minor.
- [ ] No development copies of the engine are present.
- [ ] Runtime package contains only files required by end users.

## Safety and recovery

- [ ] Baseline creation succeeds before persistent changes.
- [ ] Baseline file is readable after creation.
- [ ] Restore removes tracked values that were absent before KXM.
- [ ] Restore returns tracked service configuration/state.
- [ ] Restore returns to the original active power plan when available.
- [ ] KXM-created power plan is removed during restore.
- [ ] Restore failure is visible and logged.
- [ ] System Restore availability is reported truthfully.
- [ ] GAME READY can end without leaving its temporary power/session state behind.
- [ ] Undo Last Session handles missing or corrupt session snapshots safely.

## Hardware intelligence

- [ ] Recommendation is based on detected hardware, not a universal preset.
- [ ] HDD and 8 GB-or-less systems keep SysMain automatic.
- [ ] Smaller systems receive scaled-down emulator resource guidance.
- [ ] FPS values are documented as guidance, not guarantees.
- [ ] BlueStacks GPU preference is applied only when BlueStacks is detected.

## Diagnostics

- [ ] Network latency reports actual measurements or a truthful unavailable state.
- [ ] Thermal diagnostics return `UNKNOWN` when Windows exposes no usable reading.
- [ ] Driver diagnostics do not invent provider/version/date values.
- [ ] PresentMon is reported as detected/not detected; no synthetic frame-time data is shown.
- [ ] Pending reboot and tracked-policy drift are reported accurately.

## Telemetry and privacy

- [ ] Community telemetry is OFF by default.
- [ ] Telemetry uses the dedicated module only.
- [ ] No secret or service-role key is shipped to clients.
- [ ] Payload excludes credentials, documents, usernames, MAC addresses, serials, registry dumps, and game account identifiers.
- [ ] Local queueing is bounded and retry-safe.

## Quality gates

- [ ] Windows PowerShell 5.1 parser check passes.
- [ ] PSScriptAnalyzer passes.
- [ ] Launcher-target validation passes.
- [ ] Recommendation regression tests pass.
- [ ] Restore regression tests pass.
- [ ] Release workflow packages the exact tagged source.
- [ ] SHA256 is generated for the release archive.

## Release contents

The release package should contain only:

- `KXM_BLUEFIRE.bat`
- `KXM_BLUEFIRE.ps1`
- `KXM_LANG.json`
- `KXM_TELEMETRY.ps1`
- `KXM_SUPABASE_CONFIG.json`
- `KXM_CONFIG.ini`
- `README.md`
- `LICENSE`
- `RELEASE-MANIFEST.json`

Do not ship development workflows, tests, internal docs, or maintainer-only files in the runtime ZIP.

## Stable-release gate

A green CI run does not equal Stable.

Before a stable release, gather real-device compatibility reports across:

- Intel and AMD CPUs
- integrated and discrete GPUs
- HDD, SSD, and NVMe storage
- multiple RAM tiers
- Windows 10 and Windows 11
- multiple BlueStacks versions/configurations
