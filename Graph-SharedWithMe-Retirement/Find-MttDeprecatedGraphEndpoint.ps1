#Requires -Version 5.1

function Find-MttDeprecatedGraphEndpoint {
    <#
    .SYNOPSIS
        Finds scripts and config files that call the retired Microsoft Graph file endpoints.
    .DESCRIPTION
        Searches a folder and its subfolders for /me/drive/sharedWithMe, /me/drive/recent, /me/insights/used and
        /me/insights/shared, which stop returning data after November 2026. Returns one row per matching line,
        with the file, line number, the endpoint it found and the line itself.

        The function is read-only and runs on your own machine: it needs no module and no sign-in, and it doesn't
        write files. Pipe the result to Export-Csv.
    .PARAMETER Path
        Folder to search. Accepts pipeline input, for example from Get-Item or Get-ChildItem -Directory.
    .PARAMETER Exclude
        Folders to skip. Any file whose full path starts with one of these is left out.
    .PARAMETER Include
        File patterns to search. Defaults to *.ps1, *.psm1, *.js, *.ts and *.json.
    .EXAMPLE
        Find-MttDeprecatedGraphEndpoint -Path C:\Scripts

        Lists every line in C:\Scripts that calls one of the retired endpoints.
    .EXAMPLE
        Find-MttDeprecatedGraphEndpoint -Path C:\Scripts -Exclude C:\Scripts\Archive | Export-Csv .\GraphEndpoints.csv -NoTypeInformation -Encoding UTF8

        Saves the matches as a CSV file, leaving out the Archive folder.
    .EXAMPLE
        Find-MttDeprecatedGraphEndpoint -Path C:\Scripts | Group-Object Endpoint | Select-Object Name, Count

        Counts the matches per endpoint.
    .OUTPUTS
        MSTechTalk.DeprecatedGraphEndpoint

        Path        Full path of the file
        LineNumber  Line number of the match
        Endpoint    The retired endpoints found on the line: sharedWithMe, drive/recent, insights/used or
                    insights/shared, comma-separated when there is more than one
        Line        The line, without leading and trailing spaces
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      None
        Requires:    None (reads local files)
        Permissions: Read access to the folder
        Level:       Local script files
        Tested:      16 November 2026 in PowerShell 7.6.9 and Windows PowerShell 5.1: same lines as
                     Find-DeprecatedGraphEndpoint.ps1 on sample files and on a 41-file folder
    .LINK
        https://mstechtalk.com/graph-sharedwithme-recent-retired-search-api/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.DeprecatedGraphEndpoint')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'ScriptFolder')]
        [string]$Path,

        [string[]]$Exclude = @(),

        [string[]]$Include = @('*.ps1', '*.psm1', '*.js', '*.ts', '*.json')
    )

    begin {
        $patterns = 'sharedWithMe', 'drive/recent', 'insights/used', 'insights/shared'
    }

    process {
        if (-not (Test-Path -Path $Path -PathType Container)) {
            Write-Warning "Skipped ${Path}: it isn't a folder."
            return
        }
        $excludeFull = @($Exclude | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\', '/') })

        $files = Get-ChildItem -Path $Path -Recurse -File -Include $Include -ErrorAction SilentlyContinue -ErrorVariable listErrors |
            Where-Object { $file = $_.FullName; -not ($excludeFull | Where-Object { $file -like "$_*" }) }
        foreach ($listError in $listErrors) {
            Write-Warning "Couldn't read $($listError.TargetObject): $($listError.Exception.Message)"
        }
        Write-Verbose "Searching $(@($files).Count) files under $Path"

        foreach ($match in ($files | Select-String -Pattern $patterns -ErrorAction SilentlyContinue)) {
            # A line can call more than one retired endpoint; list them all
            $found = @($patterns | Where-Object { $match.Line -like "*$_*" })
            [PSCustomObject]@{
                PSTypeName = 'MSTechTalk.DeprecatedGraphEndpoint'
                Path       = $match.Path
                LineNumber = $match.LineNumber
                Endpoint   = $found -join ', '
                Line       = $match.Line.Trim()
            }
        }
    }
}
