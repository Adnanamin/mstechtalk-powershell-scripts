# Reading a SharePoint list over the 5,000-item threshold

`Get-MttListItem` reads a SharePoint list of any size: every item in pages, or only the items where one column has one value, filtered on the server with a CAML query on an indexed column. Both stay under the 5,000-item list view threshold.

It is a read-only report function for the planned **MSTechTalk.M365** module (see [CONVENTIONS.md](../CONVENTIONS.md)). It doesn't sign in and doesn't write files: you connect first, and pipe the result to `Export-Csv`.

> **Renamed:** this function replaces `Get-LargeListItem.ps1`. The whole-list read and the indexed filter are now one function: `-Field` picks the columns, and `-FilterField` with `-FilterValue` sets the filter. It also warns before it filters on a column that isn't indexed.

## Requirements

| | |
|---|---|
| **Requires** | PnP |
| **Level** | List |
| **PowerShell** | 7.4 or later |
| **Module** | PnP.PowerShell 3.x (tested with 3.5.0) |
| **Sign-in** | `Connect-PnPOnline` with your own Entra app registration (`-ClientId`) |
| **Permissions** | Read access to the list. On a list over 5,000 items, the filter column must be indexed. |

## How to run it

```powershell
Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId
. .\Get-MttListItem.ps1
Get-MttListItem -SiteUrl $SiteUrl -Library "Service Desk Tickets" -Field Title, TicketStatus, Opened | Export-Csv .\Tickets.csv -NoTypeInformation -Encoding UTF8
```

Only the items with one status, filtered on the indexed `TicketStatus` column:

```powershell
Get-MttListItem -SiteUrl $SiteUrl -Library "Service Desk Tickets" -Field Title, TicketStatus, Opened -FilterField TicketStatus -FilterValue "In progress"
```

Count the items per status:

```powershell
Get-MttListItem -SiteUrl $SiteUrl -Library "Service Desk Tickets" -Field TicketStatus | Group-Object TicketStatus | Select-Object Name, Count
```

`Get-Help Get-MttListItem -Full` shows every parameter and example, and `Get-Help Get-MttListItem -Online` opens the blog post.

## Parameters

| Parameter | Description |
|---|---|
| `-SiteUrl` | Site the list is on (alias `Url`). Accepts pipeline input. It must be the site your PnP connection is signed in to; any other site is skipped with a warning. |
| `-Library` | Title of the list or library to read (alias `List`). |
| `-Field` | Internal names of the columns to return. Defaults to `Title`, `Created` and `Modified`. |
| `-FilterField` | Internal name of the column to filter on. Use it with `-FilterValue`. |
| `-FilterValue` | Value the filter column must equal. |
| `-PageSize` | Items per request, from 1 to 5000. Defaults to 500. |

## Output

One `MSTechTalk.ListItem` object per item:

| Property | Description |
|---|---|
| `SiteUrl` | Site the row belongs to |
| `List` | Title of the list |
| `Id` | Item ID |
| one per `-Field` column | The column's value. Dates stay dates; person and lookup columns show the display name; multi-value columns are joined with `; ` |

On the 6,200-item demo list in the article, the whole list took 6 seconds and the `In progress` filter took 1 second:

```text
Name             Count
----             -----
Closed            4637
Resolved          1528
Waiting for user    15
In progress         14
New                  6
```

[samples/InProgressTickets-sample.csv](samples/InProgressTickets-sample.csv) is the filtered output from that run.

## Important notes

- An index only helps when the filtered result is under 5,000 items.
- You can add or remove an index only while the list has fewer than 20,000 items.
- A filter on a column that isn't indexed fails on a big list with "The attempted operation is prohibited because it exceeds the list view threshold." The function warns before it runs such a filter, and skips the list with a warning when it fails.
- The function only reads. Adding an index (`Set-PnPField -Values @{ Indexed = $true }`) changes the list, so it isn't part of it.

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.

## Related article

- Fix: the number of items in this list exceeds the list view threshold (coming soon)
