function Set-AllowlistedServiceStartupType {
    <#
    .SYNOPSIS
        Sets the startup type of an allowlisted Windows service.

    .DESCRIPTION
        Validates the service against the SafeOps allowlist, then changes the Windows
        Service startup type. Supports -WhatIf and -Confirm so the change can be
        previewed or gated on interactive approval before it is applied.

    .PARAMETER Name
        The allowlisted service to modify. Must be one of: Spooler, wuauserv, WinDefend.

    .PARAMETER StartupType
        The desired startup type: Automatic, Manual, or Disabled.

    .OUTPUTS
        PSCustomObject with properties: Name, StartType.

    .EXAMPLE
        Set-AllowlistedServiceStartupType -Name Spooler -StartupType Manual

    .EXAMPLE
        Set-AllowlistedServiceStartupType -Name wuauserv -StartupType Disabled -WhatIf

    .EXAMPLE
        Set-AllowlistedServiceStartupType -Name WinDefend -StartupType Automatic -Confirm

    .NOTES
        Requires Service Control rights (Administrator on most Windows configurations).
        The change takes effect immediately; no reboot is required.
        The requested startup type is logged before and after execution in
        SafeOpsToolkit\logs\safeops.log.
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('Spooler', 'wuauserv', 'WinDefend')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateSet('Automatic', 'Manual', 'Disabled')]
        [string] $StartupType
    )

    Assert-SafeOpsAllowed -ServiceName $Name

    if ($PSCmdlet.ShouldProcess($Name, "Set startup type to '$StartupType'")) {
        Write-SafeOpsLog -Level INFO -Message "Changing service startup type" -Context @{ Service = $Name; StartupType = $StartupType }

        try {
            Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
        } catch {
            Write-SafeOpsLog -Level ERROR -Message "Failed to set startup type" -Context @{ Service = $Name }
            throw
        }

        Write-SafeOpsLog -Level INFO -Message "Startup type changed" -Context @{ Service = $Name; StartupType = $StartupType }

        ConvertTo-SafeOpsResult -Properties ([ordered] @{
            Name      = $Name
            StartType = $StartupType
        })
    }
}
