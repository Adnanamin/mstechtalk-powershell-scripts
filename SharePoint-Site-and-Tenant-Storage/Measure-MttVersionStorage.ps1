#Requires -Version 5.1

function Measure-MttVersionStorage {
    <#
    .SYNOPSIS
        Reads a SharePoint version storage report CSV and shows how much space version history uses, and how much
        a trim would free.
    .DESCRIPTION
        Reads the CSV that Microsoft's version storage report job writes (one row per file version) and returns
        one row per file, largest version history first. With -Summary it returns one row of totals instead.

        The newest version of each file (highest major.minor) counts as the current version; the rest is version
        history. Some report columns are "compact": the value is left empty when it is the same as the row above,
        so the function fills those in first.

        KeepFreesMB and OlderThanFreesMB are what-if estimates for -KeepVersions and -OlderThanDays. The real trim
        job uses SharePoint's own rules, and files under retention keep their versions.

        The function is read-only and runs on your own machine: it needs no module and no sign-in, and it doesn't
        write files. Pipe the result to Export-Csv.
    .PARAMETER ReportPath
        Path of the version storage report CSV. Accepts pipeline input, for example from Get-ChildItem.
    .PARAMETER KeepVersions
        What-if: keep this many newest versions per file, the current version included. Defaults to 100.
    .PARAMETER OlderThanDays
        What-if: delete older versions last modified more than this many days ago. Defaults to 365.
    .PARAMETER Summary
        Return one row of totals for the report instead of one row per file.
    .EXAMPLE
        Measure-MttVersionStorage -ReportPath C:\Temp\VersionReport.csv -Summary

        Shows the totals: version history size and what each what-if would free.
    .EXAMPLE
        Measure-MttVersionStorage -ReportPath C:\Temp\VersionReport.csv | Select-Object -First 20

        The 20 files with the largest version history.
    .EXAMPLE
        Measure-MttVersionStorage -ReportPath C:\Temp\VersionReport.csv -KeepVersions 50 -OlderThanDays 180 | Export-Csv .\VersionStorage-Files.csv -NoTypeInformation -Encoding UTF8

        Saves one row per file, with the what-if for keeping 50 versions or deleting versions older than 180 days.
    .OUTPUTS
        MSTechTalk.VersionStorageFile (default)

        SiteUrl           Site the file is on
        FileUrl           File URL
        Versions          Number of versions in the report, current version included
        CurrentVersion    Current version number, for example 4.0
        CurrentSizeMB     Size of the current version
        HistorySizeMB     Size of all other versions
        TotalSizeMB       Current version plus history
        KeepFreesMB       What -KeepVersions would free on this file
        OlderThanFreesMB  What -OlderThanDays would free on this file

        MSTechTalk.VersionStorageSummary (with -Summary)

        ReportPath, FileVersions, Files, TotalSizeGB, CurrentVersionsGB, VersionHistoryGB, VersionHistoryVersions,
        KeepVersions, KeepFreesGB, OlderThanDays, OlderThanFreesGB
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      None
        Requires:    None (reads a CSV you downloaded; start the report job with Start-VersionStorageReport.ps1)
        Permissions: None
        Level:       Site, Library, File
        Tested:      16 November 2026 in PowerShell 7.6.9 and Windows PowerShell 5.1, on the template and a made-up
                     3,851-row report: same results as Measure-VersionStorageReport.ps1
    .LINK
        https://mstechtalk.com/how-to-find-what-is-filling-a-sharepoint-site-and-free-up-tenant-storage/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.VersionStorageFile', 'MSTechTalk.VersionStorageSummary')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('FullName', 'Path')]
        [string]$ReportPath,

        [ValidateRange(1, 50000)]
        [int]$KeepVersions = 100,

        [ValidateRange(1, 36500)]
        [int]$OlderThanDays = 365,

        [switch]$Summary
    )

    process {
        try {
            $rows = @(Import-Csv -Path $ReportPath -ErrorAction Stop)
        }
        catch {
            Write-Warning "Skipped ${ReportPath}: $($_.Exception.Message)"
            return
        }
        if ($rows.Count -eq 0) {
            Write-Warning "Skipped ${ReportPath}: the report is empty. Check that the report job has completed."
            return
        }

        # Column names end in ".Compact" in some reports and not in others
        $columns = $rows[0].PSObject.Properties.Name
        $columnName = { param($Name) if ($columns -contains "$Name.Compact") { "$Name.Compact" } else { $Name } }
        $fileUrlCol = & $columnName 'FileUrl'
        $docIdCol   = & $columnName 'DocId'
        $webUrlCol  = & $columnName 'WebUrl'
        foreach ($required in $fileUrlCol, 'MajorVersion', 'MinorVersion', 'Size') {
            if ($columns -notcontains $required) {
                Write-Warning "Skipped ${ReportPath}: it has no $required column, so it isn't a version storage report."
                return
            }
        }

        # Fill in compact columns (empty = same as the row above)
        $compact = @($columns | Where-Object { $_ -like '*.Compact' })
        for ($i = 1; $i -lt $rows.Count; $i++) {
            foreach ($col in $compact) {
                if ([string]::IsNullOrEmpty($rows[$i].$col)) { $rows[$i].$col = $rows[$i - 1].$col }
            }
        }

        $cutoff = (Get-Date).ToUniversalTime().AddDays(-$OlderThanDays)
        $totalBytes = 0; $historyBytes = 0; $historyVersions = 0; $keepFreed = 0; $ageFreed = 0

        # One group per file (DocId when present, otherwise the file URL)
        $groups = $rows | Group-Object { if ($_.$docIdCol) { $_.$docIdCol } else { $_.$fileUrlCol } }

        $files = foreach ($group in $groups) {
            # Newest version first
            $versions = @($group.Group | Sort-Object { [int]$_.MajorVersion }, { [int]$_.MinorVersion } -Descending)
            $current  = $versions[0]
            $older    = @($versions | Select-Object -Skip 1)

            $fileBytes    = [long]($versions | Measure-Object -Property Size -Sum).Sum
            $fileHistory  = $fileBytes - [long]$current.Size
            $fileKeep     = [long]($versions | Select-Object -Skip $KeepVersions | Measure-Object -Property Size -Sum).Sum
            $fileAge      = [long]($older | Where-Object { $_.LastModifiedDate -and ([datetime]$_.LastModifiedDate).ToUniversalTime() -lt $cutoff } |
                                Measure-Object -Property Size -Sum).Sum
            $totalBytes      += $fileBytes
            $historyBytes    += $fileHistory
            $historyVersions += $older.Count
            $keepFreed       += $fileKeep
            $ageFreed        += $fileAge

            [PSCustomObject]@{
                PSTypeName       = 'MSTechTalk.VersionStorageFile'
                SiteUrl          = "$($current.$webUrlCol)"
                FileUrl          = "$($current.$fileUrlCol)"
                Versions         = $versions.Count
                CurrentVersion   = "$($current.MajorVersion).$($current.MinorVersion)"
                CurrentSizeMB    = [math]::Round([long]$current.Size / 1MB, 2)
                HistorySizeMB    = [math]::Round($fileHistory / 1MB, 2)
                TotalSizeMB      = [math]::Round($fileBytes / 1MB, 2)
                KeepFreesMB      = [math]::Round($fileKeep / 1MB, 2)
                OlderThanFreesMB = [math]::Round($fileAge / 1MB, 2)
            }
        }

        if ($Summary) {
            [PSCustomObject]@{
                PSTypeName             = 'MSTechTalk.VersionStorageSummary'
                ReportPath             = $ReportPath
                FileVersions           = $rows.Count
                Files                  = @($files).Count
                TotalSizeGB            = [math]::Round($totalBytes / 1GB, 2)
                CurrentVersionsGB      = [math]::Round(($totalBytes - $historyBytes) / 1GB, 2)
                VersionHistoryGB       = [math]::Round($historyBytes / 1GB, 2)
                VersionHistoryVersions = $historyVersions
                KeepVersions           = $KeepVersions
                KeepFreesGB            = [math]::Round($keepFreed / 1GB, 2)
                OlderThanDays          = $OlderThanDays
                OlderThanFreesGB       = [math]::Round($ageFreed / 1GB, 2)
            }
        }
        else {
            $files | Sort-Object HistorySizeMB -Descending
        }
    }
}
