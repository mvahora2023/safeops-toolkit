# SafeOps Risk Register

**Document ID:** RR-SAFEOPS-001  
**Version:** 1.0  
**Author:** Mahmadarsh Vahora  
**Date:** 2025-05-30  
**Related Document:** TM-SAFEOPS-001 (Threat Model)  
**Review Cycle:** Semi-annual or upon material change

---

## Risk Register

| Risk ID | Asset | Threat Description | Likelihood (1–5) | Impact (1–5) | Risk Score | Current Control | Control Effectiveness | Residual Risk | Risk Owner | Status |
|---|---|---|---|---|---|---|---|---|---|---|
| R-001 | Allowlist Configuration (A-002) | Authorized insider edits the ValidateSet or runtime allowlist array to add unauthorized commands, enabling privilege escalation through a trusted execution path | 2 | 4 | **8 — Medium** | Double-layer allowlist (ValidateSet + runtime check); CI validates allowlist on every commit; Pester tests assert specific blocked commands | Moderate — CI catches committed changes but not local file edits before commit | **5 — Low-Medium** | Module Owner | Open — code signing recommended |
| R-002 | Audit Logs (A-003) | Local administrator deletes or truncates Write-SafeOpsLog output files post-incident to destroy forensic evidence and break compliance audit trail | 3 | 3 | **9 — Medium** | Protected log directory with restricted ACL; structured log format with ISO 8601 timestamps for integrity | Moderate — local protection only; no off-host copy | **6 — Medium** | Module Owner | Open — SIEM forwarding planned |
| R-003 | Module (A-001) | Insider or attacker bypasses SafeOps entirely by invoking underlying PowerShell cmdlets directly, producing no SafeOps audit log entry | 4 | 2 | **8 — Medium** | Windows Security EventID 4688 (process creation) + EDR agent provides backup visibility; ShouldProcess on destructive operations | Moderate — SafeOps is additive, not mandatory; direct invocation always possible | **4 — Low** | Endpoint Security Team | Accepted — layered controls sufficient |
| R-004 | CI/CD Pipeline (A-004) | GitHub Actions workflow compromise results in malicious SafeOps module version being distributed to endpoints, enabling arbitrary code execution under the appearance of a trusted tool | 2 | 5 | **10 — High** | Branch protection rules; Pester 5 test suite validates behavior on every PR; GitHub repository access limited to module owner | Partial — no code-signing or hash verification at install time | **8 — Medium** | Module Owner | Open — code signing gap, **not yet remediated** |
| R-005 | Module (A-001) | Malware running with elevated privileges uses SafeOps as a trusted execution proxy to run commands that would otherwise trigger EDR detections | 2 | 4 | **8 — Medium** | EDR agent monitors all process behavior independent of SafeOps; Windows Defender real-time protection | Moderate — EDR provides compensating control; SafeOps itself cannot prevent this | **4 — Low** | Endpoint Security Team | Accepted — EDR compensating control documented |
| R-006 | Allowlist Configuration (A-002) | Allowlist configuration contents are read by unauthorized user, revealing permitted command surface and aiding reconnaissance for evasion | 3 | 2 | **6 — Low** | File system ACL restricts read access to administrators only; configuration is embedded in module (not external file) | Effective — low-sensitivity data; allowlist is also partly visible in module source | **2 — Low** | Module Owner | Accepted — low impact; no additional control warranted |

---

## Risk Score Legend

| Score Range | Rating | Required Action |
|---|---|---|
| 1–4 | **Low** | Accept with documentation; review annually |
| 5–9 | **Medium** | Implement additional control or formally accept with justification; review semi-annually |
| 10–14 | **High** | Remediation required before production deployment; escalate to risk owner |
| 15–25 | **Critical** | Immediate remediation; executive notification required |

---

## Open Action Items

| Action | Risk ID | Owner | Target Date | Status |
|---|---|---|---|---|
| Implement PowerShell module code signing via self-signed or enterprise CA certificate | R-001, R-004 | Mahmadarsh Vahora | 2025-08-30 | Not Started |
| Configure real-time log forwarding to Splunk or Windows Event Log via WEF | R-002 | Mahmadarsh Vahora | 2025-07-30 | Not Started |
| Document formal policy requiring SafeOps use for all privileged PS execution | R-003 | Mahmadarsh Vahora | 2025-06-30 | In Progress |
| Add module hash verification to deployment script | R-004 | Mahmadarsh Vahora | 2025-08-30 | Not Started |

---

## Risk Acceptance Statement

Risks R-003, R-005, and R-006 are formally accepted at current residual risk levels based on the presence of compensating controls (EDR, Windows native auditing, file system ACL) and the limited deployment scope (personal/lab environment). This acceptance is documented for audit purposes and is subject to re-evaluation upon scope expansion to production enterprise environments.

**Accepted by:** Mahmadarsh Vahora  
**Date:** 2025-05-30  
**Next Review:** 2025-11-30
