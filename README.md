# SharePoint site and tenant storage

Scripts for the MSTechtalk post **How to find what is filling a SharePoint site and free up tenant storage**: [CONFIRM: post URL once published].

Three scripts use the **SharePoint Online Management Shell** (`Microsoft.Online.SharePoint.PowerShell`). `Measure-VersionStorageReport.ps1` only reads a CSV on your machine and needs no module.

| Script | What it does | Changes anything? |
|---|---|---|
| `Get-TopSitesByStorage.ps1` | Exports the sites using the most storage, with last change date | No |
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

```powershell
.\Get-TopSitesByStorage.ps1 -AdminUrl https://contoso-admin.sharepoint.com -Top 25
```

Writes `TopSitesByStorage.csv`. Big sites with a high `DaysSinceLastChange` are archive candidates. See `templates/TopSitesByStorage-template.csv` for the layout.

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

On screen you get the totals and the top files. Four CSVs are written next to the report:

| File | One row per | Main columns |
|---|---|---|
| `VersionStorage-Summary.csv` | measure | total size, current versions, version history, history %, what-if for `-KeepVersions` and `-OlderThanDays` |
| `VersionStorage-Files.csv` | file | `Versions`, `CurrentSizeMB`, `HistorySizeMB`, `TotalSizeMB`, `OldestVersionUtc` |
| `VersionStorage-Libraries.csv` | library | `Files`, `Versions`, `TotalSizeMB`, `HistorySizeMB` |
| `VersionStorage-Users.csv` | person | `HistoryVersions`, `HistorySizeMB` |

The newest version of each file (highest major.minor) counts as the current version. Everything else is version history. The what-if numbers are estimates: the real trim job uses SharePoint's own rules, and files under retention keep their versions.

Try it on the sample first: `.\Measure-VersionStorageReport.ps1 -ReportPath .\templates\VersionStorageReport-template.csv -KeepVersions 2`

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

**`TopSitesByStorage-template.csv`** is the output of `Get-TopSitesByStorage.ps1`: `Url`, `Title`, `Template`, `LastContentModifiedDate`, `UsedGB`, `QuotaGB`, `DaysSinceLastChange`.

## References

- [Generate version storage usage report for a site](https://learn.microsoft.com/sharepoint/version-storage-report-site)
- [Tutorial: generate and analyse a version usage report](https://learn.microsoft.com/sharepoint/tutorial-generate-version-usage-report)
- [Queue a version trim job](https://learn.microsoft.com/sharepoint/tutorial-queue-a-trim-job)
- [Manage version history limits on a site or library](https://learn.microsoft.com/sharepoint/tutorial-manage-version-limits)
