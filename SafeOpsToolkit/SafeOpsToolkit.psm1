#Requires -Version 5.1
<#
.SYNOPSIS
    SafeOpsToolkit module loader. Dot-sources Private then Public functions and
    exports only the declared public surface — no wildcard exports.
#>

# Module-scoped log directory — set once at load time so private helpers can reference it
# without relying on $PSScriptRoot inside a function body (which resolves to the caller's scope).
$Script:SafeOpsLogDir = Join-Path $PSScriptRoot 'logs'

# Load private helpers first so they are available when public functions are sourced
foreach ($file in (Get-ChildItem -Path "$PSScriptRoot\Private\*.ps1" -ErrorAction SilentlyContinue)) {
    . $file.FullName
}

# Load public commands
foreach ($file in (Get-ChildItem -Path "$PSScriptRoot\Public\*.ps1" -ErrorAction SilentlyContinue)) {
    . $file.FullName
}

# Explicit export list — must match FunctionsToExport in SafeOpsToolkit.psd1
Export-ModuleMember -Function @(
    'Get-AllowlistedServiceStatus',
    'Restart-AllowlistedService',
    'Set-AllowlistedServiceStartupType',
    'Get-RecentLogErrors',
    'Get-LogEventsById',
    'Export-SafeOpsReport'
)
