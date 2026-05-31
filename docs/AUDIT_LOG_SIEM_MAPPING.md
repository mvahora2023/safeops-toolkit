# SafeOps Audit Log — SIEM Field Mapping

Author: Mahmadarsh Vahora  
Last Updated: 2025-05-30  
Purpose: Documents how Write-SafeOpsLog fields translate to CEF/Syslog standard fields and identifies SOC detection use cases for each field.

---

## Write-SafeOpsLog Output Format

SafeOps logs are emitted as structured objects with the following fields, serialized to a flat log line or JSON depending on sink configuration:

```
[2025-05-30T14:23:11Z] Actor=DOMAIN\jsmith Action=Invoke-SafeCommand Target=C:\Scripts\cleanup.ps1 Outcome=ALLOWED Severity=INFO
```

---

## Field Mapping Table

| SafeOps Field | Type | Example Value | CEF Field | CEF Key | Syslog / RFC 5424 Equivalent | SOC Detection Use Case |
|---|---|---|---|---|---|---|
| `Timestamp` | DateTime (ISO 8601 UTC) | `2025-05-30T14:23:11Z` | `rt` (Receipt Time) | `rt` | `TIMESTAMP` (NILVALUE if missing) | Timeline reconstruction; out-of-hours execution alerts |
| `Actor` | String (DOMAIN\User) | `DOMAIN\jsmith` | `suser` (Source Username) | `suser` | Structured Data `[user id="..."]` | Privilege abuse detection; anomalous user activity |
| `Action` | String (cmdlet/function name) | `Invoke-SafeCommand` | `act` (Device Action) | `act` | Structured Data `[action id="..."]` | Blocked command frequency; denied-action spike detection |
| `Target` | String (file/resource path or object) | `C:\Scripts\cleanup.ps1` | `filePath` | `fpath` | Structured Data `[target id="..."]` | Sensitive path access detection; scope violation |
| `Outcome` | Enum: ALLOWED / DENIED / ERROR | `DENIED` | `outcome` | `outcome` | Structured Data `[outcome id="..."]` | Denied-action threshold alerting; error spike = tool misuse |
| `Severity` | Enum: INFO / WARN / ERROR / CRITICAL | `WARN` | `severity` | `sev` | `SEVERITY` (PRI field in Syslog) | Escalation routing; CRITICAL events auto-page on-call |
| *(implicit)* `HostName` | String (auto-populated by logger) | `WORKSTATION-42` | `dhost` (Destination Host) | `dhost` | `HOSTNAME` | Lateral movement detection; single-actor multi-host pattern |
| *(implicit)* `ProcessID` | Int (PowerShell PID) | `4892` | `dpid` | `dpid` | `PROCID` | Process injection detection; PID correlation with EDR |
| *(implicit)* `ScriptPath` | String (calling script full path) | `C:\SafeOps\SafeOps.psm1` | `cs1` (Custom String 1) | `cs1Label=ScriptPath` | Structured Data extension | Unsigned script execution detection |

---

## SIEM Ingestion Configuration

### Option 1: Splunk Universal Forwarder (Recommended for Windows)

Add to `inputs.conf` on the SafeOps host:

```ini
[monitor://C:\ProgramData\SafeOps\Logs\safeops.log]
index = safeops
sourcetype = safeops_audit
host_segment = 1
```

Add to `props.conf` on the indexer:

```ini
[safeops_audit]
TIME_PREFIX = \[
TIME_FORMAT = %Y-%m-%dT%H:%M:%SZ
MAX_TIMESTAMP_LOOKAHEAD = 25
SHOULD_LINEMERGE = false
KV_MODE = auto
REPORT-safeops_fields = safeops_kv_extract

[source::...safeops.log]
sourcetype = safeops_audit
```

Add to `transforms.conf`:

```ini
[safeops_kv_extract]
REGEX = Actor=(?P<Actor>[^\s]+)\s+Action=(?P<Action>[^\s]+)\s+Target=(?P<Target>[^\s]+)\s+Outcome=(?P<Outcome>[^\s]+)\s+Severity=(?P<Severity>[^\s]+)
FORMAT = Actor::$1 Action::$2 Target::$3 Outcome::$4 Severity::$5
```

### Option 2: Windows Event Log Forwarding (WEF) via PowerShell

Redirect SafeOps log entries to the Application event log using `Write-EventLog`:

```powershell
# Add to Write-SafeOpsLog function
Write-EventLog -LogName Application -Source "SafeOps" -EventId 9001 -EntryType Information -Message (
    "Actor=$Actor Action=$Action Target=$Target Outcome=$Outcome Severity=$Severity"
)
```

Then collect via standard WinEventLog WEF subscription or Splunk WinEventLog input.

---

## Recommended SIEM Alerts on SafeOps Data

| Alert Name | Detection Logic | Threshold | Severity |
|---|---|---|---|
| SafeOps Blocked Command Spike | `Outcome=DENIED` count per Actor per hour | > 5 in 1 hour | Medium |
| SafeOps After-Hours Execution | `Outcome=ALLOWED` AND Timestamp outside 06:00–22:00 local | Any occurrence | Medium |
| SafeOps CRITICAL Severity | `Severity=CRITICAL` | Any occurrence | High |
| SafeOps Multi-Host Actor | Same Actor on > 2 distinct HostNames in 1 hour | > 2 hosts | High |
| SafeOps Repeated Denied Target | Same Target appears in DENIED events 3+ times | 3 in 30 min | Medium |

---

## Compliance Mapping

| SafeOps Log Field | NIST CSF Control | PCI DSS Requirement | SOC 2 Trust Criterion |
|---|---|---|---|
| Actor + Action + Timestamp | DE.CM-3 (Personnel activity monitoring) | Req 10.2.1 (User access to audit logs) | CC6.2 (Prior to issuing system credentials) |
| Outcome=DENIED | PR.AC-4 (Access permissions managed) | Req 7.1 (Limit access to system components) | CC6.3 (Access authorization) |
| Severity=CRITICAL | RS.CO-2 (Incidents reported per criteria) | Req 12.10.1 (Incident response plan) | CC7.4 (Security incidents evaluated) |
