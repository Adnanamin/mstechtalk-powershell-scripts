<#
.SYNOPSIS
    Lists every SharePoint site where Copilot is blocked by Restricted Content Discovery (RCD).

.DESCRIPTION
    Read-only. Needs the SharePoint Online Management Shell (Microsoft.Online.SharePoint.PowerShell)
    and the SharePoint Administrator role. Windows PowerShell 5.1 is recommended.

    Loops through every site, reads the RestrictContentOrgWideSearch property of each one and
    exports the sites where it is on to CSV (Title, Url, Owner). Each site is queried by URL
    because the Get-SPOSite reference doesn't document this property for bulk (-Limit All) output.
    One call per site, so it is slow on a big tenant: use Get-RCDInsightsReport.ps1 there.

.PARAMETER AdminUrl
    SharePoint admin center URL, for example https://contoso-admin.sharepoint.com

.PARAMETER ReportPath
    Path of the CSV file to write. Default: copilot-blocked-sites.csv in the current folder.

.EXAMPLE
    .\Get-CopilotBlockedSites.ps1 -AdminUrl https://mstalk-admin.sharepoint.com
.EXAMPLE
    .\Get-CopilotBlockedSites.ps1 -AdminUrl https://mstalk-admin.sharepoint.com -ReportPath C:\Temp\copilot-blocked-sites.csv

.NOTES
    Author      : Adnan Amin
    Blog        : https://mstechtalk.com
    Article     : https://mstechtalk.com/find-sharepoint-sites-copilot-blocked/
    GitHub      : https://github.com/adnanamin/mstechtalk-powershell-scripts
    Permissions : SharePoint Administrator
    Tested      : 15 November 2026, Windows PowerShell 5.1, on a demo tenant
    Disclaimer  : Provided as-is. Review the code and test in a suitable
                  environment before using it in production.
#>
#Requires -Modules Microsoft.Online.SharePoint.PowerShell
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AdminUrl,

    [string]$ReportPath = (Join-Path (Get-Location).Path 'copilot-blocked-sites.csv')
)

$ErrorActionPreference = 'Stop'

Connect-SPOService -Url $AdminUrl

$Sites  = Get-SPOSite -Limit All
$Result = foreach ($Site in $Sites) {
    try {
        # Query each site by URL so the RCD property is read for that site
        $Detail = Get-SPOSite -Identity $Site.Url
        if ($Detail.RestrictContentOrgWideSearch) {
            [PSCustomObject]@{
                Title = $Detail.Title
                Url   = $Detail.Url
                Owner = $Detail.Owner
            }
        }
    }
    catch {
        Write-Warning "Could not read $($Site.Url): $($_.Exception.Message)"
    }
}

$Result | Export-Csv -Path $ReportPath -NoTypeInformation
Write-Output "$(@($Result).Count) sites have Copilot blocked. Report: $ReportPath"
