#Requires -Version 5.1

function Get-MttOneDriveUsage {
    <#
    .SYNOPSIS
        Lists OneDrive accounts with storage used, quota and how much is over the licensed storage.
    .DESCRIPTION
        Reads every OneDrive site in the tenant with Get-SPOSite in one call, or only the users you give it, and
        returns one row per account, highest percentage first, then largest.

        Two limits are shown, because they are different things:

        - StorageQuotaGB is the quota set on the account. An admin can raise it above the licence.
        - EntitlementGB is the storage the user's licence includes. With OneDrive pay-as-you-go storage,
          Microsoft bills the storage used above this, not above the quota. OverEntitlementGB shows that amount.

        The function can't read each user's licence, so EntitlementGB is the value you pass with -EntitlementGB
        (1024 GB, 1 TB, when you leave it out). Set it to what your plan includes.

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-SPOService first,
        and pipe the result to Export-Csv.

        In PowerShell 7, load the SharePoint Online Management Shell with
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell before you connect.
    .PARAMETER User
        One or more users, by user principal name. Accepts pipeline input. Leave it out to report on every
        OneDrive in the tenant.
    .PARAMETER MinPercentUsed
        Return only accounts using at least this percentage of their quota, for example 80.
    .PARAMETER EntitlementGB
        Storage included in the user's licence, in GB. Used for EntitlementGB and OverEntitlementGB.
        Leave it out for 1024 (1 TB).
    .EXAMPLE
        Get-MttOneDriveUsage -MinPercentUsed 80

        Accounts at 80 percent of their quota or more.
    .EXAMPLE
        Get-MttOneDriveUsage -User alex.miller@contoso.com

        One user's OneDrive.
    .EXAMPLE
        Get-MttOneDriveUsage | Export-Csv .\OneDriveUsage.csv -NoTypeInformation -Encoding UTF8

        Saves every OneDrive account as a CSV file.
    .EXAMPLE
        Get-MttOneDriveUsage | Where-Object OverEntitlementGB -gt 0

        Accounts using more than their licence includes: with pay-as-you-go storage, this is what is billed.
    .OUTPUTS
        MSTechTalk.OneDriveUsage

        UserPrincipalName    Owner of the OneDrive
        SiteUrl              OneDrive URL
        StorageUsedGB        Storage used, in GB
        StorageQuotaGB       Quota set on the account, in GB
        PercentUsed          Storage used as a percentage of the quota
        EntitlementGB        Licensed storage, from -EntitlementGB
        OverEntitlementGB    Storage used above EntitlementGB, or 0
        LastContentModified  Date of the last content change
        DaysSinceLastChange  Days since that change
        LockState            Unlock, ReadOnly or NoAccess (unlicensed accounts become read-only, then archived)
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Online.SharePoint.PowerShell (SharePoint Online Management Shell)
        Requires:    SPO (one Get-SPOSite call returns storage for every OneDrive; PnP needs a call per site)
        Permissions: SharePoint Administrator
        Level:       Tenant, User
        Tested:      20 November 2026 on the MST demo tenant (Windows PowerShell 5.1, and PowerShell 7.6.10 with
                     -UseWindowsPowerShell; SPO module 16.0.27814.12015): 13 OneDrive accounts, the same rows and
                     order in both; -User, pipeline input, -MinPercentUsed and the -EntitlementGB minimum checked.
                     No demo account is over 1 GB, so OverEntitlementGB was checked on sample data only.
        No #Requires -Modules line: in PowerShell 7 that line would load the module without
        -UseWindowsPowerShell, so the function checks for it in begin instead.
    .LINK
        https://mstechtalk.com/find-onedrive-accounts-near-their-storage-quota-with-powershell/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.OneDriveUsage')]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UserPrincipalName')]
        [string[]]$User,

        [ValidateRange(0, 100)]
        [double]$MinPercentUsed,

        [ValidateRange(1, 1000000)]
        [double]$EntitlementGB = 1024
    )

    begin {
        $connectHint = 'Connect-SPOService -Url https://<tenant>-admin.sharepoint.com'
        if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
            throw "Get-MttOneDriveUsage needs the SharePoint Online Management Shell. In PowerShell 7 run: Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell, then $connectHint"
        }
        try {
            $null = Get-SPOSite -Limit 1 -ErrorAction Stop -WarningAction SilentlyContinue -Verbose:$false
        }
        catch {
            throw "Get-MttOneDriveUsage needs a SharePoint Online Management Shell connection. Run: $connectHint"
        }

        $sites = New-Object System.Collections.ArrayList
        $checkedAny = $false
        $isOneDrive = { param($s) "$($s.Url)" -like '*-my.sharepoint.com/personal/*' }
    }

    process {
        foreach ($upn in $User) {
            if (-not $upn) { continue }
            $checkedAny = $true
            try {
                $found = @(Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Owner -eq '$upn'" -ErrorAction Stop -Verbose:$false |
                    Where-Object { & $isOneDrive $_ })
                if (-not $found) {
                    Write-Warning "Skipped ${upn}: no OneDrive found for this user."
                    continue
                }
                foreach ($s in $found) { $null = $sites.Add($s) }
            }
            catch {
                Write-Warning "Skipped ${upn}: $($_.Exception.Message)"
            }
        }
    }

    end {
        if (-not $checkedAny) {
            Write-Verbose 'Reading every OneDrive in the tenant'
            try {
                foreach ($s in @(Get-SPOSite -IncludePersonalSite $true -Limit All -Filter "Url -like '-my.sharepoint.com/personal/'" -ErrorAction Stop -Verbose:$false)) {
                    if (& $isOneDrive $s) { $null = $sites.Add($s) }
                }
            }
            catch {
                throw "Get-MttOneDriveUsage couldn't list the OneDrive sites: $($_.Exception.Message)"
            }
        }
        Write-Verbose "OneDrive sites read: $($sites.Count)"

        $now = Get-Date
        $rows = foreach ($s in $sites) {
            # StorageUsageCurrent and StorageQuota are in MB
            $usedMB = [double]$s.StorageUsageCurrent
            $quotaMB = [double]$s.StorageQuota
            $usedGB = [math]::Round($usedMB / 1024, 2)
            $quotaGB = [math]::Round($quotaMB / 1024, 2)
            $percent = $null
            if ($quotaMB -gt 0) { $percent = [math]::Round($usedMB / $quotaMB * 100, 2) }
            if ($PSBoundParameters.ContainsKey('MinPercentUsed') -and ($null -eq $percent -or $percent -lt $MinPercentUsed)) { continue }

            $modified = $s.LastContentModifiedDate
            if ($modified -and -not ($modified -is [datetime])) { $modified = [datetime]$modified }
            $days = $null
            if ($modified -and $modified -gt [datetime]'1900-01-01') { $days = [int]($now - $modified).TotalDays }

            [PSCustomObject]@{
                PSTypeName          = 'MSTechTalk.OneDriveUsage'
                UserPrincipalName   = "$($s.Owner)"
                SiteUrl             = "$($s.Url)"
                StorageUsedGB       = $usedGB
                StorageQuotaGB      = $quotaGB
                PercentUsed         = $percent
                EntitlementGB       = $EntitlementGB
                OverEntitlementGB   = [math]::Max([double]0, [math]::Round($usedGB - $EntitlementGB, 2))
                LastContentModified = $modified
                DaysSinceLastChange = $days
                LockState           = "$($s.LockState)"
            }
        }
        $rows | Sort-Object @{ Expression = { [double]$_.PercentUsed }; Descending = $true }, @{ Expression = { [double]$_.StorageUsedGB }; Descending = $true }, UserPrincipalName
    }
}
