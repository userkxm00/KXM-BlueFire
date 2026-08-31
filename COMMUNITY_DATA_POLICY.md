# KXM Community Data Policy

## Default

Community telemetry is **OFF by default**. KXM should never silently transmit diagnostic data.

## User consent

Before enabling it, KXM explains that shared data is limited to coarse hardware/configuration categories and optimization outcomes. The user can decline without losing access to KXM.

## Data categories

Potentially shared:
- KXM version and schema version
- Windows build
- coarse CPU/GPU/RAM/storage categories
- BlueStacks/game profile and configuration categories
- which KXM changes succeeded, failed, were skipped, or were reverted
- reboot requirement
- optional benchmark measurements explicitly entered or captured by KXM

Never intentionally shared:
- passwords or credentials
- tokens/API keys
- documents or file contents
- browser history
- Windows username or account identifiers
- game-account identifiers
- registry dumps unrelated to KXM-managed settings
- arbitrary process command lines

## Data minimization

KXM should prefer categories over unique hardware identifiers. Do not upload serial numbers, MAC addresses, disk serials, or full device identifiers.

## Outcome learning

Community data is used only in aggregate to improve recommendations. A tweak should require a meaningful sample size and consider success, neutral, and revert/negative outcomes before its recommendation level changes.

## Transparency

The repository should contain the event schema and the client should provide a human-readable preview of what will be sent.
