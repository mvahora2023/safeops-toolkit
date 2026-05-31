# SafeOps Control Assessment Checklist

**Document ID:** AUDIT-CHECKLIST-001  
**Version:** 1.0  
**Author:** Mahmadarsh Vahora  
**Date:** 2025-05-30  
**Purpose:** Auditor verification checklist — confirms each SafeOps control is implemented and operational, not just documented.  
**How to Use:** Each item requires objective evidence. Mark Pass/Fail/Not Tested. Document evidence reference (screenshot, log sample, test output) for each Pass.

---

## Pre-Assessment Requirements

- [ ] Access to SafeOps module source code (`.psm1`)
- [ ] Access to SafeOps log directory (`C:\ProgramData\SafeOps\Logs\` or configured path)
- [ ] Access to GitHub repository (for CI/CD verification)
- [ ] PowerShell 5.1+ environment to run test commands
- [ ] Windows Event Viewer access (for event log verification items)

---

## Assessment Checklist

### Section 1: Allowlist Enforcement (SC-001)

**Control Objective:** The module must reject any command not present in both the ValidateSet parameter attribute and the runtime allowlist array.

---

**Item 1.1 — ValidateSet Attribute Present**

- **Test:** Open `SafeOps.psm1`. Locate the primary `Invoke-SafeCommand` (or equivalent) function. Verify that the `$CommandName` parameter has a `[ValidateSet(...)]` attribute listing all approved commands.
- **Evidence Required:** Screenshot or code excerpt showing `[ValidateSet("command1", "command2", ...)]` annotation
- **Expected Result:** PASS if ValidateSet is present and non-empty; FAIL if parameter lacks ValidateSet or accepts arbitrary strings
- [ ] Pass   [ ] Fail   [ ] Not Tested
- **Evidence Reference:** _______________

---

**Item 1.2 — Runtime Allowlist Check**

- **Test:** Attempt to invoke a command NOT in the allowlist by passing it as the `-CommandName` parameter (bypass ValidateSet using reflection or by temporarily modifying a test copy). Verify a DENIED log entry is generated.
- **Evidence Required:** Log entry showing `Outcome=DENIED` for a non-allowlisted command
- **Expected Result:** PASS if DENIED logged and execution halted; FAIL if command executes or no log entry appears
- [ ] Pass   [ ] Fail   [ ] Not Tested
- **Evidence Reference:** _______________

---

**Item 1.3 — Pester Test Coverage for Allowlist**

- **Test:** Run Pester test suite (`Invoke-Pester -Path .\tests\`). Review test results for tests asserting: (a) allowlisted commands succeed, (b) blocked commands fail.
- **Evidence Required:** Pester test output showing tests for allowlist behavior; green (Pass) status
- **Expected Result:** PASS if tests exist and pass; FAIL if no allowlist tests present or tests fail
- [ ] Pass   [ ] Fail   [ ] Not Tested
- **Evidence Reference:** _______________

---

### Section 2: ShouldProcess / Confirmation Safety (SC-002)

**Control Objective:** Destructive operations must require explicit confirmation and support `-WhatIf` for safe rehearsal.

---

**Item 2.1 — ShouldProcess Declared**

- **Test:** Open module source. Verify `CmdletBinding(SupportsShouldProcess)` is present in the function definition for any function that modifies state.
- **Evidence Required:** Code excerpt showing `[CmdletBinding(SupportsShouldProcess)]` and `$PSCmdlet.ShouldProcess(...)` call before state change
- **Expected Result:** PASS if ShouldProcess present and called before every state-modifying action
- [ ] Pass   [ ] Fail   [ ] Not Tested
- **Evidence Reference:** _______________

---

**Item 2.2 — WhatIf Behavior**

- **Test:** Run any destructive SafeOps function with `-WhatIf`. Verify: (a) no actual change is made, (b) output describes what would have happened, (c) no log entry is written for a WhatIf-skipped action.
- **Evidence Required:** Terminal output showing WhatIf message; verification that no state change occurred; log file showing no entry for the WhatIf run
- **Expected Result:** PASS if WhatIf suppresses action and produces informational output
- [ ] Pass   [ ] Fail   [ ] Not Tested
- **Evidence Reference:** _______________

---

### Section 3: Audit Logging (SC-003, SC-004, SC-005)

**Control Objective:** Every command execution attempt (allowed or denied) must produce a structured log entry with all 6 required fields.

---

**Item 3.1 — Log Entry Fields Present**

- **Test:** Execute one allowed command and one that triggers a denied outcome. Inspect the resulting log entries. Verify all 6 fields are present: `Timestamp`, `Actor`, `Action`, `Target`, `Outcome`, `Severity`.
- **Evidence Required:** Copy of two log lines (one ALLOWED, one DENIED) with all fields visible
- **Expected Result:** PASS if all 6 fields present in both entries
- [ ] Pass   [ ] Fail   [ ] Not Tested
- **Evidence Reference:** _______________

---

**Item 3.2 — Timestamp Format (ISO 8601 UTC)**

- **Test:** Inspect Timestamp field in log entry. Verify format matches ISO 8601: `YYYY-MM-DDTHH:MM:SSZ`
- **Evidence Required:** Log entry timestamp field value
- **Expected Result:** PASS if timestamp is UTC ISO 8601 format
- [ ] Pass   [ ] Fail   [ ] Not Tested
- **Evidence Reference:** _______________

---

**Item 3.3 — Actor Field Captures Identity**

- **Test:** Run SafeOps as User A, then as User B (use `runas` or a second test account). Verify Actor field in each log entry differs and reflects the correct user.
- **Evidence Required:** Two log entries with different Actor values corresponding to different user accounts
- **Expected Result:** PASS if Actor correctly captures `DOMAIN\Username` for both users
- [ ] Pass   [ ] Fail   [ ] Not Tested
- **Evidence Reference:** _______________

---

**Item 3.4 — DENIED Events Logged**

- **Test:** Attempt a command that should be blocked. Verify a DENIED log entry exists even though the command did not execute.
- **Evidence Required:** Log entry with `Outcome=DENIED`; confirmation that the blocked command did not execute (no system state change)
- **Expected Result:** PASS if DENIED entry appears and no execution occurred
- [ ] Pass   [ ] Fail   [ ] Not Tested
- **Evidence Reference:** _______________

---

### Section 4: CI/CD Pipeline Integrity (SC-008, SC-009)

**Control Objective:** The CI pipeline must run all Pester tests on every code change and prevent merge if tests fail.

---

**Item 4.1 — GitHub Actions Workflow Exists**

- **Test:** Navigate to repository `.github/workflows/`. Verify CI workflow file exists and includes a step running Pester tests.
- **Evidence Required:** Screenshot of workflow file content showing Pester execution step
- **Expected Result:** PASS if workflow file exists and contains Pester invocation
- [ ] Pass   [ ] Fail   [ ] Not Tested
- **Evidence Reference:** _______________

---

**Item 4.2 — Branch Protection Enforces CI**

- **Test:** Check GitHub repository Settings > Branches. Verify main branch has protection rule requiring status checks (CI) to pass before merge.
- **Evidence Required:** Screenshot of branch protection rules showing required status check
- **Expected Result:** PASS if CI is a required check; FAIL if PRs can merge without CI passing
- [ ] Pass   [ ] Fail   [ ] Not Tested
- **Evidence Reference:** _______________

---

### Section 5: Log File Protection (SC-007)

**Control Objective:** Log files must be protected against unauthorized modification or deletion by non-privileged users.

---

**Item 5.1 — Log Directory ACL**

- **Test:** Run `Get-Acl "C:\ProgramData\SafeOps\Logs" | Format-List` (or equivalent). Verify that standard user accounts do not have Write or Delete permissions on the log directory.
- **Evidence Required:** ACL output showing Administrators have Full Control; standard Users have Read-Only or no access
- **Expected Result:** PASS if non-admin users cannot write to log directory
- [ ] Pass   [ ] Fail   [ ] Not Tested
- **Evidence Reference:** _______________

---

## Assessment Summary

| Section | Items | Pass | Fail | Not Tested |
|---|---|---|---|---|
| 1 — Allowlist Enforcement | 3 | | | |
| 2 — ShouldProcess Safety | 2 | | | |
| 3 — Audit Logging | 4 | | | |
| 4 — CI/CD Integrity | 2 | | | |
| 5 — Log Protection | 1 | | | |
| **Total** | **12** | | | |

---

**Assessment Conducted By:** _______________  
**Assessment Date:** _______________  
**Overall Result:** [ ] Pass (all 12 items Pass)   [ ] Conditional Pass (minor gaps)   [ ] Fail (critical gaps)  
**Findings Summary:** _______________
