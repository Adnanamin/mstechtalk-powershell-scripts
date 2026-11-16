#Requires -Version 5.1

function Get-MttVersionStorageReportStatus {
    <#
    .SYNOPSIS
        Shows the status of a SharePoint version storage report job for a site, a OneDrive or one library.
    .DESCRIPTION
        Checks the job that Start-MttVersionStorageReport started. The status is one of completed, in_progress,
        no_report_found or failed. A small site takes over 24 hours and a large one a few days. When the status is
        completed, download the CSV from the library and read it with Measure-MttVersionStorage.

        The function is read-only. It doesn't connect: sign in with Connect-SPOService first.

        In PowerShell 7, load the SharePoint Online Management Shell with
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell before you connect.
    .PARAMETER SiteUrl
        Site or OneDrive URL the report job runs on.
    .PARAMETER ReportUrl
        Full URL of the report CSV, as given to Start-MttVersionStorageReport.
    .PARAMETER Library
        Title of the library, if the job was started for one library. SharePoint looks the job up by report URL,
        so a site job and a library job with the same report URL show the same status.
    .EXAMPLE
        Get-MttVersionStorageReportStatus -SiteUrl https://contoso.sharepoint.com/sites/Projects -ReportUrl "https://contoso.sharepoint.com/sites/Projects/Shared Documents/VersionReport.csv"

        Shows whether the report for the Projects site is still running.
    .EXAMPLE
        Start-MttVersionStorageReport -SiteUrl $SiteUrl -ReportUrl $ReportUrl | Get-MttVersionStorageReportStatus

        Checks the job again later, from the object Start-MttVersionStorageReport returned.
    .OUTPUTS
        MSTechTalk.VersionStorageReportStatus

        SiteUrl       Site the job runs on
        Library       Library title, or empty for the whole site
        ReportUrl     URL of the report CSV
        Status        completed, in_progress, no_report_found or failed
        ErrorMessage  Error from SharePoint, if the job failed
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Online.SharePoint.PowerShell (SharePoint Online Management Shell)
        Requires:    SPO (the version report job cmdlets are only in this module)
        Permissions: SharePoint Administrator
        Level:       Site, Library
        Tested:      16 November 2026 on the MST demo tenant (PowerShell 7.6.9 with -UseWindowsPowerShell, and
                     Windows PowerShell 5.1; SPO module 16.0.27424.0): in_progress, then completed
        No #Requires -Modules line: in PowerShell 7 that line would load the module without
        -UseWindowsPowerShell, so the function checks for it in begin instead.
    .LINK
        https://mstechtalk.com/how-to-find-what-is-filling-a-sharepoint-site-and-free-up-tenant-storage/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.VersionStorageReportStatus')]
    param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('Url')]
        [string]$SiteUrl,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string]$ReportUrl,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Library
    )

    begin {
        $connectHint = 'Connect-SPOService -Url https://<tenant>-admin.sharepoint.com'
        if (-not (Get-Command Get-SPOSiteFileVersionExpirationReportJobProgress -ErrorAction SilentlyContinue)) {
            throw "Get-MttVersionStorageReportStatus needs a recent SharePoint Online Management Shell. In PowerShell 7 run: Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell, then $connectHint"
        }
        try {
            $null = Get-SPOSite -Limit 1 -ErrorAction Stop -WarningAction SilentlyContinue -Verbose:$false
        }
        catch {
            throw "Get-MttVersionStorageReportStatus needs a SharePoint Online Management Shell connection. Run: $connectHint"
        }
    }

    process {
        $site = $SiteUrl.TrimEnd('/')
        try {
            if ($Library) {
                $progress = Get-SPOListFileVersionExpirationReportJobProgress -Site $site -List $Library -ReportUrl $ReportUrl -ErrorAction Stop -Verbose:$false
            }
            else {
                $progress = Get-SPOSiteFileVersionExpirationReportJobProgress -Identity $site -ReportUrl $ReportUrl -ErrorAction Stop -Verbose:$false
            }
        }
        catch {
            Write-Warning "Skipped ${site}: $($_.Exception.Message)"
            return
        }

        # The cmdlet returns a plain object; read its status and error by name, whatever the casing
        $status = $null; $errorMessage = $null
        foreach ($property in $progress.PSObject.Properties) {
            if ($property.Name -match '^status$') { $status = "$($property.Value)" }
            elseif ($property.Name -match 'error') { $errorMessage = "$($property.Value)" }
        }
        if (-not $status) { $status = "$progress" }

        [PSCustomObject]@{
            PSTypeName   = 'MSTechTalk.VersionStorageReportStatus'
            SiteUrl      = $site
            Library      = $Library
            ReportUrl    = $ReportUrl
            Status       = $status
            ErrorMessage = $errorMessage
        }
    }
}
