#Requires -Version 5.1

function Get-MttSiteStorage {
    <#
    .SYNOPSIS
        Lists SharePoint sites by the storage they use, largest first, with the date of their last content change.
    .DESCRIPTION
        Reads every site collection in the tenant (OneDrive excluded) with Get-SPOSite, or only the sites you
        give it, and returns them sorted by storage used, largest first. Big sites with a high
        DaysSinceLastChange are archive candidates.

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-SPOService first,
        and pipe the result to Export-Csv.

        In PowerShell 7, load the SharePoint Online Management Shell with
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell before you connect.
    .PARAMETER SiteUrl
        One or more sites to report on. Accepts pipeline input from Get-MttSite. Leave it out to report on every
        site in the tenant.
    .PARAMETER Top
        Return only this many sites, the largest first. Leave it out to return them all.
    .EXAMPLE
        Get-MttSiteStorage -Top 25

        Lists the 25 sites using the most storage.
    .EXAMPLE
        Get-MttSiteStorage -SiteUrl https://contoso.sharepoint.com/sites/Projects

        Shows the storage used by the Projects site.
    .EXAMPLE
        Get-MttSiteStorage | Export-Csv .\SiteStorage.csv -NoTypeInformation -Encoding UTF8

        Saves every site, largest first, as a CSV file.
    .EXAMPLE
        Get-MttSiteStorage | Where-Object { $_.StorageUsedGB -gt 100 -and $_.DaysSinceLastChange -gt 365 }

        Sites over 100 GB that haven't changed in a year: archive candidates.
    .OUTPUTS
        MSTechTalk.SiteStorage

        SiteUrl              Site URL
        Title                Site title
        Template             Site template, for example GROUP#0 or SITEPAGEPUBLISHING#0
        StorageUsedGB        Storage used, in GB
        StorageQuotaGB       Storage quota, in GB
        PercentUsed          Storage used as a percentage of the quota
        LastContentModified  Date of the last content change on the site
        DaysSinceLastChange  Days since that change
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Online.SharePoint.PowerShell (SharePoint Online Management Shell)
        Requires:    SPO (one Get-SPOSite call returns storage for every site; PnP needs a call per site)
        Permissions: SharePoint Administrator
        Level:       Tenant, Site
        Tested:      16 November 2026 on the MST demo tenant (PowerShell 7.6.9 with -UseWindowsPowerShell, and
                     Windows PowerShell 5.1; SPO module 16.0.27424.0)
        No #Requires -Modules line: in PowerShell 7 that line would load the module without
        -UseWindowsPowerShell, so the function checks for it in begin instead.
    .LINK
        https://mstechtalk.com/how-to-find-what-is-filling-a-sharepoint-site-and-free-up-tenant-storage/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.SiteStorage')]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Url')]
        [string[]]$SiteUrl,

        [ValidateRange(1, 1000000)]
        [int]$Top
    )

    begin {
        $connectHint = 'Connect-SPOService -Url https://<tenant>-admin.sharepoint.com'
        if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
            throw "Get-MttSiteStorage needs the SharePoint Online Management Shell. In PowerShell 7 run: Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell, then $connectHint"
        }
        try {
            $null = Get-SPOSite -Limit 1 -ErrorAction Stop -WarningAction SilentlyContinue -Verbose:$false
        }
        catch {
            throw "Get-MttSiteStorage needs a SharePoint Online Management Shell connection. Run: $connectHint"
        }

        $sites = New-Object System.Collections.ArrayList
        $checkedAny = $false
    }

    process {
        foreach ($url in $SiteUrl) {
            if (-not $url) { continue }
            $checkedAny = $true
            try {
                $null = $sites.Add((Get-SPOSite -Identity $url.TrimEnd('/') -ErrorAction Stop -Verbose:$false))
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
                foreach ($site in @(Get-SPOSite -Limit All -ErrorAction Stop -Verbose:$false)) { $null = $sites.Add($site) }
            }
            catch {
                throw "Get-MttSiteStorage couldn't list the sites: $($_.Exception.Message)"
            }
        }

        # StorageUsageCurrent and StorageQuota are in MB
        $totalMB = ($sites | Measure-Object -Property StorageUsageCurrent -Sum).Sum
        Write-Verbose "Sites read: $($sites.Count). Storage used by these sites: $([math]::Round($totalMB / 1024, 2)) GB"

        $sorted = $sites | Sort-Object { [double]$_.StorageUsageCurrent } -Descending
        if ($Top) { $sorted = $sorted | Select-Object -First $Top }

        $now = Get-Date
        foreach ($site in $sorted) {
            $usedMB = [double]$site.StorageUsageCurrent
            $quotaMB = [double]$site.StorageQuota
            $modified = $site.LastContentModifiedDate
            if ($modified -and -not ($modified -is [datetime])) { $modified = [datetime]$modified }
            $days = $null
            if ($modified -and $modified -gt [datetime]'1900-01-01') { $days = [int]($now - $modified).TotalDays }
            $percent = $null
            if ($quotaMB -gt 0) { $percent = [math]::Round($usedMB / $quotaMB * 100, 1) }

            [PSCustomObject]@{
                PSTypeName          = 'MSTechTalk.SiteStorage'
                SiteUrl             = "$($site.Url)"
                Title               = "$($site.Title)"
                Template            = "$($site.Template)"
                StorageUsedGB       = [math]::Round($usedMB / 1024, 2)
                StorageQuotaGB      = [math]::Round($quotaMB / 1024, 2)
                PercentUsed         = $percent
                LastContentModified = $modified
                DaysSinceLastChange = $days
            }
        }
    }
}
