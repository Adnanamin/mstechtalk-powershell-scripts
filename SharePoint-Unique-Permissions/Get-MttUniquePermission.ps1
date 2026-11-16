#Requires -Version 7.4
#Requires -Modules PnP.PowerShell

function Get-MttUniquePermission {
    <#
    .SYNOPSIS
        Lists every library, list, folder, file and list item with unique permissions on a SharePoint site.
    .DESCRIPTION
        Checks HasUniqueRoleAssignments on each visible library and list, and on each item in it. Returns one
        row for every object that has stopped inheriting permissions, as soon as it is found.

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-PnPOnline first,
        and pipe the result to Export-Csv.

        HasUniqueRoleAssignments is loaded one item at a time, so a big site takes a while (about 9,000 items
        took 30 minutes). Use -Library to check one library first.
    .PARAMETER SiteUrl
        Site to report on. It must be the site the current PnP connection is signed in to. Accepts pipeline
        input from Get-MttSite.
    .PARAMETER Library
        Title of one library or list on the site. Leave it out to report on the whole site.
    .EXAMPLE
        Get-MttUniquePermission -SiteUrl https://contoso.sharepoint.com/sites/Projects

        Lists everything with unique permissions on the Projects site.
    .EXAMPLE
        Get-MttUniquePermission -SiteUrl https://contoso.sharepoint.com/sites/Projects -Library "Documents"

        Checks the Documents library only.
    .EXAMPLE
        Get-MttUniquePermission -SiteUrl https://contoso.sharepoint.com/sites/Projects | Export-Csv .\UniquePermissions.csv -NoTypeInformation -Encoding UTF8

        Saves the report as a CSV file.
    .EXAMPLE
        Get-MttSite | Get-MttUniquePermission | Export-Csv .\UniquePermissions.csv -NoTypeInformation -Encoding UTF8

        Takes sites from the pipeline. A site the current PnP connection isn't signed in to is skipped with a warning.
    .OUTPUTS
        MSTechTalk.UniquePermission

        SiteUrl  Site the row belongs to
        List     Title of the library or list
        Level    List, Folder, File or Item
        Path     Server-relative path of the folder, file or item; the title for a library or list
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      PnP.PowerShell 3.x
        Requires:    PnP
        Permissions: Site collection admin on the site; your own Entra app registration for Connect-PnPOnline
        Level:       Site, Library
        Tested:      16 November 2026 on the MST demo tenant (PowerShell 7.6.9, PnP.PowerShell 3.5.0)
    .LINK
        https://mstechtalk.com/sharepoint-unique-permissions-report-pnp-powershell/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.UniquePermission')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Url')]
        [string]$SiteUrl,

        [string]$Library
    )

    begin {
        $connectHint = 'Connect-PnPOnline -Url <site URL> -Interactive -ClientId <your Entra app client ID>'
        try { $connection = Get-PnPConnection -ErrorAction Stop -Verbose:$false } catch { $connection = $null }
        if (-not $connection) {
            throw "Get-MttUniquePermission needs a PnP PowerShell connection. Run: $connectHint"
        }
    }

    process {
        $site = $SiteUrl.TrimEnd('/')
        $connectedUrl = "$((Get-PnPConnection -Verbose:$false).Url)".TrimEnd('/')
        if ($connectedUrl -ne $site) {
            Write-Warning "Skipped ${site}: the PnP connection is signed in to $connectedUrl. Run: $($connectHint.Replace('<site URL>', $site))"
            return
        }

        try {
            if ($Library) {
                $lists = @(Get-PnPList -Identity $Library -ErrorAction Stop -Verbose:$false)
                if (-not $lists) {
                    Write-Warning "Skipped ${site}: no library or list named '$Library'."
                    return
                }
            }
            else {
                $lists = @(Get-PnPList -ErrorAction Stop -Verbose:$false |
                    Where-Object { -not $_.Hidden -and $_.BaseType -in 'DocumentLibrary', 'GenericList' })
            }
        }
        catch {
            Write-Warning "Skipped ${site}: $($_.Exception.Message)"
            return
        }

        $activity = "Unique permissions on $site"
        $listNumber = 0
        foreach ($list in $lists) {
            $listNumber++
            Write-Verbose "Checking $($list.Title) ($($list.ItemCount) items)"
            Write-Progress -Activity $activity -Status "$($list.Title) ($listNumber of $($lists.Count))" -PercentComplete (($listNumber - 1) / $lists.Count * 100)

            try {
                if (Get-PnPProperty -ClientObject $list -Property HasUniqueRoleAssignments -ErrorAction Stop -Verbose:$false) {
                    [PSCustomObject]@{
                        PSTypeName = 'MSTechTalk.UniquePermission'
                        SiteUrl    = $site
                        List       = $list.Title
                        Level      = 'List'
                        Path       = $list.Title
                    }
                }

                $itemNumber = 0
                foreach ($item in Get-PnPListItem -List $list -PageSize 500 -ErrorAction Stop -Verbose:$false) {
                    $itemNumber++
                    if ($itemNumber % 500 -eq 0) {
                        Write-Verbose "  $($list.Title): $itemNumber of $($list.ItemCount) items checked"
                    }
                    if ($itemNumber % 100 -eq 0) {
                        Write-Progress -Activity $activity -Status "$($list.Title) ($listNumber of $($lists.Count)): item $itemNumber of $($list.ItemCount)" -PercentComplete (($listNumber - 1) / $lists.Count * 100)
                    }

                    try {
                        if (Get-PnPProperty -ClientObject $item -Property HasUniqueRoleAssignments -ErrorAction Stop -Verbose:$false) {
                            # SharePoint returns File for a list item, so name it Item when the list isn't a library
                            $level = "$($item.FileSystemObjectType)"
                            if ($level -eq 'File' -and $list.BaseType -eq 'GenericList') { $level = 'Item' }

                            [PSCustomObject]@{
                                PSTypeName = 'MSTechTalk.UniquePermission'
                                SiteUrl    = $site
                                List       = $list.Title
                                Level      = $level
                                Path       = $item.FieldValues.FileRef
                            }
                        }
                    }
                    catch {
                        Write-Warning "Skipped item $($item.Id) in $($list.Title): $($_.Exception.Message)"
                    }
                }
            }
            catch {
                Write-Warning "Skipped $($list.Title): $($_.Exception.Message)"
            }
        }
        Write-Progress -Activity $activity -Completed
    }
}
