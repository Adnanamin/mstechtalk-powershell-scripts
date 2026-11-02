# MSTechTalk PowerShell Scripts

A collection of practical PowerShell scripts published alongside technical articles on [MSTechTalk](https://mstechtalk.com).

These scripts help IT professionals, Microsoft 365 administrators, consultants, and technology teams automate administrative tasks, generate reports, and better understand their Microsoft environments.

## Script Collections

### Microsoft Copilot and AI Agents

Tools for reporting on Microsoft 365 Copilot usage and discovering agents in your organization.

- **Script:** `Get-CopilotAgentUsage.ps1`
- **Features:** Copilot usage reporting, agent inventory, owner information, and agent usage metrics.
- **Requirements:** PowerShell 7.2 or later and the required Microsoft Graph permissions.
- **Documentation:** [Copilot and Agents Usage](./Copilot-and-Agents-Usage/README.md)

### SharePoint Site and Tenant Storage

Tools for finding what is filling a SharePoint site, measuring version history storage and trimming old versions.

- **Scripts:** `Get-TopSitesByStorage.ps1`, `Start-VersionStorageReport.ps1`, `Measure-VersionStorageReport.ps1`, `Invoke-VersionTrim.ps1`
- **Features:** Top sites by storage, version storage report jobs, version history analysis per file, library and user, what-if estimates, version limits and trim jobs.
- **Requirements:** SharePoint Online Management Shell and the SharePoint Administrator role. `Measure-VersionStorageReport.ps1` needs no module.
- **Documentation:** [SharePoint Site and Tenant Storage](./SharePoint-Site-and-Tenant-Storage/README.md)

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
