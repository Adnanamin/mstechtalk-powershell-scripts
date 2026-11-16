# SharePoint sites with Copilot blocked

Two functions that list the SharePoint sites where Copilot is blocked by Restricted Content Discovery (RCD). Since the Copilot in SharePoint opt-outs ended on 1 November 2026, RCD is the setting that keeps Copilot off a site.

| File | What it does | Best for |
|---|---|---|
| `Get-MttCopilotBlockedSite.ps1` | Report function: reads `RestrictContentOrgWideSearch` per site and returns the blocked ones, for the whole tenant or for the sites you give it | Quick checks, one site or a few, or when you want to add your own columns |
| `Start-MttRcdInsightsReport.ps1` | Report function: runs Microsoft's RCD insights report, waits until it shows Completed, downloads it and returns the sites in it | Large tenants |

> **Renamed:** `Get-MttCopilotBlockedSite` replaces `Get-CopilotBlockedSites.ps1`, and `Start-MttRcdInsightsReport` replaces `Get-RCDInsightsReport.ps1`. Both find the same sites as before; signing in and the CSV export moved out to the calling lines. `Get-MttCopilotBlockedSite` names its URL column `SiteUrl` and adds `Template` and `LastContentModified`. `Start-MttRcdInsightsReport` returns rows instead of saving Microsoft's CSV, and no longer asks you to confirm.

Both are read-only report functions for the planned **MSTechTalk.M365** module (see [CONVENTIONS.md](../CONVENTIONS.md)). They don't sign in and don't write files: you connect first, and pipe the result to `Export-Csv`.

## Requirements

| | |
|---|---|
| **Requires** | SPO |
| **Level** | `Get-MttCopilotBlockedSite`: Tenant, Site. `Start-MttRcdInsightsReport`: Tenant |
| **PowerShell** | 7.4 or later, or Windows PowerShell 5.1 |
| **Module** | Microsoft.Online.SharePoint.PowerShell (SharePoint Online Management Shell) |
| **Sign-in** | `Connect-SPOService` to your admin URL |
| **Permissions** | SharePoint Administrator |

SPO is used because PnP PowerShell and Microsoft Graph don't return the RCD setting or the RCD report. RCD itself also needs Microsoft 365 Copilot licences and SharePoint Advanced Management in the tenant.

```powershell
Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser
```

In PowerShell 7, import the module with `-UseWindowsPowerShell`, as Microsoft requires. In Windows PowerShell 5.1, leave that line out.

## Get-MttCopilotBlockedSite

Checks `RestrictContentOrgWideSearch` on every site, or on the sites you give it.

### How to run it

```powershell
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
Connect-SPOService -Url https://contoso-admin.sharepoint.com
. .\Get-MttCopilotBlockedSite.ps1
Get-MttCopilotBlockedSite | Export-Csv .\CopilotBlockedSites.csv -NoTypeInformation -Encoding UTF8
```

Check one site, or a few:

```powershell
Get-MttCopilotBlockedSite -SiteUrl https://contoso.sharepoint.com/sites/Finance, https://contoso.sharepoint.com/sites/HR
```

`Get-Help Get-MttCopilotBlockedSite -Full` shows every parameter and example, and `Get-Help Get-MttCopilotBlockedSite -Online` opens the blog post.

### Parameters

| Parameter | Description |
|---|---|
| `-SiteUrl` | One or more sites to check (alias `Url`). Accepts pipeline input. Leave it out to check every site in the tenant. |

### Output

One `MSTechTalk.CopilotBlockedSite` object per site where Copilot is blocked:

| Property | Description |
|---|---|
| `SiteUrl` | Site URL |
| `Title` | Site title |
| `Owner` | Primary owner, as `Get-SPOSite` returns it |
| `Template` | Site template, for example `STS#3` or `SITEPAGEPUBLISHING#0` |
| `LastContentModified` | Date of the last content change on the site |

On the demo tenant in the article, the function checked 72 sites in under a minute and found the 4 blocked ones (owner column left out here):

```text
SiteUrl                                               Title               Template             LastContentModified
-------                                               -----               --------             -------------------
https://mstalk.sharepoint.com/sites/MST-ITServiceDesk MST IT Service Desk STS#3                11/14/2026 11:02:30 PM
https://mstalk.sharepoint.com/sites/MST-Intranet      MST Intranet        SITEPAGEPUBLISHING#0 11/15/2026 10:52:36 AM
https://mstalk.sharepoint.com/sites/hr-live           Benefits            SITEPAGEPUBLISHING#0 11/13/2026 9:25:27 AM
https://mstalk.sharepoint.com/sites/MST-Finance       MST Finance         STS#3                11/14/2026 8:39:48 PM
```

## Start-MttRcdInsightsReport

Queues Microsoft's RCD insights report, waits until it shows Completed, downloads it to a temporary folder and returns one row per site. The temporary folder is removed afterwards.

### How to run it

```powershell
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
Connect-SPOService -Url https://contoso-admin.sharepoint.com
. .\Start-MttRcdInsightsReport.ps1
Start-MttRcdInsightsReport | Export-Csv .\RcdInsights.csv -NoTypeInformation -Encoding UTF8
```

The status goes NotStarted, InQueue, Completed. On the demo tenant it took about two minutes.

Microsoft allows one new RCD report every 24 hours. Within that window the function warns and returns the latest existing report instead. To collect the latest report without starting a new one:

```powershell
Start-MttRcdInsightsReport -UseExisting
```

### Parameters

| Parameter | Description |
|---|---|
| `-UseExisting` | Don't start a new report: return the latest existing one. |
| `-TimeoutMinutes` | How long to wait for the report, from 1 to 1440 minutes. Defaults to 30. |
| `-PollSeconds` | How often to check the status, from 10 to 600 seconds. Defaults to 30. |

### Output

One `MSTechTalk.RcdInsightsSite` object per site in the report:

| Property | Description |
|---|---|
| `SiteUrl` | Site URL |
| `Title` | Site title |
| `OwnerEmail` | Site owner's email address |
| `LastModified` | Date of the last change to the site, as the report gives it |
| `TimeCreated` | Date the site was created |
| `ReportId` | ID of the RCD report the row comes from |

On the demo tenant the report listed the same 4 sites as `Get-MttCopilotBlockedSite`, and collecting an existing report took 3 seconds.

## Important notes

- `Get-MttCopilotBlockedSite` makes one `Get-SPOSite` call per site, so it is slow on a big tenant. `Get-SPOSite -Limit All` doesn't fill in `RestrictContentOrgWideSearch`, which is why each site is read by URL.
- Neither function shows sites where an owner hid the Copilot button for visitors in **Settings** > **Site AI**. That option only hides the button from visitors.
- RCD doesn't apply to OneDrive, and `Get-SPOSite -Limit All` skips OneDrive sites by default.
- Treat the CSV files as organisational data: they contain owner email addresses. Store them according to your policies.

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.

## Related article

- [Three ways to find which SharePoint sites have Copilot blocked](https://mstechtalk.com/find-sharepoint-sites-copilot-blocked/)
