<#
.SYNOPSIS
    Runs Microsoft's Restricted Content Discovery (RCD) insights report and downloads the CSV.

.DESCRIPTION
    Needs the SharePoint Online Management Shell (Microsoft.Online.SharePoint.PowerShell)
    and the SharePoint Administrator role. Windows PowerShell 5.1 is recommended.

    Queues the report with Start-SPORestrictedContentDiscoverabilityReport, checks the status
    with Get-SPORestrictedContentDiscoverabilityReport until it shows Completed, then downloads
    the CSV to the output folder. The start cmdlet asks you to confirm because the report takes
    time to build: answer Y.

    Microsoft allows one new report every 24 hours. If one was already generated in that
    window, the start cmdlet fails and this script downloads the latest existing report instead.

    The status goes NotStarted, InQueue, Completed. On a small demo tenant it took about two
    minutes; expect longer on a big tenant. The CSV has the columns SiteTitle, SiteUrl,
    SiteOwnerEmail, LastModified and TimeCreated.

.PARAMETER AdminUrl
    SharePoint admin center URL, for example https://contoso-admin.sharepoint.com

.PARAMETER OutputFolder
    Folder for the downloaded CSV. Default is the current folder.

.PARAMETER TimeoutMinutes
    How long to wait for the report before giving up. Default 30.

.EXAMPLE
    .\Get-RCDInsightsReport.ps1 -AdminUrl https://mstalk-admin.sharepoint.com
.EXAMPLE
    .\Get-RCDInsightsReport.ps1 -AdminUrl https://mstalk-admin.sharepoint.com -OutputFolder C:\Temp -TimeoutMinutes 60

.NOTES
    Author      : Adnan Amin
    Blog        : https://mstechtalk.com
    Article     : https://mstechtalk.com/find-sharepoint-sites-copilot-blocked/
    GitHub      : https://github.com/adnanamin/mstechtalk-powershell-scripts
    Permissions : SharePoint Administrator
    Tested      : 15 November 2026, Windows PowerShell 5.1, on a demo tenant.
                  The 24-hour fallback has not been run yet.
    Disclaimer  : Provided as-is. Review the code and test in a suitable
                  environment before using it in production.
#>
#Requires -Modules Microsoft.Online.SharePoint.PowerShell
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$AdminUrl,

    [string]$OutputFolder = (Get-Location).Path,

    [ValidateRange(1, 1440)]
    [int]$TimeoutMinutes = 30
)

$ErrorActionPreference = 'Stop'

Connect-SPOService -Url $AdminUrl

# Queue the report (asks for confirmation). Only one new report is allowed every 24 hours.
$Started = $null
try {
    $Started = Start-SPORestrictedContentDiscoverabilityReport
    $Started | Format-List
}
catch {
    if ($_.Exception.Message -match '24 hours') {
        Write-Warning 'A report was already generated in the last 24 hours. Downloading the latest existing report instead.'
    }
    else { throw }
}

# Poll every 30 seconds until the newest report shows Completed
$Deadline = (Get-Date).AddMinutes($TimeoutMinutes)
do {
    Start-Sleep -Seconds 30
    $Latest = @(Get-SPORestrictedContentDiscoverabilityReport) |
        Where-Object { -not $Started.Id -or $_.Id -eq $Started.Id } |
        Select-Object -First 1
    Write-Output "Status: $($Latest.Status)"
} until ($Latest.Status -eq 'Completed' -or (Get-Date) -gt $Deadline)

if ($Latest.Status -ne 'Completed') {
    Write-Warning "Report $($Latest.Id) is not completed after $TimeoutMinutes minutes. Run Get-SPORestrictedContentDiscoverabilityReport later and download it with -Action Download."
    return
}

# The download saves RestrictedContentDiscoverabilityReport_<number>.csv in the current folder
Push-Location $OutputFolder
try {
    Get-SPORestrictedContentDiscoverabilityReport -Action Download -ReportId $Latest.Id
}
finally {
    Pop-Location
}
