<#
.SYNOPSIS
    Exports Microsoft 365 Copilot usage per user, and every agent in the tenant with its owner and usage.

.DESCRIPTION
    Read-only. Needs PowerShell 7 and the Microsoft.Graph.Authentication module (Microsoft Graph PowerShell).
    Runs on Windows, macOS and Linux. Writes two CSV files:

      CopilotUserUsage-<date>.csv   One row per Copilot-licensed user (Copilot usage report).
      CopilotAgents-<date>.csv      One row per agent in the organisation catalog, with owner and 30-day usage.

    Permissions (delegated, admin consent needed once):
      Reports.Read.All, CopilotPackages.Read.All, AgentIdentity.Read.All, User.ReadBasic.All
    Role for the person signing in: AI Administrator or Global Administrator.
    The agent list needs a Microsoft Agent 365 licence in the tenant. Without it, that part is skipped with a warning.

.PARAMETER Days
    Period for the user usage report: 7, 28, 90 or 180. Default 28.

.PARAMETER OutputFolder
    Folder for the CSV files. Default is the current folder.

.EXAMPLE
    ./Get-CopilotAgentUsage.ps1
.EXAMPLE
    ./Get-CopilotAgentUsage.ps1 -Days 90 -OutputFolder ~/Reports

.NOTES
    Author      : Adnan Amin
    Blog        : https://mstechtalk.com
    GitHub      : https://github.com/adnanamin/mstechtalk-powershell-scripts
    Description : Published as part of the MSTechTalk PowerShell scripts collection.
    Disclaimer  : Provided as-is. Review the code and test in a suitable
                  environment before using it in production.
#>
#Requires -Version 7.2
#Requires -Modules Microsoft.Graph.Authentication
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interactive admin script: console progress only')]
[CmdletBinding()]
param(
    [ValidateSet(7, 28, 90, 180)]
    [int]$Days = 28,

    [string]$OutputFolder = (Get-Location).Path
)

$ErrorActionPreference = 'Stop'
$graph  = 'https://graph.microsoft.com'
$scopes = 'Reports.Read.All', 'CopilotPackages.Read.All', 'AgentIdentity.Read.All', 'User.ReadBasic.All'
$stamp  = Get-Date -Format 'yyyy-MM-dd'

# Returns every item from a Graph call, following @odata.nextLink (the usage report pages at 200 rows)
function Get-GraphItem([string]$Uri) {
    while ($Uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject
        if ($page.PSObject.Properties['value']) { $page.value } else { $page }
        $Uri = $page.'@odata.nextLink'
    }
}

# Arrays become "a; b", nested objects become compact JSON, so every value fits in one CSV cell
function Format-Cell($Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [string] -or $Value -is [ValueType]) { return $Value }
    if ($Value -is [System.Collections.IEnumerable] -and -not @($Value | Where-Object { $_ -isnot [string] -and $_ -isnot [ValueType] }).Count) {
        return ($Value -join '; ')
    }
    $Value | ConvertTo-Json -Depth 5 -Compress
}

# Report rows hold a per-period array; lift its fields (prompt counts, active days in report v2) into columns
function ConvertTo-FlatRow($Row) {
    $flat = [ordered]@{}
    foreach ($p in $Row.PSObject.Properties) {
        if ($p.Value -is [array] -and ($p.Value.Count -eq 0 -or $p.Value[0] -is [pscustomobject])) {
            $first = @($p.Value) | Select-Object -First 1
            foreach ($q in $(if ($first) { $first.PSObject.Properties })) {
                if (-not $flat.Contains($q.Name)) { $flat[$q.Name] = Format-Cell $q.Value }
            }
        }
        elseif ($p.Name -notlike '@odata*') { $flat[$p.Name] = Format-Cell $p.Value }
    }
    [pscustomobject]$flat
}

$userCache = @{}
function Get-UserInfo([string]$Id) {
    if (-not $Id -or $Id -eq [guid]::Empty.ToString()) { return $null }
    if (-not $userCache.ContainsKey($Id)) {
        try { $userCache[$Id] = Invoke-MgGraphRequest -Method GET -OutputType PSObject -Uri "$graph/v1.0/users/$Id" }
        catch {
            $why = if ($_.Exception.Message -match 'NotFound') { 'Deleted or unknown user' } else { 'Owner lookup failed' }
            $userCache[$Id] = [pscustomobject]@{ displayName = "$why ($Id)"; mail = $null; userPrincipalName = $null }
        }
    }
    $userCache[$Id]
}

function Get-AgentOwner($Agent) {
    # 1. ownerId on the package. The beta API returns it but the Learn property table doesn't list it yet.
    $user = Get-UserInfo $Agent.ownerId
    if ($user) {
        return [pscustomobject]@{ Name = $user.displayName; Email = $user.mail ?? $user.userPrincipalName; Source = 'Agent package' }
    }
    # 2. Owners of the agent's Microsoft Entra Agent ID, when it has one
    if ($Agent.agentIdentityId) {
        try {
            $owners = @(Get-GraphItem "$graph/beta/servicePrincipals/$($Agent.agentIdentityId)/microsoft.graph.agentIdentity/owners")
            if ($owners.Count) {
                return [pscustomobject]@{
                    Name   = ($owners.displayName -join '; ')
                    Email  = (($owners | ForEach-Object { $_.mail ?? $_.userPrincipalName }) -join '; ')
                    Source = 'Entra Agent ID'
                }
            }
        }
        catch { Write-Verbose "Owner lookup failed for $($Agent.displayName): $($_.Exception.Message)" }
    }
    [pscustomobject]@{ Name = $null; Email = $null; Source = 'No owner found' }
}

# ---- Sign in (reuses an existing Connect-MgGraph session if it already has the scopes) ----
$ctx = Get-MgContext
if (-not $ctx -or ($ctx.AuthType -ne 'AppOnly' -and ($scopes | Where-Object { $ctx.Scopes -notcontains $_ }))) {
    Connect-MgGraph -Scopes $scopes -NoWelcome
}
if (-not (Test-Path $OutputFolder)) { New-Item -ItemType Directory -Path $OutputFolder | Out-Null }

# ---- 1. Copilot usage per user ----
Write-Host "Reading Copilot usage for the last $Days days..."
$usage = @()
try {
    try {
        $usage = @(Get-GraphItem "$graph/v1.0/copilot/reports/getMicrosoft365CopilotUsageUserDetail(period='D$Days',version='v2')")
    }
    catch {
        # Report v1 has no 28-day period, so 28 becomes 30
        Write-Warning "Usage report v2 not available, using v1. ($($_.Exception.Message))"
        $v1Days = if ($Days -eq 28) { 30 } else { $Days }
        $usage = @(Get-GraphItem "$graph/v1.0/copilot/reports/getMicrosoft365CopilotUsageUserDetail(period='D$v1Days')")
    }
    $usageRows = @($usage | ForEach-Object { ConvertTo-FlatRow $_ })
    $columns   = $usageRows | ForEach-Object { $_.PSObject.Properties.Name } | Select-Object -Unique
    $usageFile = Join-Path $OutputFolder "CopilotUserUsage-$stamp.csv"
    $usageRows | Select-Object $columns | Export-Csv $usageFile -NoTypeInformation -Encoding utf8BOM
    Write-Host "  $($usageRows.Count) users written to $usageFile"

    if ($usage.Count -and -not ($usage | Where-Object { $_.userPrincipalName -like '*@*' })) {
        Write-Warning 'User names are hidden (report privacy setting is on). A Global Administrator can show them: Settings > Org settings > Services > Reports (clear "Conceal user, group, and site names in all reports"; older UI: tick "Display concealed ...").'
    }
}
catch { Write-Warning "Copilot usage report failed: $($_.Exception.Message)" }

# ---- 2. Agents with owners and 30-day usage ----
Write-Host 'Reading agents from the organisation catalog...'
$agentRows = @()
try {
    $packages = @(Get-GraphItem "$graph/beta/copilot/admin/catalog/packages")
    # The catalog also holds ordinary apps and add-ins. Keep agents and bots.
    $agents = @($packages | Where-Object { "$($_.elementTypes) $($_.supportedHosts)" -match 'agent|bot|copilot' })
    $i = 0
    $agentRows = foreach ($p in $agents) {
        $i++
        Write-Progress -Activity 'Reading agents' -Status $p.displayName -PercentComplete ($i / $agents.Count * 100)
        # Details carry the usage numbers (activeUsers, totalSessions, lastUsedDateTime)
        $d = try { Invoke-MgGraphRequest -Method GET -OutputType PSObject -Uri "$graph/beta/copilot/admin/catalog/packages/$($p.id)" } catch { $p }
        $owner = Get-AgentOwner $d
        [pscustomobject]@{
            AgentName       = $d.displayName
            Type            = $d.type
            Platform        = $d.platform
            Publisher       = $d.publisher
            OwnerName       = $owner.Name
            OwnerEmail      = $owner.Email
            OwnerSource     = $owner.Source
            ActiveUsers30d  = $d.activeUsers
            Sessions30d     = $d.totalSessions
            RunTimeHours30d = $d.totalRunTimeInHours
            ExceptionRate   = $d.exceptionRate
            LastUsed        = $d.lastUsedDateTime
            IsBlocked       = $d.isBlocked
            AvailableTo     = $d.availableTo
            DeployedTo      = $d.deployedTo
            SharedWithCount = @($d.sharedWithUsersAndGroups).Where({ $_ }).Count
            AgentKind       = $d.governanceMetadata
            ElementTypes    = Format-Cell $d.elementTypes
            SupportedHosts  = Format-Cell $d.supportedHosts
            Sensitivity     = $d.sensitivity
            Created         = $d.createdDateTime
            LastModified    = $d.lastModifiedDateTime
            Version         = $d.version
            Description     = $d.shortDescription
            AgentId         = $d.id
            AgentIdentityId = $d.agentIdentityId
            AppId           = $d.appId
        }
    }
    Write-Progress -Activity 'Reading agents' -Completed
    $agentRows = @($agentRows)
    $agentFile = Join-Path $OutputFolder "CopilotAgents-$stamp.csv"
    $agentRows | Export-Csv $agentFile -NoTypeInformation -Encoding utf8BOM
    Write-Host "  $($agentRows.Count) agents written to $agentFile"
}
catch {
    Write-Warning "Agent list failed: $($_.Exception.Message)"
    Write-Warning 'This part needs a Microsoft Agent 365 licence, CopilotPackages.Read.All and the AI Administrator or Global Administrator role.'
}

# ---- Summary ----
Write-Host ''
Write-Host "Copilot users in report : $($usage.Count)"
$active = @($usage | Where-Object { $_.lastActivityDate -and [datetime]$_.lastActivityDate -gt ([datetime]$_.reportRefreshDate).AddDays(-$Days) })
Write-Host "Active in last $Days days : $($active.Count)"
Write-Host "Agents                  : $($agentRows.Count)"
Write-Host "Agents with no owner    : $(@($agentRows | Where-Object { -not $_.OwnerName }).Count)"
Write-Host "Agents unused (30 days) : $(@($agentRows | Where-Object { -not $_.ActiveUsers30d }).Count)"
Write-Host "Blocked agents          : $(@($agentRows | Where-Object { $_.IsBlocked }).Count)"
