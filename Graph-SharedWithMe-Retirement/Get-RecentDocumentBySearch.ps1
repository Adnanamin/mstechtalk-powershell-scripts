<#
.SYNOPSIS
    Lists the signed-in user's most recently modified documents with the Microsoft Search API.
.DESCRIPTION
    A replacement approach for the retired /me/drive/recent endpoint. Results are trimmed to what the
    signed-in user can access, so run it as an ordinary user to see what they see.
.NOTES
    Author:      Adnan Amin
    Blog:        https://mstechtalk.com
    GitHub:      https://github.com/adnanamin/mstechtalk-powershell-scripts
    Module:      Microsoft.Graph.Authentication
    Permissions: Delegated Files.Read.All and Sites.Read.All
    Tested:      15 November 2026 (PowerShell 7.6, Microsoft.Graph.Authentication 2.41.2)
.LINK
    https://mstechtalk.com/graph-sharedwithme-recent-retired-search-api/
#>
param(
    [int]$Size = 25
)

Connect-MgGraph -Scopes "Files.Read.All", "Sites.Read.All" -NoWelcome

$body = @{
    requests = @(
        @{
            entityTypes    = @("driveItem")
            query          = @{ queryString = "IsDocument:true" }
            sortProperties = @(@{ name = "lastModifiedDateTime"; isDescending = $true })
            from           = 0
            size           = $Size
        }
    )
} | ConvertTo-Json -Depth 6

try {
    $response = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/search/query" `
        -Body $body -ContentType "application/json" -ErrorAction Stop

    $response.value[0].hitsContainers[0].hits | ForEach-Object {
        [PSCustomObject]@{
            Name     = $_.resource.name
            Modified = $_.resource.lastModifiedDateTime
            Url      = $_.resource.webUrl
        }
    }
}
catch {
    Write-Warning "Search failed: $($_.Exception.Message)"
}
