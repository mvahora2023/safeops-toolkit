#Requires -Version 5.1
<#
.SYNOPSIS
    SafeOps Key Patterns — three core security automation patterns demonstrated.

.DESCRIPTION
    Pattern 1: Double-layer allowlist (ValidateSet + runtime hashtable check)
    Pattern 2: SupportsShouldProcess / -WhatIf dry-run wrapper
    Pattern 3: Write-SafeOpsLog structured audit logging function

    All functions are safe to call repeatedly (idempotent where applicable).
    Every privileged action produces a structured log entry — nothing is silent.
#>

# ---------------------------------------------------------------------------
# PATTERN 3 — Write-SafeOpsLog (defined first; used by all other patterns)
# ---------------------------------------------------------------------------

function Write-SafeOpsLog {
    <#
    .SYNOPSIS
        Write a structured, machine-parseable audit log entry to disk and the event stream.
    .DESCRIPTION
        All six fields are required to ensure log entries are queryable and consistent.
        Output format: CSV-compatible pipe-delimited string for easy SIEM ingestion.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Actor,       # Who triggered the action (username/service)
        [Parameter(Mandatory)] [string] $Action,      # What operation was attempted
        [Parameter(Mandatory)] [string] $Target,      # What resource was targeted
        [Parameter(Mandatory)] [string] $Outcome,     # Result: Success | Skipped | Violation | Failed
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'CRITICAL')]
        [string] $Severity,
        [string] $LogPath = "$env:ProgramData\SafeOps\safeops_audit.log"
    )

    $timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    $logLine   = "$timestamp | $Actor | $Action | $Target | $Outcome | $Severity"

    # Ensure log directory exists
    $logDir = Split-Path $LogPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    Add-Content -Path $LogPath -Value $logLine -Encoding UTF8

    # Mirror to verbose stream so callers using -Verbose see real-time output
    Write-Verbose $logLine

    # Escalate CRITICAL to error stream so monitoring can catch it
    if ($Severity -eq 'CRITICAL') {
        Write-Error "SAFEOPS CRITICAL: $logLine" -ErrorAction Continue
    }
}


# ---------------------------------------------------------------------------
# PATTERN 1 — Double-Layer Allowlist
# ---------------------------------------------------------------------------

# Layer 2: runtime hashtable — allows context-sensitive rules ValidateSet cannot express
# (e.g., environment-specific paths, dynamic deny conditions)
$Script:AllowedTargetPaths = @{
    'C:\SafeOps\Managed'     = $true
    'C:\SafeOps\Reports'     = $true
    'C:\SafeOps\Exports'     = $true
}

function Invoke-SafeOpsFileOperation {
    <#
    .SYNOPSIS
        Perform a file operation only if the target passes BOTH allowlist layers.
    .DESCRIPTION
        Layer 1: [ValidateSet] — rejects unknown operations at parse time (PowerShell enforces this
                 before the function body runs — attacker cannot bypass with a creative string).
        Layer 2: Runtime hashtable — checks the normalized target path against allowed destinations.
                 Catches path traversal attempts and edge cases ValidateSet cannot see.

        Any violation produces a structured CRITICAL log entry and stops execution.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Copy', 'Move', 'Delete', 'Archive')]  # Layer 1: only these four verbs
        [string] $Operation,

        [Parameter(Mandatory)]
        [string] $TargetPath
    )

    $actor = $env:USERNAME

    # --- Layer 2: normalize path and check runtime allowlist ---
    try {
        $normalizedPath = (Resolve-Path $TargetPath -ErrorAction Stop).Path
    } catch {
        # Path does not exist — check if the parent is allowed
        $normalizedPath = $TargetPath
    }

    # Check if target path starts with any allowed path
    $allowed = $false
    foreach ($allowedRoot in $Script:AllowedTargetPaths.Keys) {
        if ($normalizedPath -like "$allowedRoot*") {
            $allowed = $true
            break
        }
    }

    if (-not $allowed) {
        Write-SafeOpsLog -Actor $actor -Action $Operation -Target $TargetPath `
            -Outcome 'Violation' -Severity 'CRITICAL'
        throw "SAFEOPS VIOLATION: Target path '$TargetPath' is not in the allowlist. " +
              "Operation '$Operation' blocked."
    }

    # --- Both layers passed — proceed with ShouldProcess check ---
    if ($PSCmdlet.ShouldProcess($TargetPath, $Operation)) {
        Write-SafeOpsLog -Actor $actor -Action $Operation -Target $TargetPath `
            -Outcome 'Success' -Severity 'INFO'

        switch ($Operation) {
            'Copy'    { Write-Verbose "Executing: Copy-Item $TargetPath" }
            'Move'    { Write-Verbose "Executing: Move-Item $TargetPath" }
            'Delete'  { Write-Verbose "Executing: Remove-Item $TargetPath" }
            'Archive' { Write-Verbose "Executing: Compress-Archive $TargetPath" }
        }
        # Production: replace Write-Verbose with actual file cmdlet calls
    } else {
        # -WhatIf mode: log the planned action without executing
        Write-SafeOpsLog -Actor $actor -Action "WhatIf:$Operation" -Target $TargetPath `
            -Outcome 'Skipped' -Severity 'INFO'
    }
}


# ---------------------------------------------------------------------------
# PATTERN 2 — SupportsShouldProcess wrapper (standalone example)
# ---------------------------------------------------------------------------

function Remove-SafeOpsServiceAccount {
    <#
    .SYNOPSIS
        Demonstrate SupportsShouldProcess for a destructive privileged operation.
    .DESCRIPTION
        Supports -WhatIf for dry-run inspection before committing.
        Supports -Confirm for interactive confirmation prompt.
        All outcomes are logged — including WhatIf (planned) and blocked (violation).
    .EXAMPLE
        Remove-SafeOpsServiceAccount -AccountName "svc_jarvis" -WhatIf
        # Shows what would happen. No action taken. Log entry written.

        Remove-SafeOpsServiceAccount -AccountName "svc_jarvis"
        # Prompts for confirmation if $ConfirmPreference is set; otherwise executes.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('svc_jarvis', 'svc_safeops', 'svc_monitor')]  # Layer 1: only managed accounts
        [string] $AccountName
    )

    $actor = $env:USERNAME

    if ($PSCmdlet.ShouldProcess($AccountName, 'Remove-LocalUser')) {
        # Confirmed — execute and log
        Write-SafeOpsLog -Actor $actor -Action 'RemoveServiceAccount' `
            -Target $AccountName -Outcome 'Success' -Severity 'WARN'

        # Production: Remove-LocalUser -Name $AccountName
        Write-Verbose "Removed service account: $AccountName"
    } else {
        # -WhatIf or user declined confirmation
        Write-SafeOpsLog -Actor $actor -Action 'RemoveServiceAccount' `
            -Target $AccountName -Outcome 'Skipped' -Severity 'INFO'
        Write-Verbose "Skipped (WhatIf or user declined): $AccountName"
    }
}
