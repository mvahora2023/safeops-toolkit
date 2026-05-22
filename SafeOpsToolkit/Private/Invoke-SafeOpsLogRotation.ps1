function Invoke-SafeOpsLogRotation {
    <#
    .SYNOPSIS
        Rotates the SafeOps log file when it exceeds the configured size threshold.

    .DESCRIPTION
        If the specified log file is larger than MaxBytes, shifts existing generations
        (.1→.2, .2→.3, ...) and discards any generation beyond MaxGenerations before
        renaming the active log to .1. Called automatically by Write-SafeOpsLog before
        each write so callers never need to trigger rotation manually.

    .PARAMETER LogPath
        Full path to the active log file (safeops.log).

    .PARAMETER MaxBytes
        Size threshold in bytes. Rotation triggers when the file is >= this value.
        Default: 10 MB.

    .PARAMETER Generations
        Maximum number of rotated files to retain (safeops.log.1 through
        safeops.log.N). The oldest generation beyond this limit is deleted.
        Default: 5.

    .EXAMPLE
        Invoke-SafeOpsLogRotation -LogPath 'C:\Logs\safeops.log'

    .EXAMPLE
        Invoke-SafeOpsLogRotation -LogPath $logFile -MaxBytes 1MB -Generations 3
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string] $LogPath,

        [long] $MaxBytes    = 10MB,
        [int]  $Generations = 5
    )

    if (-not (Test-Path -LiteralPath $LogPath)) { return }
    if ((Get-Item -LiteralPath $LogPath).Length -lt $MaxBytes) { return }

    # Drop the oldest generation to make room for the shift.
    $oldest = "$LogPath.$Generations"
    if (Test-Path -LiteralPath $oldest) { Remove-Item -LiteralPath $oldest -Force }

    # Shift generations up one slot (iterate high-to-low to avoid overwriting).
    for ($gen = ($Generations - 1); $gen -ge 1; $gen--) {
        $src = "$LogPath.$gen"
        if (Test-Path -LiteralPath $src) {
            Rename-Item -LiteralPath $src `
                -NewName ([System.IO.Path]::GetFileName("$LogPath.$($gen + 1)")) -Force
        }
    }

    # Archive the active log as generation 1.
    Rename-Item -LiteralPath $LogPath `
        -NewName ([System.IO.Path]::GetFileName("$LogPath.1")) -Force
}
