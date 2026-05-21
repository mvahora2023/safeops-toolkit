#
# Module manifest for module 'SafeOpsToolkit'
#
@{
    # Script module or binary module file associated with this manifest
    RootModule        = 'SafeOpsToolkit.psm1'

    ModuleVersion     = '1.0.0'

    # Unique identifier for this module
    GUID              = '8288dcb2-9439-4978-a6a9-8e02852c8b60'

    Author            = 'SafeOps Team'
    CompanyName       = 'SafeOps'
    Copyright         = '(c) 2026 SafeOps. All rights reserved.'

    Description       = 'Production-quality toolkit for allowlisted Windows service management, log inspection, and safe operations reporting.'

    PowerShellVersion = '5.1'

    # Only public surface is exported — private helpers are intentionally omitted
    FunctionsToExport = @(
        'Get-AllowlistedServiceStatus',
        'Restart-AllowlistedService',
        'Set-AllowlistedServiceStartupType',
        'Get-RecentLogErrors',
        'Get-LogEventsById',
        'Export-SafeOpsReport'
    )

    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()

    PrivateData       = @{
        PSData = @{
            Tags         = @('Windows', 'Service', 'EventLog', 'Operations', 'Allowlist',
                             'Security', 'Audit', 'Triage', 'SafeOps')
            ProjectUri   = 'https://github.com/your-org/safeops-toolkit'
            LicenseUri   = 'https://github.com/your-org/safeops-toolkit/blob/main/LICENSE'
            ReleaseNotes = 'v1.0.0 — Initial release. See CHANGELOG.md for full history.'
        }
    }
}
