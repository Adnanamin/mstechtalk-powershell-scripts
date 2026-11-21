#Requires -Version 5.1

function Get-MttCopilotContainer {
    <#
    .SYNOPSIS
        Lists the SharePoint Embedded containers that hold Copilot Workspaces, Copilot Notebooks, Copilot Pages
        and Loop content.
    .DESCRIPTION
        Copilot Workspaces, Copilot Notebooks, Copilot Pages and Loop My workspace share one user-owned
        SharePoint Embedded container per user. In the SharePoint admin center, PowerShell and the audit log
        that container always shows the application name Loop, so this function reads every container of the
        Loop owning application with Get-SPOContainer, page by page, and returns one row per container.

        Use it to see who has a container, who owns it, how much storage it uses, and to find containers with
        no owner, for example after a user leaves.

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-SPOService
        first, and pipe the result to Export-Csv.

        In PowerShell 7, load the SharePoint Online Management Shell with
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell before you connect.
    .PARAMETER OwningApplicationId
        One or more SharePoint Embedded owning application IDs. Leave it out for Microsoft Loop
        (a187e399-0c36-4b98-8f04-1edc167a0996), the application Copilot Workspaces, Notebooks and Pages use.
    .EXAMPLE
        Get-MttCopilotContainer

        Every Loop container in the tenant.
    .EXAMPLE
        Get-MttCopilotContainer | Export-Csv .\CopilotContainers.csv -NoTypeInformation -Encoding UTF8

        Saves every container as a CSV file.
    .EXAMPLE
        Get-MttCopilotContainer | Where-Object OwnersCount -eq 0

        Containers with no owner, for example after a leaver.
    .EXAMPLE
        Get-MttCopilotContainer | Sort-Object StorageUsedGB -Descending | Select-Object -First 10

        The ten largest containers.
    .OUTPUTS
        MSTechTalk.CopilotContainer

        UserPrincipalName    Principal owner of the container (empty when it has none)
        ContainerId          SharePoint Embedded container ID
        ContainerName        Container name, for example Pages or My workspace, or a GUID
        OwnershipType        UserOwned, GroupOwned or TenantOwned
        OwnersCount          Number of owners
        StorageUsedGB        Storage used, in GB
        Status               Active, or another state such as Inactive
        SensitivityLabel     Container sensitivity label, if set
        CreatedOn            When the container was created
        OwningApplicationId  SharePoint Embedded application that owns the container
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Online.SharePoint.PowerShell (SharePoint Online Management Shell) 16.0.27814 or later
        Requires:    SPO (Get-SPOContainer has no PnP or Graph PowerShell equivalent that returns owners and storage)
        Permissions: SharePoint Embedded Administrator or Global Administrator
        Level:       Tenant
        Tested:      21 November 2026 on the MST demo tenant (Windows PowerShell 5.1, SPO module 16.0.27814.12015):
                     two Loop containers returned, paging ended on "End of containers view".
        No #Requires -Modules line: in PowerShell 7 that line would load the module without
        -UseWindowsPowerShell, so the function checks for it in begin instead.
    .LINK
        https://mstechtalk.com/copilot-workspaces-admin-storage-security/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.CopilotContainer')]
    param(
        [guid[]]$OwningApplicationId = @('a187e399-0c36-4b98-8f04-1edc167a0996')
    )

    begin {
        $connectHint = 'Connect-SPOService -Url https://<tenant>-admin.sharepoint.com'
        if (-not (Get-Command Get-SPOContainer -ErrorAction SilentlyContinue)) {
            throw "Get-MttCopilotContainer needs the SharePoint Online Management Shell 16.0.27814 or later. In PowerShell 7 run: Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell, then $connectHint"
        }
        # Get-SPOTenant would need SharePoint Administrator, so the connection is checked on the first call instead

        # StorageUsed comes back as text such as "0 GB" or "512 MB"
        $toGB = {
            param($value)
            if ($null -eq $value) { return $null }
            if ($value -is [ValueType]) { return [math]::Round([double]$value, 2) }
            if ("$value" -match '^\s*([\d\.,]+)\s*(B|KB|MB|GB|TB)?\s*$') {
                $number = [double]::Parse(($Matches[1] -replace ',', ''), [Globalization.CultureInfo]::InvariantCulture)
                $factor = switch ($Matches[2]) { 'B' { 1 / 1GB } 'KB' { 1 / 1MB } 'MB' { 1 / 1KB } 'TB' { 1024 } default { 1 } }
                return [math]::Round($number * $factor, 2)
            }
            return $null
        }
    }

    process {
        foreach ($appId in $OwningApplicationId) {
            Write-Verbose "Reading containers for owning application $appId"
            $pagingToken = $null
            $page = 0
            do {
                $page++
                Write-Progress -Activity 'Get-MttCopilotContainer' -Status "Application $appId, page $page"
                try {
                    if ($pagingToken) {
                        $result = Get-SPOContainer -OwningApplicationId $appId -Paged -PagingToken $pagingToken -ErrorAction Stop
                    }
                    else {
                        $result = Get-SPOContainer -OwningApplicationId $appId -Paged -ErrorAction Stop
                    }
                }
                catch {
                    if ($_.Exception.Message -match 'Connect-SPOService|no connection|not connected') {
                        throw "Get-MttCopilotContainer needs a SharePoint Online Management Shell connection. Run: $connectHint"
                    }
                    Write-Warning "Skipped application ${appId}: $($_.Exception.Message)"
                    break
                }

                $pagingToken = $null
                foreach ($item in $result) {
                    # -Paged ends with a text line: either a token for the next page or "End of containers view"
                    if ($item -is [string]) {
                        if ($item -match 'token:\s*(\S+)') { $pagingToken = $Matches[1].Trim() }
                        continue
                    }
                    if (-not $item.ContainerId) { continue }

                    $created = $item.CreatedOn
                    if ($created -and $created -isnot [datetime]) {
                        try { $created = [datetime]$created } catch { $created = $null }
                    }

                    [PSCustomObject]@{
                        PSTypeName          = 'MSTechTalk.CopilotContainer'
                        UserPrincipalName   = $item.PrincipalOwner
                        ContainerId         = $item.ContainerId
                        ContainerName       = $item.ContainerName
                        OwnershipType       = $item.OwnershipType
                        OwnersCount         = $item.OwnersCount
                        StorageUsedGB       = & $toGB $item.StorageUsed
                        Status              = $item.Status
                        SensitivityLabel    = $item.SensitivityLabel
                        CreatedOn           = $created
                        OwningApplicationId = $appId
                    }
                }
            } while ($pagingToken)
        }
        Write-Progress -Activity 'Get-MttCopilotContainer' -Completed
    }
}
