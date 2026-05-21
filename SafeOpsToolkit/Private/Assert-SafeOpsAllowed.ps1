function Assert-SafeOpsAllowed {
    <#
    .SYNOPSIS
        Throws if the supplied service name is not on the SafeOps operations allowlist.

    .DESCRIPTION
        Central allowlist gate called by every public command that touches a Windows service.
        Raising the error here — rather than in each caller — ensures the check cannot be
        accidentally omitted when new public commands are added.

    .PARAMETER ServiceName
        The Windows service name to validate.

    .EXAMPLE
        Assert-SafeOpsAllowed -ServiceName 'Spooler'
        # passes silently

    .EXAMPLE
        Assert-SafeOpsAllowed -ServiceName 'SomeOtherService'
        # throws System.Security.SecurityException
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $ServiceName
    )

    # Single authoritative list — keep in sync with ValidateSet attributes in Public/*.ps1
    $allowlist = @('Spooler', 'wuauserv', 'WinDefend')

    if ($ServiceName -notin $allowlist) {
        throw [System.Security.SecurityException]::new(
            "Service '$ServiceName' is not on the SafeOps allowlist. " +
            "Permitted services: $($allowlist -join ', ')."
        )
    }
}
