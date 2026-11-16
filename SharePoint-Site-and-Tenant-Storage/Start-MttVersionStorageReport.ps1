#Requires -Version 5.1

function Start-MttVersionStorageReport {
    <#
    .SYNOPSIS
        Starts a SharePoint version storage report job for a site, a OneDrive or one library.
    .DESCRIPTION
        Queues Microsoft's version storage report job. The job writes one CSV row per file version (size, version
        number, who changed it, expiration dates) to the report URL you give, in a document library of the same
        site. It runs in the background: a small site takes over 24 hours, a large one a few days.

        Don't open or edit the CSV while it fills, or the job fails. Deleting the CSV cancels the job. Put it in a
        library or folder only site owners can open: the report lists every file and who edited it.

        The function only creates the report CSV; it doesn't change any file or version. It doesn't connect: sign in
        with Connect-SPOService first. It returns the job status; check it again later with
        Get-MttVersionStorageReportStatus, then read the finished CSV with Measure-MttVersionStorage.

        In PowerShell 7, load the SharePoint Online Management Shell with
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell before you connect.
    .PARAMETER SiteUrl
        Site or OneDrive URL to report on.
    .PARAMETER ReportUrl
        Full URL of the CSV to create, in a document library of the same site. The file must not exist yet.
    .PARAMETER Library
        Title of one library. Leave it out to report on the whole site.
    .EXAMPLE
        Start-MttVersionStorageReport -SiteUrl https://contoso.sharepoint.com/sites/Projects -ReportUrl "https://contoso.sharepoint.com/sites/Projects/Shared Documents/Reports/VersionReport.csv"

        Starts the report for the whole Projects site.
    .EXAMPLE
        Start-MttVersionStorageReport -SiteUrl https://contoso.sharepoint.com/sites/Projects -Library "Documents" -ReportUrl "https://contoso.sharepoint.com/sites/Projects/Shared Documents/Reports/DocsVersions.csv"

        Starts the report for the Documents library only.
    .EXAMPLE
        $job = Start-MttVersionStorageReport -SiteUrl $SiteUrl -ReportUrl $ReportUrl
        $job | Get-MttVersionStorageReportStatus

        Starts the job, and checks it again later.
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
                     Windows PowerShell 5.1; SPO module 16.0.27424.0): the job on a demo site completed the same
                     evening, and Measure-MttVersionStorage read the CSV (2,376 versions of 574 files)
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

        [Parameter(Mandatory)]
        [string]$ReportUrl,

        [string]$Library
    )

    begin {
        $connectHint = 'Connect-SPOService -Url https://<tenant>-admin.sharepoint.com'
        if (-not (Get-Command New-SPOSiteFileVersionExpirationReportJob -ErrorAction SilentlyContinue)) {
            throw "Start-MttVersionStorageReport needs a recent SharePoint Online Management Shell. In PowerShell 7 run: Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell, then $connectHint"
        }
        try {
            $null = Get-SPOSite -Limit 1 -ErrorAction Stop -WarningAction SilentlyContinue -Verbose:$false
        }
        catch {
            throw "Start-MttVersionStorageReport needs a SharePoint Online Management Shell connection. Run: $connectHint"
        }
    }

    process {
        $site = $SiteUrl.TrimEnd('/')
        if (-not $ReportUrl.StartsWith("$site/", [StringComparison]::OrdinalIgnoreCase)) {
            throw "ReportUrl must be in a document library of the same site ($site)."
        }
        if (-not $ReportUrl.EndsWith('.csv', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'ReportUrl must end with .csv'
        }

        try {
            if ($Library) {
                $null = New-SPOListFileVersionExpirationReportJob -Site $site -List $Library -ReportUrl $ReportUrl -Confirm:$false -ErrorAction Stop -Verbose:$false
                $progress = Get-SPOListFileVersionExpirationReportJobProgress -Site $site -List $Library -ReportUrl $ReportUrl -ErrorAction Stop -Verbose:$false
            }
            else {
                $null = New-SPOSiteFileVersionExpirationReportJob -Identity $site -ReportUrl $ReportUrl -Confirm:$false -ErrorAction Stop -Verbose:$false
                $progress = Get-SPOSiteFileVersionExpirationReportJobProgress -Identity $site -ReportUrl $ReportUrl -ErrorAction Stop -Verbose:$false
            }
        }
        catch {
            Write-Warning "Couldn't start the report for ${site}: $($_.Exception.Message)"
            return
        }
        Write-Verbose "Report job started for $site. Check it with Get-MttVersionStorageReportStatus in a few hours."

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
