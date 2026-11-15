# Anyone links on a SharePoint site

`Get-AnyoneSharingLink.ps1` lists every Anyone (anonymous) sharing link on a SharePoint site: the file or folder, whether it can view or edit, and when it expires. Anyone links don't need a sign-in, so the ones that never expire are the ones to check first.

The script is read-only and writes a CSV report.

## Requirements

- PowerShell 7.4 or later and PnP.PowerShell 3.x (tested with 3.5.0).
- Your own Entra app registration for `Connect-PnPOnline` (PnP PowerShell 3 needs one).
- Site collection admin on the site.

```powershell
Install-Module PnP.PowerShell -Scope CurrentUser
```

## Usage

```powershell
.\Get-AnyoneSharingLink.ps1 -SiteUrl https://contoso.sharepoint.com/sites/Marketing -ClientId <your-app-client-id> -Report C:\Temp\AnyoneLinks.csv
```

Columns: `Library`, `Path`, `Type` (View or Edit), `Expires` (empty = never expires).

## Reading the report

The CSV has one row for every item an Anyone link opens, not one row per link. When a folder has an Anyone link, every file inside it gets a row for that folder link as well. On the demo site the script wrote 50 rows for 12 links. 29 rows came from one edit link on the Logos folder that never expires.

To find the links themselves, keep the rows whose parent folder isn't also in the list. Every item with its own sharing link also has unique permissions, so you can cross-check with [Get-UniquePermissionReport.ps1](../SharePoint-Unique-Permissions/).

[samples/AnyoneLinks-sample.csv](samples/AnyoneLinks-sample.csv) is the real output from the demo tenant used in the article.

## Important notes

- One call per item: it took about four minutes on a site with 8 libraries and about 1,000 items.
- Run it once per site.
- Treat the CSV as organisational data and store it according to your policies.

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.

## Related article

- [How to find Anyone links on a SharePoint site with PnP PowerShell](https://mstechtalk.com/find-anyone-links-sharepoint-pnp-powershell/)
