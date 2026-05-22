function Export-SafeOpsReport {
    <#
    .SYNOPSIS
        Exports a collection of SafeOps result objects to a JSON or CSV file.

    .DESCRIPTION
        Accepts pipeline or direct input, collects all objects, then writes them to the
        path specified in -Path using the format specified in -Format. The parent directory
        is created if it does not already exist. Returns a summary object on success.

    .PARAMETER InputObject
        One or more PSCustomObjects to export. Accepts pipeline input.

    .PARAMETER Format
        Output format: JSON or CSV.

    .PARAMETER Path
        Destination file path. The file is created or overwritten. The parent directory
        is created automatically if it does not exist.

    .OUTPUTS
        PSCustomObject with properties: Path, Format, Count.

    .EXAMPLE
        Get-AllowlistedServiceStatus -Name Spooler, wuauserv | Export-SafeOpsReport -Format JSON -Path .\report.json

    .EXAMPLE
        Get-RecentLogErrors -LogName System | Export-SafeOpsReport -Format CSV -Path C:\Reports\errors.csv

    .EXAMPLE
        $results = Get-LogEventsById -LogName Application -EventId 1000
        Export-SafeOpsReport -InputObject $results -Format JSON -Path .\events.json

    .NOTES
        Existing files at the target path are silently overwritten without a backup.
        The parent directory is created automatically if it does not exist.
        Output is UTF-8 encoded. The export action (format and item count only, not the
        file path) is recorded in SafeOpsToolkit\logs\safeops.log.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object[]] $InputObject,

        [Parameter(Mandatory)]
        [ValidateSet('JSON', 'CSV')]
        [string] $Format,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    begin {
        $collected = [System.Collections.Generic.List[object]]::new()
    }

    process {
        foreach ($item in $InputObject) {
            $collected.Add($item)
        }
    }

    end {
        $parentDir = Split-Path -Path $Path -Parent
        if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        switch ($Format) {
            'JSON' {
                $collected | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding UTF8
            }
            'CSV' {
                $collected | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
            }
        }

        $resolvedPath = (Resolve-Path -LiteralPath $Path).Path
        Write-SafeOpsLog -Level INFO -Message "Report exported" -Context @{ Format = $Format; Path = $resolvedPath; Count = $collected.Count }

        ConvertTo-SafeOpsResult -Properties ([ordered] @{
            Path   = $resolvedPath
            Format = $Format
            Count  = $collected.Count
        })
    }
}
