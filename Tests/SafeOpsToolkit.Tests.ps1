#Requires -Version 5.1
#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.0' }

BeforeAll {
    $modulePath = Join-Path $PSScriptRoot '..\SafeOpsToolkit\SafeOpsToolkit.psd1'
    Import-Module (Resolve-Path $modulePath) -Force
}

# ── Module ──────────────────────────────────────────────────────────────────────────────────────

Describe 'Module' {

    It 'manifest passes Test-ModuleManifest without errors' {
        $manifestPath = Join-Path $PSScriptRoot '..\SafeOpsToolkit\SafeOpsToolkit.psd1'
        { Test-ModuleManifest -Path (Resolve-Path $manifestPath) -ErrorAction Stop } |
            Should -Not -Throw
    }

    It 'exports exactly 6 public functions' {
        (Get-Module SafeOpsToolkit).ExportedFunctions.Count | Should -Be 6
    }

    It 'exports all six expected public commands' {
        $exported = (Get-Module SafeOpsToolkit).ExportedFunctions.Keys
        @(
            'Get-AllowlistedServiceStatus'
            'Restart-AllowlistedService'
            'Set-AllowlistedServiceStartupType'
            'Get-RecentLogErrors'
            'Get-LogEventsById'
            'Export-SafeOpsReport'
        ) | ForEach-Object { $exported | Should -Contain $_ }
    }

    It 'does not export private helpers' {
        $exported = (Get-Module SafeOpsToolkit).ExportedFunctions.Keys
        $exported | Should -Not -Contain 'Write-SafeOpsLog'
        $exported | Should -Not -Contain 'Assert-SafeOpsAllowed'
        $exported | Should -Not -Contain 'ConvertTo-SafeOpsResult'
    }
}

# ── Parameter / ValidateSet enforcement ─────────────────────────────────────────────────────────
# ValidateSet violations throw ParameterBindingValidationException before function body runs.
# No mocking required — these are pure parameter-binding tests.

Describe 'Parameter validation' {

    Context 'Get-AllowlistedServiceStatus' {
        It 'rejects a service name not in the allowlist' {
            { Get-AllowlistedServiceStatus -Name 'MSSQLSERVER' } | Should -Throw
        }
    }

    Context 'Restart-AllowlistedService' {
        It 'rejects a service name not in the allowlist' {
            { Restart-AllowlistedService -Name 'MSSQLSERVER' } | Should -Throw
        }
    }

    Context 'Set-AllowlistedServiceStartupType' {
        It 'rejects a service name not in the allowlist' {
            { Set-AllowlistedServiceStartupType -Name 'MSSQLSERVER' -StartupType Automatic } |
                Should -Throw
        }

        It 'rejects a startup type outside Automatic / Manual / Disabled' {
            { Set-AllowlistedServiceStartupType -Name Spooler -StartupType 'DelayedStart' } |
                Should -Throw
        }
    }

    Context 'Get-RecentLogErrors' {
        It 'rejects a log name outside System and Application' {
            { Get-RecentLogErrors -LogName 'Security' } | Should -Throw
        }

        It 'rejects MaxEvents = 0 (below ValidateRange minimum)' {
            { Get-RecentLogErrors -LogName System -MaxEvents 0 } | Should -Throw
        }

        It 'rejects MaxEvents = 501 (above ValidateRange maximum)' {
            { Get-RecentLogErrors -LogName System -MaxEvents 501 } | Should -Throw
        }

        It 'accepts MaxEvents = 1 (boundary: minimum)' {
            # Cannot call without mocking Get-WinEvent — tested elsewhere.
            # This validates that ValidateRange boundary itself is not accidentally wrong.
            $cmd = Get-Command Get-RecentLogErrors
            $attr = $cmd.Parameters['MaxEvents'].Attributes |
                Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $attr.MinRange | Should -Be 1
            $attr.MaxRange | Should -Be 500
        }
    }

    Context 'Get-LogEventsById' {
        It 'rejects a log name outside System and Application' {
            { Get-LogEventsById -LogName 'Security' -EventId 4624 } | Should -Throw
        }

        It 'rejects MaxEvents = 0' {
            { Get-LogEventsById -LogName System -EventId 7036 -MaxEvents 0 } | Should -Throw
        }

        It 'rejects MaxEvents = 501' {
            { Get-LogEventsById -LogName System -EventId 7036 -MaxEvents 501 } | Should -Throw
        }
    }

    Context 'Export-SafeOpsReport' {
        It 'rejects a format outside JSON and CSV' {
            { Export-SafeOpsReport -InputObject ([PSCustomObject]@{}) -Format 'XML' -Path 'C:\nul' } |
                Should -Throw
        }
    }
}

# ── Get-AllowlistedServiceStatus ─────────────────────────────────────────────────────────────────

Describe 'Get-AllowlistedServiceStatus' {
    BeforeAll {
        Mock -CommandName 'Write-SafeOpsLog' -ModuleName 'SafeOpsToolkit' -MockWith {}

        # The mock uses $Name (the parameter passed to Get-Service) to return a realistic object.
        Mock -CommandName 'Get-Service' -ModuleName 'SafeOpsToolkit' -MockWith {
            [PSCustomObject]@{
                Name        = $Name
                DisplayName = "Mocked $Name Service"
                Status      = 'Running'
                StartType   = 'Automatic'
            }
        }
    }

    It 'returns a non-null result for a valid allowlisted service' {
        Get-AllowlistedServiceStatus -Name Spooler | Should -Not -BeNullOrEmpty
    }

    It 'output object contains Name, DisplayName, Status, StartType' {
        $result = Get-AllowlistedServiceStatus -Name Spooler
        $props  = $result.PSObject.Properties.Name
        $props  | Should -Contain 'Name'
        $props  | Should -Contain 'DisplayName'
        $props  | Should -Contain 'Status'
        $props  | Should -Contain 'StartType'
    }

    It 'output object has exactly four properties — no extra fields' {
        $result = Get-AllowlistedServiceStatus -Name Spooler
        $result.PSObject.Properties.Name.Count | Should -Be 4
    }

    It 'Name in result matches the queried service' {
        $result = Get-AllowlistedServiceStatus -Name wuauserv
        $result.Name | Should -Be 'wuauserv'
    }

    It 'returns one result per name when multiple names are supplied' {
        $results = Get-AllowlistedServiceStatus -Name Spooler, wuauserv, WinDefend
        $results.Count | Should -Be 3
    }

    It 'each result Name matches its respective queried service' {
        $results = Get-AllowlistedServiceStatus -Name Spooler, wuauserv
        $results[0].Name | Should -Be 'Spooler'
        $results[1].Name | Should -Be 'wuauserv'
    }

    It 'accepts service names from the pipeline' {
        $result = 'Spooler' | Get-AllowlistedServiceStatus
        $result | Should -Not -BeNullOrEmpty
    }
}

# ── Restart-AllowlistedService ────────────────────────────────────────────────────────────────────

Describe 'Restart-AllowlistedService' {
    BeforeAll {
        Mock -CommandName 'Write-SafeOpsLog' -ModuleName 'SafeOpsToolkit' -MockWith {}
        Mock -CommandName 'Restart-Service'  -ModuleName 'SafeOpsToolkit' -MockWith {}
        Mock -CommandName 'Get-Service'      -ModuleName 'SafeOpsToolkit' -MockWith {
            [PSCustomObject]@{ Name = $Name; DisplayName = "Mocked $Name"; Status = 'Running'; StartType = 'Automatic' }
        }
    }

    Context '-WhatIf behaviour' {
        It 'does not throw with a valid allowlisted name and -WhatIf' {
            { Restart-AllowlistedService -Name Spooler -WhatIf } | Should -Not -Throw
        }

        It 'does not invoke Restart-Service when -WhatIf is set' {
            Restart-AllowlistedService -Name Spooler -WhatIf
            Should -Invoke -CommandName 'Restart-Service' -ModuleName 'SafeOpsToolkit' `
                -Times 0 -Exactly
        }

        It 'returns no output when -WhatIf is set' {
            $result = Restart-AllowlistedService -Name Spooler -WhatIf
            $result | Should -BeNullOrEmpty
        }
    }

    Context 'normal execution' {
        It 'invokes Restart-Service exactly once' {
            Restart-AllowlistedService -Name Spooler -Confirm:$false
            Should -Invoke -CommandName 'Restart-Service' -ModuleName 'SafeOpsToolkit' `
                -Times 1 -Exactly
        }

        It 'returns an object with Name and Status' {
            $result = Restart-AllowlistedService -Name Spooler -Confirm:$false
            $result.Name   | Should -Be 'Spooler'
            $result.Status | Should -Not -BeNullOrEmpty
        }

        It 'output has exactly two properties: Name and Status' {
            $result = Restart-AllowlistedService -Name Spooler -Confirm:$false
            $result.PSObject.Properties.Name.Count | Should -Be 2
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'Status'
        }
    }
}

# ── Set-AllowlistedServiceStartupType ────────────────────────────────────────────────────────────

Describe 'Set-AllowlistedServiceStartupType' {
    BeforeAll {
        Mock -CommandName 'Write-SafeOpsLog' -ModuleName 'SafeOpsToolkit' -MockWith {}
        Mock -CommandName 'Set-Service'      -ModuleName 'SafeOpsToolkit' -MockWith {}
    }

    Context '-WhatIf behaviour' {
        It 'does not throw with a valid service and startup type and -WhatIf' {
            { Set-AllowlistedServiceStartupType -Name Spooler -StartupType Manual -WhatIf } |
                Should -Not -Throw
        }

        It 'does not invoke Set-Service when -WhatIf is set' {
            Set-AllowlistedServiceStartupType -Name Spooler -StartupType Manual -WhatIf
            Should -Invoke -CommandName 'Set-Service' -ModuleName 'SafeOpsToolkit' `
                -Times 0 -Exactly
        }
    }

    Context 'normal execution' {
        It 'invokes Set-Service exactly once' {
            Set-AllowlistedServiceStartupType -Name Spooler -StartupType Manual -Confirm:$false
            Should -Invoke -CommandName 'Set-Service' -ModuleName 'SafeOpsToolkit' `
                -Times 1 -Exactly
        }

        It 'output Name matches the input service name' {
            $result = Set-AllowlistedServiceStartupType -Name Spooler -StartupType Manual -Confirm:$false
            $result.Name | Should -Be 'Spooler'
        }

        It 'output StartType matches the requested type' {
            $result = Set-AllowlistedServiceStartupType -Name Spooler -StartupType Manual -Confirm:$false
            $result.StartType | Should -Be 'Manual'
        }

        It 'reflects Disabled correctly in output' {
            $result = Set-AllowlistedServiceStartupType -Name wuauserv -StartupType Disabled -Confirm:$false
            $result.StartType | Should -Be 'Disabled'
        }

        It 'output has exactly two properties: Name and StartType' {
            $result = Set-AllowlistedServiceStartupType -Name Spooler -StartupType Automatic -Confirm:$false
            $result.PSObject.Properties.Name.Count | Should -Be 2
            $result.PSObject.Properties.Name | Should -Contain 'Name'
            $result.PSObject.Properties.Name | Should -Contain 'StartType'
        }
    }
}

# ── Get-RecentLogErrors ───────────────────────────────────────────────────────────────────────────

Describe 'Get-RecentLogErrors' {
    BeforeAll {
        Mock -CommandName 'Write-SafeOpsLog' -ModuleName 'SafeOpsToolkit' -MockWith {}
    }

    Context 'when Error events exist' {
        BeforeAll {
            Mock -CommandName 'Get-WinEvent' -ModuleName 'SafeOpsToolkit' -MockWith {
                @(
                    [PSCustomObject]@{
                        TimeCreated      = [datetime]'2026-05-21T08:42:11Z'
                        Id               = 7034
                        ProviderName     = 'Service Control Manager'
                        LevelDisplayName = 'Error'
                        Message          = 'The Print Spooler service terminated unexpectedly.'
                    },
                    [PSCustomObject]@{
                        TimeCreated      = [datetime]'2026-05-21T07:55:03Z'
                        Id               = 7023
                        ProviderName     = 'Service Control Manager'
                        LevelDisplayName = 'Error'
                        Message          = 'The Windows Update service terminated with an error.'
                    }
                )
            }
        }

        It 'returns a non-empty result' {
            Get-RecentLogErrors -LogName System -MaxEvents 10 | Should -Not -BeNullOrEmpty
        }

        It 'output objects contain TimeCreated, Id, ProviderName, LevelDisplayName, Message' {
            $result = Get-RecentLogErrors -LogName System -MaxEvents 10 | Select-Object -First 1
            $props  = $result.PSObject.Properties.Name
            @('TimeCreated', 'Id', 'ProviderName', 'LevelDisplayName', 'Message') |
                ForEach-Object { $props | Should -Contain $_ }
        }

        It 'output schema has exactly five properties' {
            $result = Get-RecentLogErrors -LogName System -MaxEvents 10 | Select-Object -First 1
            $result.PSObject.Properties.Name.Count | Should -Be 5
        }

        It 'returns two results when the mock provides two events' {
            $results = Get-RecentLogErrors -LogName System -MaxEvents 10
            $results.Count | Should -Be 2
        }

        It 'passes MaxEvents value through to Get-WinEvent' {
            Get-RecentLogErrors -LogName System -MaxEvents 77
            Should -Invoke -CommandName 'Get-WinEvent' -ModuleName 'SafeOpsToolkit' `
                -Times 1 -Exactly -ParameterFilter { $MaxEvents -eq 77 }
        }

        It 'queries Level 2 (Error) in the filter hashtable' {
            Get-RecentLogErrors -LogName Application -MaxEvents 10
            Should -Invoke -CommandName 'Get-WinEvent' -ModuleName 'SafeOpsToolkit' `
                -Times 1 -Exactly -ParameterFilter { $FilterHashtable.Level -eq 2 }
        }
    }

    Context 'when no events exist' {
        BeforeAll {
            Mock -CommandName 'Get-WinEvent' -ModuleName 'SafeOpsToolkit' -MockWith { return }
        }

        It 'returns nothing (empty output)' {
            Get-RecentLogErrors -LogName Application -MaxEvents 10 | Should -BeNullOrEmpty
        }

        It 'does not throw when no events are found' {
            { Get-RecentLogErrors -LogName Application -MaxEvents 10 } | Should -Not -Throw
        }
    }
}

# ── Get-LogEventsById ─────────────────────────────────────────────────────────────────────────────

Describe 'Get-LogEventsById' {
    BeforeAll {
        Mock -CommandName 'Write-SafeOpsLog' -ModuleName 'SafeOpsToolkit' -MockWith {}
    }

    Context 'when matching events exist' {
        BeforeAll {
            Mock -CommandName 'Get-WinEvent' -ModuleName 'SafeOpsToolkit' -MockWith {
                @(
                    [PSCustomObject]@{
                        TimeCreated      = [datetime]'2026-05-21T08:42:11Z'
                        Id               = 7036
                        ProviderName     = 'Service Control Manager'
                        LevelDisplayName = 'Information'
                        Message          = 'The Print Spooler service entered the running state.'
                    },
                    [PSCustomObject]@{
                        TimeCreated      = [datetime]'2026-05-21T07:10:44Z'
                        Id               = 7036
                        ProviderName     = 'Service Control Manager'
                        LevelDisplayName = 'Information'
                        Message          = 'The Print Spooler service entered the stopped state.'
                    }
                )
            }
        }

        It 'returns a non-empty result' {
            Get-LogEventsById -LogName System -EventId 7036 | Should -Not -BeNullOrEmpty
        }

        It 'output objects contain TimeCreated, Id, ProviderName, LevelDisplayName, Message' {
            $result = Get-LogEventsById -LogName System -EventId 7036 | Select-Object -First 1
            $props  = $result.PSObject.Properties.Name
            @('TimeCreated', 'Id', 'ProviderName', 'LevelDisplayName', 'Message') |
                ForEach-Object { $props | Should -Contain $_ }
        }

        It 'output schema has exactly five properties' {
            $result = Get-LogEventsById -LogName System -EventId 7036 | Select-Object -First 1
            $result.PSObject.Properties.Name.Count | Should -Be 5
        }

        It 'Id in every returned object matches the queried Event ID' {
            Get-LogEventsById -LogName System -EventId 7036 |
                ForEach-Object { $_.Id | Should -Be 7036 }
        }

        It 'passes the EventId to the Get-WinEvent filter hashtable' {
            Get-LogEventsById -LogName System -EventId 7036
            Should -Invoke -CommandName 'Get-WinEvent' -ModuleName 'SafeOpsToolkit' `
                -Times 1 -Exactly -ParameterFilter { $FilterHashtable.Id -eq 7036 }
        }

        It 'passes MaxEvents value through to Get-WinEvent' {
            Get-LogEventsById -LogName System -EventId 7036 -MaxEvents 42
            Should -Invoke -CommandName 'Get-WinEvent' -ModuleName 'SafeOpsToolkit' `
                -Times 1 -Exactly -ParameterFilter { $MaxEvents -eq 42 }
        }
    }

    Context 'when no matching events exist' {
        BeforeAll {
            Mock -CommandName 'Get-WinEvent' -ModuleName 'SafeOpsToolkit' -MockWith { return }
        }

        It 'returns nothing (empty output)' {
            Get-LogEventsById -LogName System -EventId 32000 | Should -BeNullOrEmpty
        }

        It 'does not throw when no events are found' {
            { Get-LogEventsById -LogName System -EventId 32000 } | Should -Not -Throw
        }
    }
}

# ── Export-SafeOpsReport ──────────────────────────────────────────────────────────────────────────

Describe 'Export-SafeOpsReport' {
    BeforeAll {
        Mock -CommandName 'Write-SafeOpsLog' -ModuleName 'SafeOpsToolkit' -MockWith {}
    }

    Context 'JSON output' {
        It 'creates the JSON file on disk' {
            $path = Join-Path $TestDrive 'report.json'
            [PSCustomObject]@{ Name = 'Spooler'; Status = 'Running' } |
                Export-SafeOpsReport -Format JSON -Path $path
            $path | Should -Exist
        }

        It 'returns a summary object with Path, Format, Count' {
            $path   = Join-Path $TestDrive 'summary.json'
            $result = @(
                [PSCustomObject]@{ Name = 'Spooler';  Status = 'Running' },
                [PSCustomObject]@{ Name = 'wuauserv'; Status = 'Stopped' }
            ) | Export-SafeOpsReport -Format JSON -Path $path
            $result.Path   | Should -Exist
            $result.Format | Should -Be 'JSON'
            $result.Count  | Should -Be 2
        }

        It 'written JSON is parseable without error' {
            $path = Join-Path $TestDrive 'valid.json'
            [PSCustomObject]@{ Name = 'Spooler'; Status = 'Running' } |
                Export-SafeOpsReport -Format JSON -Path $path
            { Get-Content $path | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'written JSON preserves the input data' {
            $path = Join-Path $TestDrive 'data.json'
            [PSCustomObject]@{ Name = 'Spooler'; Status = 'Running' } |
                Export-SafeOpsReport -Format JSON -Path $path
            $parsed = Get-Content $path | ConvertFrom-Json
            $parsed[0].Name | Should -Be 'Spooler'
        }
    }

    Context 'CSV output' {
        It 'creates the CSV file on disk' {
            $path = Join-Path $TestDrive 'report.csv'
            [PSCustomObject]@{ Name = 'Spooler'; Status = 'Running' } |
                Export-SafeOpsReport -Format CSV -Path $path
            $path | Should -Exist
        }

        It 'returns a summary object with Path, Format, Count' {
            $path   = Join-Path $TestDrive 'summary.csv'
            $result = [PSCustomObject]@{ Name = 'Spooler'; Status = 'Running' } |
                Export-SafeOpsReport -Format CSV -Path $path
            $result.Path   | Should -Exist
            $result.Format | Should -Be 'CSV'
            $result.Count  | Should -Be 1
        }

        It 'first line of the CSV file is a header row' {
            $path = Join-Path $TestDrive 'headers.csv'
            [PSCustomObject]@{ Name = 'Spooler'; Status = 'Running' } |
                Export-SafeOpsReport -Format CSV -Path $path
            $firstLine = Get-Content $path | Select-Object -First 1
            $firstLine | Should -Match '"?Name"?'
        }

        It 'written CSV is importable and preserves input data' {
            $path = Join-Path $TestDrive 'importable.csv'
            [PSCustomObject]@{ Name = 'Spooler'; Status = 'Running' } |
                Export-SafeOpsReport -Format CSV -Path $path
            $rows = Import-Csv $path
            $rows[0].Name | Should -Be 'Spooler'
        }
    }

    Context 'parent directory creation' {
        It 'creates missing parent directories without throwing' {
            $path = Join-Path $TestDrive 'nested\deep\report.json'
            { [PSCustomObject]@{ x = 1 } | Export-SafeOpsReport -Format JSON -Path $path } |
                Should -Not -Throw
            $path | Should -Exist
        }
    }

    Context 'Count accuracy' {
        It 'Count in the summary equals the number of piped objects — 3' {
            $path   = Join-Path $TestDrive 'count3.json'
            $result = @(
                [PSCustomObject]@{ A = 1 },
                [PSCustomObject]@{ A = 2 },
                [PSCustomObject]@{ A = 3 }
            ) | Export-SafeOpsReport -Format JSON -Path $path
            $result.Count | Should -Be 3
        }

        It 'Count is 1 when a single object is exported' {
            $path   = Join-Path $TestDrive 'count1.csv'
            $result = [PSCustomObject]@{ A = 1 } |
                Export-SafeOpsReport -Format CSV -Path $path
            $result.Count | Should -Be 1
        }
    }
}

AfterAll {
    Remove-Module SafeOpsToolkit -ErrorAction SilentlyContinue
}
