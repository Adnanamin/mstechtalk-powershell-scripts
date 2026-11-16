# Microsoft Graph sharedWithMe and recent retirement

`/me/drive/sharedWithMe`, `/me/drive/recent`, `/me/insights/used` and `/me/insights/shared` stop returning data after November 2026. Two scripts help you move off them.

| Script | What it does |
|---|---|
| `Find-MttDeprecatedGraphEndpoint.ps1` | Report function: searches a folder of scripts and exported config (.ps1, .psm1, .js, .ts, .json) for calls to the four endpoints |
| `Get-RecentDocumentBySearch.ps1` | Lists the signed-in user's most recently modified documents with the Microsoft Search API, as a replacement for a recent-files view |

Both are read-only.

## Requirements

- `Find-MttDeprecatedGraphEndpoint.ps1`: no module and no sign-in. Windows PowerShell 5.1 or PowerShell 7.
- `Get-RecentDocumentBySearch.ps1`: Microsoft.Graph.Authentication (tested with 2.41.2), delegated `Files.Read.All` and `Sites.Read.All`.

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

### Get-RecentDocumentBySearch.ps1

```powershell
.\Get-RecentDocumentBySearch.ps1 -Size 25
```

## Important notes

- There is no documented one-to-one replacement. The Search API returns files the signed-in user can access, trimmed by permissions. It has no "shared with me" or "who shared it" detail and doesn't include items shared from other tenants.
- Run `Get-RecentDocumentBySearch.ps1` as an ordinary user to see what that user sees. An admin account sees results from every site it can open.
- On Windows, `Connect-MgGraph` signs in through Web Account Manager (WAM) by default, and the sign-in window can open behind an embedded terminal.

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.

## Related article

- [Microsoft Graph sharedWithMe and recent stop returning data this month](https://mstechtalk.com/graph-sharedwithme-recent-retired-search-api/)
