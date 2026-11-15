# SharePoint sites with Copilot blocked

Two scripts that list the SharePoint sites where Copilot is blocked by Restricted Content Discovery (RCD). Since the Copilot in SharePoint opt-outs ended on 1 November 2026, RCD is the setting that keeps Copilot off a site.

Both scripts are read-only and write CSV reports.

## Scripts

| Script | What it does | Best for |
|---|---|---|
| `Get-CopilotBlockedSites.ps1` | Loops through every site, reads `RestrictContentOrgWideSearch` per site and exports the blocked ones (Title, Url, Owner) | Quick checks, or when you want to add your own columns |
| `Get-RCDInsightsReport.ps1` | Runs Microsoft's RCD insights report, waits until it shows Completed and downloads the CSV (SiteTitle, SiteUrl, SiteOwnerEmail, LastModified, TimeCreated) | Large tenants |

## Requirements

- SharePoint Online Management Shell (`Microsoft.Online.SharePoint.PowerShell`). Windows PowerShell 5.1 is recommended.
- SharePoint Administrator role.
- Microsoft 365 Copilot licences and SharePoint Advanced Management in the tenant (RCD needs both).

Install the module if needed:

```powershell
Install-Module Microsoft.Online.SharePoint.PowerShell -Scope CurrentUser
```

## Usage

```powershell
# Method 2: loop through every site
.\Get-CopilotBlockedSites.ps1 -AdminUrl https://contoso-admin.sharepoint.com -ReportPath C:\Temp\copilot-blocked-sites.csv

# Method 3: Microsoft's RCD insights report
.\Get-RCDInsightsReport.ps1 -AdminUrl https://contoso-admin.sharepoint.com -OutputFolder C:\Temp
```

`Get-RCDInsightsReport.ps1` asks you to confirm before it queues the report: answer **Y**. The status goes NotStarted, InQueue, Completed. On a small demo tenant it took about two minutes.

Microsoft allows one new RCD report every 24 hours. A second start in that window fails with "new report can be generated once in every 24 hours", so the script downloads the latest existing report instead.

## Important notes

- One `Get-SPOSite` call per site makes `Get-CopilotBlockedSites.ps1` slow on a big tenant.
- Neither script shows sites where an owner hid the Copilot button for visitors in **Settings** > **Site AI**. That option only hides the button from visitors.
- RCD doesn't apply to OneDrive, and `Get-SPOSite -Limit All` skips OneDrive sites by default.
- Treat the CSV files as organisational data and store them according to your policies.

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.

## Related article

- [Three ways to find which SharePoint sites have Copilot blocked](https://mstechtalk.com/find-sharepoint-sites-copilot-blocked/)
