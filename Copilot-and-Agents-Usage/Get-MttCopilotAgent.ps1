#Requires -Version 7.4
#Requires -Modules Microsoft.Graph.Authentication

function Get-MttCopilotAgent {
    <#
    .SYNOPSIS
        Lists the agents in the Microsoft 365 organisation catalog, with their owner and 30-day usage.
    .DESCRIPTION
        Reads the agents from the Copilot admin catalog (Microsoft Graph beta) and returns one row per agent: type,
        platform, publisher, owner, 30-day active users, sessions and run time, last use, whether it is blocked,
        and who it is available and deployed to. The catalog also holds ordinary apps and add-ins; only packages
        whose element types or hosts mention agents, bots or Copilot are returned.

        The owner comes from the agent package; when that is empty, from the owners of the agent's Microsoft Entra
        Agent ID. OwnerSource says which one was used.

        The agent catalog needs a Microsoft Agent 365 licence in the tenant. The API is in beta, so properties can
        change.

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-MgGraph first,
        and pipe the result to Export-Csv.
    .EXAMPLE
        Get-MttCopilotAgent | Export-Csv .\CopilotAgents.csv -NoTypeInformation -Encoding UTF8

        Saves every agent with its owner and usage as a CSV file.
    .EXAMPLE
        Get-MttCopilotAgent | Where-Object { -not $_.OwnerName -or -not $_.ActiveUsers30d } | Select-Object AgentName, OwnerName, ActiveUsers30d, LastUsed

        Agents with no owner, or not used in the last 30 days.
    .OUTPUTS
        MSTechTalk.CopilotAgent

        AgentName, Type, Platform, Publisher, OwnerName, OwnerEmail, OwnerSource, ActiveUsers30d, Sessions30d,
        RunTimeHours30d, ExceptionRate, LastUsed, IsBlocked, AvailableTo, DeployedTo, SharedWithCount, AgentKind,
        ElementTypes, SupportedHosts, Sensitivity, Created, LastModified, Version, Description, AgentId,
        AgentIdentityId, AppId
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Graph.Authentication 2.x
        Requires:    Graph (Connect-MgGraph -Scopes CopilotPackages.Read.All, AgentIdentity.Read.All, User.ReadBasic.All)
        Permissions: Delegated CopilotPackages.Read.All, AgentIdentity.Read.All and User.ReadBasic.All, with the AI
                     Administrator or Global Administrator role; a Microsoft Agent 365 licence in the tenant
        Level:       Tenant
        Tested:      16 November 2026, partly: the sign-in check, and the clear stop on a tenant without an Agent
                     365 licence (the MST demo tenant has none). Reading agents from the catalog is not yet tested.
    .LINK
        https://mstechtalk.com/how-to-monitor-microsoft-365-copilot-and-agents-usage-in-your-organization/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.CopilotAgent')]
    param()

    begin {
        $scopes = 'CopilotPackages.Read.All', 'AgentIdentity.Read.All', 'User.ReadBasic.All'
        $connectHint = "Connect-MgGraph -Scopes $($scopes -join ', ')"
        $context = Get-MgContext
        if (-not $context) {
            throw "Get-MttCopilotAgent needs a Microsoft Graph connection. Run: $connectHint"
        }
        $missing = @($scopes | Where-Object { $context.Scopes -notcontains $_ })
        if ($context.AuthType -eq 'Delegated' -and $missing.Count) {
            Write-Warning "The Graph connection doesn't have $($missing -join ', '), so agents or owners may be missing. Run: $connectHint"
        }

        $graph = 'https://graph.microsoft.com'
        $userCache = @{}

        function Get-MttGraphPage([string]$Uri) {
            while ($Uri) {
                $page = Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputType PSObject -ErrorAction Stop -Verbose:$false
                if ($page.PSObject.Properties['value']) { $page.value } else { $page }
                $Uri = $page.'@odata.nextLink'
            }
        }

        function Format-MttCell($Value) {
            if ($null -eq $Value) { return $null }
            if ($Value -is [string] -or $Value -is [ValueType]) { return $Value }
            if ($Value -is [Collections.IEnumerable] -and -not @($Value | Where-Object { $_ -isnot [string] -and $_ -isnot [ValueType] }).Count) {
                return ($Value -join '; ')
            }
            $Value | ConvertTo-Json -Depth 5 -Compress
        }

        function Get-MttUserInfo([string]$Id) {
            if (-not $Id -or $Id -eq [guid]::Empty.ToString()) { return $null }
            if (-not $userCache.ContainsKey($Id)) {
                try {
                    $userCache[$Id] = Invoke-MgGraphRequest -Method GET -OutputType PSObject -Uri "$graph/v1.0/users/$Id" -ErrorAction Stop -Verbose:$false
                }
                catch {
                    $why = if ($_.Exception.Message -match 'NotFound') { 'Deleted or unknown user' } else { 'Owner lookup failed' }
                    $userCache[$Id] = [PSCustomObject]@{ displayName = "$why ($Id)"; mail = $null; userPrincipalName = $null }
                }
            }
            $userCache[$Id]
        }

        function Get-MttAgentOwner($Agent) {
            # 1. ownerId on the package (returned by the beta API, not yet in the Learn property table)
            $user = Get-MttUserInfo $Agent.ownerId
            if ($user) {
                return [PSCustomObject]@{ Name = $user.displayName; Email = $user.mail ?? $user.userPrincipalName; Source = 'Agent package' }
            }
            # 2. Owners of the agent's Microsoft Entra Agent ID, when it has one
            if ($Agent.agentIdentityId) {
                try {
                    $owners = @(Get-MttGraphPage "$graph/beta/servicePrincipals/$($Agent.agentIdentityId)/microsoft.graph.agentIdentity/owners")
                    if ($owners.Count) {
                        return [PSCustomObject]@{
                            Name   = ($owners.displayName -join '; ')
                            Email  = (($owners | ForEach-Object { $_.mail ?? $_.userPrincipalName }) -join '; ')
                            Source = 'Entra Agent ID'
                        }
                    }
                }
                catch { Write-Verbose "Owner lookup failed for $($Agent.displayName): $($_.Exception.Message)" }
            }
            [PSCustomObject]@{ Name = $null; Email = $null; Source = 'No owner found' }
        }

        function ConvertTo-MttDate($Value) {
            if ($null -eq $Value -or "$Value" -eq '') { return $null }
            if ($Value -is [datetime]) { return $Value }
            if ($Value -is [DateTimeOffset]) { return $Value.UtcDateTime }
            $parsed = [datetime]::MinValue
            if ([datetime]::TryParse("$Value", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind, [ref]$parsed)) { return $parsed }
            $Value
        }
    }

    end {
        try {
            $packages = @(Get-MttGraphPage "$graph/beta/copilot/admin/catalog/packages")
        }
        catch {
            throw "Get-MttCopilotAgent couldn't read the agent catalog: $($_.Exception.Message) It needs a Microsoft Agent 365 licence, CopilotPackages.Read.All and the AI Administrator or Global Administrator role."
        }

        # The catalog also holds ordinary apps and add-ins. Keep agents and bots.
        $agents = @($packages | Where-Object { "$($_.elementTypes) $($_.supportedHosts)" -match 'agent|bot|copilot' })
        Write-Verbose "Catalog: $($packages.Count) packages, $($agents.Count) agents"

        $number = 0
        foreach ($package in $agents) {
            $number++
            Write-Progress -Activity 'Reading agents' -Status $package.displayName -PercentComplete ($number / $agents.Count * 100)

            # The package details carry the usage numbers (activeUsers, totalSessions, lastUsedDateTime)
            try {
                $detail = Invoke-MgGraphRequest -Method GET -OutputType PSObject -Uri "$graph/beta/copilot/admin/catalog/packages/$($package.id)" -ErrorAction Stop -Verbose:$false
            }
            catch {
                Write-Warning "No details for $($package.displayName), so usage is empty: $($_.Exception.Message)"
                $detail = $package
            }
            $owner = Get-MttAgentOwner $detail

            [PSCustomObject]@{
                PSTypeName      = 'MSTechTalk.CopilotAgent'
                AgentName       = $detail.displayName
                Type            = $detail.type
                Platform        = $detail.platform
                Publisher       = $detail.publisher
                OwnerName       = $owner.Name
                OwnerEmail      = $owner.Email
                OwnerSource     = $owner.Source
                ActiveUsers30d  = $detail.activeUsers
                Sessions30d     = $detail.totalSessions
                RunTimeHours30d = $detail.totalRunTimeInHours
                ExceptionRate   = $detail.exceptionRate
                LastUsed        = ConvertTo-MttDate $detail.lastUsedDateTime
                IsBlocked       = $detail.isBlocked
                AvailableTo     = $detail.availableTo
                DeployedTo      = $detail.deployedTo
                SharedWithCount = @($detail.sharedWithUsersAndGroups).Where({ $_ }).Count
                AgentKind       = $detail.governanceMetadata
                ElementTypes    = Format-MttCell $detail.elementTypes
                SupportedHosts  = Format-MttCell $detail.supportedHosts
                Sensitivity     = $detail.sensitivity
                Created         = ConvertTo-MttDate $detail.createdDateTime
                LastModified    = ConvertTo-MttDate $detail.lastModifiedDateTime
                Version         = $detail.version
                Description     = $detail.shortDescription
                AgentId         = $detail.id
                AgentIdentityId = $detail.agentIdentityId
                AppId           = $detail.appId
            }
        }
        Write-Progress -Activity 'Reading agents' -Completed
    }
}
