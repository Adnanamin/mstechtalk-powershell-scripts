#Requires -Version 5.1

function Get-MttCustomScriptSite {
    <#
    .SYNOPSIS
        Lists the SharePoint sites that allow custom script.
    .DESCRIPTION
        Reads DenyAddAndCustomizePages for every site (OneDrive excluded), or the sites you give it, and returns the
        sites where custom script is allowed. Use it before turning on the Baseline Security Mode setting
        "Don't allow new custom scripts in OneDrive and SharePoint sites", or to check what that setting's impact
        report shows. Add -IncludeBlocked to return every site with its state.

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-SPOService first,
        and pipe the result to Export-Csv.

        In PowerShell 7, load the SharePoint Online Management Shell with
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell before you connect.
    .PARAMETER SiteUrl
        One or more sites to check (alias Url). Accepts pipeline input. Leave it out to check every site.
    .PARAMETER IncludeBlocked
        Also return the sites where custom script is blocked.
    .EXAMPLE
        Get-MttCustomScriptSite

        Lists every site that allows custom script.
    .EXAMPLE
        Get-MttCustomScriptSite -SiteUrl https://contoso.sharepoint.com/sites/Projects -IncludeBlocked

        Shows the custom script state of the Projects site.
    .EXAMPLE
        Get-MttCustomScriptSite -IncludeBlocked | Export-Csv .\CustomScriptSites.csv -NoTypeInformation -Encoding UTF8

        Saves every site with its custom script state as a CSV file.
    .OUTPUTS
        MSTechTalk.CustomScriptSite

        SiteUrl                   Site URL
        Title                     Site title
        Template                  Site template
        DenyAddAndCustomizePages  Raw value: Enabled = custom script blocked, Disabled = allowed
        CustomScriptAllowed       True when custom script is allowed
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Online.SharePoint.PowerShell (SharePoint Online Management Shell)
        Requires:    SPO (one Get-SPOSite call returns the value for every site)
        Permissions: SharePoint Administrator
        Level:       Tenant, Site
        Tested:      18 November 2026 on the MST demo tenant (Windows PowerShell 5.1, and PowerShell 7.6.10 with
                     -UseWindowsPowerShell; SPO module 16.0.27814.12015)
        No #Requires -Modules line: in PowerShell 7 that line would load the module without
        -UseWindowsPowerShell, so the function checks for it in begin instead.
    .LINK
        https://mstechtalk.com/sharepoint-baseline-security-mode-2026/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.CustomScriptSite')]
    param(
        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Url')]
        [string[]]$SiteUrl,

        [switch]$IncludeBlocked
    )

    begin {
        $connectHint = 'Connect-SPOService -Url https://<tenant>-admin.sharepoint.com'
        if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
            throw "Get-MttCustomScriptSite needs the SharePoint Online Management Shell. In PowerShell 7 run: Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell, then $connectHint"
        }
        try {
            $null = Get-SPOSite -Limit 1 -ErrorAction Stop -WarningAction SilentlyContinue -Verbose:$false
        }
        catch {
            throw "Get-MttCustomScriptSite needs a SharePoint Online Management Shell connection. Run: $connectHint"
        }
        $sites = New-Object System.Collections.ArrayList
        $checkedAny = $false
    }

    process {
        foreach ($url in $SiteUrl) {
            if (-not $url) { continue }
            $checkedAny = $true
            try {
                $null = $sites.Add((Get-SPOSite -Identity $url.TrimEnd('/') -ErrorAction Stop -Verbose:$false))
            }
            catch {
                Write-Warning "Skipped ${url}: $($_.Exception.Message)"
            }
        }
    }

    end {
        if (-not $checkedAny) {
            Write-Verbose 'Reading every site in the tenant'
            try {
                foreach ($site in @(Get-SPOSite -Limit All -ErrorAction Stop -Verbose:$false)) { $null = $sites.Add($site) }
            }
            catch {
                throw "Get-MttCustomScriptSite couldn't list the sites: $($_.Exception.Message)"
            }
        }
        Write-Verbose "Sites read: $($sites.Count)"

        foreach ($site in $sites) {
            $state = "$($site.DenyAddAndCustomizePages)"
            $allowed = ($state -ne 'Enabled')
            if (-not $allowed -and -not $IncludeBlocked) { continue }
            [PSCustomObject]@{
                PSTypeName               = 'MSTechTalk.CustomScriptSite'
                SiteUrl                  = "$($site.Url)"
                Title                    = "$($site.Title)"
                Template                 = "$($site.Template)"
                DenyAddAndCustomizePages = $state
                CustomScriptAllowed      = $allowed
            }
        }
    }
}
