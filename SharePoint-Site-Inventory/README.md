# SharePoint site inventory

`Get-MttSite` lists every SharePoint site in the tenant in one call, with site type, owner, storage, hub, last change date and, if you ask, external sharing. It returns the sites on the admin center's Active sites page plus Teams channel sites, which that page hides. It is the starting point for tenant-wide reports in the planned **MSTechTalk.M365** module (see [CONVENTIONS.md](../CONVENTIONS.md)): filter its output, or pipe it into another `Mtt` function.

Blog post with scenarios, admin center steps and screenshots: [Build a SharePoint site inventory: admin center and PowerShell](https://mstechtalk.com/sharepoint-site-inventory-powershell/)

| Script | What it does | Changes anything? |
|---|---|---|
| `Get-MttSite.ps1` | Report function: one row per site with site type, owner, storage, hub, last change, Teams connection, lock and archive state, and optionally external sharing | No |

## Prerequisites

- SharePoint Administrator role.
- SharePoint Online Management Shell: `Install-Module Microsoft.Online.SharePoint.PowerShell`.
- Windows. The SPO module runs in Windows PowerShell 5.1, or PowerShell 7 on Windows with `-UseWindowsPowerShell`.

## How to run

In PowerShell 7, import the module with `-UseWindowsPowerShell`. In Windows PowerShell 5.1, leave that line out.

```powershell
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
Connect-SPOService -Url https://contoso-admin.sharepoint.com
. .\Get-MttSite.ps1
Get-MttSite | Export-Csv .\Sites.csv -NoTypeInformation -Encoding UTF8
```

Filter first, then pass the sites on:

```powershell
Get-MttSite | Sort-Object StorageUsedGB -Descending | Select-Object -First 10        # largest sites
Get-MttSite | Where-Object { $_.SiteType -eq 'Group site' -and -not $_.IsTeamsConnected }  # group sites with no team
Get-MttSite | Where-Object HubSite | Group-Object HubSite                           # sites per hub
Get-MttSite -IncludeSharing | Where-Object SharingCapability -eq 'ExternalUserAndGuestSharing'  # Anyone links allowed
Get-MttSite | Get-MttCustomScriptSite                                              # into another SPO-based function
```

| Parameter | Description |
|---|---|
| `-Template` | Only sites with this template, for example `GROUP#0`, `SITEPAGEPUBLISHING#0`, `STS#3` or `TEAMCHANNEL#0`. Filtered on the server. |
| `-IncludeSharing` | Also read each site's external sharing setting. One extra call per site: 68 sites took about 40 seconds instead of 2. |
| `-IncludeOneDrive` | Also return OneDrive sites. |
| `-IncludeSystemSite` | Also return site redirects, the My Site host, PointPublishing sites and the search center, which the admin center hides too. |

### With functions that use PnP PowerShell

`Get-MttUniquePermission`, `Get-MttAnyoneSharingLink` and `Get-MttListItem` report only on the site PnP is signed in to, and skip other sites with a warning. To cover several sites, sign in to each one in turn:

```powershell
Get-MttSite | Where-Object SiteUrl -like '*/sites/Projects*' | ForEach-Object {
    Connect-PnPOnline -Url $_.SiteUrl -Interactive -ClientId $ClientId
    Get-MttUniquePermission -SiteUrl $_.SiteUrl
} | Export-Csv .\UniquePermissions.csv -NoTypeInformation -Encoding UTF8
```

## Output

One `MSTechTalk.Site` object per site:

| Column | Meaning |
|---|---|
| `SiteUrl` | Site URL |
| `Title` | Site title |
| `SiteType` | Group site, Communication site, Team site (no group), Channel site, Classic site, App catalog, OneDrive or Other |
| `Template` | Site template, for example `GROUP#0` or `SITEPAGEPUBLISHING#0` |
| `Owner` | Primary admin. Empty for group sites, where the group owners own the site |
| `StorageUsedGB` | Storage used, in GB |
| `LastContentModified` | Date of the last change of any kind, not only user changes (see below) |
| `DaysSinceLastChange` | Days since that change |
| `IsTeamsConnected` | True when the site belongs to a team in Microsoft Teams |
| `GroupId` | ID of the Microsoft 365 group, or empty |
| `IsHubSite` | True when the site is a registered hub site |
| `HubSite` | Name of the hub the site is associated with (a hub site shows its own name) |
| `LockState` | `Unlock`, `ReadOnly` or `NoAccess` |
| `ArchiveStatus` | Microsoft 365 Archive status, for example `NotArchived` |
| `SharingCapability` | With `-IncludeSharing` only: `ExternalUserAndGuestSharing` (Anyone), `ExternalUserSharingOnly` (New and existing guests), `ExistingExternalUserSharingOnly` (Existing guests) or `Disabled` (Only people in your organization) |

`LastContentModified` moves with changes people don't make: on the demo tenant 40 of 68 sites showed the same date. For user activity, use the **Last activity** column in the admin center or an inactive site policy.

| | |
|---|---|
| **Requires** | SPO |
| **Level** | Tenant |
| **Permissions** | SharePoint Administrator |

It uses the SharePoint Online Management Shell rather than PnP: PnP's tenant site list needs a connection to the admin site, which would replace the per-site PnP connection the other functions rely on.

On the demo tenant it returned 68 sites (72 with `-IncludeSystemSite`) in about 2 seconds in Windows PowerShell 5.1 and PowerShell 7.

## Author

- **Adnan Amin**, [MSTechTalk](https://mstechtalk.com)
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.
