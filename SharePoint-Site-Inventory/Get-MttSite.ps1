#Requires -Version 5.1

function Get-MttSite {
    <#
    .SYNOPSIS
        Lists the SharePoint sites in the tenant, with template, owner, storage and last change date.
    .DESCRIPTION
        Reads every site collection with Get-SPOSite in one call and returns one row per site. It is the
        starting point for tenant-wide reports: pipe it into another Mtt function, or filter it first.

        OneDrive sites and site redirects (REDIRECTSITE#0, left behind by a site rename) are left out unless
        you ask for them.

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-SPOService first,
        and pipe the result to Export-Csv.

        In PowerShell 7, load the SharePoint Online Management Shell with
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell before you connect.

        Piping into functions that use PnP PowerShell (for example Get-MttUniquePermission) works one site at a
        time: those functions report only on the site PnP is signed in to and skip the others with a warning.
        See the last example for a loop that signs in to each site.
    .PARAMETER Template
        Return only sites with this template, for example GROUP#0 (Microsoft 365 group sites),
        SITEPAGEPUBLISHING#0 (communication sites) or STS#3 (team sites without a group). Filtered on the server.
    .PARAMETER IncludeOneDrive
        Also return OneDrive sites.
    .PARAMETER IncludeRedirect
        Also return site redirects (REDIRECTSITE#0).
    .EXAMPLE
        Get-MttSite

        Lists every SharePoint site in the tenant.
    .EXAMPLE
        Get-MttSite -Template GROUP#0 | Export-Csv .\GroupSites.csv -NoTypeInformation -Encoding UTF8

        Saves every Microsoft 365 group site as a CSV file.
    .EXAMPLE
        Get-MttSite | Where-Object { $_.DaysSinceLastChange -gt 365 }

        Sites with no content change in a year.
    .EXAMPLE
        Get-MttSite | Get-MttCustomScriptSite

        Passes every site to another SPO-based function.
    .EXAMPLE
        Get-MttSite | Where-Object SiteUrl -like '*/sites/Projects*' | ForEach-Object {
            Connect-PnPOnline -Url $_.SiteUrl -Interactive -ClientId $ClientId
            Get-MttUniquePermission -SiteUrl $_.SiteUrl
        } | Export-Csv .\UniquePermissions.csv -NoTypeInformation -Encoding UTF8

        Signs in to each site with PnP in turn, so a PnP-based function can report on all of them.
    .OUTPUTS
        MSTechTalk.Site

        SiteUrl              Site URL
        Title                Site title
        Template             Site template, for example GROUP#0 or SITEPAGEPUBLISHING#0
        Owner                Primary owner (for group sites this is the group, shown as an ID)
        StorageUsedGB        Storage used, in GB
        LastContentModified  Date of the last content change on the site
        DaysSinceLastChange  Days since that change
        IsTeamsConnected     True when the site belongs to a team in Microsoft Teams
        GroupId              ID of the Microsoft 365 group, or empty
        LockState            Unlock, ReadOnly or NoAccess
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Online.SharePoint.PowerShell (SharePoint Online Management Shell)
        Requires:    SPO (one Get-SPOSite call lists every site; PnP's tenant site list needs an admin-site
                     connection, which would replace the per-site PnP connection the other functions use)
        Permissions: SharePoint Administrator
        Level:       Tenant
        Tested:      20 November 2026 on the MST demo tenant (Windows PowerShell 5.1, and PowerShell 7.6.10 with
                     -UseWindowsPowerShell; SPO module 16.0.27814.12015): 72 sites, the same count and storage
                     (31.38 GB) as Get-MttSiteStorage; -Template GROUP#0 and -IncludeOneDrive checked
        No #Requires -Modules line: in PowerShell 7 that line would load the module without
        -UseWindowsPowerShell, so the function checks for it in begin instead.
    .LINK
        https://github.com/Adnanamin/mstechtalk-powershell-scripts/tree/main/SharePoint-Site-Inventory
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.Site')]
    param(
        [string]$Template,

        [switch]$IncludeOneDrive,

        [switch]$IncludeRedirect
    )

    begin {
        $connectHint = 'Connect-SPOService -Url https://<tenant>-admin.sharepoint.com'
        if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
            throw "Get-MttSite needs the SharePoint Online Management Shell. In PowerShell 7 run: Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell, then $connectHint"
        }
        try {
            $null = Get-SPOSite -Limit 1 -ErrorAction Stop -WarningAction SilentlyContinue -Verbose:$false
        }
        catch {
            throw "Get-MttSite needs a SharePoint Online Management Shell connection. Run: $connectHint"
        }
    }

    end {
        $params = @{ Limit = 'All'; ErrorAction = 'Stop'; Verbose = $false }
        if ($Template) { $params.Template = $Template }
        if ($IncludeOneDrive) { $params.IncludePersonalSite = $true }

        Write-Verbose 'Reading the sites in the tenant'
        try {
            $sites = @(Get-SPOSite @params)
        }
        catch {
            throw "Get-MttSite couldn't list the sites: $($_.Exception.Message)"
        }
        Write-Verbose "Sites read: $($sites.Count)"

        $now = Get-Date
        foreach ($site in $sites) {
            if (-not $IncludeRedirect -and -not $Template -and "$($site.Template)" -like 'REDIRECTSITE*') { continue }

            $modified = $site.LastContentModifiedDate
            if ($modified -and -not ($modified -is [datetime])) { $modified = [datetime]$modified }
            $days = $null
            if ($modified -and $modified -gt [datetime]'1900-01-01') { $days = [int]($now - $modified).TotalDays }

            $groupId = $null
            if ($site.GroupId -and "$($site.GroupId)" -ne '00000000-0000-0000-0000-000000000000') { $groupId = "$($site.GroupId)" }

            [PSCustomObject]@{
                PSTypeName          = 'MSTechTalk.Site'
                SiteUrl             = "$($site.Url)"
                Title               = "$($site.Title)"
                Template            = "$($site.Template)"
                Owner               = "$($site.Owner)"
                StorageUsedGB       = [math]::Round([double]$site.StorageUsageCurrent / 1024, 2)
                LastContentModified = $modified
                DaysSinceLastChange = $days
                IsTeamsConnected    = [bool]$site.IsTeamsConnected
                GroupId             = $groupId
                LockState           = "$($site.LockState)"
            }
        }
    }
}
