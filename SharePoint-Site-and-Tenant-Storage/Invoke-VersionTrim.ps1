#Requires -Version 5.1

<#
.SYNOPSIS
    Plans and, with -Apply, sets version history limits on a site or library and queues a job that trims the
    versions already there.

.DESCRIPTION
    WARNING: versions deleted by a trim job are deleted permanently. They do NOT go to the recycle bin.
    Run Start-MttVersionStorageReport and Measure-MttVersionStorage first, and agree the limit with the site
    owner. Files under a retention policy or label keep their versions whatever you set.

    Changing a limit only affects versions created from now on. The trim job is what removes the versions that
    already exist. This script does both, in that order.

    Without -Apply the script changes nothing. It reads the current limits, writes a plan CSV (current and new
    limits, and the trim job it would queue) and shows it. Keep that CSV: it is your record of the old limits if
    you need to set them back. Add -ReportPath with a finished version storage report and the plan also shows
    an estimate of what the trim would free (needs Measure-MttVersionStorage.ps1 in the same folder).

    With -Apply it writes the same plan, then asks you to confirm each step: the limits, then the trim. Use
    -WhatIf with -Apply to see the steps without running them.

    In PowerShell 7 the script loads the SharePoint Online Management Shell with -UseWindowsPowerShell itself.
    It signs in with Connect-SPOService unless you are already connected.

    Module : SharePoint Online Management Shell (Microsoft.Online.SharePoint.PowerShell)
    Role   : SharePoint Administrator
    Docs   : https://learn.microsoft.com/sharepoint/tutorial-queue-a-trim-job

.PARAMETER AdminUrl
    SharePoint admin center URL, for example https://contoso-admin.sharepoint.com.
.PARAMETER SiteUrl
    Site or OneDrive URL.
.PARAMETER Library
    Title of one library. Leave it out for every library in the site.
.PARAMETER Mode
    Automatic, MajorVersionLimit or DeleteBeforeDays. See the folder README for what each sets and trims.
.PARAMETER MajorVersionLimit
    Major versions to keep. Defaults to 100.
.PARAMETER MajorWithMinorVersionsLimit
    Minor (draft) versions to keep for each kept major version, for the trim job. Defaults to 0.
.PARAMETER DeleteBeforeDays
    Delete versions older than this many days. Defaults to 365.
.PARAMETER TrimOnly
    Queue the trim job but leave the limits as they are.
.PARAMETER ReportPath
    Optional: a finished version storage report CSV. Adds an estimate of what the trim would free to the plan.
.PARAMETER PlanPath
    Where to write the plan CSV. Defaults to VersionTrimPlan-<yyyyMMdd-HHmm>.csv in the current folder.
.PARAMETER Apply
    Make the changes. Without it the script only writes the plan.
.PARAMETER Status
    Show the progress of the trim job.
.PARAMETER Stop
    Stop the trim job. Versions already deleted stay deleted.

.EXAMPLE
    # Plan only: nothing changes
    .\Invoke-VersionTrim.ps1 -AdminUrl https://contoso-admin.sharepoint.com -SiteUrl https://contoso.sharepoint.com/sites/Projects -Mode MajorVersionLimit -MajorVersionLimit 100 -ReportPath C:\Temp\VersionReport.csv

.EXAMPLE
    # Test on one library first: see the steps, then run them
    .\Invoke-VersionTrim.ps1 -AdminUrl https://contoso-admin.sharepoint.com -SiteUrl https://contoso.sharepoint.com/sites/Projects -Library "Documents" -Mode MajorVersionLimit -Apply -WhatIf
    .\Invoke-VersionTrim.ps1 -AdminUrl https://contoso-admin.sharepoint.com -SiteUrl https://contoso.sharepoint.com/sites/Projects -Library "Documents" -Mode MajorVersionLimit -Apply

.EXAMPLE
    # Automatic limits for every library in the site, then trim existing versions the same way
    .\Invoke-VersionTrim.ps1 -AdminUrl https://contoso-admin.sharepoint.com -SiteUrl https://contoso.sharepoint.com/sites/Projects -Mode Automatic -Apply

.EXAMPLE
    # Check progress of a trim job, or stop it (stopping doesn't bring back versions already deleted)
    .\Invoke-VersionTrim.ps1 -AdminUrl https://contoso-admin.sharepoint.com -SiteUrl https://contoso.sharepoint.com/sites/Projects -Status
    .\Invoke-VersionTrim.ps1 -AdminUrl https://contoso-admin.sharepoint.com -SiteUrl https://contoso.sharepoint.com/sites/Projects -Stop

.NOTES
    Author      : Adnan Amin
    Blog        : https://mstechtalk.com
    Blog post   : https://mstechtalk.com/how-to-find-what-is-filling-a-sharepoint-site-and-free-up-tenant-storage/
    GitHub      : https://github.com/adnanamin/mstechtalk-powershell-scripts
    Tested      : 16 November 2026 on the MST demo tenant (Windows PowerShell 5.1 and PowerShell 7.6.9): plan mode for a
                  site and a library with the report estimate, -Apply -WhatIf and -Status. No real trim was run.
    Disclaimer  : Provided as-is. Review the code and test in a suitable
                  environment before using it in production.
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'Trim')]
param(
    [Parameter(Mandatory = $true)]
    [string]$AdminUrl,

    [Parameter(Mandatory = $true)]
    [string]$SiteUrl,

    [string]$Library,

    [Parameter(ParameterSetName = 'Trim', Mandatory = $true)]
    [ValidateSet('Automatic', 'MajorVersionLimit', 'DeleteBeforeDays')]
    [string]$Mode,

    [Parameter(ParameterSetName = 'Trim')]
    [ValidateRange(1, 50000)]
    [int]$MajorVersionLimit = 100,

    [Parameter(ParameterSetName = 'Trim')]
    [ValidateRange(0, 50000)]
    [int]$MajorWithMinorVersionsLimit = 0,

    [Parameter(ParameterSetName = 'Trim')]
    [ValidateRange(1, 36500)]
    [int]$DeleteBeforeDays = 365,

    [Parameter(ParameterSetName = 'Trim')]
    [switch]$TrimOnly,

    [Parameter(ParameterSetName = 'Trim')]
    [string]$ReportPath,

    [Parameter(ParameterSetName = 'Trim')]
    [string]$PlanPath = (Join-Path (Get-Location) ("VersionTrimPlan-{0:yyyyMMdd-HHmm}.csv" -f (Get-Date))),

    [Parameter(ParameterSetName = 'Trim')]
    [switch]$Apply,

    [Parameter(ParameterSetName = 'Status', Mandatory = $true)]
    [switch]$Status,

    [Parameter(ParameterSetName = 'Stop', Mandatory = $true)]
    [switch]$Stop
)

$ErrorActionPreference = 'Stop'

# --- Sign in ---------------------------------------------------------------------------------------------------
if (-not (Get-Command Connect-SPOService -ErrorAction SilentlyContinue)) {
    if ($PSVersionTable.PSEdition -eq 'Core') {
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell -WarningAction SilentlyContinue
    }
    else {
        Import-Module Microsoft.Online.SharePoint.PowerShell
    }
}
try {
    $null = Get-SPOSite -Limit 1 -ErrorAction Stop -WarningAction SilentlyContinue
}
catch {
    Connect-SPOService -Url $AdminUrl
}

$SiteUrl = $SiteUrl.TrimEnd('/')
$Target = if ($Library) { "library '$Library' in $SiteUrl" } else { "all libraries in $SiteUrl" }

if ($Status) {
    if ($Library) { Get-SPOListFileVersionBatchDeleteJobProgress -Site $SiteUrl -List $Library }
    else          { Get-SPOSiteFileVersionBatchDeleteJobProgress -Identity $SiteUrl }
    return
}

if ($Stop) {
    if ($PSCmdlet.ShouldProcess($Target, 'Stop the version trim job')) {
        if ($Library) { Remove-SPOListFileVersionBatchDeleteJob -Site $SiteUrl -List $Library -Confirm:$false }
        else          { Remove-SPOSiteFileVersionBatchDeleteJob -Identity $SiteUrl -Confirm:$false }
    }
    return
}

# --- 1. Read the current limits ----------------------------------------------------------------------------------
function Get-Prop($Object, [string]$Name) {
    if ($Object -and $Object.PSObject.Properties[$Name]) { $Object.$Name } else { $null }
}

$currentSource = if ($Library) { Get-SPOListVersionPolicy -Site $SiteUrl -List $Library } else { Get-SPOSite -Identity $SiteUrl }
$current = [ordered]@{
    EnableAutoExpirationVersionTrim = Get-Prop $currentSource 'EnableAutoExpirationVersionTrim'
    MajorVersionLimit               = Get-Prop $currentSource 'MajorVersionLimit'
    MajorWithMinorVersionsLimit     = Get-Prop $currentSource 'MajorWithMinorVersionsLimit'
    ExpireVersionsAfterDays         = Get-Prop $currentSource 'ExpireVersionsAfterDays'
}

# --- 2. Build the plan ---------------------------------------------------------------------------------------
$newLimit = [ordered]@{ EnableAutoExpirationVersionTrim = $true }
if ($Mode -ne 'Automatic') {
    $newLimit = [ordered]@{
        EnableAutoExpirationVersionTrim = $false
        MajorVersionLimit               = $MajorVersionLimit
        # 0 means versions never expire by age
        ExpireVersionsAfterDays         = $(if ($Mode -eq 'DeleteBeforeDays') { $DeleteBeforeDays } else { 0 })
    }
}
$trim = switch ($Mode) {
    'Automatic'         { [ordered]@{ Automatic = $true } }
    'MajorVersionLimit' { [ordered]@{ MajorVersionLimit = $MajorVersionLimit; MajorWithMinorVersionsLimit = $MajorWithMinorVersionsLimit } }
    'DeleteBeforeDays'  { [ordered]@{ DeleteBeforeDays = $DeleteBeforeDays } }
}
$asText = { param($h) ($h.GetEnumerator() | Where-Object { $null -ne $_.Value -and '' -ne "$($_.Value)" } | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value }) -join '; ' }
$currentText = & $asText $current
if (-not $currentText) { $currentText = 'Not set on the site: the organization limits apply' }
$undo = if ($Library) {
    'To undo, run Set-SPOListVersionPolicy with the Current values'
}
elseif ($currentText -like 'Not set*') {
    'To undo for new libraries: Set-SPOSite -InheritVersionPolicyFromTenant. Existing libraries keep the new limits until you set them per library'
}
else {
    'To undo, run Set-SPOSite with the Current values'
}

$estimate = 'Not estimated (add -ReportPath with a finished version storage report)'
if ($ReportPath) {
    $measure = Join-Path $PSScriptRoot 'Measure-MttVersionStorage.ps1'
    if ($Mode -eq 'Automatic') {
        $estimate = 'Not estimated: automatic trimming uses Microsoft''s own rules'
    }
    elseif (-not (Test-Path $measure)) {
        $estimate = 'Not estimated: Measure-MttVersionStorage.ps1 not found next to this script'
    }
    else {
        . $measure
        $sum = Measure-MttVersionStorage -ReportPath $ReportPath -Summary -KeepVersions $MajorVersionLimit -OlderThanDays $DeleteBeforeDays
        $frees = if ($Mode -eq 'MajorVersionLimit') { $sum.KeepFreesGB } else { $sum.OlderThanFreesGB }
        $estimate = 'About {0} GB of {1} GB version history, from the report (the trim job uses SharePoint''s own rules)' -f $frees, $sum.VersionHistoryGB
    }
}

$plan = @(
    [pscustomobject]@{
        Step    = 1
        Action  = 'Set version history limits for new versions'
        Target  = $Target
        Current = $currentText
        New     = $(if ($TrimOnly) { 'Unchanged (-TrimOnly)' } else { & $asText $newLimit })
        Note    = $undo
    }
    [pscustomobject]@{
        Step    = 2
        Action  = "Queue a trim job on existing versions ($Mode)"
        Target  = $Target
        Current = ''
        New     = & $asText $trim
        Note    = "PERMANENT. Estimate: $estimate"
    }
)
$plan | Export-Csv -Path $PlanPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false
$plan | Format-List | Out-String | Write-Host
Write-Host "Plan saved to $PlanPath"

if (-not $Apply) {
    Write-Host 'Nothing was changed. Review the plan, then run again with -Apply.'
    return
}

# --- 3. Apply ------------------------------------------------------------------------------------------------
if (-not $TrimOnly) {
    if ($PSCmdlet.ShouldProcess($Target, "Set version history limits ($Mode)")) {
        $limit = @{}
        foreach ($key in $newLimit.Keys) { $limit[$key] = $newLimit[$key] }
        if ($Library) {
            Set-SPOListVersionPolicy -Site $SiteUrl -List $Library @limit
        }
        else {
            # Applies to existing and new libraries; runs as a background job
            Set-SPOSite -Identity $SiteUrl @limit -Confirm:$false
            Get-SPOSiteVersionPolicyJobProgress -Identity $SiteUrl
        }
    }
}

if ($PSCmdlet.ShouldProcess($Target, "PERMANENTLY delete existing versions ($Mode). Deleted versions can't be recovered")) {
    $trimArgs = @{}
    foreach ($key in $trim.Keys) { $trimArgs[$key] = $trim[$key] }
    # You already confirmed above, so the cmdlet's own prompt is skipped
    if ($Library) {
        New-SPOListFileVersionBatchDeleteJob -Site $SiteUrl -List $Library @trimArgs -Confirm:$false
    }
    else {
        New-SPOSiteFileVersionBatchDeleteJob -Identity $SiteUrl @trimArgs -Confirm:$false
    }
    Write-Host 'Trim job queued. It runs in batches over the next days. Check it with -Status.'
}
