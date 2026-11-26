# SharePoint classic publishing

Function for the MSTechTalk post [Three ways to find classic publishing sites in SharePoint Online](https://mstechtalk.com/find-classic-publishing-sites-sharepoint-online/) by Adnan Amin.

From 1 March 2027 SharePoint Online can't create classic publishing sites or turn on the publishing feature ([MC1565964](https://mc.merill.net/message/MC1565964)). `Get-MttClassicPublishingSite` finds the site collections and subsites that still use publishing, so you can plan the move to modern sites and fix provisioning scripts before that date. It is a read-only report function for the planned **MSTechTalk.M365** module (see [CONVENTIONS.md](../CONVENTIONS.md)).

| Script | What it does | Changes anything? |
|---|---|---|
| `Get-MttClassicPublishingSite.ps1` | Report function: publishing features and blocked templates on a site collection and every subsite | No |

## What it checks

A web is returned when any of these is true:

- **PublishingInfrastructureOn:** the SharePoint Server Publishing Infrastructure feature (`f6924d36-2fa8-4f0b-b16d-06b7250180fa`, site collection scope) is active.
- **PublishingFeatureOn:** the SharePoint Server Publishing feature (`94c94ca6-b32f-4da9-a9e3-1f3d343d7ecb`, web scope) is active.
- **BlockedTemplate:** the web uses one of the ten templates that can't be created from 1 March 2027: BLANKINTERNETCONTAINER#0, CMSPUBLISHING#0, BLANKINTERNET#0, ENTERWIKI#0, SRCHCEN#0, SPSSITES#0, SPSNHOME#0, PRODUCTCATALOG#0, SPSREPORTCENTER#0, SPSTOPIC#0.

A classic team site (STS#0) can have publishing switched on later, so the template alone isn't enough.

## Prerequisites

| What | Needed |
|---|---|
| Module | PnP.PowerShell 3.x on PowerShell 7.4 or later |
| Entra app | Your own app registration with delegated SharePoint AllSites.Read |
| Role | SharePoint Administrator, to list sites with `Get-PnPTenantSite` |
| Site access | Read access to each site checked. The SharePoint Administrator role alone doesn't give it; sites you can't read are skipped with a warning |

## How to run

```powershell
Connect-PnPOnline -Url https://contoso-admin.sharepoint.com -Interactive -ClientId $ClientId
. .\Get-MttClassicPublishingSite.ps1
Get-PnPTenantSite | Get-MttClassicPublishingSite | Export-Csv .\ClassicPublishingSites.csv -NoTypeInformation -Encoding UTF8
```

One site collection:

```powershell
Get-MttClassicPublishingSite -SiteUrl https://contoso.sharepoint.com/sites/Intranet
```

## Parameters

| Parameter | Description |
|---|---|
| `-SiteUrl` (alias `Url`) | Site collection to check. Accepts pipeline input, for example from `Get-PnPTenantSite` |

## Output columns

| Column | Description |
|---|---|
| `SiteUrl` | Site collection checked |
| `WebUrl` | The site collection or subsite this row is about |
| `Title` | Web title |
| `Template` | Web template and configuration, for example `CMSPUBLISHING#0` |
| `BlockedTemplate` | True when the template can't be created from 1 March 2027 |
| `PublishingInfrastructureOn` | Site collection publishing feature active |
| `PublishingFeatureOn` | Web publishing feature active |
| `LastItemModifiedDate` | Last change to any item in the web |

## Level

Site: the site collection and all of its subsites. Add-in webs, which live on a different host and return 403, are skipped.

## Notes

- Read-only. It uses REST GET calls through `Invoke-PnPSPRestMethod` and changes nothing.
- Each web is three REST calls, so a tenant with many subsites takes a while.
- Not yet tested as a function. The same REST calls were run against the classic sites on the MST demo tenant on 26 November 2026.
