#Requires -Version 7.4
#Requires -Modules PnP.PowerShell

function Get-MttClassicPublishingSite {
    <#
    .SYNOPSIS
        Finds classic publishing sites and subsites in SharePoint Online.
    .DESCRIPTION
        Checks a site collection and all of its subsites for the SharePoint Server Publishing
        Infrastructure feature (site collection), the SharePoint Server Publishing feature (web)
        and the ten classic templates that can't be created from 1 March 2027 (MC1565964).
        Returns one row for each web that matches. Read-only: it changes nothing.
    .PARAMETER SiteUrl
        Site collection to check. Accepts pipeline input, for example from Get-PnPTenantSite.
    .EXAMPLE
        Get-MttClassicPublishingSite -SiteUrl https://contoso.sharepoint.com/sites/Intranet
    .EXAMPLE
        Get-PnPTenantSite | Get-MttClassicPublishingSite | Export-Csv .\ClassicPublishingSites.csv -NoTypeInformation -Encoding UTF8
    .OUTPUTS
        MSTechTalk.ClassicPublishingSite
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      PnP.PowerShell 3.x
        Requires:    PnP
        Permissions: Delegated SharePoint AllSites.Read on your own Entra app; SharePoint Administrator
                     role to list sites with Get-PnPTenantSite; read access to each site checked
        Level:       Site (site collection and its subsites)
        Tested:      Not yet tested
    .LINK
        https://mstechtalk.com/find-classic-publishing-sites-sharepoint-online/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.ClassicPublishingSite')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Url')]
        [string]$SiteUrl
    )

    begin {
        try {
            $null = Get-PnPConnection -ErrorAction Stop
        }
        catch {
            throw 'Get-MttClassicPublishingSite needs a PnP PowerShell connection. Run: Connect-PnPOnline -Url https://contoso-admin.sharepoint.com -Interactive -ClientId <your app id>'
        }

        $publishingSiteFeature = 'f6924d36-2fa8-4f0b-b16d-06b7250180fa'  # SharePoint Server Publishing Infrastructure (site collection)
        $publishingWebFeature  = '94c94ca6-b32f-4da9-a9e3-1f3d343d7ecb'  # SharePoint Server Publishing (web)
        $blockedTemplates = @(
            'BLANKINTERNETCONTAINER#0', 'CMSPUBLISHING#0', 'BLANKINTERNET#0', 'ENTERWIKI#0', 'SRCHCEN#0',
            'SPSSITES#0', 'SPSNHOME#0', 'PRODUCTCATALOG#0', 'SPSREPORTCENTER#0', 'SPSTOPIC#0'
        )
    }

    process {
        $SiteUrl = $SiteUrl.TrimEnd('/')
        $siteHost = ([uri]$SiteUrl).Host
        Write-Verbose "Checking $SiteUrl"

        try {
            $siteFeatures = (Invoke-PnPSPRestMethod -Url "$SiteUrl/_api/site/features?`$select=DefinitionId" -ErrorAction Stop).value.DefinitionId
            $infrastructureActive = $siteFeatures -contains $publishingSiteFeature
        }
        catch {
            Write-Warning "Skipped $SiteUrl : $($_.Exception.Message)"
            return
        }

        # Walk the site collection and every subsite
        $webQueue = [System.Collections.Generic.Queue[string]]::new()
        $webQueue.Enqueue($SiteUrl)

        while ($webQueue.Count -gt 0) {
            $webUrl = $webQueue.Dequeue()
            try {
                $web = Invoke-PnPSPRestMethod -Url "$webUrl/_api/web?`$select=Title,WebTemplate,Configuration,LastItemModifiedDate" -ErrorAction Stop
                $webFeatures = (Invoke-PnPSPRestMethod -Url "$webUrl/_api/web/features?`$select=DefinitionId" -ErrorAction Stop).value.DefinitionId
                $template = '{0}#{1}' -f $web.WebTemplate, $web.Configuration
                $publishingActive = $webFeatures -contains $publishingWebFeature
                $blockedTemplate = $blockedTemplates -contains $template

                if ($infrastructureActive -or $publishingActive -or $blockedTemplate) {
                    [PSCustomObject]@{
                        PSTypeName                   = 'MSTechTalk.ClassicPublishingSite'
                        SiteUrl                      = $SiteUrl
                        WebUrl                       = $webUrl
                        Title                        = $web.Title
                        Template                     = $template
                        BlockedTemplate              = $blockedTemplate
                        PublishingInfrastructureOn   = $infrastructureActive
                        PublishingFeatureOn          = $publishingActive
                        LastItemModifiedDate         = [datetime]$web.LastItemModifiedDate
                    }
                }

                foreach ($subWeb in (Invoke-PnPSPRestMethod -Url "$webUrl/_api/web/webs?`$select=Url" -ErrorAction Stop).value) {
                    # Add-in (app) webs live on a different host and return 403, so skip them
                    if (([uri]$subWeb.Url).Host -ne $siteHost) {
                        Write-Verbose "Skipping add-in web $($subWeb.Url)"
                        continue
                    }
                    $webQueue.Enqueue($subWeb.Url.TrimEnd('/'))
                }
            }
            catch {
                Write-Warning "Skipped $webUrl : $($_.Exception.Message)"
            }
        }
    }
}
