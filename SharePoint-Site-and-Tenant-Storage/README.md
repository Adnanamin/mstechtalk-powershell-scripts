# SharePoint site and tenant storage

Scripts and functions for the MSTechTalk post [How to find what is filling a SharePoint site and free up tenant storage](https://mstechtalk.com/how-to-find-what-is-filling-a-sharepoint-site-and-free-up-tenant-storage/) by Adnan Amin.

Four of them use the **SharePoint Online Management Shell** (`Microsoft.Online.SharePoint.PowerShell`). `Measure-MttVersionStorage.ps1` only reads a CSV on your machine and needs no module.

| Script | What it does | Changes anything? |
|---|---|---|
| `Get-MttSiteStorage.ps1` | Report function: lists sites by the storage they use, largest first, with last change date | No |
| `Start-MttVersionStorageReport.ps1` | Function: starts Microsoft's version storage report job for a site, OneDrive or library | Creates the report CSV only |
| `Get-MttVersionStorageReportStatus.ps1` | Report function: shows the status of that job | No |
| `Measure-MttVersionStorage.ps1` | Report function: reads the finished report and returns version history size per file, or the totals, and what a trim would free | No |
| `Invoke-VersionTrim.ps1` | Sets version history limits and queues a trim job for the versions already there | **Yes. Deleted versions can't be recovered** |

## Prerequisites

- SharePoint Administrator role.
- SharePoint Online Management Shell, latest version: `Install-Module Microsoft.Online.SharePoint.PowerShell` (or `Update-Module`). The report and trim cmdlets need a recent build.
- Windows. The SPO module runs in Windows PowerShell 5.1, or PowerShell 7 on Windows.
- `Measure-MttVersionStorage.ps1` runs anywhere: Windows PowerShell 5.1 or PowerShell 7 on Windows, macOS or Linux.

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

`Start-MttVersionStorageReport` and `Get-MttVersionStorageReportStatus` are functions for the planned **MSTechTalk.M365** module. Together they replace `Start-VersionStorageReport.ps1`: they don't sign in, and checking progress is its own function instead of a `-CheckProgress` switch.

```powershell
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
Connect-SPOService -Url https://contoso-admin.sharepoint.com
. .\Start-MttVersionStorageReport.ps1
. .\Get-MttVersionStorageReportStatus.ps1
$job = Start-MttVersionStorageReport -SiteUrl https://contoso.sharepoint.com/sites/Projects `
    -ReportUrl "https://contoso.sharepoint.com/sites/Projects/Shared Documents/Reports/VersionReport.csv"
```

- The CSV must go in a document library of the same site, and the file must not exist yet.
- Put it in a folder only site owners can open. The report lists every file and who edited it.
- Add `-Library "Documents"` for one library.
- The job runs in the background. Microsoft says over 24 hours for a small site and a few days for a large one; a small demo site finished the same evening. Don't open or edit the CSV while it fills. Deleting it cancels the job.

Check progress until the status is `completed`, in the same session or a new one:

```powershell
$job | Get-MttVersionStorageReportStatus
Get-MttVersionStorageReportStatus -SiteUrl https://contoso.sharepoint.com/sites/Projects `
    -ReportUrl "https://contoso.sharepoint.com/sites/Projects/Shared Documents/Reports/VersionReport.csv"
```

| Parameter | Description |
|---|---|
| `-SiteUrl` | Site or OneDrive URL (alias `Url`). |
| `-ReportUrl` | Full URL of the report CSV, in a library of the same site. |
| `-Library` | Title of one library. Leave it out for the whole site. |

Both return one `MSTechTalk.VersionStorageReportStatus` object: `SiteUrl`, `Library`, `ReportUrl`, `Status` (`completed`, `in_progress`, `no_report_found` or `failed`) and `ErrorMessage`. SharePoint looks the job up by report URL, so use the same `-ReportUrl` you started it with.

| | |
|---|---|
| **Requires** | SPO |
| **Level** | Site, Library |
| **Permissions** | SharePoint Administrator |

### 3. Analyse the report

`Measure-MttVersionStorage` is a read-only report function for the planned **MSTechTalk.M365** module. It replaces `Measure-VersionStorageReport.ps1`: it returns rows instead of writing two CSVs next to the report, and it needs no module and no sign-in.

Download the CSV, then:

```powershell
. .\Measure-MttVersionStorage.ps1
Measure-MttVersionStorage -ReportPath C:\Temp\VersionReport.csv -Summary
Measure-MttVersionStorage -ReportPath C:\Temp\VersionReport.csv | Select-Object -First 20
```

Save both to CSV:

```powershell
Measure-MttVersionStorage -ReportPath C:\Temp\VersionReport.csv -Summary | Export-Csv .\VersionStorage-Summary.csv -NoTypeInformation -Encoding UTF8
Measure-MttVersionStorage -ReportPath C:\Temp\VersionReport.csv | Export-Csv .\VersionStorage-Files.csv -NoTypeInformation -Encoding UTF8
```

| Parameter | Description |
|---|---|
| `-ReportPath` | Path of the report CSV (aliases `FullName`, `Path`). Accepts pipeline input, for example from `Get-ChildItem`. |
| `-KeepVersions` | What-if: keep this many newest versions per file, the current one included. Defaults to 100. |
| `-OlderThanDays` | What-if: delete older versions last modified more than this many days ago. Defaults to 365. |
| `-Summary` | Return one row of totals instead of one row per file. |

| Output | One row per | Properties |
|---|---|---|
| `MSTechTalk.VersionStorageFile` (default) | file, largest version history first | `SiteUrl`, `FileUrl`, `Versions`, `CurrentVersion`, `CurrentSizeMB`, `HistorySizeMB`, `TotalSizeMB`, `KeepFreesMB`, `OlderThanFreesMB` |
| `MSTechTalk.VersionStorageSummary` (`-Summary`) | report | `ReportPath`, `FileVersions`, `Files`, `TotalSizeGB`, `CurrentVersionsGB`, `VersionHistoryGB`, `VersionHistoryVersions`, `KeepVersions`, `KeepFreesGB`, `OlderThanDays`, `OlderThanFreesGB` |

| | |
|---|---|
| **Requires** | None |
| **Level** | Site, Library, File |
| **PowerShell** | Windows PowerShell 5.1 or PowerShell 7, on any OS |

The newest version of each file (highest major.minor) counts as the current version. Everything else is version history. The what-if numbers are estimates: the real trim job uses SharePoint's own rules, and files under retention keep their versions.

Try it on the sample first: `Measure-MttVersionStorage -ReportPath .\templates\VersionStorageReport-template.csv -KeepVersions 2 -Summary`

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
