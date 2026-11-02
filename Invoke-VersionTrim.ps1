<#
.SYNOPSIS
    Sets version history limits on a site or library and queues a job that trims the versions already there.

.DESCRIPTION
    WARNING: versions deleted by a trim job are deleted permanently. They do NOT go to the recycle bin.
    Run Start-VersionStorageReport.ps1 and Measure-VersionStorageReport.ps1 first, and agree the limit
    with the site owner. Files under a retention policy or label keep their versions whatever you set.

    Changing a limit only affects versions created from now on. The trim job is what removes the
    versions that already exist. This script does both, in that order.

    Nothing is changed unless you confirm. Use -WhatIf to see what would run.

    Module : SharePoint Online Management Shell (Microsoft.Online.SharePoint.PowerShell)
    Role   : SharePoint Administrator
    Docs   : https://learn.microsoft.com/sharepoint/tutorial-queue-a-trim-job

.EXAMPLE
    # Automatic limits for every library in the site, then trim existing versions the same way
    .\Invoke-VersionTrim.ps1 -AdminUrl https://contoso-admin.sharepoint.com -SiteUrl https://contoso.sharepoint.com/sites/Projects -Mode Automatic

.EXAMPLE
    # Keep the newest 100 major versions in one library
    .\Invoke-VersionTrim.ps1 -AdminUrl https://contoso-admin.sharepoint.com -SiteUrl https://contoso.sharepoint.com/sites/Projects -Library "Documents" -Mode MajorVersionLimit -MajorVersionLimit 100

.EXAMPLE
    # Delete versions older than 365 days, trim only (limits unchanged), preview first
    .\Invoke-VersionTrim.ps1 -AdminUrl https://contoso-admin.sharepoint.com -SiteUrl https://contoso.sharepoint.com/sites/Projects -Mode DeleteBeforeDays -DeleteBeforeDays 365 -TrimOnly -WhatIf

.EXAMPLE
    # Check progress of a trim job, or stop it (stopping doesn't bring back versions already deleted)
    .\Invoke-VersionTrim.ps1 -AdminUrl https://contoso-admin.sharepoint.com -SiteUrl https://contoso.sharepoint.com/sites/Projects -Status
    .\Invoke-VersionTrim.ps1 -AdminUrl https://contoso-admin.sharepoint.com -SiteUrl https://contoso.sharepoint.com/sites/Projects -Stop
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'Trim')]
param(
    [Parameter(Mandatory = $true)]
    [string]$AdminUrl,

    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,

    # Library title. Leave empty for every library in the site.
    [string]$Library,

    [Parameter(ParameterSetName = 'Trim', Mandatory = $true)]
    [ValidateSet('Automatic', 'MajorVersionLimit', 'DeleteBeforeDays')]
    [string]$Mode,

    [Parameter(ParameterSetName = 'Trim')]
    [ValidateRange(1, 50000)]
    [int]$MajorVersionLimit = 100,

    # Minor (draft) versions to keep for each kept major version
    [Parameter(ParameterSetName = 'Trim')]
    [ValidateRange(0, 50000)]
    [int]$MajorWithMinorVersionsLimit = 0,

    [Parameter(ParameterSetName = 'Trim')]
    [ValidateRange(1, 36500)]
    [int]$DeleteBeforeDays = 365,

    # Queue the trim job but leave the version limits as they are
    [Parameter(ParameterSetName = 'Trim')]
    [switch]$TrimOnly,

    [Parameter(ParameterSetName = 'Status', Mandatory = $true)]
    [switch]$Status,

    [Parameter(ParameterSetName = 'Stop', Mandatory = $true)]
    [switch]$Stop
)

Connect-SPOService -Url $AdminUrl
$Target = if ($Library) { "library '$Library' in $SiteUrl" } else { "all libraries in $SiteUrl" }

if ($Status) {
    if ($Library) { Get-SPOListFileVersionBatchDeleteJobProgress -Site $SiteUrl -List $Library }
    else          { Get-SPOSiteFileVersionBatchDeleteJobProgress -Identity $SiteUrl }
    return
}

if ($Stop) {
    if ($PSCmdlet.ShouldProcess($Target, "Stop the version trim job")) {
        if ($Library) { Remove-SPOListFileVersionBatchDeleteJob -Site $SiteUrl -List $Library -Confirm:$false }
        else          { Remove-SPOSiteFileVersionBatchDeleteJob -Identity $SiteUrl -Confirm:$false }
    }
    return
}

# 1. Version history limits for new versions
if (-not $TrimOnly) {
    $Limit = @{ EnableAutoExpirationVersionTrim = $true }
    if ($Mode -ne 'Automatic') {
        $Limit = @{
            EnableAutoExpirationVersionTrim = $false
            MajorVersionLimit               = $MajorVersionLimit
            # 0 means versions never expire by age
            ExpireVersionsAfterDays         = $(if ($Mode -eq 'DeleteBeforeDays') { $DeleteBeforeDays } else { 0 })
        }
    }
    if ($PSCmdlet.ShouldProcess($Target, "Set version history limits ($Mode)")) {
        if ($Library) {
            Set-SPOListVersionPolicy -Site $SiteUrl -List $Library @Limit
        }
        else {
            # Applies to existing and new libraries; runs as a background job
            Set-SPOSite -Identity $SiteUrl @Limit
            Get-SPOSiteVersionPolicyJobProgress -Identity $SiteUrl
        }
    }
}

# 2. Trim the versions that already exist (permanent)
$Trim = switch ($Mode) {
    'Automatic'         { @{ Automatic = $true } }
    'MajorVersionLimit' { @{ MajorVersionLimit = $MajorVersionLimit; MajorWithMinorVersionsLimit = $MajorWithMinorVersionsLimit } }
    'DeleteBeforeDays'  { @{ DeleteBeforeDays = $DeleteBeforeDays } }
}

if ($PSCmdlet.ShouldProcess($Target, "PERMANENTLY delete existing versions ($Mode). Deleted versions can't be recovered")) {
    # You already confirmed above, so the cmdlet's own prompt is skipped
    if ($Library) {
        New-SPOListFileVersionBatchDeleteJob -Site $SiteUrl -List $Library @Trim -Confirm:$false
    }
    else {
        New-SPOSiteFileVersionBatchDeleteJob -Identity $SiteUrl @Trim -Confirm:$false
    }
    Write-Host "Trim job queued. It runs in batches over the next days. Check it with: -Status"
}
