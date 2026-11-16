# SharePoint site and tenant storage

Scripts and functions for the MSTechTalk post [How to find what is filling a SharePoint site and free up tenant storage](https://mstechtalk.com/how-to-find-what-is-filling-a-sharepoint-site-and-free-up-tenant-storage/) by Adnan Amin.

Three of them use the **SharePoint Online Management Shell** (`Microsoft.Online.SharePoint.PowerShell`). `Measure-VersionStorageReport.ps1` only reads a CSV on your machine and needs no module.

| Script | What it does | Changes anything? |
|---|---|---|
| `Get-MttSiteStorage.ps1` | Report function: lists sites by the storage they use, largest first, with last change date | No |
| `Start-VersionStorageReport.ps1` | Starts Microsoft's version storage report job for a site, OneDrive or library, or checks its progress | Creates the report CSV only |
| `Measure-VersionStorageReport.ps1` | Reads the finished report: version history size per file, library and person, and what a trim would free | No |
| `Invoke-VersionTrim.ps1` | Sets version history limits and queues a trim job for the versions already there | **Yes. Deleted versions can't be recovered** |

## Prerequisites

- SharePoint Administrator role.
- SharePoint Online Management Shell, latest version: `Install-Module Microsoft.Online.SharePoint.PowerShell` (or `Update-Module`). The report and trim cmdlets need a recent build.
- Windows. The SPO module runs in Windows PowerShell 5.1, or PowerShell 7 on Windows.
- `Measure-VersionStorageReport.ps1` runs anywhere: Windows PowerShell 5.1 or PowerShell 7 on Windows, macOS or Linux.

## Run order

### 1. Find the biggest sites

`Get-MttSiteStorage` is a read-only report function for the planned **MSTechTalk.M365** module (see [CONVENTIONS.md](../CONVENTIONS.md)). It replaces `Get-TopSitesByStorage.ps1`: it doesn't sign in or write the CSV itself, `-Top` is optional, and `-SiteUrl` checks one site or a few.

In PowerShell 7, import the module with `-UseWindowsPowerShell`, as Microsoft requires. In Windows PowerShell 5.1, leave that line out.

```powershell
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
Connect-SPOService -Url https://contoso-admin.sharepoint.com
. .\Get-MttSiteStorage.ps1
Get-MttSiteStorage -Top 25 | Export-Csv .\SiteStorage.csv -NoTypeInformation -Encoding UTF8
```

Archive candidates, over 100 GB and unchanged for a year:

```powershell
Get-MttSiteStorage | Where-Object { $_.StorageUsedGB -gt 100 -and $_.DaysSinceLastChange -gt 365 }
```

| Parameter | Description |
|---|---|
| `-SiteUrl` | One or more sites to report on (alias `Url`). Accepts pipeline input. Leave it out for every site in the tenant (OneDrive excluded). |
| `-Top` | Return only this many sites, the largest first. Leave it out to return them all. |

One `MSTechTalk.SiteStorage` object per site, largest first: `SiteUrl`, `Title`, `Template`, `StorageUsedGB`, `StorageQuotaGB`, `PercentUsed`, `LastContentModified` and `DaysSinceLastChange`. `-Verbose` also shows the number of sites and the total storage they use. See `templates/TopSitesByStorage-template.csv` for the layout.

| | |
|---|---|
| **Requires** | SPO |
| **Level** | Tenant, Site |
| **Permissions** | SharePoint Administrator |

On the demo tenant it read 72 sites in a second or two, in PowerShell 7 and 5.1, with the same top 25 as the old script.

### 2. Start the version storage report on one of them

```powershell
.\Start-VersionStorageReport.ps1 -AdminUrl https://contoso-admin.sharepoint.com `
    -SiteUrl https://contoso.sharepoint.com/sites/Projects `
    -ReportUrl "https://contoso.sharepoint.com/sites/Projects/Shared Documents/Reports/VersionReport.csv"
```

- The CSV must go in a document library of the same site, and the file must not exist yet.
- Put it in a folder only site owners can open. The report lists every file and who edited it.
- Add `-Library "Documents"` for one library.
- The job runs in the background: over 24 hours for a small site, a few days for a large one. Don't open or edit the CSV while it fills. Deleting it cancels the job.

Check progress until the status is `completed`:

```powershell
.\Start-VersionStorageReport.ps1 -AdminUrl https://contoso-admin.sharepoint.com `
    -SiteUrl https://contoso.sharepoint.com/sites/Projects `
    -ReportUrl "https://contoso.sharepoint.com/sites/Projects/Shared Documents/Reports/VersionReport.csv" -CheckProgress
```

### 3. Analyse the report

Download the CSV, then:

```powershell
.\Measure-VersionStorageReport.ps1 -ReportPath C:\Temp\VersionReport.csv -KeepVersions 100 -OlderThanDays 365
```

On screen you get the totals and the top files. Two CSVs are saved next to the report:

| File | One row per | Main columns |
|---|---|---|
| `VersionStorage-Summary.csv` | report | total size, current versions, version history (GB), what-if for `-KeepVersions` and `-OlderThanDays` |
| `VersionStorage-Files.csv` | file | `Versions`, `CurrentVersion`, `CurrentSizeMB`, `HistorySizeMB`, `TotalSizeMB` |

The newest version of each file (highest major.minor) counts as the current version. Everything else is version history. The what-if numbers are estimates: the real trim job uses SharePoint's own rules, and files under retention keep their versions.

Try it on the sample first (copy `templates\VersionStorageReport-template.csv` to `C:\Temp` so the results don't land in the templates folder): `.\Measure-VersionStorageReport.ps1 -ReportPath C:\Temp\VersionStorageReport-template.csv -KeepVersions 2`

### 4. Set limits and trim

Preview first. Nothing changes with `-WhatIf`:

```powershell
.\Invoke-VersionTrim.ps1 -AdminUrl https://contoso-admin.sharepoint.com `
    -SiteUrl https://contoso.sharepoint.com/sites/Projects -Mode Automatic -WhatIf
```

Then run it without `-WhatIf`. You're asked to confirm twice: once for the limits, once for the trim.

| `-Mode` | Limit set for new versions | Trim job on existing versions |
|---|---|---|
| `Automatic` | Automatic (Microsoft's own logic) | `-Automatic` |
| `MajorVersionLimit` | keep `-MajorVersionLimit` (default 100), no age limit | keep `-MajorVersionLimit`, `-MajorWithMinorVersionsLimit` (default 0) |
| `DeleteBeforeDays` | keep `-MajorVersionLimit`, expire after `-DeleteBeforeDays` | delete versions older than `-DeleteBeforeDays` (default 365) |

Other switches: `-Library "Documents"` for one library, `-TrimOnly` to leave the limits alone, `-Status` to check the trim job, `-Stop` to stop it (versions already deleted stay deleted).

Changing limits only affects versions created from now on. The trim job is what removes the versions already there, and it runs in batches over the next days.

## CSV templates

`templates/` has sample files so you can see the layout before you run anything. The data is made up.

**`VersionStorageReport-template.csv`** follows the version storage report. Columns ending in `.Compact` are left empty when the value is the same as the row above (that's Microsoft's format, not missing data).

| Column | Meaning |
|---|---|
| `WebId.Compact`, `DocId.Compact` | Site (web) ID and file ID. Together they identify one file |
| `MajorVersion`, `MinorVersion` | Version number, e.g. 3 and 0 for version 3.0 |
| `WebUrl.Compact`, `FileUrl.Compact` | Site URL and file URL |
| `Size` | Size of this version in bytes |
| `ModifiedBy_UserId.Compact`, `ModifiedBy_DisplayName.Compact` | Who saved this version |
| `LastModifiedDate` | When this version was saved (UTC, round-trip format) |
| `SnapshotDate`, `IsSnapshotDateEstimated` | When the version was stored, and whether that date is estimated |
| `CurrentExpirationDate` | When this version expires under the current limits. Empty or "never" if it doesn't |
| `AutomaticPolicyExpirationDate` | When it would expire under automatic limits |
| `TargetExpirationDate` | Same as current at first. Edit it to model a different schedule in Microsoft's analysis tools |

**`TopSitesByStorage-template.csv`** shows the output of `Get-MttSiteStorage` exported to CSV: `SiteUrl`, `Title`, `Template`, `StorageUsedGB`, `StorageQuotaGB`, `PercentUsed`, `LastContentModified`, `DaysSinceLastChange`.

## References

- [Generate version storage usage report for a site](https://learn.microsoft.com/sharepoint/version-storage-report-site)
- [Tutorial: generate and analyse a version usage report](https://learn.microsoft.com/sharepoint/tutorial-generate-version-usage-report)
- [Queue a version trim job](https://learn.microsoft.com/sharepoint/tutorial-queue-a-trim-job)
- [Manage version history limits on a site or library](https://learn.microsoft.com/sharepoint/tutorial-manage-version-limits)
