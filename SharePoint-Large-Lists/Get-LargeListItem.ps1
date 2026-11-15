<#
.SYNOPSIS
    Reads all items, or a filtered set, from a SharePoint list over the 5,000-item list view threshold.
.DESCRIPTION
    Reads the whole list in pages with -PageSize, then reads only the items with one status using a
    CAML query on an indexed column. Both stay under the list view threshold.
.NOTES
    Author:      Adnan Amin
    Blog:        https://mstechtalk.com
    GitHub:      https://github.com/adnanamin/mstechtalk-powershell-scripts
    Module:      PnP.PowerShell 3.x (tested with 3.5.0), PowerShell 7.4 or later
    Permissions: Read access to the list; your own Entra app registration for Connect-PnPOnline
    Tested:      15 November 2026 (PowerShell 7.6, PnP.PowerShell 3.5.0)
.LINK
    https://mstechtalk.com/sharepoint-list-view-threshold-5000-fix/
#>
param(
    [string]$SiteUrl  = "https://mstalk.sharepoint.com/sites/MST-ITServiceDesk",  # Replace with your own
    [string]$ClientId = "<your-entra-app-client-id>",                              # Replace with your own
    [string]$List     = "Service Desk Tickets",
    [string]$Status   = "In progress"
)

Connect-PnPOnline -Url $SiteUrl -ClientId $ClientId -Interactive

# 1. All items, read in pages of 500
$items = Get-PnPListItem -List $List -PageSize 500 -Fields "Title", "TicketStatus", "Opened"
Write-Host "Read $($items.Count) items"

# 2. Only one status, filtered on the indexed TicketStatus column
$query = @"
<View>
  <Query><Where><Eq><FieldRef Name='TicketStatus'/><Value Type='Choice'>$Status</Value></Eq></Where></Query>
  <RowLimit Paged='TRUE'>500</RowLimit>
</View>
"@

try {
    $filtered = Get-PnPListItem -List $List -Query $query -PageSize 500 -ErrorAction Stop
    Write-Host "$Status tickets: $($filtered.Count)"
}
catch {
    Write-Warning $_.Exception.Message
}
