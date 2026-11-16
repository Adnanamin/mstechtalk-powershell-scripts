#Requires -Version 7.4
#Requires -Modules PnP.PowerShell

function Get-MttAnyoneSharingLink {
    <#
    .SYNOPSIS
        Lists every Anyone (anonymous) sharing link on the files and folders of a SharePoint site.
    .DESCRIPTION
        Checks the sharing links on each file and folder in every visible document library, and returns one
        row for each Anyone link it finds, with view or edit and the expiry date. Anyone links open without a
        sign-in, so the ones with no expiry date are the ones to check first.

        A folder's Anyone link is returned on the folder and again on every file and subfolder inside it, so a
        site has more rows than links. Every row of one link has the same LinkId: group by LinkId to count the
        links themselves.

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-PnPOnline first,
        and pipe the result to Export-Csv.

        Sharing links are read one item at a time, so a big site takes a while (about 470 items in 8 libraries took five
        minutes). Use -Library to check one library first.
    .PARAMETER SiteUrl
        Site to report on. It must be the site the current PnP connection is signed in to. Accepts pipeline
        input from Get-MttSite.
    .PARAMETER Library
        Title of one document library on the site. Leave it out to report on every visible library.
    .EXAMPLE
        Get-MttAnyoneSharingLink -SiteUrl https://contoso.sharepoint.com/sites/Marketing

        Lists every Anyone link on the Marketing site.
    .EXAMPLE
        Get-MttAnyoneSharingLink -SiteUrl https://contoso.sharepoint.com/sites/Marketing -Library "Brand Assets"

        Checks the Brand Assets library only.
    .EXAMPLE
        Get-MttAnyoneSharingLink -SiteUrl https://contoso.sharepoint.com/sites/Marketing | Export-Csv .\AnyoneLinks.csv -NoTypeInformation -Encoding UTF8

        Saves the report as a CSV file.
    .EXAMPLE
        Get-MttAnyoneSharingLink -SiteUrl https://contoso.sharepoint.com/sites/Marketing | Where-Object { -not $_.Expires }

        Shows only the Anyone links that never expire.
    .EXAMPLE
        Get-MttSite | Get-MttAnyoneSharingLink | Export-Csv .\AnyoneLinks.csv -NoTypeInformation -Encoding UTF8

        Takes sites from the pipeline. A site the current PnP connection isn't signed in to is skipped with a warning.
    .OUTPUTS
        MSTechTalk.AnyoneSharingLink

        SiteUrl   Site the row belongs to
        Library   Title of the document library
        ItemType  File or Folder
        Path      Server-relative path of the file or folder
        LinkType  View or Edit
        Expires   Expiry date, or empty when the link never expires
        LinkId    ID of the sharing link; the same on every row the link opens
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      PnP.PowerShell 3.x
        Requires:    PnP
        Permissions: Site collection admin on the site; your own Entra app registration for Connect-PnPOnline
        Level:       Site, Library
        Tested:      16 November 2026 on the MST demo tenant (PowerShell 7.6.9, PnP.PowerShell 3.5.0)
    .LINK
        https://mstechtalk.com/find-anyone-links-sharepoint-pnp-powershell/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.AnyoneSharingLink')]
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
            throw "Get-MttAnyoneSharingLink needs a PnP PowerShell connection. Run: $connectHint"
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
                $libraries = @(Get-PnPList -Identity $Library -ErrorAction Stop -Verbose:$false)
                if (-not $libraries) {
                    Write-Warning "Skipped ${site}: no library named '$Library'."
                    return
                }
                if ($libraries[0].BaseTemplate -ne 101) {
                    Write-Warning "Skipped ${site}: '$Library' isn't a document library. Anyone links are only on files and folders in document libraries."
                    return
                }
            }
            else {
                $libraries = @(Get-PnPList -ErrorAction Stop -Verbose:$false |
                    Where-Object { $_.BaseTemplate -eq 101 -and -not $_.Hidden })
            }
        }
        catch {
            Write-Warning "Skipped ${site}: $($_.Exception.Message)"
            return
        }

        $activity = "Anyone links on $site"
        $libraryNumber = 0
        foreach ($list in $libraries) {
            $libraryNumber++
            Write-Verbose "Checking $($list.Title) ($($list.ItemCount) items)"
            Write-Progress -Activity $activity -Status "$($list.Title) ($libraryNumber of $($libraries.Count))" -PercentComplete (($libraryNumber - 1) / $libraries.Count * 100)

            try {
                $itemNumber = 0
                foreach ($item in Get-PnPListItem -List $list -PageSize 500 -ErrorAction Stop -Verbose:$false) {
                    $itemNumber++
                    if ($itemNumber % 100 -eq 0) {
                        Write-Progress -Activity $activity -Status "$($list.Title) ($libraryNumber of $($libraries.Count)): item $itemNumber of $($list.ItemCount)" -PercentComplete (($libraryNumber - 1) / $libraries.Count * 100)
                    }

                    $path = $item.FieldValues.FileRef
                    $itemType = "$($item.FileSystemObjectType)"
                    try {
                        if ($itemType -eq 'Folder') {
                            $links = Get-PnPFolderSharingLink -Folder $path -ErrorAction Stop -Verbose:$false
                        }
                        else {
                            $links = Get-PnPFileSharingLink -Identity $path -ErrorAction Stop -Verbose:$false
                        }
                    }
                    catch {
                        Write-Warning "Skipped ${path}: $($_.Exception.Message)"
                        continue
                    }

                    foreach ($link in $links | Where-Object { $_.Link.Scope -eq 'anonymous' }) {
                        $expires = $link.ExpirationDateTime
                        if ($expires -is [DateTimeOffset]) { $expires = $expires.DateTime }
                        elseif ($expires) { $expires = [datetime]$expires }
                        else { $expires = $null }

                        $linkType = "$($link.Link.Type)"
                        if ($linkType) { $linkType = $linkType.Substring(0, 1).ToUpper() + $linkType.Substring(1) }

                        [PSCustomObject]@{
                            PSTypeName = 'MSTechTalk.AnyoneSharingLink'
                            SiteUrl    = $site
                            Library    = $list.Title
                            ItemType   = $itemType
                            Path       = $path
                            LinkType   = $linkType
                            Expires    = $expires
                            LinkId     = $link.Id
                        }
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
