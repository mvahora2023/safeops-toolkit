@{
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # Get-LogEventsById and Get-RecentLogErrors use intentional plurals (Events, Errors)
        # that accurately describe multi-value return types.  Renaming would be a breaking
        # change to the public API.
        'PSUseSingularNouns'
    )
}
