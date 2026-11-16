<#
.SYNOPSIS
    Reads a SharePoint version storage report CSV and shows how much space version history uses,
    and how much a trim would free.

.DESCRIPTION
    Read-only. Runs on your own machine against the CSV from Start-VersionStorageReport.ps1.
    No SharePoint connection or module needed. Works in Windows PowerShell 5.1 and PowerShell 7.

    The report has one row per file version. Some columns are "compact": the value is left empty
    when it is the same as the row above, so the script fills those in first.
    The newest version of each file counts as the current version. The rest is version history.

    Writes two CSV files next to the report:
      VersionStorage-Summary.csv   totals and what-if estimates
      VersionStorage-Files.csv     one row per file, largest version history first

    What-if numbers are estimates. The real trim job uses SharePoint's own rules,
    and files under retention keep their versions.

.EXAMPLE
    .\Measure-VersionStorageReport.ps1 -ReportPath C:\Temp\VersionReport.csv

.EXAMPLE
    .\Measure-VersionStorageReport.ps1 -ReportPath C:\Temp\VersionReport.csv -KeepVersions 50 -OlderThanDays 180

.NOTES
    Author      : Adnan Amin
    Blog        : https://mstechtalk.com
    Blog post   : https://mstechtalk.com/how-to-find-what-is-filling-a-sharepoint-site-and-free-up-tenant-storage/
    GitHub      : https://github.com/adnanamin/mstechtalk-powershell-scripts
    Disclaimer  : Provided as-is. Review the code and test in a suitable
                  environment before using it in production.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReportPath,

    # What-if: keep this many newest versions per file (current version included)
    [int]$KeepVersions = 100,

    # What-if: delete older versions last modified more than this many days ago
    [int]$OlderThanDays = 365,

    # Number of files to show on screen
    [int]$Top = 20
)

$Rows = @(Import-Csv -Path $ReportPath)
if ($Rows.Count -eq 0) { throw "The report is empty. Check the job finished with Start-VersionStorageReport.ps1 -CheckProgress." }

# Column names end in ".Compact" in some reports and not in others
$Columns = $Rows[0].PSObject.Properties.Name
function Get-ColumnName($Name) {
    if ($Columns -contains "$Name.Compact") { return "$Name.Compact" }
    return $Name
}
$FileUrlCol = Get-ColumnName 'FileUrl'
$DocIdCol   = Get-ColumnName 'DocId'

# Fill in compact columns (empty = same as the row above)
$Compact = $Columns | Where-Object { $_ -like '*.Compact' }
for ($i = 1; $i -lt $Rows.Count; $i++) {
    foreach ($Col in $Compact) {
        if ([string]::IsNullOrEmpty($Rows[$i].$Col)) { $Rows[$i].$Col = $Rows[$i - 1].$Col }
    }
}

$Cutoff = (Get-Date).ToUniversalTime().AddDays(-$OlderThanDays)
$TotalBytes = 0; $HistoryBytes = 0; $HistoryVersions = 0; $KeepFreed = 0; $AgeFreed = 0

# One group per file (DocId when present, otherwise the file URL)
$Groups = $Rows | Group-Object { if ($_.$DocIdCol) { $_.$DocIdCol } else { $_.$FileUrlCol } }

$Files = foreach ($Group in $Groups) {
    # Newest version first
    $Versions = @($Group.Group | Sort-Object { [int]$_.MajorVersion }, { [int]$_.MinorVersion } -Descending)
    $Current  = $Versions[0]
    $Older    = @($Versions | Select-Object -Skip 1)

    $FileBytes   = [long]($Versions | Measure-Object -Property Size -Sum).Sum
    $FileHistory = $FileBytes - [long]$Current.Size
    $TotalBytes      += $FileBytes
    $HistoryBytes    += $FileHistory
    $HistoryVersions += $Older.Count

    $KeepFreed += [long]($Versions | Select-Object -Skip $KeepVersions | Measure-Object -Property Size -Sum).Sum
    $AgeFreed  += [long]($Older | Where-Object { $_.LastModifiedDate -and ([datetime]$_.LastModifiedDate).ToUniversalTime() -lt $Cutoff } |
                         Measure-Object -Property Size -Sum).Sum

    [pscustomobject]@{
        FileUrl        = $Current.$FileUrlCol
        Versions       = $Versions.Count
        CurrentVersion = "$($Current.MajorVersion).$($Current.MinorVersion)"
        CurrentSizeMB  = [math]::Round([long]$Current.Size / 1MB, 2)
        HistorySizeMB  = [math]::Round($FileHistory / 1MB, 2)
        TotalSizeMB    = [math]::Round($FileBytes / 1MB, 2)
    }
}
$Files = @($Files | Sort-Object HistorySizeMB -Descending)

$Summary = [pscustomobject][ordered]@{
    'File versions in report'                   = $Rows.Count
    'Files'                                     = $Files.Count
    'Total size (GB)'                           = [math]::Round($TotalBytes / 1GB, 2)
    'Current versions (GB)'                     = [math]::Round(($TotalBytes - $HistoryBytes) / 1GB, 2)
    'Version history (GB)'                      = [math]::Round($HistoryBytes / 1GB, 2)
    'Version history versions'                  = $HistoryVersions
    "Keep newest $KeepVersions frees (GB)"      = [math]::Round($KeepFreed / 1GB, 2)
    "Older than $OlderThanDays days frees (GB)" = [math]::Round($AgeFreed / 1GB, 2)
}

$Folder = Split-Path -Path (Resolve-Path $ReportPath) -Parent
$Summary | Export-Csv -Path (Join-Path $Folder 'VersionStorage-Summary.csv') -NoTypeInformation -Encoding UTF8
$Files   | Export-Csv -Path (Join-Path $Folder 'VersionStorage-Files.csv') -NoTypeInformation -Encoding UTF8

$Summary | Format-List | Out-Host
$Files | Select-Object -First $Top FileUrl, Versions, CurrentSizeMB, HistorySizeMB | Format-Table -AutoSize | Out-Host
Write-Host "Results saved in $Folder"
