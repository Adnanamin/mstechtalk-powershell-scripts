# Get-CopilotAgentUsage.ps1

Read-only report of Microsoft 365 Copilot usage per user, plus every agent in the tenant with its owner and 30-day usage. PowerShell 7, Microsoft Graph PowerShell (`Microsoft.Graph.Authentication` only). Runs on Windows and macOS.

## Run it

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser   # once
./Get-CopilotAgentUsage.ps1                      # last 28 days, CSVs in the current folder
./Get-CopilotAgentUsage.ps1 -Days 90 -OutputFolder ~/Reports
```

To sign in with a device code (approve from another machine), run `Connect-MgGraph -Scopes Reports.Read.All,CopilotPackages.Read.All,AgentIdentity.Read.All,User.ReadBasic.All -UseDeviceCode` first. The script reuses that session.

## Permissions

| What | Needed for |
|---|---|
| `Reports.Read.All` (delegated) | Copilot usage per user |
| `CopilotPackages.Read.All` (delegated) | Agent list and per-agent usage |
| `AgentIdentity.Read.All` (delegated) | Owners from Microsoft Entra Agent ID |
| `User.ReadBasic.All` (delegated) | Owner name and email |
| Role: **AI Administrator** (or Global Administrator) | Covers both reports |
| Licence: **Microsoft Agent 365** in the tenant | Agent list. Without it the agent part is skipped with a warning |

All four scopes need admin consent once. If user names show as long hex strings, the report privacy setting is on: a Global Administrator opens **Settings** > **Org settings** > **Services** > **Reports** and clears **Conceal user, group, and site names in all reports** (older wording: tick **Display concealed user, group, and site names in all reports**).

## Output

**CopilotUserUsage-&lt;date&gt;.csv** (one row per Copilot-licensed user, from `GET /v1.0/copilot/reports/getMicrosoft365CopilotUsageUserDetail(period='D28',version='v2')`, falls back to report v1 / D30 if v2 is refused):
reportRefreshDate, userPrincipalName, displayName, lastActivityDate, and a LastActivityDate column per app (Copilot Chat, Teams, Word, Excel, PowerPoint, Outlook, OneNote, Loop), then whatever the per-period block returns (reportPeriod and, in report v2, prompt counts and active days). Column names come straight from Graph, so new metrics appear without a script change.

**CopilotAgents-&lt;date&gt;.csv** (one row per agent or bot in the organisation catalog, from `GET /beta/copilot/admin/catalog/packages` and `/packages/{id}`):
AgentName, Type, Platform, Publisher, OwnerName, OwnerEmail, OwnerSource, ActiveUsers30d, Sessions30d, RunTimeHours30d, ExceptionRate, LastUsed, IsBlocked, AvailableTo, DeployedTo, SharedWithCount, AgentKind, ElementTypes, SupportedHosts, Sensitivity, Created, LastModified, Version, Description, AgentId, AgentIdentityId, AppId.

Plus a console summary: users in report, users active in the period, agents, agents with no owner, unused agents, blocked agents.

## Known limits

- **Owner**: Graph has no documented owner property on agent packages yet. The script reads `ownerId` (returned by the beta API, used in the documented reassign flow) and falls back to the agent's Entra Agent ID owners. Anything else shows "No owner found".
- Agent usage numbers are Microsoft's 30-day figures from the package details, regardless of `-Days`.
- Copilot Chat (unlicensed) usage isn't in the Graph report yet. Use the admin center Copilot Chat report or the Purview audit log.
- Usage data lags up to 48 hours.
