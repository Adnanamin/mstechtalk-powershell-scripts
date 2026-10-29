# Get-CopilotAgentUsage.ps1

Export Microsoft 365 Copilot usage per user and, when the required tenant licensing and permissions are available, a catalogue of agents with owner and usage information.

The script is read-only and writes CSV reports to the selected output folder.

## What it exports

- **Copilot user usage:** One row per user included in the Microsoft 365 Copilot usage report.
- **Agent catalogue:** One row per agent returned by the organisation's agent catalogue, including available owner and 30-day usage information.

The script creates date-stamped files:

- `CopilotUserUsage-<date>.csv`
- `CopilotAgents-<date>.csv`

The agent report may be skipped with a warning if the required Microsoft Agent 365 licensing or access is unavailable.

## Requirements

- PowerShell 7.2 or later
- `Microsoft.Graph.Authentication` PowerShell module
- An account with the appropriate Microsoft Graph permissions and administrative role
- Required tenant licensing for the agent catalogue report

Install the module if needed:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

## Permissions and access

The script requests the following delegated Microsoft Graph scopes, with admin consent required as described in the script:

- `Reports.Read.All`
- `CopilotPackages.Read.All`
- `AgentIdentity.Read.All`
- `User.ReadBasic.All`

The script documentation identifies **AI Administrator** or **Global Administrator** as the role for the signing-in account. Exact permission and licensing requirements can change, so verify them against current Microsoft documentation and your tenant configuration before running the script.

## Usage

Run the script from the folder where you saved it:

```powershell
./Get-CopilotAgentUsage.ps1
```

Choose a reporting period of 7, 28, 90, or 180 days and specify an output folder:

```powershell
./Get-CopilotAgentUsage.ps1 -Days 90 -OutputFolder ~/Reports
```

`-Days` defaults to `28`. `-OutputFolder` defaults to the current directory.

## Important notes

- The script is intended to read data and export reports. Review the code before running it in your environment.
- The contents of the reports depend on the data Microsoft Graph makes available to your tenant and the permissions granted to the account.
- Treat exported CSV files as potentially sensitive organisational data. Store and share them according to your organisation's policies.
- Test in a suitable non-production or controlled environment before using the reports for operational decisions.

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience. His areas of expertise include Microsoft 365, SharePoint, Microsoft Teams, Power Platform, Microsoft Copilot, and AI agents.

Through [MSTechTalk](https://mstechtalk.com), Adnan shares technical articles, practical guidance, and tools to help IT professionals and administrators learn, implement, and manage Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

This script is provided for educational and administrative purposes. Review the code, verify the required permissions, and test it in a suitable environment before production use. Use it at your own risk.

## Related article

 - [How to monitor Microsoft 365 Copilot and agents usage in your organization](https://mstechtalk.com/how-to-monitor-microsoft-365-copilot-and-agents-usage-in-your-organization/)
 - [Roles and permissions to monitor Copilot and agents in Microsoft 365](https://mstechtalk.com/roles-and-permissions-to-monitor-copilot-and-agents-in-microsoft-365/)

