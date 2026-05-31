# NIST CSF 2.0 Control Mapping — SafeOps PowerShell Module

**Document ID:** CTRL-MAP-001  
**Version:** 1.0  
**Author:** Mahmadarsh Vahora  
**Date:** 2025-05-30  
**Framework Reference:** NIST Cybersecurity Framework 2.0 (February 2024)  
**Scope:** SafeOps PowerShell security module and associated CI/CD pipeline

---

## Framework Reference

NIST CSF 2.0 organizes controls into six Functions: **Govern (GV)**, **Identify (ID)**, **Protect (PR)**, **Detect (DE)**, **Respond (RS)**, **Recover (RC)**.  
Each Function contains Categories (e.g., PR.AC) and Subcategories (e.g., PR.AC-01).

---

## Control Mapping Table

| Control ID | CSF Function | CSF Category | CSF Subcategory | Subcategory Description (CSF 2.0) | SafeOps Control Description | Implementation Evidence | Status |
|---|---|---|---|---|---|---|---|
| SC-001 | **Protect (PR)** | PR.AC — Identity Management, Authentication, and Access Control | PR.AC-03 | Remote access is managed | Double-layer allowlist (ValidateSet + runtime check) restricts which commands any user can execute through SafeOps, regardless of OS-level permissions | `ValidateSet` parameter attribute in module source; runtime `$AllowedCommands` array with exact match check; denied attempts return error before execution | **Implemented** |
| SC-002 | **Protect (PR)** | PR.AC — Identity Management, Authentication, and Access Control | PR.AC-04 | Access permissions are managed, incorporating the principles of least privilege and separation of duties | `SupportsShouldProcess` and `ConfirmImpact='High'` require explicit confirmation before destructive operations; prevents accidental or coerced high-impact actions | `-WhatIf` support in module; `$PSCmdlet.ShouldProcess()` call before state-changing operations; Pester test verifies ShouldProcess behavior | **Implemented** |
| SC-003 | **Detect (DE)** | DE.AE — Anomalies and Events | DE.AE-03 | Event data are aggregated and correlated from multiple sources and sensors | `Write-SafeOpsLog` emits structured log entries with 6 fields (Timestamp, Actor, Action, Target, Outcome, Severity) for every execution attempt; allows correlation across sessions | Log entries in `C:\ProgramData\SafeOps\Logs\`; consistent field format enabling SIEM parsing; fields map to CEF standard (documented in audit_log_siem_mapping.md) | **Implemented** |
| SC-004 | **Detect (DE)** | DE.CM — Continuous Monitoring | DE.CM-03 | Personnel activity and technology usage are monitored to find potentially anomalous events | Actor field in every log entry captures DOMAIN\Username; allows per-user behavior analysis; denied actions are logged with same fields as allowed actions | `Actor=$env:USERDOMAIN\$env:USERNAME` in Write-SafeOpsLog; Outcome field distinguishes ALLOWED/DENIED/ERROR | **Implemented** |
| SC-005 | **Detect (DE)** | DE.CM — Continuous Monitoring | DE.CM-07 | Monitoring for unauthorized activities is performed | DENIED outcomes logged for every blocked command attempt; creates audit record of attempted policy violations | Log entries with Outcome=DENIED; Severity=WARN for denied attempts; field parseable in Splunk via KV extraction | **Implemented** |
| SC-006 | **Govern (GV)** | GV.OV — Organizational Context | GV.OV-02 | The organizational mission is understood and informs the management of cybersecurity risk | Module designed with explicit security purpose: control and audit privileged PS execution; security intent documented in module help text and README | `.SYNOPSIS` and `.DESCRIPTION` in module; README documents detective control purpose | **Implemented** |
| SC-007 | **Protect (PR)** | PR.DS — Data Security | PR.DS-01 | The confidentiality, integrity, and availability of data-at-rest are protected | Audit logs stored in protected directory with restricted ACL; log format preserves integrity via ISO 8601 timestamps | Log directory ACL restricts write to SafeOps process; Read-Only for non-admin users | **Partial** — no cryptographic log integrity (hash on write not yet implemented) |
| SC-008 | **Identify (ID)** | ID.IM — Improvement | ID.IM-02 | Improvements are identified from evaluations | Pester 5 test suite validates control behavior on every code change; tests cover allowlist enforcement, ShouldProcess, and log output | `tests/SafeOps.Tests.ps1` in repository; GitHub Actions runs tests on every push and PR | **Implemented** |
| SC-009 | **Protect (PR)** | PR.PS — Platform Security | PR.PS-02 | Software is maintained | GitHub Actions CI pipeline enforces automated testing before merge; no untested code reaches main branch | `.github/workflows/ci.yml`; branch protection rule requiring passing checks before merge | **Implemented** |
| SC-010 | **Respond (RS)** | RS.CO — Incident Response Communication | RS.CO-02 | Incidents are reported consistent with established criteria | Severity field in log entries enables alert routing: INFO/WARN/ERROR/CRITICAL; CRITICAL entries designed to trigger immediate notification | Severity=CRITICAL for unauthorized execution attempts; designed to map to SIEM alert severity | **Partial** — alert routing requires SIEM integration (not yet configured in lab environment) |
| SC-011 | **Govern (GV)** | GV.SC — Cybersecurity Supply Chain Risk Management | GV.SC-04 | Suppliers are known and prioritized by criticality | GitHub Actions uses pinned action versions; dependency on Pester module version locked in CI config | `uses: actions/checkout@v4` with pinned SHA in workflow file; Pester version constraint in CI | **Partial** — module itself not code-signed; supply chain risk R-004 accepted (see risk register) |
| SC-012 | **Protect (PR)** | PR.IR — Technology Infrastructure Resilience | PR.IR-01 | Networks and environments are protected from unauthorized logical access | Module enforces execution boundary: only pre-approved commands can be invoked; any other command triggers DENIED log and error | Runtime allowlist check throws `TerminatingError` for non-allowlisted commands; validated by Pester test | **Implemented** |

---

## Implementation Status Summary

| Status | Count | Percentage |
|---|---|---|
| Implemented | 8 | 67% |
| Partial | 3 | 25% |
| Planned | 1 | 8% |
| **Total Controls** | **12** | **100%** |

---

## Partial Controls — Remediation Actions

| Control ID | Gap | Remediation Action | Target Date |
|---|---|---|---|
| SC-007 | No cryptographic log integrity; log files can be modified without detection | Implement SHA-256 hash of each log entry appended to the line; or use Windows Event Log (tamper-resistant) as sink | 2025-08-30 |
| SC-010 | Alert routing not configured; CRITICAL log entries do not trigger notifications | Configure SIEM ingestion of SafeOps log; create alert rule on Severity=CRITICAL | 2025-07-30 |
| SC-011 | SafeOps module not code-signed; distribution integrity not cryptographically verifiable | Implement PowerShell code signing via self-signed or enterprise CA | 2025-08-30 |
