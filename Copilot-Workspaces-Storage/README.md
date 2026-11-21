# Copilot Workspaces storage

Function for the MSTechTalk post [Copilot Workspaces for admins: where the content lives and what to check](https://mstechtalk.com/copilot-workspaces-admin-storage-security/) by Adnan Amin.

`Get-MttCopilotContainer` lists the SharePoint Embedded containers that hold Copilot Workspaces, Copilot Notebooks, Copilot Pages and Loop My workspace content, with owner, ownership type, owner count and storage. It is a read-only report function for the planned **MSTechTalk.M365** module (see [CONVENTIONS.md](../CONVENTIONS.md)).

| Script | What it does | Changes anything? |
|---|---|---|
| `Get-MttCopilotContainer.ps1` | Report function: one row per Loop container, with owner, owners count and storage | No |

## Why the application is Loop

Copilot Workspaces, Notebooks and Pages share one user-owned container per user with Loop My workspace. In the SharePoint admin center, PowerShell and the audit log, that container always shows the application name **Loop**, as Microsoft explains in [Overview of Copilot Pages and Copilot Notebooks storage](https://learn.microsoft.com/microsoft-365/loop/cpcn-storage). The function uses the Loop owning application ID from Microsoft's [SharePoint Embedded management page](https://learn.microsoft.com/microsoft-365/loop/spe-management). It is Microsoft's published ID, not a tenant or app registration ID.

`Get-SPOApplication` returns nothing for Microsoft's own applications, so the ID is set as the default of `-OwningApplicationId`.

## Prerequisites

- SharePoint Embedded Administrator or Global Administrator role.
- SharePoint Online Management Shell 16.0.27814 or later: `Install-Module Microsoft.Online.SharePoint.PowerShell`.
- Windows. The SPO module runs in Windows PowerShell 5.1, or PowerShell 7 on Windows with `-UseWindowsPowerShell`.

## How to run

In PowerShell 7, import the module with `-UseWindowsPowerShell`. In Windows PowerShell 5.1, leave that line out.

```powershell
Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell
Connect-SPOService -Url https://contoso-admin.sharepoint.com
. .\Get-MttCopilotContainer.ps1
Get-MttCopilotContainer | Export-Csv .\CopilotContainers.csv -NoTypeInformation -Encoding UTF8
```

More examples:

```powershell
Get-MttCopilotContainer | Where-Object OwnersCount -eq 0                                    # no owner, for example after a leaver
Get-MttCopilotContainer | Sort-Object StorageUsedGB -Descending | Select-Object -First 10   # ten largest
Get-MttCopilotContainer | Group-Object OwnershipType                                        # user, group and tenant owned
```

| Parameter | Description |
|---|---|
| `-OwningApplicationId` | One or more SharePoint Embedded owning application IDs. Default: Microsoft Loop. |

## Output

One `MSTechTalk.CopilotContainer` object per container:

| Column | Meaning |
|---|---|
| `UserPrincipalName` | Principal owner of the container (empty when it has none) |
| `ContainerId` | SharePoint Embedded container ID |
| `ContainerName` | For example `Pages` or `My workspace`, or a GUID |
| `OwnershipType` | `UserOwned`, `GroupOwned` or `TenantOwned` |
| `OwnersCount` | Number of owners |
| `StorageUsedGB` | Storage used, in GB |
| `Status` | `Active`, or another state |
| `SensitivityLabel` | Container sensitivity label, if set |
| `CreatedOn` | When the container was created |
| `OwningApplicationId` | Application that owns the container |

| | |
|---|---|
| **Requires** | SPO |
| **Level** | Tenant |
| **Permissions** | SharePoint Embedded Administrator or Global Administrator |

On the demo tenant it returned two Loop containers: one created on the day the first Copilot workspace was made, and an older `Pages` container. A user who only joined a shared workspace had no container. The Work IQ "Aether Workspace" containers belong to a different application and aren't listed.

## Author

- **Adnan Amin**, [MSTechTalk](https://mstechtalk.com)
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.
