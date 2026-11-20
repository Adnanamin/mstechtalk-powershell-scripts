# SharePoint site inventory

`Get-MttSite` lists every SharePoint site in the tenant in one call, with template, owner, storage and last change date. It is the starting point for tenant-wide reports in the planned **MSTechTalk.M365** module (see [CONVENTIONS.md](../CONVENTIONS.md)): filter its output, or pipe it into another `Mtt` function.

| Script | What it does | Changes anything? |
|---|---|---|
| `Get-MttSite.ps1` | Report function: one row per site with template, owner, storage, last change, Teams connection and lock state | No |

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
Get-MttSite -Template GROUP#0                                  # Microsoft 365 group sites only
Get-MttSite | Where-Object { $_.DaysSinceLastChange -gt 365 }  # no content change in a year
Get-MttSite | Get-MttCustomScriptSite                          # into another SPO-based function
```

| Parameter | Description |
|---|---|
| `-Template` | Only sites with this template, for example `GROUP#0`, `SITEPAGEPUBLISHING#0` or `STS#3`. Filtered on the server. |
| `-IncludeOneDrive` | Also return OneDrive sites. |
| `-IncludeRedirect` | Also return site redirects (`REDIRECTSITE#0`), which a site rename leaves behind. |

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
| `Template` | Site template, for example `GROUP#0` or `SITEPAGEPUBLISHING#0` |
| `Owner` | Primary owner (for group sites, the group, shown as an ID) |
| `StorageUsedGB` | Storage used, in GB |
| `LastContentModified` | Date of the last content change |
| `DaysSinceLastChange` | Days since that change |
| `IsTeamsConnected` | True when the site belongs to a team in Microsoft Teams |
| `GroupId` | ID of the Microsoft 365 group, or empty |
| `LockState` | `Unlock`, `ReadOnly` or `NoAccess` |

| | |
|---|---|
| **Requires** | SPO |
| **Level** | Tenant |
| **Permissions** | SharePoint Administrator |

It uses the SharePoint Online Management Shell rather than PnP: PnP's tenant site list needs a connection to the admin site, which would replace the per-site PnP connection the other functions rely on.

On the demo tenant it returned 72 sites in Windows PowerShell 5.1 and PowerShell 7, with the same count and storage as `Get-MttSiteStorage`.

## Author

- **Adnan Amin**, [MSTechTalk](https://mstechtalk.com)
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.
