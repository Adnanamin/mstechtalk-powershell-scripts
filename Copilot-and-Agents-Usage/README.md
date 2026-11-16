# Copilot and agents usage

Two read-only report functions for monitoring Microsoft 365 Copilot in your organisation, for the planned **MSTechTalk.M365** module (see [CONVENTIONS.md](../CONVENTIONS.md)). They don't sign in and don't write files: you connect with `Connect-MgGraph` first, and pipe the result to `Export-Csv`.

| Function | What it returns |
|---|---|
| `Get-MttCopilotUsage.ps1` | One row per Copilot-licensed user from the Microsoft 365 Copilot usage report: last activity per Copilot app and, in report v2, prompt counts and active days |
| `Get-MttCopilotAgent.ps1` | One row per agent in the organisation catalog, with owner and 30-day usage |

> **Replaces `Get-CopilotAgentUsage.ps1`.** The two reports that script wrote are now two functions. `Get-MttCopilotUsage` also fixes the usage report: the v1.0 report is only available as CSV, and the old script expected JSON, so it returned no users. The function downloads Microsoft's CSV to a temporary file, reads it and removes the file.

## Requirements

| | |
|---|---|
| **Requires** | Graph |
| **PowerShell** | 7.4 or later |
| **Module** | Microsoft.Graph.Authentication 2.x (tested with 2.41.2) |
| **Level** | `Get-MttCopilotUsage`: Tenant, User. `Get-MttCopilotAgent`: Tenant |

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

| Function | Delegated scopes | Role | Licence |
|---|---|---|---|
| `Get-MttCopilotUsage` | `Reports.Read.All` | AI Administrator, Reports Reader or Global Administrator | Microsoft 365 Copilot |
| `Get-MttCopilotAgent` | `CopilotPackages.Read.All`, `AgentIdentity.Read.All`, `User.ReadBasic.All` | AI Administrator or Global Administrator | Microsoft Agent 365 |

## Get-MttCopilotUsage

```powershell
Connect-MgGraph -Scopes Reports.Read.All
. .\Get-MttCopilotUsage.ps1
Get-MttCopilotUsage -Days 28 | Export-Csv .\CopilotUsage.csv -NoTypeInformation -Encoding UTF8
```

Licensed users who haven't used Copilot:

```powershell
Get-MttCopilotUsage | Where-Object { -not $_.LastActivityDate } | Select-Object UserPrincipalName, DisplayName
```

| Parameter | Description |
|---|---|
| `-Days` | Report period: 7, 28, 90 or 180. Defaults to 28. If report v2 isn't available, v1 is used, and 28 becomes 30. |

One `MSTechTalk.CopilotUsage` object per user. The properties are the report's column names without spaces, for example `UserPrincipalName`, `DisplayName`, `LastActivityDate`, one `...LastActivityDate` per Copilot app, and in report v2 `PromptsSubmittedForAllApps` and `ActiveUsageDaysForAllApps`. Dates are dates and counts are numbers.

If the tenant hides user names in reports, `UserPrincipalName` holds an ID and the function warns. A Global Administrator can show the names: **Microsoft 365 admin center** > **Settings** > **Org settings** > **Services** > **Reports**, clear **Conceal user, group, and site names in all reports**.

On the demo tenant the function read 4 users in 2 seconds, with the same last activity date as Microsoft's CSV for every user.

## Get-MttCopilotAgent

```powershell
Connect-MgGraph -Scopes CopilotPackages.Read.All, AgentIdentity.Read.All, User.ReadBasic.All
. .\Get-MttCopilotAgent.ps1
Get-MttCopilotAgent | Export-Csv .\CopilotAgents.csv -NoTypeInformation -Encoding UTF8
```

Agents with no owner, or not used in 30 days:

```powershell
Get-MttCopilotAgent | Where-Object { -not $_.OwnerName -or -not $_.ActiveUsers30d } | Select-Object AgentName, OwnerName, ActiveUsers30d, LastUsed
```

One `MSTechTalk.CopilotAgent` object per agent: `AgentName`, `Type`, `Platform`, `Publisher`, `OwnerName`, `OwnerEmail`, `OwnerSource`, `ActiveUsers30d`, `Sessions30d`, `RunTimeHours30d`, `ExceptionRate`, `LastUsed`, `IsBlocked`, `AvailableTo`, `DeployedTo`, `SharedWithCount`, `AgentKind`, `ElementTypes`, `SupportedHosts`, `Sensitivity`, `Created`, `LastModified`, `Version`, `Description`, `AgentId`, `AgentIdentityId` and `AppId`.

The owner comes from the agent package; when that is empty, from the owners of the agent's Microsoft Entra Agent ID. `OwnerSource` says which.

> **Partly tested.** The agent catalog API is in beta and needs a Microsoft Agent 365 licence. The demo tenant has none, so the function was only tested up to Microsoft's "Customer must be licensed for Agent 365" response, where it stops with a clear message.

## Important notes

- Treat the CSV files as organisational data: they contain user names and email addresses. Store them according to your policies.
- The agent catalog uses Microsoft Graph beta, so its properties can change.
- On Windows, `Connect-MgGraph` signs in through Web Account Manager (WAM), and the sign-in window can open behind an embedded terminal.

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.

## Related articles

- [How to monitor Microsoft 365 Copilot and agents usage in your organization](https://mstechtalk.com/how-to-monitor-microsoft-365-copilot-and-agents-usage-in-your-organization/)
- [Roles and permissions to monitor Copilot and agents in Microsoft 365](https://mstechtalk.com/roles-and-permissions-to-monitor-copilot-and-agents-in-microsoft-365/)
