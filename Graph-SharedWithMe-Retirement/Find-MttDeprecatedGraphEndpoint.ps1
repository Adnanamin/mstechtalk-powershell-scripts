<#
.SYNOPSIS
    Finds scripts and config files that call the retired Microsoft Graph file endpoints.
.DESCRIPTION
    Searches a folder for /me/drive/sharedWithMe, /me/drive/recent, /insights/used and /insights/shared,
    which stop returning data after November 2026. Lists the file, line number and line.
.NOTES
    Author:      Adnan Amin
    Blog:        https://mstechtalk.com
    GitHub:      https://github.com/adnanamin/mstechtalk-powershell-scripts
    Module:      None (Windows PowerShell 5.1 or PowerShell 7)
    Permissions: Read access to the folder
    Tested:      15 November 2026 (PowerShell 7.6)
.LINK
    https://mstechtalk.com/graph-sharedwithme-recent-retired-search-api/
#>
param(
    [string]$ScriptFolder = "C:\Scripts",   # Replace with your own
    [string[]]$Exclude    = @()
)

Get-ChildItem -Path $ScriptFolder -Recurse -Include *.ps1, *.psm1, *.js, *.ts, *.json -ErrorAction SilentlyContinue |
    Where-Object { $path = $_.FullName; -not ($Exclude | Where-Object { $path -like "$_*" }) } |
    Select-String -Pattern "sharedWithMe", "drive/recent", "insights/used", "insights/shared" |
    Select-Object Path, LineNumber, Line
