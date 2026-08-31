# KXM Community Telemetry

KXM may collect **optional, anonymous diagnostic and outcome data** to improve hardware-aware recommendations.

## Privacy model

- Opt-in only; disabled by default.
- No account, name, Windows username, document contents, browser history, passwords, tokens, game-account data, or uploaded files.
- Avoid collecting raw IP addresses. The server should use standard transport logs only as needed for abuse prevention and delete them quickly.
- Hardware identity is represented as coarse categories where possible (CPU vendor/family, RAM tier, GPU vendor/tier, storage class).
- The client must show the payload categories before enabling sharing.

## Versioned event schema

Each event includes a schema version and KXM version so future changes remain backward compatible.

```json
{
  "schema": 1,
  "kx_version": "24.0",
  "event": "optimization_result",
  "hardware": {
    "cpu_vendor": "Intel",
    "cpu_family": "Ivy Bridge",
    "logical_processors": 4,
    "ram_tier_gb": 8,
    "gpu_vendor": "Intel",
    "gpu_tier": "integrated",
    "storage_class": "HDD",
    "windows_build": "19042"
  },
  "target": {
    "emulator": "BlueStacks",
    "game": "Free Fire",
    "profile": "recommended"
  },
  "changes": [
    {"id":"power_high_performance","result":"success"}
  ],
  "result": {
    "success": true,
    "reboot_required": false,
    "restored": false
  }
}
```

## What KXM should learn

Aggregate results may be used to classify a change as:

- `recommended`
- `optional`
- `neutral`
- `avoid`

The recommendation engine must not promote a tweak solely from popularity. Minimum sample counts, success rate, and negative/revert rate should be required.

## User controls

The GUI should provide:

- **Share anonymous data**: off by default
- **View what will be shared**
- **Disable sharing**
- **Delete local telemetry queue**

A future server should publish aggregated community statistics without exposing individual device records.
