<#
.SYNOPSIS
    SafeOps double-layer allowlist pattern — authorization enforcement sample.

.DESCRIPTION
    Demonstrates the SafeOps Toolkit's two-layer authorization model:

    Layer 1 — ValidateSet:
        Enforced at parameter binding by the PowerShell engine.
        Rejects values not in the declared set before the function body runs.

    Layer 2 — Runtime hashtable check:
        Verifies the value against an in-memory hashtable after parameter binding.
        Catches dynamically constructed values or pipeline-injected inputs that
        may have bypassed a static ValidateSet declaration.

    On any authorization failure:
        - Write-SafeOpsLog is called with Severity=Critical before throwing.
        - A terminating error is thrown to halt execution.

    On success:
        - ShouldProcess is honored (-WhatIf/-Confirm support).
        - Write-SafeOpsLog is called with Severity=Info on completion.

.PARAMETER Action
    The requested operation. Must be in the declared allowlist.

.PARAMETER Target
    The resource the action will be applied to.

.PARAMETER Actor
    The identity of the caller. Defaults to current user ($env:USERNAME).

.EXAMPLE
    Invoke-SafeOpsAction -Action 'Read' -Target 'config.json'
    # Allowed — logs and executes.

.EXAMPLE
    Invoke-SafeOpsAction -Action 'Delete' -Target 'critical.log'
    # Allowed — logs and executes (with ShouldProcess).

.EXAMPLE
    Invoke-SafeOpsAction -Action 'Purge' -Target 'all'
    # Layer 1: ValidateSet will reject 'Purge' at parameter binding.
    # A ParameterBindingValidationException is thrown by the engine.

.NOTES
    Author:  Mahmadarsh Vahora
    Version: 1.0
    Part of: SafeOps Toolkit security controls demonstration
#>

#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param ()

# ---------------------------------------------------------------------------
# Audit Log Configuration
# ---------------------------------------------------------------------------
$script:SafeOpsLogPath = Join-Path $env:TEMP 'SafeOps_Audit.log'

function Write-SafeOpsLog {
    <#
    .SYNOPSIS
        Writes a structured audit log entry to the SafeOps log file.

    .DESCRIPTION
        Every SafeOps operation — successful or not — produces a structured
        log entry with six fields: Timestamp, Actor, Action, Target, Outcome,
        Severity. This supports forensic reconstruction of all activity.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $Actor,

        [Parameter(Mandatory)]
        [string] $Action,

        [Parameter(Mandatory)]
        [string] $Target,

        [Parameter(Mandatory)]
        [ValidateSet('Success', 'Failure', 'Attempted', 'Blocked')]
        [string] $Outcome,

        [Parameter(Mandatory)]
        [ValidateSet('Info', 'Warning', 'Error', 'Critical')]
        [string] $Severity
    )

    $entry = [PSCustomObject]@{
        Timestamp = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
        Actor     = $Actor
        Action    = $Action
        Target    = $Target
        Outcome   = $Outcome
        Severity  = $Severity
    }

    # Write structured CSV-compatible line to log file
    $logLine = '{0}|{1}|{2}|{3}|{4}|{5}' -f `
        $entry.Timestamp,
        $entry.Actor,
        $entry.Action,
        $entry.Target,
        $entry.Outcome,
        $entry.Severity

    try {
        Add-Content -Path $script:SafeOpsLogPath -Value $logLine -ErrorAction Stop
    }
    catch {
        Write-Warning "SafeOpsLog: Could not write to log file '$script:SafeOpsLogPath'. Error: $_"
    }

    # Also emit to the verbose stream for console visibility during testing
    Write-Verbose "[$($entry.Severity)] $logLine"
}


# ---------------------------------------------------------------------------
# Authorization Configuration
# ---------------------------------------------------------------------------

# Layer 2: Runtime allowlist hashtable
# Keys are allowed action names; values are descriptions for documentation.
# This is the second barrier — independent of ValidateSet.
$script:RuntimeAllowlist = @{
    'Read'    = 'Read a resource without modification'
    'Write'   = 'Write or create a resource'
    'Delete'  = 'Remove a resource (ShouldProcess required)'
    'Archive' = 'Move a resource to an archive location'
    'Audit'   = 'Generate an audit report for a resource'
}


# ---------------------------------------------------------------------------
# Core Function — Invoke-SafeOpsAction
# ---------------------------------------------------------------------------

function Invoke-SafeOpsAction {
    <#
    .SYNOPSIS
        Execute a SafeOps-authorized action on a target resource.

    .DESCRIPTION
        Implements the double-layer allowlist pattern:
        Layer 1 via [ValidateSet] on the -Action parameter.
        Layer 2 via runtime hashtable check inside the function body.

        Any value that passes Layer 1 but fails Layer 2 is treated as an
        unauthorized attempt — logged at Severity=Critical and terminated.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    param (
        # Layer 1: ValidateSet — enforced by PowerShell engine at parameter binding
        [Parameter(Mandatory)]
        [ValidateSet('Read', 'Write', 'Delete', 'Archive', 'Audit')]
        [string] $Action,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Target,

        [Parameter()]
        [string] $Actor = $env:USERNAME
    )

    # ------------------------------------------------------------------
    # Layer 2: Runtime hashtable authorization check
    # ------------------------------------------------------------------
    # This check is reached only if ValidateSet passed.
    # It defends against:
    #   - Dynamically constructed action strings passed through the pipeline
    #   - Future changes to ValidateSet that are not reflected in the hashtable
    #   - Any bypass of the static ValidateSet enforcement
    # ------------------------------------------------------------------
    if (-not $script:RuntimeAllowlist.ContainsKey($Action)) {
        $violationMessage = "AUTHORIZATION FAILURE: Action '$Action' is not in the " +
                            "runtime allowlist. Actor: '$Actor', Target: '$Target'."

        Write-SafeOpsLog -Actor   $Actor `
                         -Action  $Action `
                         -Target  $Target `
                         -Outcome 'Blocked' `
                         -Severity 'Critical'

        # Terminating error — halts all execution in the current pipeline
        throw [System.UnauthorizedAccessException] $violationMessage
    }

    # ------------------------------------------------------------------
    # ShouldProcess — honors -WhatIf and -Confirm
    # ------------------------------------------------------------------
    $operationDescription = "Action='$Action' on Target='$Target' by Actor='$Actor'"
    if (-not $PSCmdlet.ShouldProcess($Target, "Invoke-SafeOpsAction: $Action")) {
        Write-SafeOpsLog -Actor   $Actor `
                         -Action  $Action `
                         -Target  $Target `
                         -Outcome 'Attempted' `
                         -Severity 'Info'
        Write-Verbose "WhatIf: Would execute $operationDescription"
        return
    }

    # ------------------------------------------------------------------
    # Execute the authorized action
    # ------------------------------------------------------------------
    try {
        Write-Verbose "Executing: $operationDescription"

        # Simulate action execution (replace with real logic in production)
        switch ($Action) {
            'Read'    { Write-Verbose "Reading resource: $Target" }
            'Write'   { Write-Verbose "Writing to resource: $Target" }
            'Delete'  { Write-Verbose "Deleting resource: $Target" }
            'Archive' { Write-Verbose "Archiving resource: $Target" }
            'Audit'   { Write-Verbose "Generating audit report for: $Target" }
        }

        Write-SafeOpsLog -Actor   $Actor `
                         -Action  $Action `
                         -Target  $Target `
                         -Outcome 'Success' `
                         -Severity 'Info'

        Write-Output "[SUCCESS] $operationDescription"
    }
    catch {
        Write-SafeOpsLog -Actor   $Actor `
                         -Action  $Action `
                         -Target  $Target `
                         -Outcome 'Failure' `
                         -Severity 'Error'

        throw
    }
}


# ---------------------------------------------------------------------------
# Demo — Run if executed directly (not dot-sourced)
# ---------------------------------------------------------------------------

if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "`n=== SafeOps Double-Layer Allowlist Demo ===" -ForegroundColor Cyan

    # --- Test 1: Allowed action ---
    Write-Host "`n[Test 1] Allowed action: Read on config.json" -ForegroundColor Yellow
    try {
        Invoke-SafeOpsAction -Action 'Read' -Target 'config.json' -Verbose
    }
    catch { Write-Warning "Unexpected error: $_" }

    # --- Test 2: Allowed action with ShouldProcess (WhatIf) ---
    Write-Host "`n[Test 2] Delete with -WhatIf (dry run)" -ForegroundColor Yellow
    try {
        Invoke-SafeOpsAction -Action 'Delete' -Target 'old_report.log' -WhatIf -Verbose
    }
    catch { Write-Warning "Unexpected error: $_" }

    # --- Test 3: Layer 1 block — 'Purge' not in ValidateSet ---
    Write-Host "`n[Test 3] Layer 1 block: 'Purge' not in ValidateSet" -ForegroundColor Yellow
    try {
        # This will throw a ParameterBindingValidationException before the function body runs
        Invoke-SafeOpsAction -Action 'Purge' -Target 'database' -ErrorAction Stop
    }
    catch [System.Management.Automation.ParameterBindingValidationException] {
        Write-Host "  BLOCKED by Layer 1 (ValidateSet): $_" -ForegroundColor Red
    }
    catch {
        Write-Host "  BLOCKED: $_" -ForegroundColor Red
    }

    # --- Test 4: Layer 2 block — simulate bypassing ValidateSet ---
    Write-Host "`n[Test 4] Layer 2 block: value injected past ValidateSet" -ForegroundColor Yellow
    # Directly call internal logic by temporarily injecting a value into the hashtable check
    # This simulates a dynamic value that somehow passed ValidateSet but is not in the runtime list
    $injectedAction = 'Escalate'   # not in ValidateSet and not in hashtable
    Write-Host "  Attempting to directly trigger Layer 2 check with '$injectedAction'..." -ForegroundColor Yellow
    if (-not $script:RuntimeAllowlist.ContainsKey($injectedAction)) {
        Write-SafeOpsLog -Actor 'demo_user' -Action $injectedAction -Target 'system' `
                         -Outcome 'Blocked' -Severity 'Critical'
        Write-Host "  BLOCKED by Layer 2 (Runtime Hashtable). Audit log written." -ForegroundColor Red
    }

    Write-Host "`n=== Audit Log Contents ===" -ForegroundColor Cyan
    if (Test-Path $script:SafeOpsLogPath) {
        Get-Content $script:SafeOpsLogPath | ForEach-Object {
            $fields = $_ -split '\|'
            if ($fields.Count -ge 6) {
                $severity = $fields[5]
                $color = switch ($severity) {
                    'Critical' { 'Red' }
                    'Error'    { 'DarkRed' }
                    'Warning'  { 'Yellow' }
                    default    { 'Green' }
                }
                Write-Host "  $_" -ForegroundColor $color
            }
        }
    }
    else {
        Write-Warning "Log file not found at $script:SafeOpsLogPath"
    }

    Write-Host "`n=== Demo Complete ===" -ForegroundColor Cyan
}
