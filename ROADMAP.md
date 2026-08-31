# KXM BlueFire Roadmap

## v24 — Community Release Candidate
- Recovery-first baseline
- Hardware-aware detection
- GAME READY session workflow
- Free Fire / BlueStacks profile guidance
- Maximum FPS power-plan workflow
- Conflict and dependency checks
- Dry-run preview
- Ping / jitter diagnostics
- Benchmark and verification
- Community telemetry infrastructure (opt-in only)

## v25 — Reliability First
- Thermal monitoring and thermal-headroom warnings
- GPU / chipset driver-version checks
- Windows Update resilience detection
- Profile export / import
- One-click undo of the last gaming session
- Stronger restore verification and transaction logs
- PowerShell 5.1 + GUI smoke-test matrix on Windows runners

## v26 — Gaming Profiles
- Game-specific profile architecture
- BlueStacks version detection and compatibility rules
- Frame-time analysis (including optional PresentMon integration)
- Network latency dashboard with packet-loss and jitter views
- Additional emulator profiles where evidence supports them

## v27+ — Community Ecosystem
- Community profile sharing with moderation / signatures
- Evidence-based recommendation scoring from opt-in anonymous telemetry
- Community benchmark database
- Optional baseline synchronization, designed as encrypted export/import first
- Code-signed packaged distribution when KXM ships a binary

## Release gate

KXM should not claim "Stable" until representative real-device testing covers Intel/AMD CPUs, integrated/discrete GPUs, HDD/SSD/NVMe storage, 8/16/32 GB RAM tiers, Windows 10/11, and multiple BlueStacks configurations.
