# MITRE ATT&CK Coverage Matrix — Mini SOC Lab

Author: Mahmadarsh Vahora  
Last Updated: 2025-05-30  
Scope: Priority techniques relevant to Windows endpoint environments  
Assessment Method: Manual analysis of detection rules, log sources, and triage reports

---

## Coverage Status Definitions

| Status | Meaning |
|---|---|
| **Detected** | Active detection rule exists; alert fires on technique execution; triage process documented |
| **Partial** | Some detection capability exists (e.g., one sub-technique covered, or relies on manual review) |
| **Not Detected** | No detection rule or monitoring capability; technique would execute without alert |

---

## Coverage Matrix

| # | Technique ID | Technique Name | Tactic | Coverage Status | Detection Method | Gap Priority |
|---|---|---|---|---|---|---|
| 1 | T1110 | Brute Force | Credential Access | **Detected** | Sigma rule (EventID 4625/4771 threshold); Splunk SPL query | — |
| 2 | T1110.001 | Password Guessing | Credential Access | **Detected** | Covered by T1110 rule; SubStatus 0xC000006A filter | — |
| 3 | T1110.003 | Password Spraying | Credential Access | **Detected** | Covered by T1110 rule; dc(Account_Name) > threshold | — |
| 4 | T1566 | Phishing | Initial Access | **Detected** | Sigma rule (parent-child process: Outlook/Teams → scripting engine) | — |
| 5 | T1566.001 | Spearphishing Attachment | Initial Access | **Detected** | Covered by T1566 rule | — |
| 6 | T1059.001 | PowerShell | Execution | **Detected** | Sigma rule (EventID 4104 ScriptBlock logging); pattern matching | — |
| 7 | T1027 | Obfuscated Files or Information | Defense Evasion | **Detected** | Covered by PowerShell Sigma rule; char obfuscation and Base64 patterns | — |
| 8 | T1053 | Scheduled Task/Job | Persistence, Execution | **Not Detected** | No monitoring of schtasks.exe creation or Task Scheduler event log (EventID 4698) | **High** |
| 9 | T1053.005 | Scheduled Task | Persistence | **Not Detected** | EventID 4698 (task created) not monitored; no Sigma rule for schtasks.exe spawning | **High** |
| 10 | T1547 | Boot or Logon Autostart Execution | Persistence | **Not Detected** | No monitoring of registry run keys (HKCU\...\Run) or startup folder modifications | **High** |
| 11 | T1547.001 | Registry Run Keys / Startup Folder | Persistence | **Not Detected** | No Sysmon registry monitoring configured; no EventID 4657 (registry modified) parsing | **High** |
| 12 | T1071 | Application Layer Protocol | Command and Control | **Not Detected** | No DNS monitoring, no HTTP/S beacon detection, no network traffic analysis | **Critical** |
| 13 | T1071.001 | Web Protocols (HTTP/S C2) | Command and Control | **Not Detected** | No proxy logs or DNS logs ingested; C2 beaconing would be invisible | **Critical** |
| 14 | T1078 | Valid Accounts | Defense Evasion, Persistence | **Partial** | Successful logons after failed attempts detectable via Splunk correlation; no dedicated rule for impossible travel or off-hours auth | **High** |
| 15 | T1078.002 | Domain Accounts | Defense Evasion | **Partial** | Domain logon type detected in failed-login rule; no baseline of normal behavior | **High** |
| 16 | T1055 | Process Injection | Defense Evasion, Privilege Escalation | **Not Detected** | No Sysmon EventID 8 (CreateRemoteThread) or EventID 10 (ProcessAccess) monitoring | **High** |
| 17 | T1055.001 | Dynamic-link Library Injection | Defense Evasion | **Not Detected** | DLL injection activity not captured without Sysmon configuration | **High** |
| 18 | T1003 | OS Credential Dumping | Credential Access | **Not Detected** | No monitoring for lsass.exe access (Sysmon EventID 10), no LSASS protection alerting | **Critical** |
| 19 | T1003.001 | LSASS Memory | Credential Access | **Not Detected** | LSASS process access not monitored; Mimikatz execution would generate no alert | **Critical** |
| 20 | T1190 | Exploit Public-Facing Application | Initial Access | **Not Detected** | No web application firewall logging, no IIS/Apache error log monitoring | **Critical** |
| 21 | T1486 | Data Encrypted for Impact (Ransomware) | Impact | **Not Detected** | No file system activity monitoring; mass file rename/encrypt events not detected | **Critical** |
| 22 | T1562 | Impair Defenses | Defense Evasion | **Partial** | SafeOps detects Add-MpPreference/Set-MpPreference via PowerShell rule; no coverage for service stop or GPO tamper | **High** |
| 23 | T1562.001 | Disable or Modify Tools | Defense Evasion | **Partial** | Defender CLI tampering detected via PowerShell rule only; sc.exe stop commands not monitored | **High** |
| 24 | T1021 | Remote Services | Lateral Movement | **Partial** | Lateral movement Splunk query (EventID 4624 type 3/10 multi-host correlation) exists; no dedicated Sigma rule | **Medium** |
| 25 | T1021.001 | Remote Desktop Protocol | Lateral Movement | **Partial** | Logon Type 10 included in lateral movement query; no dedicated RDP rule | **Medium** |

---

## Coverage Summary

| Status | Count | Percentage |
|---|---|---|
| Detected | 7 | 28% |
| Partial | 6 | 24% |
| Not Detected | 12 | 48% |
| **Total Assessed** | **25** | **100%** |

---

## Priority Gap Summary

| Priority | Count | Techniques |
|---|---|---|
| Critical | 5 | T1071, T1003, T1190, T1486, T1562 (partial) |
| High | 6 | T1053, T1547, T1078, T1055, T1562 (broader scope) |
| Medium | 2 | T1021 (partial coverage) |

**9 distinct technique families with gaps identified.** See `gap_remediation_plan.md` for prioritized remediation roadmap.
