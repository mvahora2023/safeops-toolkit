# SafeOpsToolkit — Runbook

Operational procedures for teams using SafeOpsToolkit in production environments.
All commands require SafeOpsToolkit to be imported first:

```powershell
Import-Module .\SafeOpsToolkit\SafeOpsToolkit.psd1
```

---

## Standard Workflow

Every service-change engagement follows the same six-step pattern regardless of scenario:

```
1. Collect evidence   — establish current state before touching anything
2. Preview change     — run the mutating command with -WhatIf; confirm the target is correct
3. Execute            — run without -WhatIf; respond Y to the confirmation prompt or pre-approve with -Confirm:$false in automation
4. Verify             — re-query state to confirm the expected outcome
5. Export report      — write evidence to a timestamped file for the ticket
6. Record in ticket   — paste the report path and key findings into the incident record
```

---

## Scenario A — Service Down Triage

**Situation:** An alert fires indicating the Print Spooler (`Spooler`) service is not running.
You need to confirm the state, review recent errors, safely restart the service, and produce
evidence for the incident ticket.

### Step 1 — Collect evidence

```powershell
# Confirm the service is actually stopped
Get-AllowlistedServiceStatus -Name Spooler

# Sample output:
# Name    DisplayName   Status  StartType
# ----    -----------   ------  ---------
# Spooler Print Spooler Stopped Automatic

# Pull the last 20 System-log errors to understand why it stopped
Get-RecentLogErrors -LogName System -MaxEvents 20 | Format-List TimeCreated, Id, ProviderName, Message
```

### Step 2 — Preview the restart

```powershell
# Verify the target before committing — produces no side-effects
Restart-AllowlistedService -Name Spooler -WhatIf
# Output: What if: Performing the operation "Restart-Service" on target "Spooler".
```

### Step 3 — Execute

```powershell
Restart-AllowlistedService -Name Spooler
# Confirmation prompt appears (ConfirmImpact = High). Type Y to proceed.
```

### Step 4 — Verify

```powershell
Get-AllowlistedServiceStatus -Name Spooler

# Expected output:
# Name    DisplayName   Status  StartType
# ----    -----------   ------  ---------
# Spooler Print Spooler Running Automatic
```

### Step 5 — Export report

```powershell
$timestamp = Get-Date -Format 'yyyyMMdd-HHmm'
$reportDir = ".\reports\$timestamp-spooler-triage"
New-Item -ItemType Directory -Path $reportDir -Force | Out-Null

# Service state snapshot
Get-AllowlistedServiceStatus -Name Spooler |
    Export-SafeOpsReport -Format JSON -Path "$reportDir\service-status.json"

# Contributing errors
Get-RecentLogErrors -LogName System -MaxEvents 20 |
    Export-SafeOpsReport -Format CSV -Path "$reportDir\system-errors.csv"
```

### Step 6 — Record in ticket

Paste the report directory path and the contents of `service-status.json` into the incident
ticket. Note whether the service auto-restarted or required manual intervention, and whether
any contributing errors were found in the log.

---

## Scenario B — Repeated Error Events Triage

**Situation:** The application team reports intermittent failures over the past hour.
You need to identify which providers are generating errors, assess volume and recency,
and export a structured log for the developers to analyse.

### Step 1 — Get a wide error sample

```powershell
# Pull the last 200 errors from the Application log
$appErrors = Get-RecentLogErrors -LogName Application -MaxEvents 200

# Quick summary: which providers are loudest?
$appErrors |
    Group-Object ProviderName |
    Sort-Object Count -Descending |
    Select-Object -First 10 Count, Name |
    Format-Table -AutoSize
```

### Step 2 — Drill into the noisiest provider

```powershell
# Assuming '.NET Runtime' appeared at the top of the previous summary
$appErrors |
    Where-Object ProviderName -eq '.NET Runtime' |
    Select-Object TimeCreated, Id, Message |
    Format-List
```

### Step 3 — Check whether a service state change coincides

```powershell
# Event 7034 = service terminated unexpectedly
Get-LogEventsById -LogName System -EventId 7034 -MaxEvents 50 |
    Select-Object TimeCreated, ProviderName, Message |
    Format-List
```

### Step 4 — Export all evidence

```powershell
$timestamp = Get-Date -Format 'yyyyMMdd-HHmm'

Get-RecentLogErrors -LogName Application -MaxEvents 200 |
    Export-SafeOpsReport -Format CSV -Path ".\reports\$timestamp-app-errors.csv"

Get-LogEventsById -LogName System -EventId 7034 -MaxEvents 50 |
    Export-SafeOpsReport -Format JSON -Path ".\reports\$timestamp-svc-crashes.json"
```

Attach both files to the development team's incident report.

---

## Scenario C — Investigating a Specific Event ID

**Situation:** Change management has requested evidence of all Service Control Manager state
changes (Event ID 7036) over recent history to verify a maintenance window was clean.

### Step 1 — Query by Event ID

```powershell
# Retrieve the 500 most recent Service Control Manager state-change events
$stateChanges = Get-LogEventsById -LogName System -EventId 7036 -MaxEvents 500

# How many events were found?
Write-Host "Found $($stateChanges.Count) state-change events."
```

### Step 2 — Filter to the relevant services

```powershell
# Focus on the three allowlisted services
$relevant = $stateChanges | Where-Object {
    $_.Message -match 'Print Spooler|Windows Update|Microsoft Defender'
}

$relevant | Select-Object TimeCreated, Message | Format-List
```

### Step 3 — Check current state of all allowlisted services

```powershell
Get-AllowlistedServiceStatus -Name Spooler, wuauserv, WinDefend | Format-Table
```

### Step 4 — Export for change-management record

```powershell
$timestamp = Get-Date -Format 'yyyyMMdd-HHmm'

$stateChanges |
    Export-SafeOpsReport -Format CSV  -Path ".\reports\$timestamp-event7036-all.csv"

$relevant |
    Export-SafeOpsReport -Format JSON -Path ".\reports\$timestamp-event7036-allowlisted.json"

Get-AllowlistedServiceStatus -Name Spooler, wuauserv, WinDefend |
    Export-SafeOpsReport -Format JSON -Path ".\reports\$timestamp-service-snapshot.json"
```

Attach all three files to the change-management ticket and note the window start/end timestamps.

---

## Troubleshooting

| Symptom | Likely cause | Resolution |
|---|---|---|
| `SecurityException: Service 'X' is not on the SafeOps allowlist` | Service name is not in the approved list | Only `Spooler`, `wuauserv`, and `WinDefend` are permitted. Escalate if a different service needs access. |
| `Get-WinEvent` returns no results | No matching events in the time window | Increase `-MaxEvents`, or the log has been cleared. Check `Get-WinEvent -ListLog System` to confirm. |
| `Access denied` on `Restart-Service` or `Set-Service` | Insufficient Windows privileges | The command requires the `Service Control` right. Run the session as an administrator or request privilege elevation through your organisation's PAM process. |
| Log file not created | Module was not fully loaded | Run `Import-Module` again and verify `$Script:SafeOpsLogDir` resolves to a writable path. |
| `-WhatIf` output shows a different service name | Tab-completion picked the wrong `ValidateSet` value | Always confirm the `-Name` argument in the `-WhatIf` output before dropping `-WhatIf`. |

---

## Audit Log

All operations are appended to `SafeOpsToolkit\logs\safeops.log` in UTC:

```
2026-05-21T08:42:11Z [INFO] Queried service status Service=Spooler Status=Stopped
2026-05-21T08:43:02Z [INFO] Restarting service Service=Spooler
2026-05-21T08:43:08Z [INFO] Service restart complete Service=Spooler Status=Running
2026-05-21T08:43:10Z [INFO] Report exported Format=JSON Path=C:\reports\service-status.json Count=1
```

The log is plain text, UTF-8 encoded, and can be ingested by any SIEM or log aggregator.
Do **not** write secrets, credentials, or PII to the `Context` parameter of `Write-SafeOpsLog`.
