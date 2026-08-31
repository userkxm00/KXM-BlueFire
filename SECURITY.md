# Security Policy

## Scope

KXM is a privileged Windows system utility. Security issues include unintended privilege escalation, unsafe command execution, credential exposure, data exfiltration, recovery bypasses, and unsafe handling of community telemetry.

## Reporting

Please report security issues privately to the repository maintainer rather than posting working exploit details in a public issue.

Include:

- affected KXM version;
- Windows version/build;
- reproduction steps;
- expected vs actual behavior;
- relevant logs with secrets removed.

Do not include passwords, API keys, tokens, personal files, or private identifiers.

## Telemetry security

Community telemetry is opt-in. It must remain disabled unless the user explicitly enables it, and the payload must be sanitized before transmission. No credential, document, account, or intentional IP collection is permitted.

## Release security

Before distributing a packaged binary, KXM should use reproducible build steps where practical, publish checksums, and use a trusted code-signing certificate.
