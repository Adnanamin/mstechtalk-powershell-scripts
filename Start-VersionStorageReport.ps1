<#
.SYNOPSIS
    Starts, or checks, a SharePoint version storage report job for a site, a OneDrive or one library.

.DESCRIPTION
    Read-only for your files: it only creates the report CSV. Microsoft's job writes one
    CSV row per file version (size in bytes, version number, who changed it, expiration dates).
    The job runs in the background: a small site takes over 24 hours, a large one a few days.
    Don't open or edit the CSV while it fills, or the job fails. Delete the CSV to cancel.

    Run once to start the job, then run again with -CheckProgress until the status is "completed".
    Then download the CSV and run Measure-VersionStorageReport.ps1 on it.

    Module : SharePoint Online Management Shell (Microsoft.Online.SharePoint.PowerShell)
    Role   : SharePoint Administrator
    Docs   : https://learn.microsoft.com/sharepoint/version-storage-report-site

.EXAMPLE
    # Whole site
    .\Start-VersionStorageReport.ps1 -AdminUrl https://contoso-admin.sharepoint.com `
        -SiteUrl https://contoso.sharepoint.com/sites/Projects `
        -ReportUrl "https://contoso.sharepoint.com/sites/Projects/Shared Documents/Reports/VersionReport.csv"

.EXAMPLE
    # One library, then check progress later
    .\Start-VersionStorageReport.ps1 -AdminUrl https://contoso-admin.sharepoint.com `
        -SiteUrl https://contoso.sharepoint.com/sites/Projects -Library "Documents" `
        -ReportUrl "https://contoso.sharepoint.com/sites/Projects/Shared Documents/Reports/DocsVersions.csv" -CheckProgress
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AdminUrl,

    # Site or OneDrive URL
    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,

    # Full URL of the CSV to create, in a document library of the same site. The file must not exist yet.
    [Parameter(Mandatory = $true)]
    [string]$ReportUrl,

    # Library title. Leave empty for the whole site.
    [string]$Library,

    # Only check the status of a job you already started
    [switch]$CheckProgress
)

if (-not $ReportUrl.StartsWith($SiteUrl.TrimEnd('/'), [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "ReportUrl must be inside the same site as SiteUrl ($SiteUrl)."
}
if (-not $ReportUrl.EndsWith('.csv', [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "ReportUrl must end with .csv"
}

Connect-SPOService -Url $AdminUrl

if (-not $CheckProgress) {
    if ($Library) {
        New-SPOListFileVersionExpirationReportJob -Site $SiteUrl -List $Library -ReportUrl $ReportUrl
    }
    else {
        New-SPOSiteFileVersionExpirationReportJob -Identity $SiteUrl -ReportUrl $ReportUrl
    }
    Write-Host "Report job started. Run this script again with -CheckProgress in a few hours."
}

# Status values: completed, in_progress, no_report_found, failed
if ($Library) {
    $Progress = Get-SPOListFileVersionExpirationReportJobProgress -Site $SiteUrl -List $Library -ReportUrl $ReportUrl
}
else {
    $Progress = Get-SPOSiteFileVersionExpirationReportJobProgress -Identity $SiteUrl -ReportUrl $ReportUrl
}
$Progress
