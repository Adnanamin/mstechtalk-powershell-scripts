<#
.SYNOPSIS
    Lists every library, list, folder, file and list item with unique permissions on a SharePoint site.
.DESCRIPTION
    Loads HasUniqueRoleAssignments for each visible list and each item in it, and writes one CSV row
    per object that has stopped inheriting permissions. Ends with a count per list and level.
.NOTES
    Author:      Adnan Amin
    Blog:        https://mstechtalk.com
    GitHub:      https://github.com/adnanamin/mstechtalk-powershell-scripts
    Module:      PnP.PowerShell 3.x (tested with 3.5.0), PowerShell 7.4 or later
    Permissions: Site collection admin on the site; your own Entra app registration for Connect-PnPOnline
    Tested:      15 November 2026 (PowerShell 7.6, PnP.PowerShell 3.5.0)
.LINK
    https://mstechtalk.com/sharepoint-unique-permissions-report-pnp-powershell/
#>
param(
    [string]$SiteUrl  = "https://mstalk.sharepoint.com/sites/MST-PMO",  # Replace with your own
    [string]$ClientId = "<your-entra-app-client-id>",                   # Replace with your own
    [string]$Report   = "C:\Temp\UniquePermissions-PMO.csv"
)

Connect-PnPOnline -Url $SiteUrl -ClientId $ClientId -Interactive

$lists = Get-PnPList | Where-Object { -not $_.Hidden -and $_.BaseType -in "DocumentLibrary", "GenericList" }

$results = foreach ($list in $lists) {
    Write-Host "Checking $($list.Title)..."
    try {
        if (Get-PnPProperty -ClientObject $list -Property HasUniqueRoleAssignments) {
            [PSCustomObject]@{ List = $list.Title; Level = "List"; Path = $list.Title }
        }

        foreach ($item in Get-PnPListItem -List $list -PageSize 500) {
            if (Get-PnPProperty -ClientObject $item -Property HasUniqueRoleAssignments) {
                [PSCustomObject]@{
                    List  = $list.Title
                    Level = $item.FileSystemObjectType   # Folder or File (list items show as File)
                    Path  = $item.FieldValues.FileRef
                }
            }
        }
    }
    catch {
        Write-Warning "Skipped $($list.Title): $($_.Exception.Message)"
    }
}

$folder = Split-Path $Report -Parent
if ($folder) { New-Item -ItemType Directory -Path $folder -Force | Out-Null }
$results | Export-Csv -Path $Report -NoTypeInformation
$results | Group-Object List, Level | Select-Object Name, Count
