# Reading a SharePoint list over the 5,000-item threshold

`Get-LargeListItem.ps1` reads a list that is over the 5,000-item list view threshold in two ways: the whole list in pages of 500, and only the items with one status, filtered with a CAML query on an indexed column.

The script is read-only.

## Requirements

- PowerShell 7.4 or later and PnP.PowerShell 3.x (tested with 3.5.0).
- Your own Entra app registration for `Connect-PnPOnline`.
- Read access to the list. The CAML filter column (`TicketStatus` here) must be indexed.

## Usage

```powershell
.\Get-LargeListItem.ps1 -SiteUrl https://contoso.sharepoint.com/sites/ServiceDesk -ClientId <your-app-client-id> -List "Service Desk Tickets" -Status "In progress"
```

Output on the 6,200-item demo list, in 12 seconds:

```text
Read 6200 items
In progress tickets: 14
```

## Important notes

- An index only helps when the filtered result is under 5,000 items.
- You can add or remove an index only while the list has fewer than 20,000 items.
- A REST `$filter` on a column that isn't indexed fails on a big list with "The attempted operation is prohibited because it exceeds the list view threshold."

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.

## Related article

- [Fix: the number of items in this list exceeds the list view threshold](https://mstechtalk.com/sharepoint-list-view-threshold-5000-fix/)
