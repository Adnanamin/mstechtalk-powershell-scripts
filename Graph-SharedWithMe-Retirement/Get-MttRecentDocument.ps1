#Requires -Version 5.1
#Requires -Modules Microsoft.Graph.Authentication

function Get-MttRecentDocument {
    <#
    .SYNOPSIS
        Lists the most recently modified documents the signed-in user can open, with the Microsoft Search API.
    .DESCRIPTION
        A replacement approach for the retired /me/drive/recent endpoint. It runs a Microsoft Search query for
        documents, newest change first, and pages through the results until it has -Top documents.

        Search results are trimmed to what the signed-in user can access, so run it as an ordinary user to see
        what that user sees. An admin account sees results from every site it can open. Search has no "shared
        with me" or "who shared it" detail, and doesn't include items shared from other tenants.

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-MgGraph first,
        and pipe the result to Export-Csv.
    .PARAMETER Top
        How many documents to return, newest first, from 1 to 5000. Defaults to 25.
    .PARAMETER Query
        Extra KQL to narrow the search, for example "filetype:xlsx" or "path:https://contoso.sharepoint.com/sites/Projects".
    .EXAMPLE
        Get-MttRecentDocument

        The signed-in user's 25 most recently modified documents.
    .EXAMPLE
        Get-MttRecentDocument -Top 100 -Query 'filetype:xlsx' | Export-Csv .\RecentWorkbooks.csv -NoTypeInformation -Encoding UTF8

        Saves the 100 most recently modified Excel workbooks as a CSV file.
    .OUTPUTS
        MSTechTalk.RecentDocument

        UserPrincipalName  The signed-in account the results are trimmed to
        Name               File name
        LastModified       Date of the last change
        LastModifiedBy     Who made the last change
        SizeMB             File size
        WebUrl             Link to the file
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      Microsoft.Graph.Authentication 2.x
        Requires:    Graph (Connect-MgGraph -Scopes Files.Read.All, Sites.Read.All)
        Permissions: Delegated Files.Read.All and Sites.Read.All
        Level:       User
        Tested:      16 November 2026 on the MST demo tenant (PowerShell 7.6.9 and Windows PowerShell 5.1,
                     Microsoft.Graph.Authentication 2.41.2): same first 25 as Get-RecentDocumentBySearch.ps1
    .LINK
        [POST URL]
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.RecentDocument')]
    param(
        [ValidateRange(1, 5000)]
        [Alias('Size')]
        [int]$Top = 25,

        [string]$Query
    )

    begin {
        $connectHint = 'Connect-MgGraph -Scopes Files.Read.All, Sites.Read.All'
        $context = Get-MgContext
        if (-not $context) {
            throw "Get-MttRecentDocument needs a Microsoft Graph connection. Run: $connectHint"
        }
        $missing = @('Files.Read.All', 'Sites.Read.All' | Where-Object { $context.Scopes -notcontains $_ })
        if ($context.AuthType -eq 'Delegated' -and $missing.Count) {
            Write-Warning "The Graph connection doesn't have $($missing -join ' and '), so results may be missing. Run: $connectHint"
        }
    }

    end {
        $queryString = 'IsDocument:true'
        if ($Query) { $queryString = "$queryString AND ($Query)" }
        $user = "$($context.Account)"

        $returned = 0
        $from = 0
        while ($returned -lt $Top) {
            $pageSize = [math]::Min(500, $Top - $returned)
            $body = @{
                requests = @(
                    @{
                        entityTypes    = @('driveItem')
                        query          = @{ queryString = $queryString }
                        sortProperties = @(@{ name = 'lastModifiedDateTime'; isDescending = $true })
                        from           = $from
                        size           = $pageSize
                    }
                )
            } | ConvertTo-Json -Depth 6

            try {
                $response = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/search/query' `
                    -Body $body -ContentType 'application/json' -ErrorAction Stop -Verbose:$false
            }
            catch {
                Write-Warning "Search failed after $returned documents: $($_.Exception.Message)"
                return
            }

            $container = $response.value[0].hitsContainers[0]
            $hits = @($container.hits)
            Write-Verbose "Page from $from returned $($hits.Count) documents (total about $($container.total))"

            foreach ($hit in $hits) {
                $resource = $hit.resource
                $modified = $null
                if ($resource.lastModifiedDateTime) { $modified = [datetime]$resource.lastModifiedDateTime }
                $sizeMB = $null
                if ($null -ne $resource.size) { $sizeMB = [math]::Round([double]$resource.size / 1MB, 2) }
                [PSCustomObject]@{
                    PSTypeName        = 'MSTechTalk.RecentDocument'
                    UserPrincipalName = $user
                    Name              = $resource.name
                    LastModified      = $modified
                    LastModifiedBy    = $resource.lastModifiedBy.user.displayName
                    SizeMB            = $sizeMB
                    WebUrl            = $resource.webUrl
                }
                $returned++
                if ($returned -ge $Top) { break }
            }

            if (-not $hits.Count -or -not $container.moreResultsAvailable) { break }
            $from += $hits.Count
        }
    }
}
