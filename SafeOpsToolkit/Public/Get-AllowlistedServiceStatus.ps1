function Get-AllowlistedServiceStatus {
    <#
    .SYNOPSIS
        Returns the current status of one or more allowlisted Windows services.

    .DESCRIPTION
        Queries the Windows Service Control Manager for each requested service and returns
        a consistent PSCustomObject per service. Only services on the SafeOps allowlist
        (Spooler, wuauserv, WinDefend) may be queried.

    .PARAMETER Name
        One or more allowlisted service names to query. Accepts pipeline input.

    .OUTPUTS
        PSCustomObject with properties: Name, DisplayName, Status, StartType.

    .EXAMPLE
        Get-AllowlistedServiceStatus -Name Spooler

    .EXAMPLE
        'Spooler', 'wuauserv' | Get-AllowlistedServiceStatus

    .EXAMPLE
        Get-AllowlistedServiceStatus -Name Spooler, WinDefend | Format-Table

    .NOTES
        Requires Service Query rights (granted to standard users by default on most Windows
        configurations). Does not require Administrator privileges.
        Every call is recorded in SafeOpsToolkit\logs\safeops.log.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateSet('Spooler', 'wuauserv', 'WinDefend')]
        [string[]] $Name
    )

    process {
        foreach ($svcName in $Name) {
            Assert-SafeOpsAllowed -ServiceName $svcName

            try {
                $svc = Get-Service -Name $svcName -ErrorAction Stop
            } catch {
                Write-SafeOpsLog -Level ERROR -Message "Failed to query service" -Context @{ Service = $svcName }
                Write-Error "Could not retrieve service '$svcName': $($_.Exception.Message)"
                continue
            }

            Write-SafeOpsLog -Level INFO -Message "Queried service status" -Context @{ Service = $svcName; Status = $svc.Status }

            ConvertTo-SafeOpsResult -Properties ([ordered] @{
                Name        = $svc.Name
                DisplayName = $svc.DisplayName
                Status      = $svc.Status.ToString()
                StartType   = $svc.StartType.ToString()
            })
        }
    }
}
