<#
.SYNOPSIS
    Lists the SharePoint sites using the most storage and exports them to CSV.

.DESCRIPTION
    Read-only. Reads every site collection (OneDrive excluded) with Get-SPOSite,
    sorts by storage used and exports the top N with their last content change date.
    Big sites with an old LastContentModifiedDate are archive candidates.

    Module : SharePoint Online Management Shell (Microsoft.Online.SharePoint.PowerShell)
    Role   : SharePoint Administrator

.EXAMPLE
    .\Get-TopSitesByStorage.ps1 -AdminUrl https://contoso-admin.sharepoint.com

.EXAMPLE
    .\Get-TopSitesByStorage.ps1 -AdminUrl https://contoso-admin.sharepoint.com -Top 50 -ReportPath C:\Temp\Top50.csv
.NOTES
    Author      : Adnan Amin
    Blog        : https://mstechtalk.com
    Blog post   : https://mstechtalk.com/how-to-find-what-is-filling-a-sharepoint-site-and-free-up-tenant-storage/
    GitHub      : https://github.com/adnanamin/mstechtalk-powershell-scripts
    Disclaimer  : Provided as-is. Review the code and test in a suitable
                  environment before using it in production.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AdminUrl,

    [ValidateRange(1, 100000)]
    [int]$Top = 25,

    [string]$ReportPath = (Join-Path -Path (Get-Location) -ChildPath "TopSitesByStorage.csv")
)

Connect-SPOService -Url $AdminUrl

Write-Host "Reading sites. This can take a few minutes in a large tenant..."
$Sites = Get-SPOSite -Limit All

$Report = $Sites |
    Sort-Object StorageUsageCurrent -Descending |
    Select-Object -First $Top Url, Title, Template, LastContentModifiedDate,
        # StorageUsageCurrent and StorageQuota are in MB
        @{ n = "UsedGB";  e = { [math]::Round($_.StorageUsageCurrent / 1024, 2) } },
        @{ n = "QuotaGB"; e = { [math]::Round($_.StorageQuota / 1024, 2) } },
        @{ n = "DaysSinceLastChange"; e = { [int]((Get-Date) - $_.LastContentModifiedDate).TotalDays } }

$Report | Export-Csv -Path $ReportPath -NoTypeInformation -Encoding UTF8

$TotalGB = [math]::Round((($Sites | Measure-Object StorageUsageCurrent -Sum).Sum) / 1024, 2)
Write-Host "Sites read: $($Sites.Count). Storage used by all sites: $TotalGB GB."
Write-Host "Top $($Report.Count) sites exported to $ReportPath"
