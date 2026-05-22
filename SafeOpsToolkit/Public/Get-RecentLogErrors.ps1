function Get-RecentLogErrors {
    <#
    .SYNOPSIS
        Retrieves recent Error-level entries from a Windows Event Log.

    .DESCRIPTION
        Uses Get-WinEvent with a filter hashtable to query the specified log for entries
        at Level 2 (Error). Returns a PSCustomObject per event with a consistent schema.
        If no matching events exist, the function returns nothing and writes a Verbose message.

    .PARAMETER LogName
        The Windows Event Log to query: System or Application.

    .PARAMETER MaxEvents
        Maximum number of events to return. Must be between 1 and 500. Default: 50.

    .OUTPUTS
        PSCustomObject with properties: TimeCreated, Id, ProviderName, LevelDisplayName, Message.

    .EXAMPLE
        Get-RecentLogErrors -LogName System

    .EXAMPLE
        Get-RecentLogErrors -LogName Application -MaxEvents 100

    .EXAMPLE
        Get-RecentLogErrors -LogName System -MaxEvents 10 | Export-SafeOpsReport -Format JSON -Path .\errors.json

    .NOTES
        Requires Event Log read access (granted to standard users by default).
        Queries Level 2 (Error) only; Critical events (Level 1) are not included.
        Returns nothing — without raising an error — when no matching events are found.
        Each invocation is recorded in SafeOpsToolkit\logs\safeops.log.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('System', 'Application')]
        [string] $LogName,

        [ValidateRange(1, 500)]
        [int] $MaxEvents = 50
    )

    Write-SafeOpsLog -Level INFO -Message "Querying recent errors" -Context @{ LogName = $LogName; MaxEvents = $MaxEvents }

    $events = Get-WinEvent -FilterHashtable @{
        LogName = $LogName
        Level   = 2   # Error (1=Critical, 2=Error, 3=Warning, 4=Information)
    } -MaxEvents $MaxEvents -ErrorAction SilentlyContinue

    if (-not $events) {
        Write-Verbose "No Error-level events found in '$LogName'."
        return
    }

    foreach ($evt in $events) {
        ConvertTo-SafeOpsResult -Properties ([ordered] @{
            TimeCreated      = $evt.TimeCreated
            Id               = $evt.Id
            ProviderName     = $evt.ProviderName
            LevelDisplayName = $evt.LevelDisplayName
            Message          = $evt.Message
        })
    }
}
