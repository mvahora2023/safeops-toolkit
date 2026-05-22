@{
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # Get-LogEventsById and Get-RecentLogErrors use intentional plurals (Events, Errors)
        # that accurately describe multi-value return types.  Renaming would be a breaking
        # change to the public API.
        'PSUseSingularNouns',

        # All source files are UTF-8 without BOM — ASCII-only content, no non-ASCII
        # characters exist in the PowerShell source, so the BOM is unnecessary.
        # PS 5.1 and PS 7 both handle UTF-8 without BOM correctly for ASCII content.
        'PSUseBOMForUnicodeEncodedFile'
    )
}
