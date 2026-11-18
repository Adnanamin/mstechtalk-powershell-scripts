# SharePoint and Baseline Security Mode

Report functions for the MSTechTalk post [Check SharePoint's Baseline Security Mode settings before you turn them on](https://mstechtalk.com/sharepoint-baseline-security-mode-2026/) by Adnan Amin.

Microsoft announced Baseline Security Mode 2026 at Microsoft Ignite on 17 November 2026. These functions read the SharePoint tenant and site values behind its SharePoint settings, so you can check a tenant without opening the Microsoft 365 admin center.

| Script | What it does | Changes anything? |
|---|---|---|
| `Get-MttBaselineSharePointSetting.ps1` | Report function: each SharePoint baseline setting with its `Get-SPOTenant` property, current value, baseline value and whether it meets the baseline | No |
| `Get-MttCustomScriptSite.ps1` | Report function: sites that allow custom script (`DenyAddAndCustomizePages`), or every site with `-IncludeBlocked` | No |

## Prerequisites

- SharePoint Administrator role.
- SharePoint Online Management Shell 16.0.27814.12015 or later: `Install-Module Microsoft.Online.SharePoint.PowerShell`.
- Windows. The SPO module runs in Windows PowerShell 5.1, or PowerShell 7 on Windows with `-UseWindowsPowerShell`.

## How to run

In PowerShell 7, import the module with `-UseWindowsPowerShell`. In Windows PowerShell 5.1, leave that line out.

```powershell
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
Connect-SPOService -Url https://contoso-admin.sharepoint.com
. .\Get-MttBaselineSharePointSetting.ps1
. .\Get-MttCustomScriptSite.ps1
Get-MttBaselineSharePointSetting | Export-Csv .\BaselineSharePoint.csv -NoTypeInformation -Encoding UTF8
Get-MttCustomScriptSite -IncludeBlocked | Export-Csv .\CustomScriptSites.csv -NoTypeInformation -Encoding UTF8
```

Only the settings that are at risk, or one site's custom script state:

```powershell
Get-MttBaselineSharePointSetting | Where-Object { -not $_.MeetsBaseline }
Get-MttCustomScriptSite -SiteUrl https://contoso.sharepoint.com/sites/Projects -IncludeBlocked
```

## Settings covered

| Baseline Security Mode setting | `Get-SPOTenant` property | Baseline value |
|---|---|---|
| Block legacy browser authentication connections to SharePoint | `LegacyBrowserAuthProtocolsEnabled` | False |
| Block IDCRL protocol connections to SharePoint | `LegacyAuthProtocolsEnabled` | False |
| Remove access to Microsoft Store for SharePoint | `DisableSharePointStoreAccess` | True |
| Don't allow resource accounts on Teams Rooms devices from accessing Microsoft 365 files | `RestrictResourceAccountAccess` | True |

"Don't allow new custom scripts in OneDrive and SharePoint sites" has no tenant property in module 16.0.27814.12015; `Get-MttCustomScriptSite` shows the per-site state instead. The Baseline Security Mode 2026 SharePoint settings (classic pages, scoped access for high-privileged apps, pre-authenticated URLs) have no properties in that module version either.

## Output

`Get-MttBaselineSharePointSetting` returns one `MSTechTalk.BaselineSharePointSetting` object per setting: `Setting`, `TenantProperty`, `CurrentValue`, `BaselineValue`, `MeetsBaseline`. A property missing from the module is skipped with a warning.

`Get-MttCustomScriptSite` returns one `MSTechTalk.CustomScriptSite` object per site: `SiteUrl`, `Title`, `Template`, `DenyAddAndCustomizePages` (Enabled = blocked, Disabled = allowed) and `CustomScriptAllowed`. Sites that can't be read are skipped with a warning.

| | `Get-MttBaselineSharePointSetting` | `Get-MttCustomScriptSite` |
|---|---|---|
| **Requires** | SPO | SPO |
| **Level** | Tenant | Tenant, Site |
| **Permissions** | SharePoint Administrator | SharePoint Administrator |
