#Requires -Version 5.1

function Get-MttCopilotBlockedSite {
    <#
    .SYNOPSIS
        Lists the SharePoint sites where Copilot is blocked by Restricted Content Discovery (RCD).
    .DESCRIPTION
        Reads the RestrictContentOrgWideSearch property of each site and returns one row for every site where it
        is on. With -SiteUrl, or sites from the pipeline, only those sites are checked; without them, every site
        in the tenant is checked.

        Each site is read by URL, because Get-SPOSite -Limit All doesn't fill in this property. That's one call
        per site, so a big tenant takes a while: Microsoft's RCD insights report (Get-RCDInsightsReport.ps1 in
        the same folder) is faster there.

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-SPOService first,
        and pipe the result to Export-Csv.

        In PowerShell 7, load the SharePoint Online Management Shell with
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell before you connect.
    .PARAMETER SiteUrl
        One or more sites to check. Accepts pipeline input from Get-MttSite. Leave it out to check every site in
        the tenant.
    .EXAMPLE
        Get-MttCopilotBlockedSite

        Lists every site in the tenant where Copilot is blocked.
    .EXAMPLE
        Get-MttCopilotBlockedSite -SiteUrl https://contoso.sharepoint.com/sites/Finance

        Returns the Finance site if Copilot is blocked there, and nothing if it isn't.
    .EXAMPLE
        Get-MttCopilotBlockedSite | Export-Csv .\CopilotBlockedSites.csv -NoTypeInformation -Encoding UTF8

        Saves the report as a CSV file.
    .OUTPUTS
        MSTechTalk.CopilotBlockedSite

        SiteUrl              Site URL
        Title                Site title
        Owner                Primary owner, as Get-SPOSite returns it (empty for most group-connected sites)
        Template             Site template, for example GROUP#0 or SITEPAGEPUBLISHING#0
        LastContentModified  Date of the last content change on the site
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Online.SharePoint.PowerShell (SharePoint Online Management Shell)
        Requires:    SPO (PnP and Microsoft Graph don't return RestrictContentOrgWideSearch)
        Permissions: SharePoint Administrator
        Level:       Tenant, Site
        Tested:      16 November 2026 on the MST demo tenant (PowerShell 7.6.9 with -UseWindowsPowerShell, and Windows PowerShell 5.1; SPO module 16.0.27424.0)
        No #Requires -Modules line: in PowerShell 7 that line would load the module without
        -UseWindowsPowerShell, so the function checks for it in begin instead.
    .LINK
        https://mstechtalk.com/find-sharepoint-sites-copilot-blocked/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.CopilotBlockedSite')]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Url')]
        [string[]]$SiteUrl
    )

    begin {
        $connectHint = 'Connect-SPOService -Url https://<tenant>-admin.sharepoint.com'
        if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
            throw "Get-MttCopilotBlockedSite needs the SharePoint Online Management Shell. In PowerShell 7 run: Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell, then $connectHint"
        }
        try {
            $null = Get-SPOSite -Limit 1 -ErrorAction Stop -WarningAction SilentlyContinue -Verbose:$false
        }
        catch {
            throw "Get-MttCopilotBlockedSite needs a SharePoint Online Management Shell connection. Run: $connectHint"
        }

        $checkedAny = $false

        function Get-RcdSiteRow {
            param([string]$Url)
            try {
                $site = Get-SPOSite -Identity $Url -ErrorAction Stop -Verbose:$false
            }
            catch {
                Write-Warning "Skipped ${Url}: $($_.Exception.Message)"
                return
            }
            if ($site.RestrictContentOrgWideSearch -eq $true) {
                $modified = $site.LastContentModifiedDate
                if ($modified -and -not ($modified -is [datetime])) { $modified = [datetime]$modified }
                [PSCustomObject]@{
                    PSTypeName          = 'MSTechTalk.CopilotBlockedSite'
                    SiteUrl             = "$($site.Url)"
                    Title               = "$($site.Title)"
                    Owner               = "$($site.Owner)"
                    Template            = "$($site.Template)"
                    LastContentModified = $modified
                }
            }
        }
    }

    process {
        foreach ($url in $SiteUrl) {
            if (-not $url) { continue }
            $checkedAny = $true
            Write-Verbose "Checking $url"
            Get-RcdSiteRow -Url $url.TrimEnd('/')
        }
    }

    end {
        if ($checkedAny) { return }

        try {
            $sites = @(Get-SPOSite -Limit All -ErrorAction Stop -Verbose:$false)
        }
        catch {
            throw "Get-MttCopilotBlockedSite couldn't list the sites: $($_.Exception.Message)"
        }
        Write-Verbose "Checking $($sites.Count) sites"

        $activity = 'Sites with Copilot blocked'
        $number = 0
        foreach ($site in $sites) {
            $number++
            Write-Progress -Activity $activity -Status "$number of $($sites.Count): $($site.Url)" -PercentComplete ($number / $sites.Count * 100)
            Get-RcdSiteRow -Url $site.Url
        }
        Write-Progress -Activity $activity -Completed
    }
}
