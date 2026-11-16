# MSTechTalk PowerShell Scripts

A collection of practical PowerShell scripts published alongside technical articles on [MSTechTalk](https://mstechtalk.com).

These scripts help IT professionals, Microsoft 365 administrators, consultants, and technology teams automate administrative tasks, generate reports, and better understand their Microsoft environments.

## Script Catalogue

| Script | Folder | Level | Requires | Blog post |
|---|---|---|---|---|
| `Get-CopilotAgentUsage.ps1` | [Copilot-and-Agents-Usage](./Copilot-and-Agents-Usage/) | Tenant, User | Graph | [Monitor Copilot and agents usage](https://mstechtalk.com/how-to-monitor-microsoft-365-copilot-and-agents-usage-in-your-organization/) |
| `Get-MttCopilotBlockedSite.ps1` | [SharePoint-Copilot-Blocked-Sites](./SharePoint-Copilot-Blocked-Sites/) | Tenant, Site | SPO | [Find SharePoint sites with Copilot blocked](https://mstechtalk.com/find-sharepoint-sites-copilot-blocked/) |
| `Start-MttRcdInsightsReport.ps1` | [SharePoint-Copilot-Blocked-Sites](./SharePoint-Copilot-Blocked-Sites/) | Tenant | SPO | [Find SharePoint sites with Copilot blocked](https://mstechtalk.com/find-sharepoint-sites-copilot-blocked/) |
| `Get-MttSiteStorage.ps1` | [SharePoint-Site-and-Tenant-Storage](./SharePoint-Site-and-Tenant-Storage/) | Tenant, Site | SPO | [Find what is filling a SharePoint site](https://mstechtalk.com/how-to-find-what-is-filling-a-sharepoint-site-and-free-up-tenant-storage/) |
| `Start-VersionStorageReport.ps1` | [SharePoint-Site-and-Tenant-Storage](./SharePoint-Site-and-Tenant-Storage/) | Site | SPO | [Find what is filling a SharePoint site](https://mstechtalk.com/how-to-find-what-is-filling-a-sharepoint-site-and-free-up-tenant-storage/) |
| `Measure-VersionStorageReport.ps1` | [SharePoint-Site-and-Tenant-Storage](./SharePoint-Site-and-Tenant-Storage/) | Site | None | [Find what is filling a SharePoint site](https://mstechtalk.com/how-to-find-what-is-filling-a-sharepoint-site-and-free-up-tenant-storage/) |
| `Invoke-VersionTrim.ps1` *(changes data)* | [SharePoint-Site-and-Tenant-Storage](./SharePoint-Site-and-Tenant-Storage/) | Site | SPO | [Find what is filling a SharePoint site](https://mstechtalk.com/how-to-find-what-is-filling-a-sharepoint-site-and-free-up-tenant-storage/) |
| `Get-MttAnyoneSharingLink.ps1` | [SharePoint-Anyone-Sharing-Links](./SharePoint-Anyone-Sharing-Links/) | Site, Library | PnP | [Find Anyone links with PnP PowerShell](https://mstechtalk.com/find-anyone-links-sharepoint-pnp-powershell/) |
| `Get-MttUniquePermission.ps1` | [SharePoint-Unique-Permissions](./SharePoint-Unique-Permissions/) | Site, Library | PnP | [SharePoint unique permissions report](https://mstechtalk.com/sharepoint-unique-permissions-report-pnp-powershell/) |
| `Get-MttListItem.ps1` | [SharePoint-Large-Lists](./SharePoint-Large-Lists/) | List | PnP | [Fix the 5,000-item list view threshold](https://mstechtalk.com/sharepoint-list-view-threshold-5000-fix/) |
| `Find-DeprecatedGraphEndpoint.ps1` | [Graph-SharedWithMe-Retirement](./Graph-SharedWithMe-Retirement/) | Local script files | None | [Graph sharedWithMe retirement](https://mstechtalk.com/graph-sharedwithme-recent-retired-search-api/) |
| `Get-RecentDocumentBySearch.ps1` | [Graph-SharedWithMe-Retirement](./Graph-SharedWithMe-Retirement/) | User | Graph | [Graph sharedWithMe retirement](https://mstechtalk.com/graph-sharedwithme-recent-retired-search-api/) |
| `New-GuestInvitation.ps1` *(changes data)* | [SharePoint-OTP-Retirement](./SharePoint-OTP-Retirement/) | User | Graph | [SharePoint OTP retirement: guest access denied](https://mstechtalk.com/sharepoint-otp-retirement-guest-access-denied/) |

**Level** is what a script reports on. **Requires** is the sign-in it needs:

- **PnP:** PnP.PowerShell 3.x with your own Entra app registration.
- **Graph:** Microsoft Graph PowerShell.
- **SPO:** SharePoint Online Management Shell.
- **None:** no sign-in.

Scripts marked *(changes data)* create or change something in your tenant; read their README before running them. [CONVENTIONS.md](./CONVENTIONS.md) describes how scripts in this repository are written.

## Script Collections

### Microsoft Copilot and AI Agents

Tools for reporting on Microsoft 365 Copilot usage and discovering agents in your organization.

- **Script:** `Get-CopilotAgentUsage.ps1`
- **Features:** Copilot usage reporting, agent inventory, owner information, and agent usage metrics.
- **Requirements:** PowerShell 7.2 or later and the required Microsoft Graph permissions.
- **Documentation:** [Copilot and Agents Usage](./Copilot-and-Agents-Usage/README.md)

### SharePoint Sites with Copilot Blocked

Tools for listing the SharePoint sites where Copilot is blocked by Restricted Content Discovery (RCD).

- **Scripts:** `Get-MttCopilotBlockedSite.ps1` and `Start-MttRcdInsightsReport.ps1` (module-ready functions; replace `Get-CopilotBlockedSites.ps1` and `Get-RCDInsightsReport.ps1`)
- **Features:** Per-site RCD check for the whole tenant or the sites you give it, and Microsoft's RCD insights report queued, waited for and downloaded, both returned as objects you can export to CSV.
- **Requirements:** SharePoint Online Management Shell and the SharePoint Administrator role.
- **Documentation:** [SharePoint Sites with Copilot Blocked](./SharePoint-Copilot-Blocked-Sites/README.md)

### SharePoint Site and Tenant Storage

Tools for finding what is filling a SharePoint site, measuring version history storage and trimming old versions.

- **Scripts:** `Get-MttSiteStorage.ps1` (module-ready function; replaces `Get-TopSitesByStorage.ps1`), `Start-VersionStorageReport.ps1`, `Measure-VersionStorageReport.ps1`, `Invoke-VersionTrim.ps1`
- **Features:** Top sites by storage, version storage report jobs, version history analysis per file, library and user, what-if estimates, version limits and trim jobs.
- **Requirements:** SharePoint Online Management Shell and the SharePoint Administrator role. `Measure-VersionStorageReport.ps1` needs no module.
- **Documentation:** [SharePoint Site and Tenant Storage](./SharePoint-Site-and-Tenant-Storage/README.md)

### Anyone Links on a SharePoint Site

Tools for finding every Anyone (anonymous) sharing link on a SharePoint site.

- **Script:** `Get-MttAnyoneSharingLink.ps1` (module-ready function; replaces `Get-AnyoneSharingLink.ps1`)
- **Features:** Every file and folder an Anyone link opens, with view or edit, the expiry date and a link ID to count the links themselves, for one site or one library, returned as objects you can export to CSV.
- **Requirements:** PowerShell 7.4 or later, PnP.PowerShell 3.x and your own Entra app registration.
- **Documentation:** [Anyone Links on a SharePoint Site](./SharePoint-Anyone-Sharing-Links/README.md)

### SharePoint Unique Permissions

Tools for listing everything on a SharePoint site that has stopped inheriting permissions.

- **Script:** `Get-MttUniquePermission.ps1` (module-ready function; replaces `Get-UniquePermissionReport.ps1`)
- **Features:** Libraries, lists, folders, files and list items with unique permissions, for one site or one library, returned as objects you can export to CSV.
- **Requirements:** PowerShell 7.4 or later, PnP.PowerShell 3.x and your own Entra app registration.
- **Documentation:** [SharePoint Unique Permissions](./SharePoint-Unique-Permissions/README.md)

### SharePoint Large Lists

Tools for reading SharePoint lists over the 5,000-item list view threshold.

- **Script:** `Get-MttListItem.ps1` (module-ready function; replaces `Get-LargeListItem.ps1`)
- **Features:** Paged reads of every item, or only the items with one value in an indexed column, returned as objects you can export to CSV; warns before filtering on a column that isn't indexed.
- **Requirements:** PowerShell 7.4 or later, PnP.PowerShell 3.x and your own Entra app registration.
- **Documentation:** [SharePoint Large Lists](./SharePoint-Large-Lists/README.md)

### Microsoft Graph sharedWithMe Retirement

Tools for moving off the Graph file endpoints that stop returning data after November 2026.

- **Scripts:** `Find-DeprecatedGraphEndpoint.ps1`, `Get-RecentDocumentBySearch.ps1`
- **Features:** Finds old calls in your scripts, and lists recent documents with the Microsoft Search API.
- **Requirements:** Microsoft.Graph.Authentication for the Search API script.
- **Documentation:** [Microsoft Graph sharedWithMe Retirement](./Graph-SharedWithMe-Retirement/README.md)

### SharePoint OTP Retirement

Tools for giving external users access back after SharePoint one-time passcode retirement.

- **Script:** `New-GuestInvitation.ps1`
- **Features:** Creates the Entra B2B guest account an external user needs to open old specific people links.
- **Requirements:** Microsoft.Graph.Identity.SignIns and the `User.Invite.All` permission.
- **Documentation:** [SharePoint OTP Retirement](./SharePoint-OTP-Retirement/README.md)

## Getting Started

1. Open the folder for the script you want to use.
2. Read its README for prerequisites, permissions, installation instructions, and examples.
3. Review the PowerShell code before running it.
4. Test in a suitable environment before using it in production.

Requirements and permissions vary by script. Refer to each project's documentation.

## Important Notes

- Scripts are provided for educational and administrative purposes.
- Review the code and validate permissions before execution.
- Never commit passwords, access tokens, client secrets, or sensitive organizational data.
- Microsoft Graph APIs, permissions, licensing, and product capabilities may change over time.

## About the Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

Through [MSTechTalk](https://mstechtalk.com), he shares technical articles, implementation guidance, and practical resources covering Microsoft 365, SharePoint, Microsoft Teams, Power Platform, Microsoft Copilot, and AI agents.

- **Blog:** [MSTechTalk](https://mstechtalk.com)
- **GitHub:** [adnanamin](https://github.com/adnanamin)

## Disclaimer

These scripts are provided as-is, without warranties. You are responsible for reviewing and testing them and for ensuring that their use complies with your organization's policies and security requirements.
