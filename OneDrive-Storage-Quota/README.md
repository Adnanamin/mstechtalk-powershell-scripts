# OneDrive storage quota

Function for the MSTechTalk post [Find OneDrive accounts near their storage quota with PowerShell](https://mstechtalk.com/find-onedrive-accounts-near-their-storage-quota-with-powershell/) by Adnan Amin.

`Get-MttOneDriveUsage` lists every OneDrive account with storage used, its quota, and how much it uses above the storage the user's licence includes. It is a read-only report function for the planned **MSTechTalk.M365** module (see [CONVENTIONS.md](../CONVENTIONS.md)).

| Script | What it does | Changes anything? |
|---|---|---|
| `Get-MttOneDriveUsage.ps1` | Report function: storage used, quota, percentage of quota and storage above the licensed amount, per OneDrive | No |

## Quota and licensed storage are different

- **Quota** (`StorageQuotaGB`) is the limit set on the account. An admin can raise it above what the licence includes.
- **Licensed storage** (`EntitlementGB`) is what the user's licence includes. With [OneDrive pay-as-you-go storage](https://learn.microsoft.com/microsoft-365/commerce/add-storage-space), Microsoft bills the storage used above this amount, not above the quota.

So a user with a 3 TB quota who uses 1.2 TB is only 40% of the way to their quota, but already about 205 GB above a 1 TB licence. `OverEntitlementGB` shows that amount.

The function can't read each user's licence. `EntitlementGB` is the value you pass with `-EntitlementGB`, 1024 GB (1 TB) when you leave it out. Set it to what your plan includes.

## Prerequisites

- SharePoint Administrator role.
- SharePoint Online Management Shell: `Install-Module Microsoft.Online.SharePoint.PowerShell`.
- Windows. The SPO module runs in Windows PowerShell 5.1, or PowerShell 7 on Windows with `-UseWindowsPowerShell`.

## How to run

In PowerShell 7, import the module with `-UseWindowsPowerShell`. In Windows PowerShell 5.1, leave that line out.

```powershell
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
Connect-SPOService -Url https://contoso-admin.sharepoint.com
. .\Get-MttOneDriveUsage.ps1
Get-MttOneDriveUsage -MinPercentUsed 80 | Export-Csv .\OneDriveNearQuota.csv -NoTypeInformation -Encoding UTF8
```

More examples:

```powershell
Get-MttOneDriveUsage -User alex.miller@contoso.com              # one user
Get-MttOneDriveUsage | Where-Object OverEntitlementGB -gt 0     # using more than the licence includes
Get-MttOneDriveUsage -EntitlementGB 5120                        # plans that include 5 TB
```

| Parameter | Description |
|---|---|
| `-User` | One or more users by user principal name (alias `UserPrincipalName`). Accepts pipeline input. Leave it out for every OneDrive in the tenant. |
| `-MinPercentUsed` | Only accounts using at least this percentage of their quota, for example `80`. |
| `-EntitlementGB` | Storage the user's licence includes, in GB. Default `1024`. Minimum `1`. |

## Output

One `MSTechTalk.OneDriveUsage` object per account, highest percentage first, then largest:

| Column | Meaning |
|---|---|
| `UserPrincipalName` | Owner of the OneDrive |
| `SiteUrl` | OneDrive URL |
| `StorageUsedGB` | Storage used, in GB |
| `StorageQuotaGB` | Quota set on the account, in GB |
| `PercentUsed` | Storage used as a percentage of the quota, two decimals |
| `EntitlementGB` | Licensed storage, from `-EntitlementGB` |
| `OverEntitlementGB` | Storage used above `EntitlementGB`, or 0 |
| `LastContentModified` | Date of the last content change |
| `DaysSinceLastChange` | Days since that change |
| `LockState` | `Unlock`, `ReadOnly` or `NoAccess`. Unlicensed accounts become read-only, then archived. |

Users without a OneDrive are skipped with a warning.

| | |
|---|---|
| **Requires** | SPO |
| **Level** | Tenant, User |
| **Permissions** | SharePoint Administrator |

On the demo tenant it read 13 OneDrive accounts in Windows PowerShell 5.1 and PowerShell 7, with the same rows and order in both.

## Author

- **Adnan Amin**, [MSTechTalk](https://mstechtalk.com)
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.
