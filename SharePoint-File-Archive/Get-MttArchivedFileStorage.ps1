#Requires -Version 5.1

function Get-MttArchivedFileStorage {
    <#
    .SYNOPSIS
        Shows how much storage file-level archived files use on each SharePoint site, and whether users can archive there.
    .DESCRIPTION
        Reads each site with Get-SPOSite and returns the storage used, the storage held by files archived with
        Microsoft 365 Archive file-level archive (ArchivedFileDiskUsed), and the site's AllowFileArchive setting.
        Use it after users, the SharePoint Admin Agent or an inactive files policy (New-SPOFileArchivePolicy)
        have archived files, to see where archived storage sits.

        AllowFileArchive True only means users are allowed to archive. The Archive action appears only after
        Microsoft 365 Archive is turned on for the tenant (pay-as-you-go).

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-SPOService first,
        and pipe the result to Export-Csv.

        In PowerShell 7, load the SharePoint Online Management Shell with
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell before you connect.
    .PARAMETER SiteUrl
        One or more sites to report on (alias Url). Accepts pipeline input, including objects from Get-SPOSite.
        Leave it out to report on every site in the tenant (OneDrive excluded).
    .EXAMPLE
        Get-MttArchivedFileStorage -SiteUrl https://contoso.sharepoint.com/sites/Projects

        Shows the archived file storage and archive setting of the Projects site.
    .EXAMPLE
        Get-MttArchivedFileStorage | Export-Csv .\ArchivedFileStorage.csv -NoTypeInformation -Encoding UTF8

        Saves every site in the tenant as a CSV file.
    .EXAMPLE
        Get-SPOSite -Limit All | Where-Object Url -like "*/sites/HR-*" | Get-MttArchivedFileStorage

        Checks only the sites whose URL starts with HR-.
    .OUTPUTS
        MSTechTalk.ArchivedFileStorage

        SiteUrl           Site URL
        Title             Site title
        StorageUsedMB     Storage used by the site, in MB
        ArchivedFileMB    Storage used by file-level archived files, in MB
        AllowFileArchive  Whether users can archive files on the site (True by default)
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Online.SharePoint.PowerShell 16.0.27814.12015 or later
        Requires:    SPO (ArchivedFileDiskUsed and AllowFileArchive are only returned by Get-SPOSite; PnP has no equivalent)
        Permissions: SharePoint Administrator
        Level:       Tenant, Site
        Tested:      18 November 2026 on the MST demo tenant, sites piped from Get-SPOSite (Windows PowerShell 5.1,
                     SPO module 16.0.27814.12015). The no-parameter, whole-tenant run is not tested yet.
        No #Requires -Modules line: in PowerShell 7 that line would load the module without
        -UseWindowsPowerShell, so the function checks for it in begin instead.
    .LINK
        https://mstechtalk.com/sharepoint-archive-inactive-files/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.ArchivedFileStorage')]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Url')]
        [string[]]$SiteUrl
    )

    begin {
        $connectHint = 'Connect-SPOService -Url https://<tenant>-admin.sharepoint.com'
        if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
            throw "Get-MttArchivedFileStorage needs the SharePoint Online Management Shell. In PowerShell 7 run: Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell, then $connectHint"
        }
        try {
            $null = Get-SPOSite -Limit 1 -ErrorAction Stop -WarningAction SilentlyContinue -Verbose:$false
        }
        catch {
            throw "Get-MttArchivedFileStorage needs a SharePoint Online Management Shell connection. Run: $connectHint"
        }

        $checkedAny = $false

        function ConvertTo-MttArchivedFileRow {
            param($Site)
            # ArchivedFileDiskUsed is in bytes, StorageUsageCurrent in MB
            [PSCustomObject]@{
                PSTypeName       = 'MSTechTalk.ArchivedFileStorage'
                SiteUrl          = "$($Site.Url)"
                Title            = "$($Site.Title)"
                StorageUsedMB    = [double]$Site.StorageUsageCurrent
                ArchivedFileMB   = [math]::Round(([double]$Site.ArchivedFileDiskUsed) / 1MB, 2)
                AllowFileArchive = $Site.AllowFileArchive
            }
        }
    }

    process {
        foreach ($url in $SiteUrl) {
            if (-not $url) { continue }
            $checkedAny = $true
            try {
                # Read each site with -Identity, which returns the full set of site properties
                $site = Get-SPOSite -Identity $url.TrimEnd('/') -ErrorAction Stop -Verbose:$false
                ConvertTo-MttArchivedFileRow -Site $site
            }
            catch {
                Write-Warning "Skipped ${url}: $($_.Exception.Message)"
            }
        }
    }

    end {
        if (-not $checkedAny) {
            Write-Verbose 'Reading every site in the tenant'
            try {
                $all = @(Get-SPOSite -Limit All -ErrorAction Stop -Verbose:$false)
            }
            catch {
                throw "Get-MttArchivedFileStorage couldn't list the sites: $($_.Exception.Message)"
            }
            $i = 0
            foreach ($s in $all) {
                $i++
                Write-Progress -Activity 'Get-MttArchivedFileStorage' -Status $s.Url -PercentComplete ($i / $all.Count * 100)
                try {
                    ConvertTo-MttArchivedFileRow -Site (Get-SPOSite -Identity $s.Url -ErrorAction Stop -Verbose:$false)
                }
                catch {
                    Write-Warning "Skipped $($s.Url): $($_.Exception.Message)"
                }
            }
            Write-Progress -Activity 'Get-MttArchivedFileStorage' -Completed
        }
    }
}
