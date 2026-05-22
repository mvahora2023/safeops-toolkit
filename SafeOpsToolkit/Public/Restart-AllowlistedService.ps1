function Restart-AllowlistedService {
    <#
    .SYNOPSIS
        Restarts an allowlisted Windows service safely, with -WhatIf/-Confirm support.

    .DESCRIPTION
        Validates the service is on the SafeOps allowlist before attempting a restart.
        Supports ShouldProcess so callers can use -WhatIf to preview the action or
        -Confirm to require interactive approval. The restart is performed with -Force
        to stop dependent services if necessary.

    .PARAMETER Name
        The allowlisted service to restart. Must be one of: Spooler, wuauserv, WinDefend.

    .OUTPUTS
        PSCustomObject with properties: Name, Status.

    .EXAMPLE
        Restart-AllowlistedService -Name Spooler

    .EXAMPLE
        Restart-AllowlistedService -Name wuauserv -WhatIf

    .EXAMPLE
        Restart-AllowlistedService -Name WinDefend -Confirm

    .NOTES
        Requires Service Control rights (Administrator on most Windows configurations).
        Passes -Force to Restart-Service, which stops dependent services first; dependents
        are not automatically restarted and may need to be started separately.
        Start and completion are both recorded in SafeOpsToolkit\logs\safeops.log.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Spooler', 'wuauserv', 'WinDefend')]
        [string] $Name
    )

    Assert-SafeOpsAllowed -ServiceName $Name

    if ($PSCmdlet.ShouldProcess($Name, 'Restart-Service')) {
        Write-SafeOpsLog -Level INFO -Message "Restarting service" -Context @{ Service = $Name }

        try {
            Restart-Service -Name $Name -Force -ErrorAction Stop
        } catch {
            Write-SafeOpsLog -Level ERROR -Message "Failed to restart service" -Context @{ Service = $Name }
            throw
        }

        $svc = Get-Service -Name $Name -ErrorAction Stop
        Write-SafeOpsLog -Level INFO -Message "Service restart complete" -Context @{ Service = $Name; Status = $svc.Status }

        ConvertTo-SafeOpsResult -Properties ([ordered] @{
            Name   = $svc.Name
            Status = $svc.Status.ToString()
        })
    }
}
