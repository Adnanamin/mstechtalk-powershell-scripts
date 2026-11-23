#Requires -Version 5.1

function Get-MttSite {
    <#
    .SYNOPSIS
        Lists the SharePoint sites in the tenant, with type, owner, storage, hub, last change date and, if you ask,
        external sharing.
    .DESCRIPTION
        Reads every site collection with Get-SPOSite in one call and returns one row per site. It is the
        starting point for tenant-wide reports: filter it, or pipe it into another Mtt function.

        It returns the same sites as the Active sites page in the SharePoint admin center, plus Teams channel
        sites (private and shared channels), which that page only shows through the Channel sites column.
        OneDrive sites, site redirects and system sites (My Site host, PointPublishing, search center) are left
        out unless you ask for them.

        LastContentModified is the last change of any kind, including changes made by Microsoft or by an admin
        tool, so it is not the same as the Last activity column in the admin center, which counts user activity.

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-SPOService first,
        and pipe the result to Export-Csv.

        In PowerShell 7, load the SharePoint Online Management Shell with
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell before you connect.

        Piping into functions that use PnP PowerShell (for example Get-MttUniquePermission) works one site at a
        time: those functions report only on the site PnP is signed in to and skip the others with a warning.
        See the last example for a loop that signs in to each site.
    .PARAMETER Template
        Return only sites with this template, for example GROUP#0 (Microsoft 365 group sites),
        SITEPAGEPUBLISHING#0 (communication sites), STS#3 (team sites without a group) or TEAMCHANNEL#0
        (channel sites). Filtered on the server.
    .PARAMETER IncludeSharing
        Also read each site's external sharing setting. This takes one extra call per site, so it is slower on
        a large tenant (Get-SPOSite doesn't return sharing settings when it lists all sites).
    .PARAMETER IncludeOneDrive
        Also return OneDrive sites.
    .PARAMETER IncludeSystemSite
        Also return site redirects (REDIRECTSITE#0), the My Site host, PointPublishing sites and the search
        center. The admin center hides these too.
    .EXAMPLE
        Get-MttSite | Export-Csv .\Sites.csv -NoTypeInformation -Encoding UTF8

        Saves every site as a CSV file.
    .EXAMPLE
        Get-MttSite | Sort-Object StorageUsedGB -Descending | Select-Object -First 10

        The ten largest sites.
    .EXAMPLE
        Get-MttSite | Where-Object { $_.SiteType -eq 'Group site' -and -not $_.IsTeamsConnected }

        Microsoft 365 group sites that have no team in Microsoft Teams.
    .EXAMPLE
        Get-MttSite -IncludeSharing | Where-Object SharingCapability -eq 'ExternalUserAndGuestSharing'

        Sites that allow Anyone links.
    .EXAMPLE
        Get-MttSite | Group-Object HubSite | Select-Object Name, Count

        How many sites are associated with each hub.
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
        SiteType             Group site, Team site (no group), Communication site, Channel site, Classic site,
                             App catalog, OneDrive or Other
        Template             Site template, for example GROUP#0 or SITEPAGEPUBLISHING#0
        Owner                Primary admin. Empty for group sites, where the group owners own the site
        StorageUsedGB        Storage used, in GB
        LastContentModified  Date of the last change of any kind on the site
        DaysSinceLastChange  Days since that change
        IsTeamsConnected     True when the site belongs to a team in Microsoft Teams
        GroupId              ID of the Microsoft 365 group, or empty
        IsHubSite            True when the site is registered as a hub
        HubSite              Title of the hub the site is associated with (a hub site shows its own title), or empty
        LockState            Unlock, ReadOnly or NoAccess
        ArchiveStatus        Microsoft 365 Archive status, for example NotArchived or FullyArchived
        SharingCapability    External sharing setting (only with -IncludeSharing): Disabled,
                             ExistingExternalUserSharingOnly, ExternalUserSharingOnly or ExternalUserAndGuestSharing
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Online.SharePoint.PowerShell (SharePoint Online Management Shell)
        Requires:    SPO (one Get-SPOSite call lists every site; PnP's tenant site list needs an admin-site
                     connection, which would replace the per-site PnP connection the other functions use)
        Permissions: SharePoint Administrator
        Level:       Tenant
        Tested:      20 November 2026 on the MST demo tenant (Windows PowerShell 5.1, and PowerShell 7.6.10 with
                     -UseWindowsPowerShell; SPO module 16.0.27814.12015): 68 sites in 2 seconds (72 with
                     -IncludeSystemSite), 1 hub site (3 more hub registrations have no site URL),
                     -IncludeSharing on 68 sites in about 40 seconds
        No #Requires -Modules line: in PowerShell 7 that line would load the module without
        -UseWindowsPowerShell, so the function checks for it in begin instead.
    .LINK
        https://mstechtalk.com/sharepoint-site-inventory-powershell/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.Site')]
    param(
        [string]$Template,

        [switch]$IncludeSharing,

        [switch]$IncludeOneDrive,

        [switch]$IncludeSystemSite
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

        # Templates the Active sites page hides as system sites (channel sites are kept)
        $systemTemplates = 'REDIRECTSITE*', 'SPSMSITEHOST*', 'POINTPUBLISHING*', 'SRCHCEN*', 'CENTRALADMIN*',
            'TENANTADMIN*', 'CSPCONTAINER*', 'POLICYCTR*', 'REVIEWCTR*'
        $emptyGuid = '00000000-0000-0000-0000-000000000000'

        function Get-SiteValue {
            param($Site, [string]$Name)
            $p = $Site.PSObject.Properties[$Name]
            if ($p) { $p.Value }
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

        # Hub titles, one call for the tenant
        $hubs = @{}
        $hubUrls = @{}
        try {
            foreach ($hub in @(Get-SPOHubSite -ErrorAction Stop -Verbose:$false)) {
                $hubs["$($hub.ID)"] = "$($hub.Title)"
                $hubUrls["$($hub.SiteUrl)".TrimEnd('/').ToLowerInvariant()] = $true
            }
            Write-Verbose "Hubs read: $($hubs.Count)"
        }
        catch {
            Write-Warning "Couldn't read the hub sites, so HubSite is empty: $($_.Exception.Message)"
        }

        $now = Get-Date
        $i = 0
        foreach ($site in $sites) {
            $i++
            $tpl = "$($site.Template)"
            if (-not $IncludeSystemSite -and -not $Template) {
                $isSystem = $false
                foreach ($pattern in $systemTemplates) { if ($tpl -like $pattern) { $isSystem = $true; break } }
                if ($isSystem) { continue }
            }

            $siteType = switch -Wildcard ($tpl) {
                'GROUP#*'              { 'Group site'; break }
                'SITEPAGEPUBLISHING#*' { 'Communication site'; break }
                'STS#3'                { 'Team site (no group)'; break }
                'TEAMCHANNEL#*'        { 'Channel site'; break }
                'SPSPERS*'             { 'OneDrive'; break }
                'STS#0'                { 'Classic site'; break }
                'STS#1'                { 'Classic site'; break }
                'BLOG#*'               { 'Classic site'; break }
                'BDR#*'                { 'Classic site'; break }
                'DEV#*'                { 'Classic site'; break }
                'PROJECTSITE#*'        { 'Classic site'; break }
                'APPCATALOG#*'         { 'App catalog'; break }
                default                { 'Other' }
            }

            $modified = $site.LastContentModifiedDate
            if ($modified -and -not ($modified -is [datetime])) { $modified = [datetime]$modified }
            $days = $null
            if ($modified -and $modified -gt [datetime]'1900-01-01') { $days = [int]($now - $modified).TotalDays }

            $groupId = $null
            if ($site.GroupId -and "$($site.GroupId)" -ne $emptyGuid) { $groupId = "$($site.GroupId)" }

            $hubId = "$(Get-SiteValue $site 'HubSiteId')"
            $hubTitle = $null
            if ($hubId -and $hubId -ne $emptyGuid) {
                $hubTitle = $hubs[$hubId]
                if (-not $hubTitle) { $hubTitle = $hubId }
            }

            $archive = Get-SiteValue $site 'ArchiveStatus'

            $row = [ordered]@{
                PSTypeName          = 'MSTechTalk.Site'
                SiteUrl             = "$($site.Url)"
                Title               = "$($site.Title)"
                SiteType            = $siteType
                Template            = $tpl
                Owner               = "$($site.Owner)"
                StorageUsedGB       = [math]::Round([double]$site.StorageUsageCurrent / 1024, 2)
                LastContentModified = $modified
                DaysSinceLastChange = $days
                IsTeamsConnected    = [bool]$site.IsTeamsConnected
                GroupId             = $groupId
                IsHubSite           = [bool]($hubUrls["$($site.Url)".TrimEnd('/').ToLowerInvariant()] -or (Get-SiteValue $site 'IsHubSite'))
                HubSite             = $hubTitle
                LockState           = "$($site.LockState)"
                ArchiveStatus       = $(if ($null -ne $archive) { "$archive" } else { $null })
            }

            if ($IncludeSharing) {
                Write-Progress -Activity 'Get-MttSite' -Status "Reading sharing setting: $($site.Url)" -PercentComplete ([int]($i / $sites.Count * 100))
                $sharing = $null
                try {
                    $one = Get-SPOSite -Identity $site.Url -ErrorAction Stop -Verbose:$false
                    $sharing = "$($one.SharingCapability)"
                }
                catch {
                    Write-Warning "Couldn't read the sharing setting of $($site.Url): $($_.Exception.Message)"
                }
                $row.SharingCapability = $sharing
            }

            [PSCustomObject]$row
        }
        if ($IncludeSharing) { Write-Progress -Activity 'Get-MttSite' -Completed }
    }
}
