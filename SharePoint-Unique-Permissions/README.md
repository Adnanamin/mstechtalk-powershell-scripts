# Unique permissions report for a SharePoint site

`Get-MttUniquePermission` lists every library, list, folder, file and list item on a SharePoint site that has stopped inheriting permissions.

It is a read-only report function for the planned **MSTechTalk.M365** module (see [CONVENTIONS.md](../CONVENTIONS.md)). It doesn't sign in and doesn't write files: you connect first, and pipe the result to `Export-Csv`.

> **Renamed:** this function replaces `Get-UniquePermissionReport.ps1`. The logic is the same; signing in and the CSV export moved out to the calling lines, and list items now show as `Item` instead of `File`.

## Requirements

| | |
|---|---|
| **Requires** | PnP |
| **Level** | Site, Library |
| **PowerShell** | 7.4 or later |
| **Module** | PnP.PowerShell 3.x |
| **Sign-in** | `Connect-PnPOnline` with your own Entra app registration (`-ClientId`) |
| **Permissions** | Site collection admin on the site |

## How to run it

```powershell
Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId
. .\Get-MttUniquePermission.ps1
Get-MttUniquePermission -SiteUrl $SiteUrl | Export-Csv .\UniquePermissions.csv -NoTypeInformation -Encoding UTF8
```

Check one library first on a big site:

```powershell
Get-MttUniquePermission -SiteUrl $SiteUrl -Library "Documents"
```

Count the results per list and level:

```powershell
Get-MttUniquePermission -SiteUrl $SiteUrl | Group-Object List, Level | Select-Object Name, Count
```

`Get-Help Get-MttUniquePermission -Full` shows every parameter and example, and `Get-Help Get-MttUniquePermission -Online` opens the blog post.

## Parameters

| Parameter | Description |
|---|---|
| `-SiteUrl` | Site to report on (alias `Url`). Accepts pipeline input. It must be the site your PnP connection is signed in to; any other site is skipped with a warning. |
| `-Library` | Title of one library or list. Leave it out to check every visible library and list. |

## Output

One `MSTechTalk.UniquePermission` object per object with unique permissions:

| Property | Description |
|---|---|
| `SiteUrl` | Site the row belongs to |
| `List` | Title of the library or list |
| `Level` | `List`, `Folder`, `File` or `Item` |
| `Path` | Server-relative path of the folder, file or item; the title for a library or list |

Count per list and level on the demo site in the article (`Group-Object List, Level`):

```text
Name                          Count
----                          -----
Governance and Steering, File     1
Governance and Steering, List     1
Projects, File                   11
Projects, Folder                 39
Projects, List                    1
Risk Register, Item               3
Templates, File                   2
Templates, Folder                 1
Templates, List                   1
```

[samples/UniquePermissions-sample.csv](samples/UniquePermissions-sample.csv) is the full output from that run.

## Important notes

- `Get-PnPListItem` doesn't load `HasUniqueRoleAssignments`, so the function loads it per item. That's one call per item: the demo site (about 9,000 items in 16 lists) took 24 to 30 minutes. Use `-Library` to check one library first.
- Every sharing link creates its own permission scope. Check the [Anyone links report](../SharePoint-Anyone-Sharing-Links/) before you restore inheritance, because restoring it removes those links.

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.

## Related article

- [Unique permissions report for a SharePoint site using PnP PowerShell](https://mstechtalk.com/sharepoint-unique-permissions-report-pnp-powershell/)
