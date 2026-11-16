#Requires -Version 7.4
#Requires -Modules Microsoft.Graph.Authentication

function Get-MttCopilotUsage {
    <#
    .SYNOPSIS
        Lists Microsoft 365 Copilot usage per user from the Copilot usage report.
    .DESCRIPTION
        Downloads the Microsoft 365 Copilot usage user detail report from Microsoft Graph and returns one row per
        Copilot-licensed user: the last activity date in each Copilot app and, in report v2, prompt counts and
        active days. It uses report v2 and falls back to v1 when v2 isn't available (v1 has no 28-day period, so
        28 becomes 30).

        The v1.0 report is only available as CSV, so the function downloads it to a temporary file, reads it and
        deletes the file. Property names are the report's column names without spaces, for example
        "User Principal Name" becomes UserPrincipalName; dates are [datetime]. When the tenant hides user names in
        reports, UserPrincipalName holds an ID instead and the function warns.

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-MgGraph first,
        and pipe the result to Export-Csv.
    .PARAMETER Days
        Report period: 7, 28, 90 or 180 days. Defaults to 28.
    .EXAMPLE
        Get-MttCopilotUsage

        Copilot usage per user for the last 28 days.
    .EXAMPLE
        Get-MttCopilotUsage -Days 90 | Export-Csv .\CopilotUsage.csv -NoTypeInformation -Encoding UTF8

        Saves 90 days of usage as a CSV file.
    .EXAMPLE
        Get-MttCopilotUsage | Where-Object { -not $_.LastActivityDate } | Select-Object UserPrincipalName, DisplayName

        Licensed users who haven't used Copilot.
    .OUTPUTS
        MSTechTalk.CopilotUsage

        UserPrincipalName, ReportRefreshDate, ReportPeriod, DisplayName, LastActivityDate, one LastActivityDate
        column per Copilot app (Teams, Word, Excel, PowerPoint, Outlook, OneNote, Loop, Copilot Chat) and, in report
        v2, prompt counts and active usage days. The exact columns are the ones Microsoft's report returns.
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Graph.Authentication 2.x
        Requires:    Graph (Connect-MgGraph -Scopes Reports.Read.All)
        Permissions: Delegated Reports.Read.All, with the AI Administrator, Reports Reader or Global Administrator role
        Level:       Tenant, User
        Tested:      16 November 2026 on the MST demo tenant (PowerShell 7.6.9, Microsoft.Graph.Authentication
                     2.41.2): report v2, 4 users, the same Last Activity Date as Microsoft's CSV for every user
    .LINK
        https://mstechtalk.com/how-to-monitor-microsoft-365-copilot-and-agents-usage-in-your-organization/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.CopilotUsage')]
    param(
        [ValidateSet(7, 28, 90, 180)]
        [int]$Days = 28
    )

    begin {
        $connectHint = 'Connect-MgGraph -Scopes Reports.Read.All'
        $context = Get-MgContext
        if (-not $context) {
            throw "Get-MttCopilotUsage needs a Microsoft Graph connection. Run: $connectHint"
        }
        if ($context.AuthType -eq 'Delegated' -and $context.Scopes -notcontains 'Reports.Read.All') {
            Write-Warning "The Graph connection doesn't have Reports.Read.All, so the report may fail. Run: $connectHint"
        }

        # "User Principal Name" -> UserPrincipalName, "Copilot Chat (work) Last Activity Date" -> CopilotChatWorkLastActivityDate
        function ConvertTo-MttPropertyName([string]$Column) {
            (($Column -split '[^A-Za-z0-9]+' | Where-Object { $_ } | ForEach-Object { $_.Substring(0, 1).ToUpperInvariant() + $_.Substring(1) }) -join '')
        }

        function Get-MttReportCsv([string]$Uri) {
            $file = Join-Path ([IO.Path]::GetTempPath()) ("MttCopilotUsage-" + [guid]::NewGuid().ToString('N') + '.csv')
            try {
                Invoke-MgGraphRequest -Method GET -Uri $Uri -OutputFilePath $file -ErrorAction Stop -Verbose:$false
                @(Import-Csv -Path $file -Encoding UTF8)
            }
            finally {
                Remove-Item -Path $file -Force -ErrorAction SilentlyContinue
            }
        }
    }

    end {
        $graph = 'https://graph.microsoft.com'
        try {
            $rows = Get-MttReportCsv "$graph/v1.0/copilot/reports/getMicrosoft365CopilotUsageUserDetail(period='D$Days',version='v2')"
        }
        catch {
            $v1Days = if ($Days -eq 28) { 30 } else { $Days }
            Write-Warning "Copilot usage report v2 isn't available, so v1 is used with $v1Days days. ($($_.Exception.Message))"
            try {
                $rows = Get-MttReportCsv "$graph/v1.0/copilot/reports/getMicrosoft365CopilotUsageUserDetail(period='D$v1Days',version='v1')"
            }
            catch {
                throw "Get-MttCopilotUsage couldn't read the Copilot usage report: $($_.Exception.Message)"
            }
        }
        Write-Verbose "Copilot usage report: $($rows.Count) users"

        $named = 0
        foreach ($row in $rows) {
            $flat = [ordered]@{ PSTypeName = 'MSTechTalk.CopilotUsage'; UserPrincipalName = $null }
            foreach ($property in $row.PSObject.Properties) {
                $name = ConvertTo-MttPropertyName $property.Name
                $value = "$($property.Value)".Trim()
                if ($value -eq '') { $value = $null }
                elseif ($name -match 'Date$') {
                    $parsed = [datetime]::MinValue
                    if ([datetime]::TryParse($value, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) { $value = $parsed }
                }
                elseif ($value -match '^\d+$') { $value = [long]$value }
                $flat[$name] = $value
            }
            if ("$($flat.UserPrincipalName)" -like '*@*') { $named++ }
            [PSCustomObject]$flat
        }

        if ($rows.Count -and -not $named) {
            Write-Warning 'User names are hidden because the report privacy setting is on. A Global Administrator can show them: Microsoft 365 admin center > Settings > Org settings > Services > Reports, clear "Conceal user, group, and site names in all reports".'
        }
    }
}
