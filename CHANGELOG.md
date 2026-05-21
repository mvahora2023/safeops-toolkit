# Changelog

All notable changes to SafeOpsToolkit are documented in this file.
Format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/).

---

## [Unreleased]

_No unreleased changes._

---

## [1.0.0] — 2026-05-21

### Added

**Public commands**
- `Get-AllowlistedServiceStatus` — query running state and startup type for one or more
  allowlisted services; supports pipeline and multi-name input.
- `Restart-AllowlistedService` — restart an allowlisted service with `SupportsShouldProcess`
  (`ConfirmImpact = High`); supports `-WhatIf` and `-Confirm`.
- `Set-AllowlistedServiceStartupType` — change the startup type of an allowlisted service
  with `SupportsShouldProcess` (`ConfirmImpact = Medium`).
- `Get-RecentLogErrors` — retrieve recent Error-level (Level 2) entries from the System or
  Application event log; configurable via `-MaxEvents` (1–500).
- `Get-LogEventsById` — retrieve event log entries by Event ID (1–65535); returns any
  severity level; configurable via `-MaxEvents` (1–500).
- `Export-SafeOpsReport` — export any collection of `PSCustomObject`s to JSON or CSV;
  creates parent directories automatically; returns a summary object.

**Private helpers**
- `Assert-SafeOpsAllowed` — central allowlist gate; throws `SecurityException` for any
  service name not in the approved list.
- `ConvertTo-SafeOpsResult` — normalises ordered hashtables into `PSCustomObject` output
  with consistent property ordering.
- `Write-SafeOpsLog` — appends UTC-timestamped, structured log lines to
  `SafeOpsToolkit\logs\safeops.log`; never logs secrets or exception messages.

**Infrastructure**
- Module manifest (`SafeOpsToolkit.psd1`) with explicit `FunctionsToExport`; no wildcards.
- Pester 5 test suite — 63 tests covering parameter validation, output schemas, WhatIf
  behaviour, mock-verified call counts, and file I/O correctness. No admin required.
- GitHub Actions CI workflow — manifest validation, Pester run with `Run.Exit = $true`,
  NUnit XML test-result publishing, and downloadable artifact upload.

**Documentation**
- `docs/RUNBOOK.md` — three operational triage scenarios with runnable commands.
- `docs/THREAT_MODEL.md` — scope, assets, five named threats, controls table, residual risk.
- `docs/DESIGN_DECISIONS.md` — eight architecture decisions with rationale and trade-offs.
- `demo/sample-output.json` and `demo/sample-output.csv` — synthetic data matching the
  event-result object schema.

### Security

- Service operations are gated by both a `[ValidateSet]` attribute and a runtime
  `Assert-SafeOpsAllowed` call — dual enforcement prevents allowlist bypass.
- Exception messages are not written to the audit log to avoid leaking system paths
  or OS error strings; errors propagate to the caller via `throw` / `Write-Error`.
- No credential, token, or secret parameters exist anywhere in the module.

---

## Version policy

| Change type | Version bump |
|---|---|
| Breaking change to public API | Major (X.0.0) |
| New public command or parameter | Minor (1.X.0) |
| Bug fix, docs, tests, polish | Patch (1.0.X) |
| Allowlist additions | Minor (requires deliberate review) |
