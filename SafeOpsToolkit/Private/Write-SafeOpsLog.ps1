function Write-SafeOpsLog {
    <#
    .SYNOPSIS
        Appends a structured log line to the module's log file.

    .DESCRIPTION
        Writes a timestamped, level-tagged entry to logs\safeops.log relative to the
        module root. The log directory is created on first use. Do not pass secrets,
        credentials, or personally identifiable information in the Message or Context
        parameters — this function does not redact values.

    .PARAMETER Level
        Severity label: INFO, WARN, ERROR, or DEBUG.

    .PARAMETER Message
        Human-readable description of the operation. Must not contain secrets.

    .PARAMETER Context
        Optional hashtable of additional key=value pairs appended to the log line.

    .EXAMPLE
        Write-SafeOpsLog -Level INFO -Message 'Restarting service' -Context @{ Service = 'Spooler' }
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'DEBUG')]
        [string] $Level,

        [Parameter(Mandatory)]
        [string] $Message,

        [hashtable] $Context = @{}
    )

    # $Script:SafeOpsLogDir is set in SafeOpsToolkit.psm1 at module load time
    $logDir = $Script:SafeOpsLogDir
    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $contextStr = if ($Context.Count -gt 0) {
        ' ' + (($Context.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' ')
    } else { '' }

    $line = "$timestamp [$Level] $Message$contextStr"
    Add-Content -LiteralPath (Join-Path $logDir 'safeops.log') -Value $line -Encoding UTF8
}
