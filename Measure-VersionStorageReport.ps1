<#
.SYNOPSIS
    Reads a SharePoint version storage report CSV and shows where the version history space is,
    and how much a trim would free.

.DESCRIPTION
    Read-only. Runs on your machine against the CSV that Start-VersionStorageReport.ps1
    (New-SPOSiteFileVersionExpirationReportJob / New-SPOListFileVersionExpirationReportJob) produced.
    No SharePoint connection or module needed. Works in Windows PowerShell 5.1 and PowerShell 7.

    The report has one row per file version. Some columns are "compact": the value is left empty when
    it is the same as the row above. The script fills those in before it counts anything.

    For each file, the newest version (highest major.minor) is treated as the current version.
    Everything else is version history.

    Output (in -OutputFolder):
      VersionStorage-Summary.csv     totals and what-if estimates
      VersionStorage-Files.csv       one row per file, largest version history first
      VersionStorage-Libraries.csv   totals per library (taken from the file URL)
      VersionStorage-Users.csv       version history size per person who saved the versions

    The what-if numbers are estimates from the report. The real trim job uses SharePoint's own rules,
    and files under retention keep their versions.

.EXAMPLE
    .\Measure-VersionStorageReport.ps1 -ReportPath C:\Temp\VersionReport.csv

.EXAMPLE
    # Estimate what "keep 100 versions" and "delete versions older than 365 days" would free
    .\Measure-VersionStorageReport.ps1 -ReportPath C:\Temp\VersionReport.csv -KeepVersions 100 -OlderThanDays 365 -Top 50
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path -Path $_ -PathType Leaf })]
    [string]$ReportPath,

    [string]$OutputFolder = (Split-Path -Path (Resolve-Path $ReportPath) -Parent),

    # What-if: keep this many newest versions per file (current version included)
    [ValidateRange(1, 50000)]
    [int]$KeepVersions = 100,

    # What-if: delete history versions last modified more than this many days ago
    [ValidateRange(1, 36500)]
    [int]$OlderThanDays = 365,

    # How many files to show on screen
    [ValidateRange(1, 1000)]
    [int]$Top = 20
)

function Format-Size([double]$Bytes) {
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    return "{0:N0} KB" -f ($Bytes / 1KB)
}

# Find a column whatever form the header uses: "FileUrl" or "FileUrl.Compact"
function Find-Column([string[]]$Headers, [string[]]$Names) {
    foreach ($Name in $Names) {
        foreach ($Candidate in @($Name, "$Name.Compact")) {
            $Match = $Headers | Where-Object { $_ -eq $Candidate } | Select-Object -First 1
            if ($Match) { return $Match }
        }
    }
    return $null
}

$Headers = (Get-Content -Path $ReportPath -TotalCount 1).Split(',') | ForEach-Object { $_.Trim().Trim('"') }

$Col = @{
    WebId    = Find-Column $Headers @('WebId')
    DocId    = Find-Column $Headers @('DocId')
    WebUrl   = Find-Column $Headers @('WebUrl')
    FileUrl  = Find-Column $Headers @('FileUrl')
    Major    = Find-Column $Headers @('MajorVersion')
    Minor    = Find-Column $Headers @('MinorVersion')
    Size     = Find-Column $Headers @('Size')
    User     = Find-Column $Headers @('ModifiedBy_DisplayName', 'ModifiedBy_UserDisplayName')
    Modified = Find-Column $Headers @('LastModifiedDate')
}
foreach ($Required in 'FileUrl', 'Major', 'Size') {
    if (-not $Col[$Required]) { throw "Column '$Required' not found. Headers in the file: $($Headers -join ', ')" }
}
$CompactColumns = @($Headers | Where-Object { $_ -like '*.Compact' })

Write-Host "Reading $ReportPath ..."
$Files    = @{}       # key -> file object with its versions
$Previous = @{}       # last seen value of each compact column
$RowCount = 0

Import-Csv -Path $ReportPath | ForEach-Object {
    $Row = $_
    foreach ($C in $CompactColumns) {
        if ([string]::IsNullOrEmpty($Row.$C)) { $Row.$C = $Previous[$C] } else { $Previous[$C] = $Row.$C }
    }
    $RowCount++

    $FileUrl = $Row.($Col.FileUrl)
    $Key = if ($Col.WebId -and $Col.DocId -and $Row.($Col.DocId)) { "$($Row.($Col.WebId))|$($Row.($Col.DocId))" } else { $FileUrl }

    if (-not $Files.ContainsKey($Key)) {
        $Files[$Key] = [pscustomobject]@{
            FileUrl  = $FileUrl
            WebUrl   = $(if ($Col.WebUrl) { $Row.($Col.WebUrl) } else { '' })
            Versions = New-Object System.Collections.Generic.List[object]
        }
    }

    $Modified = [datetime]::MinValue
    if ($Col.Modified -and $Row.($Col.Modified)) {
        [void][datetime]::TryParse($Row.($Col.Modified), [Globalization.CultureInfo]::InvariantCulture,
            [Globalization.DateTimeStyles]::RoundtripKind, [ref]$Modified)
    }
    $Files[$Key].Versions.Add([pscustomobject]@{
        Major    = [int]$Row.($Col.Major)
        Minor    = $(if ($Col.Minor -and $Row.($Col.Minor)) { [int]$Row.($Col.Minor) } else { 0 })
        Size     = [long]$Row.($Col.Size)
        User     = $(if ($Col.User) { $Row.($Col.User) } else { '' })
        Modified = $Modified
    })
}

if ($RowCount -eq 0) { throw "The report has no rows. Is the job finished? Check it with Start-VersionStorageReport.ps1 -CheckProgress." }

$Cutoff        = (Get-Date).ToUniversalTime().AddDays(-$OlderThanDays)
$Libraries     = @{}
$Users         = @{}
$TotalBytes    = [long]0
$HistoryBytes  = [long]0
$KeepNFreed    = [long]0
$AgeFreed      = [long]0
$HistoryCount  = 0

$FileRows = foreach ($File in $Files.Values) {
    $Sorted  = @($File.Versions | Sort-Object Major, Minor -Descending)
    $Current = $Sorted[0]
    $History = @($Sorted | Select-Object -Skip 1)

    $FileTotal   = [long](($Sorted | Measure-Object Size -Sum).Sum)
    $FileHistory = $FileTotal - $Current.Size
    $TotalBytes   += $FileTotal
    $HistoryBytes += $FileHistory
    $HistoryCount += $History.Count

    if ($Sorted.Count -gt $KeepVersions) {
        $KeepNFreed += [long](($Sorted | Select-Object -Skip $KeepVersions | Measure-Object Size -Sum).Sum)
    }
    $Old = @($History | Where-Object { $_.Modified -ne [datetime]::MinValue -and $_.Modified -lt $Cutoff })
    if ($Old.Count -gt 0) { $AgeFreed += [long](($Old | Measure-Object Size -Sum).Sum) }

    foreach ($V in $History) {
        $Name = if ($V.User) { $V.User } else { '(unknown)' }
        if (-not $Users.ContainsKey($Name)) { $Users[$Name] = [pscustomobject]@{ User = $Name; HistoryVersions = 0; HistoryBytes = [long]0 } }
        $Users[$Name].HistoryVersions++
        $Users[$Name].HistoryBytes += $V.Size
    }

    # Library = first folder of the file path after the site URL
    $Path = $File.FileUrl
    if ($File.WebUrl -and $Path.StartsWith($File.WebUrl, [StringComparison]::OrdinalIgnoreCase)) { $Path = $Path.Substring($File.WebUrl.Length) }
    elseif ($Path -match '^https?://[^/]+(/.*)$') { $Path = $Matches[1] }
    if ($File.WebUrl -match '^https?://[^/]+(/.*)$') {
        $WebPath = $Matches[1].TrimEnd('/')
        if ($WebPath -and $Path.StartsWith($WebPath, [StringComparison]::OrdinalIgnoreCase)) { $Path = $Path.Substring($WebPath.Length) }
    }
    $Library = ($Path.TrimStart('/') -split '/')[0]
    $LibKey  = "$($File.WebUrl)|$Library"
    if (-not $Libraries.ContainsKey($LibKey)) {
        $Libraries[$LibKey] = [pscustomobject]@{ WebUrl = $File.WebUrl; Library = $Library; Files = 0; Versions = 0; TotalBytes = [long]0; HistoryBytes = [long]0 }
    }
    $L = $Libraries[$LibKey]
    $L.Files++; $L.Versions += $Sorted.Count; $L.TotalBytes += $FileTotal; $L.HistoryBytes += $FileHistory

    [pscustomobject]@{
        FileUrl          = $File.FileUrl
        Versions         = $Sorted.Count
        CurrentVersion   = "$($Current.Major).$($Current.Minor)"
        CurrentSizeMB    = [math]::Round($Current.Size / 1MB, 2)
        HistorySizeMB    = [math]::Round($FileHistory / 1MB, 2)
        TotalSizeMB      = [math]::Round($FileTotal / 1MB, 2)
        OldestVersionUtc = $(($Sorted | Where-Object { $_.Modified -ne [datetime]::MinValue } | Sort-Object Modified | Select-Object -First 1).Modified)
    }
}

$FileRows = @($FileRows | Sort-Object HistorySizeMB -Descending)

$Summary = [ordered]@{
    'Report'                                   = (Resolve-Path $ReportPath).Path
    'Rows (file versions)'                     = $RowCount
    'Files'                                    = $Files.Count
    'Total size, all versions'                 = Format-Size $TotalBytes
    'Current versions'                         = Format-Size ($TotalBytes - $HistoryBytes)
    'Version history'                          = Format-Size $HistoryBytes
    'Version history, % of total'              = $(if ($TotalBytes) { "{0:N1} %" -f (100 * $HistoryBytes / $TotalBytes) } else { '0 %' })
    'History versions'                         = $HistoryCount
    "What-if: keep newest $KeepVersions versions frees"       = Format-Size $KeepNFreed
    "What-if: delete history older than $OlderThanDays days frees" = Format-Size $AgeFreed
}

if (-not (Test-Path $OutputFolder)) { New-Item -ItemType Directory -Path $OutputFolder | Out-Null }
$Summary.GetEnumerator() | ForEach-Object { [pscustomobject]@{ Item = $_.Key; Value = $_.Value } } |
    Export-Csv (Join-Path $OutputFolder 'VersionStorage-Summary.csv') -NoTypeInformation -Encoding UTF8
$FileRows | Export-Csv (Join-Path $OutputFolder 'VersionStorage-Files.csv') -NoTypeInformation -Encoding UTF8
$Libraries.Values | Sort-Object HistoryBytes -Descending |
    Select-Object WebUrl, Library, Files, Versions,
        @{ n = 'TotalSizeMB';   e = { [math]::Round($_.TotalBytes / 1MB, 2) } },
        @{ n = 'HistorySizeMB'; e = { [math]::Round($_.HistoryBytes / 1MB, 2) } } |
    Export-Csv (Join-Path $OutputFolder 'VersionStorage-Libraries.csv') -NoTypeInformation -Encoding UTF8
$Users.Values | Sort-Object HistoryBytes -Descending |
    Select-Object User, HistoryVersions, @{ n = 'HistorySizeMB'; e = { [math]::Round($_.HistoryBytes / 1MB, 2) } } |
    Export-Csv (Join-Path $OutputFolder 'VersionStorage-Users.csv') -NoTypeInformation -Encoding UTF8

[pscustomobject]$Summary | Format-List | Out-Host
Write-Host "Top $Top files by version history size:"
$FileRows | Select-Object -First $Top FileUrl, Versions, CurrentSizeMB, HistorySizeMB | Format-Table -AutoSize | Out-Host
Write-Host "CSV files written to $OutputFolder"
