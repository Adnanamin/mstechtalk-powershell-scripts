#Requires -Version 5.1

function Start-MttRcdInsightsReport {
    <#
    .SYNOPSIS
        Runs Microsoft's Restricted Content Discovery (RCD) insights report and returns the sites in it.
    .DESCRIPTION
        Queues the RCD insights report, waits until it shows Completed, downloads it and returns one row per
        site where Copilot is blocked by RCD. The report is built by Microsoft, so it is much faster than
        checking each site on a big tenant.

        Microsoft allows one new report every 24 hours. If one was already started in that window, the
        function warns and returns the latest existing report instead. -UseExisting skips the new report and
        always returns the latest existing one.

        The status goes NotStarted, InQueue, Completed. On a small demo tenant it took about two minutes;
        expect longer on a big tenant.

        The function only reads and reports. It doesn't connect and doesn't export: sign in with
        Connect-SPOService first, and pipe the result to Export-Csv. The downloaded CSV goes to a temporary
        folder that the function removes when it is done.

        In PowerShell 7, load the SharePoint Online Management Shell with
        Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell before you connect.
    .PARAMETER UseExisting
        Don't start a new report: return the latest existing one.
    .PARAMETER TimeoutMinutes
        How long to wait for the report to complete, from 1 to 1440 minutes. Defaults to 30.
    .PARAMETER PollSeconds
        How often to check the report status, from 10 to 600 seconds. Defaults to 30.
    .EXAMPLE
        Start-MttRcdInsightsReport

        Starts a new report, waits for it and lists the sites in it.
    .EXAMPLE
        Start-MttRcdInsightsReport | Export-Csv .\RcdInsights.csv -NoTypeInformation -Encoding UTF8

        Saves the report as a CSV file.
    .EXAMPLE
        Start-MttRcdInsightsReport -UseExisting

        Returns the latest existing report without starting a new one.
    .OUTPUTS
        MSTechTalk.RcdInsightsSite

        SiteUrl       Site URL
        Title         Site title
        OwnerEmail    Site owner's email address
        LastModified  Date of the last change to the site, as the report gives it
        TimeCreated   Date the site was created
        ReportId      ID of the RCD report the row comes from
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Online.SharePoint.PowerShell (SharePoint Online Management Shell)
        Requires:    SPO (the RCD report cmdlets are only in this module)
        Permissions: SharePoint Administrator
        Level:       Tenant
        Tested:      16 November 2026 on the MST demo tenant (PowerShell 7.6.9 with -UseWindowsPowerShell, and
                     Windows PowerShell 5.1; SPO module 16.0.27424.0): starting, waiting for and downloading a new
                     report, the 24-hour fallback and -UseExisting. Skipping the confirmation with -Force is not
                     yet tested (the 24-hour limit applied).
        No #Requires -Modules line: in PowerShell 7 that line would load the module without
        -UseWindowsPowerShell, so the function checks for it in begin instead.
    .LINK
        https://mstechtalk.com/find-sharepoint-sites-copilot-blocked/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.RcdInsightsSite')]
    param(
        [switch]$UseExisting,

        [ValidateRange(1, 1440)]
        [int]$TimeoutMinutes = 30,

        [ValidateRange(10, 600)]
        [int]$PollSeconds = 30
    )

    begin {
        $connectHint = 'Connect-SPOService -Url https://<tenant>-admin.sharepoint.com'
        if (-not (Get-Command Get-SPORestrictedContentDiscoverabilityReport -ErrorAction SilentlyContinue)) {
            throw "Start-MttRcdInsightsReport needs the SharePoint Online Management Shell. In PowerShell 7 run: Import-Module Microsoft.Online.SharePoint.PowerShell -UseWindowsPowerShell, then $connectHint"
        }
        try {
            $null = Get-SPOSite -Limit 1 -ErrorAction Stop -WarningAction SilentlyContinue -Verbose:$false
        }
        catch {
            throw "Start-MttRcdInsightsReport needs a SharePoint Online Management Shell connection. Run: $connectHint"
        }
    }

    end {
        $reportId = $null
        if (-not $UseExisting) {
            try {
                # Microsoft's cmdlet asks to confirm because the report takes time; -Force skips that where it exists
                $startParams = @{ Confirm = $false; ErrorAction = 'Stop'; Verbose = $false }
                if ((Get-Command Start-SPORestrictedContentDiscoverabilityReport).Parameters.ContainsKey('Force')) { $startParams.Force = $true }
                $started = Start-SPORestrictedContentDiscoverabilityReport @startParams
                $reportId = "$($started.Id)"
                Write-Verbose "Started report $reportId"
            }
            catch {
                if ($_.Exception.Message -match '24 hours') {
                    Write-Warning 'A report was already started in the last 24 hours, and Microsoft allows one every 24 hours. Returning the latest existing report instead.'
                }
                else {
                    throw "Start-MttRcdInsightsReport couldn't start the report: $($_.Exception.Message)"
                }
            }
        }

        $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
        $activity = 'RCD insights report'
        while ($true) {
            try {
                $reports = @(Get-SPORestrictedContentDiscoverabilityReport -ErrorAction Stop -Verbose:$false)
            }
            catch {
                throw "Start-MttRcdInsightsReport couldn't read the report status: $($_.Exception.Message)"
            }

            if ($reportId) {
                $report = $reports | Where-Object { "$($_.Id)" -eq $reportId } | Select-Object -First 1
            }
            else {
                # Newest first when the report list has creation dates; otherwise the order the cmdlet returns
                $dated = @($reports | Where-Object { $_.PSObject.Properties['CreatedDateTimeInUtc'] -and "$($_.CreatedDateTimeInUtc)" })
                if ($dated.Count -eq $reports.Count -and $dated.Count) {
                    $report = $reports | Sort-Object { [datetime]"$($_.CreatedDateTimeInUtc)" } -Descending | Select-Object -First 1
                }
                else {
                    $report = $reports | Select-Object -First 1
                }
            }

            if (-not $report) {
                Write-Warning 'No RCD report found. Run Start-MttRcdInsightsReport without -UseExisting to start one.'
                return
            }

            $status = "$($report.Status)"
            Write-Verbose "Report $($report.Id): $status"
            if ($status -eq 'Completed') { break }
            if ($status -match 'Fail') {
                Write-Warning "Report $($report.Id) failed. Start a new one after 24 hours."
                return
            }
            if ((Get-Date) -gt $deadline) {
                Write-Warning "Report $($report.Id) is still $status after $TimeoutMinutes minutes. Run Start-MttRcdInsightsReport -UseExisting later to collect it."
                return
            }
            Write-Progress -Activity $activity -Status "Report $($report.Id): $status"
            Start-Sleep -Seconds $PollSeconds
        }
        Write-Progress -Activity $activity -Completed

        # The download saves RestrictedContentDiscoverabilityReport_<number>.csv in the process's working
        # folder, not the PowerShell location. In PowerShell 7 the module runs in a separate Windows PowerShell
        # process, so the working folder is set there too, and put back afterwards.
        Write-Verbose "Downloading report $($report.Id)"
        $folder = Join-Path ([IO.Path]::GetTempPath()) ("MttRcd-" + [guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $folder -Force
        $compat = Get-PSSession -Name WinPSCompatSession -ErrorAction SilentlyContinue | Select-Object -First 1
        $setFolder = { param($Path) $old = [Environment]::CurrentDirectory; [Environment]::CurrentDirectory = $Path; $old }
        try {
            $localOld = & $setFolder $folder
            $remoteOld = $null
            if ($compat) { $remoteOld = Invoke-Command -Session $compat -ScriptBlock $setFolder -ArgumentList $folder }
            try {
                $null = Get-SPORestrictedContentDiscoverabilityReport -Action Download -ReportId $report.Id -ErrorAction Stop -Verbose:$false
            }
            finally {
                if ($compat -and $remoteOld) { $null = Invoke-Command -Session $compat -ScriptBlock $setFolder -ArgumentList $remoteOld }
                $null = & $setFolder $localOld
            }

            $csv = Get-ChildItem -Path $folder -Filter '*.csv' | Select-Object -First 1
            if (-not $csv) {
                Write-Warning "Report $($report.Id) is completed, but the download didn't save a CSV file."
                return
            }

            foreach ($row in Import-Csv -Path $csv.FullName) {
                $lastModified = $null; $created = $null
                if ($row.LastModified) { $lastModified = [datetime]$row.LastModified }
                if ($row.TimeCreated) { $created = [datetime]$row.TimeCreated }
                [PSCustomObject]@{
                    PSTypeName   = 'MSTechTalk.RcdInsightsSite'
                    SiteUrl      = $row.SiteUrl
                    Title        = $row.SiteTitle
                    OwnerEmail   = $row.SiteOwnerEmail
                    LastModified = $lastModified
                    TimeCreated  = $created
                    ReportId     = "$($report.Id)"
                }
            }
        }
        catch {
            throw "Start-MttRcdInsightsReport couldn't download report $($report.Id): $($_.Exception.Message)"
        }
        finally {
            Remove-Item -Path $folder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
