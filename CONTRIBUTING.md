# Contributing to KXM BlueFire

Thank you for helping improve KXM.

## Before submitting code

1. Read `ARCHITECTURE.md`.
2. Keep normal profiles conservative and hardware-aware.
3. Keep experimental changes explicitly opt-in.
4. Preserve the recovery-first model.
5. Never add game-file modification, DLL injection, anti-cheat bypass, or credential collection.

## New tweak checklist

For every new system change, document:

- what it changes;
- why it may help;
- supported Windows versions;
- hardware/environment limitations;
- whether reboot is required;
- rollback method;
- verification method;
- whether it belongs in Safe, Competitive, or Experimental.

A tweak without a rollback and verification path should not enter the normal profile.

## Testing

At minimum, run the PowerShell parser checks and a read-only smoke test. When possible, test on both Windows 10 and Windows 11 and record the hardware class.

Do not claim an FPS improvement without measurable before/after evidence.

## Pull requests

Use a clear title and describe:

- the user-facing problem;
- the technical change;
- compatibility considerations;
- recovery implications;
- test results.
