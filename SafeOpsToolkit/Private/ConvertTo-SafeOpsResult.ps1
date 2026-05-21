function ConvertTo-SafeOpsResult {
    <#
    .SYNOPSIS
        Converts a hashtable of properties into a typed PSCustomObject result.

    .DESCRIPTION
        All public commands funnel their output through this function to guarantee a
        consistent output type. Callers pass an ordered hashtable; this function stamps
        it as [PSCustomObject] so downstream commands (Select-Object, Export-Csv, etc.)
        work predictably.

    .PARAMETER Properties
        An ordered or unordered hashtable whose keys become object properties.

    .EXAMPLE
        ConvertTo-SafeOpsResult -Properties @{ Name = 'Spooler'; Status = 'Running' }
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable] $Properties
    )

    process {
        [PSCustomObject] $Properties
    }
}
