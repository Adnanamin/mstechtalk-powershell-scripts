# Anyone links on a SharePoint site

`Get-MttAnyoneSharingLink` lists every Anyone (anonymous) sharing link on a SharePoint site: the file or folder, whether it can view or edit, and when it expires. Anyone links don't need a sign-in, so the ones that never expire are the ones to check first.

It is a read-only report function for the planned **MSTechTalk.M365** module (see [CONVENTIONS.md](../CONVENTIONS.md)). It doesn't sign in and doesn't write files: you connect first, and pipe the result to `Export-Csv`.

> **Renamed:** this function replaces `Get-AnyoneSharingLink.ps1`. It finds the same links; signing in and the CSV export moved out to the calling lines, `Type` is now `LinkType`, and the new `SiteUrl`, `ItemType` and `LinkId` columns let you count the links themselves.

## Requirements

| | |
|---|---|
| **Requires** | PnP |
| **Level** | Site, Library |
| **PowerShell** | 7.4 or later |
| **Module** | PnP.PowerShell 3.x (tested with 3.5.0) |
| **Sign-in** | `Connect-PnPOnline` with your own Entra app registration (`-ClientId`) |
| **Permissions** | Site collection admin on the site |

```powershell
Install-Module PnP.PowerShell -Scope CurrentUser
```

## How to run it

```powershell
Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId
. .\Get-MttAnyoneSharingLink.ps1
Get-MttAnyoneSharingLink -SiteUrl $SiteUrl | Export-Csv .\AnyoneLinks.csv -NoTypeInformation -Encoding UTF8
```

Only the links that never expire:

```powershell
Get-MttAnyoneSharingLink -SiteUrl $SiteUrl | Where-Object { -not $_.Expires }
```

One library:

```powershell
Get-MttAnyoneSharingLink -SiteUrl $SiteUrl -Library "Brand Assets"
```

`Get-Help Get-MttAnyoneSharingLink -Full` shows every parameter and example, and `Get-Help Get-MttAnyoneSharingLink -Online` opens the blog post.

## Parameters

| Parameter | Description |
|---|---|
| `-SiteUrl` | Site to report on (alias `Url`). Accepts pipeline input. It must be the site your PnP connection is signed in to; any other site is skipped with a warning. |
| `-Library` | Title of one document library. Leave it out to check every visible document library. |

## Output

One `MSTechTalk.AnyoneSharingLink` object for each item an Anyone link opens:

| Property | Description |
|---|---|
| `SiteUrl` | Site the row belongs to |
| `Library` | Title of the document library |
| `ItemType` | `File` or `Folder` |
| `Path` | Server-relative path of the file or folder |
| `LinkType` | `View` or `Edit` |
| `Expires` | Expiry date; empty when the link never expires |
| `LinkId` | ID of the sharing link, the same on every row the link opens |

The link URLs themselves are not in the output, so the report can't be used to open anything.

## Reading the report

A folder's Anyone link is returned on the folder and again on every file and subfolder inside it, so a site has more rows than links. On the demo site in the article the function returned 50 rows for 12 links; 29 of those rows came from one edit link on the Logos folder that never expires.

To list the links themselves, group by `LinkId` and keep the shortest path in each group:

```powershell
Get-MttAnyoneSharingLink -SiteUrl $SiteUrl | Group-Object LinkId | ForEach-Object {
    $_.Group | Sort-Object { $_.Path.Length } | Select-Object -First 1 ItemType, LinkType, Expires, Path
}
```

Every item with its own sharing link also has unique permissions, so you can cross-check with [Get-MttUniquePermission](../SharePoint-Unique-Permissions/).

[samples/AnyoneLinks-sample.csv](samples/AnyoneLinks-sample.csv) is the full output from the demo tenant used in the article.

## Important notes

- Sharing links are read one item at a time: the demo site (8 libraries, about 470 items) took under five minutes. Use `-Library` to check one library first.
- Lists and the Site Pages library are skipped, because Anyone links are only on files and folders in document libraries.
- Treat the CSV as organisational data and store it according to your policies.

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.

## Related article

- [How to find Anyone links on a SharePoint site with PnP PowerShell](https://mstechtalk.com/find-anyone-links-sharepoint-pnp-powershell/)
