# Unique permissions report for a SharePoint site

`Get-UniquePermissionReport.ps1` lists every library, list, folder, file and list item on a SharePoint site that has stopped inheriting permissions. It ends with a count for each list and level.

The script is read-only and writes a CSV report.

## Requirements

- PowerShell 7.4 or later and PnP.PowerShell 3.x (tested with 3.5.0).
- Your own Entra app registration for `Connect-PnPOnline`.
- Site collection admin on the site.

## Usage

```powershell
.\Get-UniquePermissionReport.ps1 -SiteUrl https://contoso.sharepoint.com/sites/PMO -ClientId <your-app-client-id> -Report C:\Temp\UniquePermissions.csv
```

Columns: `List`, `Level` (List, Folder or File), `Path`.

Output from the demo site in the article:

```text
Name                          Count
----                          -----
Governance and Steering, List     1
Governance and Steering, File     1
Projects, List                    1
Projects, Folder                 39
Projects, File                   11
Risk Register, File               3
Templates, List                   1
Templates, Folder                 1
Templates, File                   2
```

[samples/UniquePermissions-sample.csv](samples/UniquePermissions-sample.csv) is the full CSV from that run. List items, like the three in the Risk Register, show as File because that is the file system object type SharePoint returns for a list item.

## Important notes

- `Get-PnPListItem` doesn't load `HasUniqueRoleAssignments`, so the script loads it per item with `Get-PnPProperty`. That's one call per item: the demo site (about 5,000 items) took 24 minutes. Point `$lists` at one library first on a big site.
- Every sharing link creates its own permission scope. Check the Anyone links report before you restore inheritance, because restoring it removes those links.

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.

## Related article

- [Unique permissions report for a SharePoint site using PnP PowerShell](https://mstechtalk.com/sharepoint-unique-permissions-report-pnp-powershell/)
