<#
.SYNOPSIS
    Lists every Anyone (anonymous) sharing link on a SharePoint site.
.DESCRIPTION
    Goes through every visible document library on the site and checks each file and folder
    for sharing links. Writes one CSV row per item that an Anyone link opens, with the link type
    (view or edit) and expiry. A file inside a folder that has an Anyone link gets a row for the
    folder's link too, so the row count is higher than the number of links created.
.NOTES
    Author:      Adnan Amin
    Blog:        https://mstechtalk.com
    GitHub:      https://github.com/adnanamin/mstechtalk-powershell-scripts
    Module:      PnP.PowerShell 3.x (tested with 3.5.0), PowerShell 7.4 or later
    Permissions: Site collection admin on the site; your own Entra app registration for Connect-PnPOnline
    Tested:      15 November 2026 (PowerShell 7.6, PnP.PowerShell 3.5.0)
.LINK
    https://mstechtalk.com/find-anyone-links-sharepoint-pnp-powershell/
#>
param(
    [string]$SiteUrl  = "https://mstalk.sharepoint.com/sites/MST-SalesMarketing",  # Replace with your own
    [string]$ClientId = "<your-entra-app-client-id>",                               # Replace with your own
    [string]$Report   = "C:\Temp\AnyoneLinks-SalesMarketing.csv"
)

Connect-PnPOnline -Url $SiteUrl -ClientId $ClientId -Interactive

$libraries = Get-PnPList | Where-Object { $_.BaseTemplate -eq 101 -and -not $_.Hidden }

$results = foreach ($library in $libraries) {
    Write-Host "Checking $($library.Title)..."
    foreach ($item in Get-PnPListItem -List $library -PageSize 500) {
        $path = $item.FieldValues.FileRef
        try {
            if ($item.FileSystemObjectType -eq "Folder") {
                $links = Get-PnPFolderSharingLink -Folder $path -ErrorAction Stop
            }
            else {
                $links = Get-PnPFileSharingLink -Identity $path -ErrorAction Stop
            }
        }
        catch {
            Write-Warning "Skipped $path : $($_.Exception.Message)"
            continue
        }

        foreach ($link in $links | Where-Object { $_.Link.Scope -eq "anonymous" }) {
            [PSCustomObject]@{
                Library = $library.Title
                Path    = $path
                Type    = $link.Link.Type        # view or edit
                Expires = $link.ExpirationDateTime
            }
        }
    }
}

$folder = Split-Path $Report -Parent
if ($folder) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
$results | Export-Csv -Path $Report -NoTypeInformation
Write-Host "$(@($results).Count) Anyone links written to $Report"
$results
