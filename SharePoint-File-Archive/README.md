# SharePoint file archive

Script for the MSTechTalk post [Archive inactive SharePoint files with the Admin Agent and PowerShell](https://mstechtalk.com/sharepoint-archive-inactive-files/) by Adnan Amin.

At Microsoft Ignite 2026 (17 November) Microsoft announced automated file-level archive in SharePoint, and the SharePoint Advanced Management inactive files policy (`New-SPOFileArchivePolicy`) is in public preview. This function shows where archived storage sits once users, the SharePoint Admin Agent or a policy start archiving.

| Script | What it does | Changes anything? |
|---|---|---|
| `Get-MttArchivedFileStorage.ps1` | Report function: storage used, storage held by file-level archived files, and the archive setting, per site | No |

## Prerequisites

- SharePoint Administrator role.
- SharePoint Online Management Shell 16.0.27814.12015 or later: `Install-Module Microsoft.Online.SharePoint.PowerShell`.
  If you installed the shell with the Windows installer, uninstall it first. Its older SharePoint client DLLs keep loading and the newer module fails with *Could not load type 'Microsoft.SharePoint.Client.Utilities.SmartWikiEntryScopeValue'*.
- Windows. The SPO module runs in Windows PowerShell 5.1, or PowerShell 7 on Windows with `-UseWindowsPowerShell`.
- Microsoft 365 Archive turned on (pay-as-you-go) before anything can be archived. `AllowFileArchive` is True by default, but the Archive action only appears once Archive is on.

## How to run

In PowerShell 7, import the module with `-UseWindowsPowerShell`. In Windows PowerShell 5.1, leave that line out.

```powershell
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
Connect-SPOService -Url https://contoso-admin.sharepoint.com
. .\Get-MttArchivedFileStorage.ps1
Get-MttArchivedFileStorage | Export-Csv .\ArchivedFileStorage.csv -NoTypeInformation -Encoding UTF8
```

One site, or a filtered set piped from `Get-SPOSite`:

```powershell
Get-MttArchivedFileStorage -SiteUrl https://contoso.sharepoint.com/sites/Projects
Get-SPOSite -Limit All | Where-Object Url -like "*/sites/HR-*" | Get-MttArchivedFileStorage
```

| Parameter | Description |
|---|---|
| `-SiteUrl` | One or more sites to report on (alias `Url`). Accepts pipeline input. Leave it out for every site in the tenant (OneDrive excluded). |

## Output

One `MSTechTalk.ArchivedFileStorage` object per site:

| Column | Meaning |
|---|---|
| `SiteUrl` | Site URL |
| `Title` | Site title |
| `StorageUsedMB` | Storage used by the site, in MB |
| `ArchivedFileMB` | Storage used by file-level archived files, in MB |
| `AllowFileArchive` | Whether users can archive files on the site |

Sites that can't be read are skipped with a warning.

| | |
|---|---|
| **Requires** | SPO |
| **Level** | Tenant, Site |
| **Permissions** | SharePoint Administrator |

## Inactive files policy (preview)

The policy itself is created with the SharePoint Online Management Shell, not with this function. Start in what-if mode, which only reports:

```powershell
$Policy = New-SPOFileArchivePolicy -PolicyType SelectedSites -Name "Projects inactive files" -LastAccessDateCriteria 12 -IsWhatIfMode $true
Add-SPOSiteToFileArchivePolicy -PolicyId $Policy.PolicyId -Site https://contoso.sharepoint.com/sites/Projects
Set-SPOFileArchivePolicy -PolicyId $Policy.PolicyId -State Active
Get-SPOFileArchivePolicyReport -PolicyId $Policy.PolicyId
```

The post explains the parameters, the what-if report and how to switch to real archiving.
