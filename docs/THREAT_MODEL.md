# SafeOpsToolkit — Threat Model

This document describes the security assumptions, assets, threats, and mitigations for
SafeOpsToolkit. It is intended for security reviewers, onboarding engineers, and anyone
evaluating whether to add a new capability to the module.

---

## Scope

SafeOpsToolkit runs on the **local Windows machine only**. It:

- Queries and modifies Windows services via the Service Control Manager (SCM) API.
- Reads from the `System` and `Application` Windows Event Logs.
- Writes a local audit log to `SafeOpsToolkit\logs\safeops.log`.
- Writes report files to caller-supplied paths on the local filesystem.

It does **not**:

- Accept a `-ComputerName` or remote-session parameter.
- Store, read, or transmit credentials or secrets.
- Execute arbitrary code or scriptblocks.
- Communicate with any network endpoint.

---

## Assumptions

| # | Assumption |
|---|---|
| A1 | The PowerShell session runs under a user or service account with appropriate Windows privileges (minimum: `Service Query` for reads; `Service Control` for writes). |
| A2 | The host machine is managed, domain-joined or otherwise controlled, and receives security patches. |
| A3 | The module is loaded from a trusted, ACL-protected path. An attacker who can modify module files can inject arbitrary code regardless of in-module controls. |
| A4 | The `SafeOpsToolkit\logs\` directory is writable by the process but its contents are treated as an append-only audit trail by policy. |
| A5 | Callers are authenticated operators — the module does not implement its own authentication layer. |

---

## Assets

| Asset | Sensitivity | Notes |
|---|---|---|
| Windows service configuration (startup type, running state) | Medium | Misconfiguration can impact availability or reduce host security (e.g., disabling WinDefend). |
| Windows Event Log data | Low–Medium | May contain application error details, stack traces, or operational metadata. |
| SafeOps audit log (`logs/safeops.log`) | Medium | Records who did what and when. Loss or tampering degrades accountability. |
| Report output files | Low–Medium | Contain event data and service state; sensitivity depends on where they are written. |

---

## Trust Boundaries

```
┌──────────────────────────────────────────┐
│  Caller (PowerShell session)             │
│  Privilege level: inherits from OS user  │
├──────────────────────────────────────────┤
│  SafeOpsToolkit module boundary          │
│  - ValidateSet  (parameter layer)        │
│  - Assert-SafeOpsAllowed (runtime layer) │
│  - ShouldProcess (confirmation layer)    │
├──────────────────────────────────────────┤
│  Windows SCM / Event Log APIs            │
│  (enforces OS-level ACLs independently)  │
└──────────────────────────────────────────┘
```

The module sits between the caller and the Windows APIs. It reduces the blast radius of
an operator error; it does not replace OS-level access controls.

---

## Threats

### T1 — Operator misuse: restarting or disabling a security-critical service

**Description:** A privileged operator intentionally or accidentally restarts `WinDefend`,
temporarily disabling host-based antivirus protection, or sets its startup type to `Disabled`,
preventing it from starting after reboot.

**Likelihood:** Medium — any module user with SCM rights can do this.

**Impact:** High — reduces host security posture; could contribute to a breach going undetected.

**Mitigations:**
- `ConfirmImpact = 'High'` on `Restart-AllowlistedService` — PowerShell will prompt unless
  `-Confirm:$false` is explicitly passed, creating a friction point and an intent signal.
- `Write-SafeOpsLog` records the operation with timestamp before and after execution,
  providing an audit trail for security review.
- The allowlist limits the surface to three known services; arbitrary services cannot be
  targeted regardless of privilege level.

---

### T2 — Privilege creep: a new public command bypasses the allowlist check

**Description:** A developer adds a new public function to `Public/` that calls `Restart-Service`
or `Set-Service` directly without invoking `Assert-SafeOpsAllowed`, expanding the attack
surface beyond the intended three services.

**Likelihood:** Low — requires a code change and a passing CI run.

**Impact:** High — silently breaks the security model without any obvious failure.

**Mitigations:**
- `Assert-SafeOpsAllowed` is a **private** function with a single, central allowlist. Any new
  public command that forgets to call it will still be constrained by `ValidateSet`, but the
  defence-in-depth check will be absent — code review should catch this.
- The Pester test suite includes a manifest validation test; a future test should verify that
  every public function that accepts a `$Name` parameter calls `Assert-SafeOpsAllowed`.
- CI runs `Test-ModuleManifest` on every push, ensuring the export list stays explicit.

---

### T3 — Missing or corrupted audit trail

**Description:** An operator performs a mutating operation that later becomes relevant to an
incident investigation, but there is no record of what was done or when.

**Likelihood:** High without structured logging; Low with it.

**Impact:** Medium — impedes incident response and accountability.

**Mitigations:**
- `Write-SafeOpsLog` is called before and after every mutating operation (restart, startup
  type change) and on every read operation (service status query, event log query).
- The log file is UTF-8 plain text; it can be forwarded to a SIEM or centrally collected
  without transformation.
- The audit log records `[LEVEL] Message key=value` lines, not free-form text, making it
  parseable by automated tooling.

**Residual risk:** The log file is local and can be deleted by anyone with write access to the
`logs/` directory. Organisations requiring tamper-evident logs should forward entries to a
remote SIEM in real time.

---

### T4 — Allowlist bypass via dynamic parameter construction

**Description:** A caller attempts to construct a service name string at runtime to bypass
the `ValidateSet` attribute (e.g., using `Invoke-Expression` or splatting a hashtable with
an arbitrary `Name` key).

**Likelihood:** Very Low — requires deliberate adversarial effort from an already-privileged
operator.

**Impact:** Medium — if successful, the operator could target services outside the allowlist.

**Mitigations:**
- **Dual enforcement:** `[ValidateSet]` is enforced by the PowerShell parameter binder (compile
  time) **and** `Assert-SafeOpsAllowed` is enforced at function entry (runtime). Both checks
  must pass. A caller using `Invoke-Expression` to bypass `ValidateSet` will still hit the
  runtime check.
- `Assert-SafeOpsAllowed` throws `System.Security.SecurityException` with a clear message,
  making bypass attempts visible in the audit log.

---

### T5 — Sensitive data written to the audit log

**Description:** A caller passes a secret (password, token, PII) to the `Context` parameter
of `Write-SafeOpsLog`, causing it to be persisted in plain text.

**Likelihood:** Low — the parameter is not exposed in public commands; only internal callers
use it, and the current callers only pass service names and status strings.

**Impact:** Medium — secrets at rest in a log file increase the blast radius of a host
compromise.

**Mitigations:**
- The `Write-SafeOpsLog` function comment and the Runbook both explicitly warn callers not to
  pass secrets or PII in the `Context` parameter.
- No public function accepts a credential or secret parameter, so there is no automated path
  by which secrets enter the log.
- A future improvement could add a simple redaction pattern (e.g., masking values whose keys
  contain "password", "token", or "secret").

---

## Controls Summary

| Control | Threats mitigated | Implementation |
|---|---|---|
| `[ValidateSet]` on `$Name` | T1, T4 | Parameter attribute in all three service commands |
| `Assert-SafeOpsAllowed` runtime check | T1, T2, T4 | `Private/Assert-SafeOpsAllowed.ps1` |
| `SupportsShouldProcess` + `ConfirmImpact` | T1 | `Restart-AllowlistedService`, `Set-AllowlistedServiceStartupType` |
| `Write-SafeOpsLog` on all operations | T3 | All six public commands |
| Explicit `FunctionsToExport` — no wildcards | T2 | `SafeOpsToolkit.psd1` + `SafeOpsToolkit.psm1` |
| No credential parameters | T5 | Design — no such parameters exist |
| Pester + CI on every push | T2 | `.github/workflows/ci.yml` |

---

## Residual Risk

| Risk | Accepted? | Rationale |
|---|---|---|
| A sufficiently privileged administrator can bypass the module entirely and call `Restart-Service` directly | Yes | The module is a guardrail, not a security boundary. OS-level privilege controls are the authoritative enforcement layer. |
| The local audit log can be deleted by the module user | Yes | Organisations requiring tamper-evident logging must forward logs to a SIEM. This is an operational process requirement, not a code requirement. |
| The allowlist is hardcoded and cannot be extended without a code change | Yes (by design) | Extensibility via configuration would require validating the configuration source, which introduces a new attack surface. Changes to the allowlist require a PR, code review, and a new module version. |
