# Microsoft Graph sharedWithMe and recent retirement

`/me/drive/sharedWithMe`, `/me/drive/recent`, `/me/insights/used` and `/me/insights/shared` stop returning data after November 2026. Two functions help you move off them.

| Script | What it does |
|---|---|
| `Find-MttDeprecatedGraphEndpoint.ps1` | Report function: searches a folder of scripts and exported config (.ps1, .psm1, .js, .ts, .json) for calls to the four endpoints |
| `Get-MttRecentDocument.ps1` | Report function: lists the most recently modified documents the signed-in user can open, with the Microsoft Search API, as a replacement for a recent-files view |

Both are read-only report functions.

## Requirements

- `Find-MttDeprecatedGraphEndpoint.ps1`: no module and no sign-in. Windows PowerShell 5.1 or PowerShell 7.
- `Get-MttRecentDocument.ps1`: Microsoft.Graph.Authentication (tested with 2.41.2), delegated `Files.Read.All` and `Sites.Read.All`. Windows PowerShell 5.1 or PowerShell 7.

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

## Usage

### Find-MttDeprecatedGraphEndpoint

A read-only report function for the planned **MSTechTalk.M365** module (see [CONVENTIONS.md](../CONVENTIONS.md)). It replaces `Find-DeprecatedGraphEndpoint.ps1`: it returns rows instead of printing them, adds an `Endpoint` column, and can leave folders out.

```powershell
. .\Find-MttDeprecatedGraphEndpoint.ps1
Find-MttDeprecatedGraphEndpoint -Path C:\Scripts | Export-Csv .\GraphEndpoints.csv -NoTypeInformation -Encoding UTF8
```

Count the matches per endpoint, leaving out an archive folder:

```powershell
Find-MttDeprecatedGraphEndpoint -Path C:\Scripts -Exclude C:\Scripts\Archive | Group-Object Endpoint | Select-Object Name, Count
```

| Parameter | Description |
|---|---|
| `-Path` | Folder to search, with its subfolders (aliases `FullName`, `ScriptFolder`). Accepts pipeline input, for example from `Get-Item`. |
| `-Exclude` | Folders to leave out. Any file whose full path starts with one of these is skipped. |
| `-Include` | File patterns to search. Defaults to `*.ps1`, `*.psm1`, `*.js`, `*.ts` and `*.json`. |

One `MSTechTalk.DeprecatedGraphEndpoint` object per matching line:

| Property | Description |
|---|---|
| `Path` | Full path of the file |
| `LineNumber` | Line number of the match |
| `Endpoint` | The retired endpoints found on the line: `sharedWithMe`, `drive/recent`, `insights/used` or `insights/shared`, comma-separated when there is more than one |
| `Line` | The line, without leading and trailing spaces |

| | |
|---|---|
| **Requires** | None |
| **Level** | Local script files |

The search ignores case, so `SharedWithMe` is found too.

### Get-MttRecentDocument

A read-only report function for the planned module. It replaces `Get-RecentDocumentBySearch.ps1`: it doesn't sign in by itself, it pages past 500 results, and it can narrow the search with KQL.

```powershell
Connect-MgGraph -Scopes Files.Read.All, Sites.Read.All
. .\Get-MttRecentDocument.ps1
Get-MttRecentDocument -Top 25 | Export-Csv .\RecentDocuments.csv -NoTypeInformation -Encoding UTF8
```

Only Excel workbooks:

```powershell
Get-MttRecentDocument -Top 100 -Query 'filetype:xlsx'
```

| Parameter | Description |
|---|---|
| `-Top` | How many documents to return, newest first, from 1 to 5000 (alias `Size`). Defaults to 25. The function pages through the search 500 at a time. |
| `-Query` | Extra KQL to narrow the search, for example `filetype:xlsx` or `path:https://contoso.sharepoint.com/sites/Projects`. |

One `MSTechTalk.RecentDocument` object per document:

| Property | Description |
|---|---|
| `UserPrincipalName` | The signed-in account the results are trimmed to |
| `Name` | File name |
| `LastModified` | Date of the last change |
| `LastModifiedBy` | Who made the last change |
| `SizeMB` | File size |
| `WebUrl` | Link to the file |

| | |
|---|---|
| **Requires** | Graph |
| **Level** | User |

On the demo tenant the first 25 matched the old script, and 600 documents took two seconds.

## Important notes

- There is no documented one-to-one replacement. The Search API returns files the signed-in user can access, trimmed by permissions. It has no "shared with me" or "who shared it" detail and doesn't include items shared from other tenants.
- Run `Get-MttRecentDocument` as an ordinary user to see what that user sees. An admin account sees results from every site it can open.
- On Windows, `Connect-MgGraph` signs in through Web Account Manager (WAM) by default, and the sign-in window can open behind an embedded terminal.

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.

## Related article

- [Microsoft Graph sharedWithMe and recent stop returning data this month](https://mstechtalk.com/graph-sharedwithme-recent-retired-search-api/)
