# SafeOpsToolkit

![CI](https://github.com/mvahora2023/safeops-toolkit/actions/workflows/ci.yml/badge.svg)
![PowerShell 5.1+](https://img.shields.io/badge/PowerShell-5.1%2B-blue)
![License MIT](https://img.shields.io/badge/license-MIT-green)

> A production-quality PowerShell module for allowlisted Windows service management, structured
> event-log inspection, and safe operational reporting — built for ops teams that need
> guardrails around day-to-day service triage.

---

## Overview

SafeOpsToolkit wraps the Windows Service Control Manager and Windows Event Log APIs behind
a narrow, audited interface. Every service operation is gated by a compile-time `ValidateSet`
**and** a runtime allowlist check; every mutating command requires explicit confirmation or a
`-WhatIf` preview pass before anything changes. All actions are written to a local audit log.

The module is designed for operations engineers, site reliability teams, and security-conscious
administrators who need to hand out scoped service-management access without exposing arbitrary
`Restart-Service` or `Set-Service` calls.

> **Demo outputs in `demo/` are entirely synthetic.** No real hostnames, usernames, event
> messages, or service states are included. They are representative of the actual object shapes
> produced by each command.

---

## Features

- **Allowlist-gated service access** — only `Spooler`, `wuauserv`, and `WinDefend` can be
  queried or modified; any other name is rejected at the parameter layer and again at runtime.
- **Safe-by-default mutations** — `Restart-AllowlistedService` and
  `Set-AllowlistedServiceStartupType` honour `-WhatIf` and `-Confirm`; CI pipelines can call
  them with `-WhatIf` to preview changes without side-effects.
- **Structured output** — every command returns `PSCustomObject`s with consistent schemas,
  making results pipeable to `Export-SafeOpsReport`, `Where-Object`, `Format-Table`, or any
  downstream tooling.
- **Local audit trail** — `Write-SafeOpsLog` appends a timestamped entry to
  `SafeOpsToolkit/logs/safeops.log` on every significant operation. No secrets are logged.
- **Zero external dependencies** — only PowerShell 5.1 built-ins and the Windows platform APIs.
- **Pester 5 test suite with GitHub Actions CI** — manifest validation and function-level
  tests run on every push and pull request.

---

## Requirements

| Requirement | Version |
|---|---|
| Windows PowerShell | 5.1+ |
| PowerShell 7 (optional) | 7.2+ |
| Pester (tests only) | 5.0+ |
| Windows OS | Windows 10 / Server 2016 or later |
| Privileges | Service Query for reads; Service Control for writes |

---

## Execution Policy

SafeOpsToolkit ships as unsigned `.ps1` files. Windows PowerShell's default execution
policy (`Restricted`) blocks all scripts. Set the policy before importing the module.

| Environment | Recommended setting | Command |
|---|---|---|
| Developer workstation | `RemoteSigned` | `Set-ExecutionPolicy RemoteSigned -Scope CurrentUser` |
| CI/CD runner | `Bypass` (process scope only) | `Set-ExecutionPolicy Bypass -Scope Process` |
| Production server | `AllSigned` | Deploy signed copies; see note below |

**AllSigned environments:** sign all `.ps1` files in `SafeOpsToolkit/` with an Authenticode
certificate before deployment:

```powershell
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert | Select-Object -First 1
Get-ChildItem -Path .\SafeOpsToolkit -Recurse -Filter '*.ps1' |
    ForEach-Object { Set-AuthenticodeSignature -FilePath $_.FullName -Certificate $cert }
```

The GitHub Actions workflow sets `-Scope Process` on the runner, so CI never modifies the
machine-level policy.

---

## Quick Start

```powershell
# 1. Clone or copy the repository
git clone https://github.com/your-org/safeops-toolkit.git
cd safeops-toolkit

# 2. Import the module
Import-Module .\SafeOpsToolkit\SafeOpsToolkit.psd1

# 3. Verify it loaded
Get-Command -Module SafeOpsToolkit

# 4. Query a service
Get-AllowlistedServiceStatus -Name Spooler
```

---

## Command Reference

### `Get-AllowlistedServiceStatus`

Returns the current status of one or more allowlisted services. Accepts pipeline input.

```powershell
# Single service
Get-AllowlistedServiceStatus -Name Spooler

# Multiple services
Get-AllowlistedServiceStatus -Name Spooler, wuauserv, WinDefend

# Pipeline
'Spooler', 'wuauserv' | Get-AllowlistedServiceStatus | Format-Table

# Example output
# Name      DisplayName                              Status  StartType
# ----      -----------                              ------  ---------
# Spooler   Print Spooler                            Running Automatic
# wuauserv  Windows Update                           Stopped Manual
```

---

### `Restart-AllowlistedService`

Restarts an allowlisted service. Always preview with `-WhatIf` before executing in production.

```powershell
# Preview — no changes made
Restart-AllowlistedService -Name Spooler -WhatIf

# Execute with interactive confirmation prompt
Restart-AllowlistedService -Name Spooler -Confirm

# Execute non-interactively (automation pipelines)
Restart-AllowlistedService -Name Spooler

# Example output
# Name    Status
# ----    ------
# Spooler Running
```

---

### `Set-AllowlistedServiceStartupType`

Changes the startup type of an allowlisted service.

```powershell
# Preview the change
Set-AllowlistedServiceStartupType -Name wuauserv -StartupType Manual -WhatIf

# Apply with confirmation
Set-AllowlistedServiceStartupType -Name wuauserv -StartupType Manual -Confirm

# Example output
# Name     StartType
# ----     ---------
# wuauserv Manual
```

---

### `Get-RecentLogErrors`

Returns the most recent Error-level entries from the System or Application event log.

```powershell
# Last 50 errors from System log (default)
Get-RecentLogErrors -LogName System

# Last 10 errors from Application log
Get-RecentLogErrors -LogName Application -MaxEvents 10

# Pipe into a report
Get-RecentLogErrors -LogName System -MaxEvents 100 |
    Export-SafeOpsReport -Format JSON -Path .\reports\system-errors.json
```

---

### `Get-LogEventsById`

Returns Event Log entries matching a specific Event ID, regardless of level.

```powershell
# All recent 7036 (Service state change) events
Get-LogEventsById -LogName System -EventId 7036

# Top 25 application crashes (Event ID 1000)
Get-LogEventsById -LogName Application -EventId 1000 -MaxEvents 25

# Example output
# TimeCreated           Id   ProviderName             LevelDisplayName Message
# -----------           --   ------------             ---------------- -------
# 2026-05-21 08:42:11   7036 Service Control Manager  Information      The Print Spooler service entered...
```

---

### `Export-SafeOpsReport`

Exports any pipeline of `PSCustomObject`s to JSON or CSV.

```powershell
# Export service status to JSON
Get-AllowlistedServiceStatus -Name Spooler, wuauserv, WinDefend |
    Export-SafeOpsReport -Format JSON -Path .\reports\services.json

# Export event log errors to CSV
Get-RecentLogErrors -LogName Application -MaxEvents 200 |
    Export-SafeOpsReport -Format CSV -Path .\reports\app-errors.csv

# Example output (the command itself returns a summary object)
# Path                                Format Count
# ----                                ------ -----
# C:\reports\services.json           JSON       3
```

---

## Safety Model

SafeOpsToolkit is designed to make unsafe operations impossible, not just discouraged.

| What it enforces | How |
|---|---|
| Only approved services can be touched | `[ValidateSet]` at the parameter level + `Assert-SafeOpsAllowed` at runtime |
| Mutations require intent | `[CmdletBinding(SupportsShouldProcess)]` — callers must opt in; `-WhatIf` works on all mutating commands |
| Every significant action is recorded | `Write-SafeOpsLog` appends to `SafeOpsToolkit/logs/safeops.log` with timestamp and context |
| Private helpers are unexported | Explicit `FunctionsToExport` in the manifest; no wildcard exports |
| No secrets are accepted or logged | Parameters accept only service names and log names; no credential parameters exist |

**What SafeOpsToolkit refuses to do:**

- Target services outside the fixed allowlist — there is no `-Force` or `-BypassAllowlist` flag.
- Accept a `-ComputerName` parameter — remote targeting is out of scope; each machine runs its own copy.
- Execute arbitrary shell commands or accept scriptblock parameters.
- Store or transmit credentials.
- Log sensitive context values — the `Context` parameter to `Write-SafeOpsLog` is caller-controlled; do not pass passwords or tokens.

---

## Testing

No admin privileges are required to run the test suite — all SCM and Event Log calls are mocked.

```powershell
# Install Pester 5 if not present
Install-Module Pester -MinimumVersion 5.0 -Force -SkipPublisherCheck

# Quick run — human-readable output
$cfg = New-PesterConfiguration
$cfg.Run.Path         = '.\Tests'
$cfg.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $cfg

# CI-equivalent — exits with a non-zero code on failure
$cfg = New-PesterConfiguration
$cfg.Run.Path         = '.\Tests'
$cfg.Run.Exit         = $true
$cfg.Output.Verbosity = 'Detailed'
Invoke-Pester -Configuration $cfg

# With code coverage
$cfg = New-PesterConfiguration
$cfg.Run.Path                   = '.\Tests'
$cfg.CodeCoverage.Enabled       = $true
$cfg.CodeCoverage.Path          = '.\SafeOpsToolkit\Public\*.ps1',
                                   '.\SafeOpsToolkit\Private\*.ps1'
$cfg.Output.Verbosity           = 'Detailed'
Invoke-Pester -Configuration $cfg
```

The GitHub Actions workflow (`.github/workflows/ci.yml`) validates the module manifest, then
runs Pester with `Run.Exit = $true` — any test failure sets a non-zero exit code and fails
the job. Test results are published as both a GitHub Actions summary and a downloadable
NUnit XML artifact.

---

## Project Structure

```
safeops-toolkit/
  SafeOpsToolkit/
    SafeOpsToolkit.psm1          # Module loader — dot-sources Private/ then Public/
    SafeOpsToolkit.psd1          # Module manifest — explicit exports, no wildcards
    Public/                      # Six exported commands
    Private/                     # Three internal helpers (unexported)
  Tests/
    SafeOpsToolkit.Tests.ps1     # Pester 5 test suite
  docs/
    RUNBOOK.md                   # Operational scenarios and procedures
    THREAT_MODEL.md              # Security assumptions, threats, mitigations
    DESIGN_DECISIONS.md          # Architecture rationale
  demo/
    sample-output.json           # Synthetic sample of Get-RecentLogErrors output
    sample-output.csv            # Same data in CSV format
    screenshots/                 # Reserved for terminal screenshots
  .github/workflows/
    ci.yml                       # GitHub Actions — Pester + manifest validation
```

---

## Documentation

| Document | Purpose |
|---|---|
| [RUNBOOK.md](docs/RUNBOOK.md) | Step-by-step operational procedures for common triage scenarios |
| [THREAT_MODEL.md](docs/THREAT_MODEL.md) | Assets, threats, mitigations, and residual risk |
| [DESIGN_DECISIONS.md](docs/DESIGN_DECISIONS.md) | Why the module is built the way it is |

---

## Versioning

SafeOpsToolkit follows [Semantic Versioning](https://semver.org/). The current release is
**v1.0.0**. See [CHANGELOG.md](CHANGELOG.md) for the full history and version policy.

---

## License

[MIT](LICENSE) — see the LICENSE file for details.
