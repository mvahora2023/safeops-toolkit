function Get-LogEventsById {
    <#
    .SYNOPSIS
        Retrieves Windows Event Log entries that match a specific Event ID.

    .DESCRIPTION
        Uses Get-WinEvent with a filter hashtable to return only entries whose Id matches
        the value supplied. Any level (Error, Warning, Information, etc.) is returned;
        use Get-RecentLogErrors when you specifically want Error-level entries.
        If no matching events exist, the function returns nothing and writes a Verbose message.

    .PARAMETER LogName
        The Windows Event Log to query: System or Application.

    .PARAMETER EventId
        The numeric Event ID to filter on.

    .PARAMETER MaxEvents
        Maximum number of events to return. Must be between 1 and 500. Default: 100.

    .OUTPUTS
        PSCustomObject with properties: TimeCreated, Id, ProviderName, LevelDisplayName, Message.

    .EXAMPLE
        Get-LogEventsById -LogName System -EventId 7036

    .EXAMPLE
        Get-LogEventsById -LogName Application -EventId 1000 -MaxEvents 25

    .EXAMPLE
        Get-LogEventsById -LogName System -EventId 7036 | Select-Object TimeCreated, Message

    .NOTES
        Requires Event Log read access (granted to standard users by default).
        Returns events at any severity level; use Get-RecentLogErrors to restrict to Error level.
        Returns nothing — without raising an error — when no matching events are found.
        Each invocation is recorded in SafeOpsToolkit\logs\safeops.log.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('System', 'Application')]
        [string] $LogName,

        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [int] $EventId,

        [ValidateRange(1, 500)]
        [int] $MaxEvents = 100
    )

    Write-SafeOpsLog -Level INFO -Message "Querying events by ID" -Context @{ LogName = $LogName; EventId = $EventId; MaxEvents = $MaxEvents }

    $events = Get-WinEvent -FilterHashtable @{
        LogName = $LogName
        Id      = $EventId
    } -MaxEvents $MaxEvents -ErrorAction SilentlyContinue

    if (-not $events) {
        Write-Verbose "No events with ID $EventId found in '$LogName'."
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
