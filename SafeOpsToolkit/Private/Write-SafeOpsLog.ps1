function Write-SafeOpsLog {
    <#
    .SYNOPSIS
        Appends a structured log line to the module's log file.

    .DESCRIPTION
        Writes a timestamped, level-tagged entry to logs\safeops.log relative to the
        module root. The log directory is created on first use.

        Context values whose keys match the sensitive-key pattern (password, token,
        secret, key, credential, apikey, accesstoken) are automatically replaced with
        '<redacted>' before writing. Never pass credentials in the Message parameter.

        Log files rotate automatically when safeops.log reaches 10 MB. Up to 5
        generations are retained (safeops.log.1 through safeops.log.5).

    .PARAMETER Level
        Severity label: INFO, WARN, ERROR, or DEBUG.

    .PARAMETER Message
        Human-readable description of the operation. Must not contain secrets.

    .PARAMETER Context
        Optional hashtable of additional key=value pairs appended to the log line.
        Keys matching the sensitive pattern are redacted; values are never evaluated
        for secret content beyond the key-name check.

    .EXAMPLE
        Write-SafeOpsLog -Level INFO -Message 'Restarting service' -Context @{ Service = 'Spooler' }

    .EXAMPLE
        Write-SafeOpsLog -Level ERROR -Message 'Restart failed' -Context @{ Service = 'Spooler' }
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

    $logDir  = $Script:SafeOpsLogDir
    $logFile = Join-Path $logDir 'safeops.log'

    if (-not (Test-Path -LiteralPath $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    Invoke-SafeOpsLogRotation -LogPath $logFile

    # Redact any context values whose keys resemble credential or secret names.
    $sensitivePattern = 'password|token|secret|key|credential|apikey|accesstoken'
    $safeContext = if ($Context.Count -gt 0) {
        $out = [ordered] @{}
        foreach ($pair in $Context.GetEnumerator()) {
            $out[$pair.Key] = if ($pair.Key -match $sensitivePattern) { '<redacted>' } else { $pair.Value }
        }
        $out
    }
    else { @{} }

    $timestamp  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $contextStr = if ($safeContext.Count -gt 0) {
        ' ' + (($safeContext.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' ')
    }
    else { '' }

    $line = "$timestamp [$Level] $Message$contextStr"
    Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
}
