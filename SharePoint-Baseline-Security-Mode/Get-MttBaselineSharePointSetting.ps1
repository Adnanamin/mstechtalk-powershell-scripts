#Requires -Version 5.1

function Get-MttBaselineSharePointSetting {
    <#
    .SYNOPSIS
        Shows whether the SharePoint settings in Microsoft 365 Baseline Security Mode meet the baseline, read from Get-SPOTenant.
    .DESCRIPTION
        Baseline Security Mode in the Microsoft 365 admin center turns several SharePoint tenant settings on for you.
        This function reads the tenant property behind each of them and returns one row per setting with the current
        value, the value the baseline expects and whether the tenant meets it. Use it to check many tenants quickly,
        or to confirm what the admin center shows.

        Settings with no tenant property in the module are not listed. On 18 November 2026 that included
        "Don't allow new custom scripts" (use Get-MttCustomScriptSite for the per-site view) and the Baseline
        Security Mode 2026 SharePoint settings announced at Ignite (classic pages, scoped access for
        high-privileged apps, pre-authenticated URLs).

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-SPOService first,
        and pipe the result to Export-Csv.

        In PowerShell 7, load the SharePoint Online Management Shell with
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell before you connect.
    .EXAMPLE
        Get-MttBaselineSharePointSetting

        Lists the SharePoint baseline settings and whether each one meets the baseline.
    .EXAMPLE
        Get-MttBaselineSharePointSetting | Where-Object { -not $_.MeetsBaseline }

        Only the settings that are at risk.
    .EXAMPLE
        Get-MttBaselineSharePointSetting | Export-Csv .\BaselineSharePoint.csv -NoTypeInformation -Encoding UTF8

        Saves the result as a CSV file.
    .OUTPUTS
        MSTechTalk.BaselineSharePointSetting

        Setting          Baseline Security Mode setting name as shown in the Microsoft 365 admin center
        TenantProperty   Get-SPOTenant property behind it
        CurrentValue     Value on the tenant now
        BaselineValue    Value the baseline expects
        MeetsBaseline    True when the current value matches the baseline
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Online.SharePoint.PowerShell 16.0.27814.12015 or later
        Requires:    SPO (these tenant settings are only exposed by Get-SPOTenant)
        Permissions: SharePoint Administrator
        Level:       Tenant
        Tested:      18 November 2026 on the MST demo tenant (Windows PowerShell 5.1, and PowerShell 7.6.10 with
                     -UseWindowsPowerShell; SPO module 16.0.27814.12015)
        No #Requires -Modules line: in PowerShell 7 that line would load the module without
        -UseWindowsPowerShell, so the function checks for it in begin instead.
    .LINK
        https://mstechtalk.com/sharepoint-baseline-security-mode-2026/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.BaselineSharePointSetting')]
    param()

    begin {
        $connectHint = 'Connect-SPOService -Url https://<tenant>-admin.sharepoint.com'
        if (-not (Get-Command Get-SPOTenant -ErrorAction SilentlyContinue)) {
            throw "Get-MttBaselineSharePointSetting needs the SharePoint Online Management Shell. In PowerShell 7 run: Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell, then $connectHint"
        }
        try {
            $tenant = Get-SPOTenant -ErrorAction Stop -WarningAction SilentlyContinue -Verbose:$false
        }
        catch {
            throw "Get-MttBaselineSharePointSetting needs a SharePoint Online Management Shell connection. Run: $connectHint"
        }

        # Setting name (as in the admin center), tenant property, value the baseline expects
        $map = @(
            [PSCustomObject]@{ Setting = 'Block legacy browser authentication connections to SharePoint'; Property = 'LegacyBrowserAuthProtocolsEnabled'; Baseline = $false }
            [PSCustomObject]@{ Setting = 'Block IDCRL protocol connections to SharePoint'; Property = 'LegacyAuthProtocolsEnabled'; Baseline = $false }
            [PSCustomObject]@{ Setting = 'Remove access to Microsoft Store for SharePoint'; Property = 'DisableSharePointStoreAccess'; Baseline = $true }
            [PSCustomObject]@{ Setting = "Don't allow resource accounts on Teams Rooms devices from accessing Microsoft 365 files"; Property = 'RestrictResourceAccountAccess'; Baseline = $true }
        )
    }

    end {
        foreach ($m in $map) {
            $property = $tenant.PSObject.Properties[$m.Property]
            if (-not $property) {
                Write-Warning "Get-SPOTenant has no $($m.Property) property in this module version. Skipped: $($m.Setting)"
                continue
            }
            $current = $property.Value
            # A string 'False' would cast to $true, so parse strings explicitly
            $currentBool = if ($current -is [string]) { $current -eq 'True' } else { [bool]$current }
            [PSCustomObject]@{
                PSTypeName     = 'MSTechTalk.BaselineSharePointSetting'
                Setting        = $m.Setting
                TenantProperty = $m.Property
                CurrentValue   = $current
                BaselineValue  = $m.Baseline
                MeetsBaseline  = ($currentBool -eq [bool]$m.Baseline)
            }
        }
    }
}
