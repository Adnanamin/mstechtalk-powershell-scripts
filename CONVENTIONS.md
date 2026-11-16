# Script conventions

How scripts in this repository are written, named and documented. Every new script follows these rules, and the existing scripts are converted to them one at a time.

The goal is a public, read-only PowerShell module, **MSTechTalk.M365**, assembled from the report functions in this repository. Each function links to the [MSTechTalk](https://mstechtalk.com) post that explains it.

## Two kinds of script

| Kind | What it does | Form | Name | In the module |
|---|---|---|---|---|
| **Report function** | Only reads and reports | One function per file | `Verb-MttNoun` | Yes |
| **Change script** | Creates, changes or deletes anything | Standalone script with safety switches | `Verb-Noun`, no `Mtt` prefix | Never |

If a script both reads and changes, it is a change script.

## Report functions

### Files and names

- One function per file. The file name is the function name: `Get-MttUniquePermission.ps1`.
- Nothing runs at file level except `#Requires` lines. Loading the file only defines the function.
- Name format: `Verb-Mtt<Noun>`, with a singular noun and an approved verb. Report functions use read verbs only: `Get`, `Find`, `Measure`, `Test` and `Export`. `Start` is allowed for a job that only produces a report.
- Before choosing a name, check the catalogue in the root README so the new name fits the existing set.

### Sign-in

- A function never connects. It does not call `Connect-PnPOnline`, `Connect-MgGraph` or `Connect-SPOService`.
- In `begin`, it checks that the sign-in it needs exists. If it doesn't, it stops with a message that names the command to run, for example:

  > Get-MttSiteStorage needs a SharePoint Online Management Shell connection. Run: Connect-SPOService -Url https://contoso-admin.sharepoint.com

- Each function needs exactly one service where possible. Its help has a `Requires:` line naming it, and the root README catalogue shows the same value.

| Requires | Module | Sign-in |
|---|---|---|
| PnP | PnP.PowerShell 3.x | `Connect-PnPOnline` with your own Entra app (`-ClientId`) |
| Graph | Microsoft.Graph.Authentication, plus sub-modules only if needed | `Connect-MgGraph` with the scopes in the function help |
| SPO | Microsoft.Online.SharePoint.PowerShell | `Connect-SPOService` to the admin URL |
| None | No module | No sign-in (for example, a function that reads local files or a downloaded report) |

- Prefer PnP for SharePoint, OneDrive and Teams sites, and Graph for users, groups, licences, Copilot and usage. Use SPO only when neither has an equivalent, and say so in the function's `.NOTES`.
- PnP.PowerShell and Microsoft Graph PowerShell work in one PowerShell session. This was tested on 16 November 2026 with PnP.PowerShell 3.5.0 and Microsoft.Graph.Authentication 2.41.2 on PowerShell 7.6.9, in both load orders. Retest before raising either minimum version.

### Parameters

Use these names everywhere they apply. Don't invent synonyms.

| Parameter | Use |
|---|---|
| `-SiteUrl` | Site to report on. `[Alias('Url')]`, accepts `ValueFromPipeline` and `ValueFromPipelineByPropertyName` |
| `-Library` | One library or list on the site |
| `-User` | One user, by user principal name |
| `-Days` | A look-back period |

Narrower levels are parameters, and wider levels come in through the pipeline. Don't write one function per level:

```powershell
Get-MttUniquePermission -SiteUrl https://contoso.sharepoint.com/sites/Projects                       # one site
Get-MttUniquePermission -SiteUrl https://contoso.sharepoint.com/sites/Projects -Library "Documents"  # one library
Get-MttSite | Get-MttUniquePermission                                                                # whole tenant
```

### Output

- Return `[PSCustomObject]` rows to the pipeline as they are found. Don't use `Export-Csv`, an `-OutputPath` parameter or `Format-*` inside the function. The caller exports.
- Set `PSTypeName = 'MSTechTalk.<Noun>'` and declare `[OutputType('MSTechTalk.<Noun>')]`.
- Use PascalCase property names. Every row has a `SiteUrl` or `UserPrincipalName` property, so results from many sites can be combined.
- Dates are `[datetime]`. Sizes are numbers with the unit in the name, such as `StorageUsedGB`.
- Once a function is published, never rename or remove a property. Only add new ones.

### Progress and errors

- Don't use `Write-Host` for data. Use `Write-Progress` and `Write-Verbose` for progress, and `Write-Warning` for a skipped item.
- Wrap each item in `try`/`catch`, log the failure and continue. A run over 5,000 sites must not stop at site 12.
- Handle paging (`-All`, `-PageSize`, `@odata.nextLink`), throttling (honour `Retry-After` on 429 and 503) and the list view threshold. Filter on the server (`-Filter`, `$select`) rather than with `Where-Object` after fetching everything.

### Help

Comment-based help inside the function, with:

- `.SYNOPSIS`, `.DESCRIPTION` and a `.PARAMETER` for each parameter
- at least two `.EXAMPLE` blocks: one for a single site and one piped to `Export-Csv`
- `.OUTPUTS` with the type name
- `.NOTES` with Author, Module, Requires, Permissions, Level and Tested
- `.LINK` set to the blog post URL, so `Get-Help <function> -Online` opens the post. Use `[POST URL]` until the post is live.

### Template

```powershell
#Requires -Version 7.4
#Requires -Modules PnP.PowerShell

function Get-MttUniquePermission {
    <#
    .SYNOPSIS
        One line: what the function reports.
    .DESCRIPTION
        When to use it and what each output row means.
    .PARAMETER SiteUrl
        Site to report on. Accepts pipeline input from Get-MttSite.
    .PARAMETER Library
        One library or list on the site. Leave it out to report on the whole site.
    .EXAMPLE
        Get-MttUniquePermission -SiteUrl https://contoso.sharepoint.com/sites/Projects
    .EXAMPLE
        Get-MttSite | Get-MttUniquePermission | Export-Csv .\UniquePermissions.csv -NoTypeInformation -Encoding UTF8
    .OUTPUTS
        MSTechTalk.UniquePermission
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      PnP.PowerShell 3.x
        Requires:    PnP
        Permissions: Site collection admin on the site
        Level:       Site, Library
        Tested:      [date on the MST demo tenant, or "Not yet tested"]
    .LINK
        [POST URL]
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
        # Stop with a clear message if the PnP sign-in is missing
    }
    process {
        # try / catch per item; emit one object per finding
        [PSCustomObject]@{
            PSTypeName = 'MSTechTalk.UniquePermission'
            SiteUrl    = $SiteUrl
        }
    }
}
```

### How a reader runs it

Every blog post and folder README shows these three lines:

```powershell
Connect-PnPOnline -Url $SiteUrl -Interactive -ClientId $ClientId
. .\Get-MttUniquePermission.ps1
Get-MttUniquePermission -SiteUrl $SiteUrl | Export-Csv .\UniquePermissions.csv -NoTypeInformation -Encoding UTF8
```

Once the module is on the PowerShell Gallery, the dot-source line is replaced by `Install-Module MSTechTalk.M365` and `Import-Module MSTechTalk.M365`.

## Change scripts

- Standalone `.ps1` with `[CmdletBinding(SupportsShouldProcess)]`, so `-WhatIf` works.
- Report first: export what would change, then act only with an explicit switch.
- Connecting and exporting inside the script is fine.
- The folder README carries a clear warning, says how to test on one site or user first, and says how to undo.
- These scripts never take the `Mtt` prefix and never enter the module.

## Both kinds

- PowerShell 7.4 or later, unless the script only needs Windows PowerShell 5.1 and says so.
- `#Requires -Version` and `#Requires -Modules` where they apply.
- No retired modules: AzureAD, AzureADPreview and MSOnline are not used.
- Least privilege. List the exact roles or Graph scopes in the help and the folder README, and say why when a broad permission is the only option.
- No aliases (`%`, `?`, `select`). Comments only where the intent isn't obvious.

## Repository layout

```text
README.md                Catalogue: every script, its level, what it requires and its blog post
CONVENTIONS.md           This file
<Product-Topic>/         One folder per blog topic, for example SharePoint-Unique-Permissions
  README.md              Scenario, permissions, parameters, output columns, how to run, post link
  Get-Mtt<Noun>.ps1      Report functions
  Verb-Noun.ps1          Change scripts
  samples/               Sample output with demo values only
```

Planned additions: `CHANGELOG.md`, a `build.ps1` that copies every `Mtt` function into `module/MSTechTalk.M365/`, and `tests/` for Pester and PSScriptAnalyzer.

- New topic folders use the `Product-Topic` naming.
- Blog posts link to the **topic folder**, not to a file, so renaming a file never breaks a post.
- Rename a file with `git mv` so its history is kept, and update the folder README, the root README and the blog post in the same sitting.

## Root README catalogue

Each script has one row in the catalogue table in the root README.

| Column | Values |
|---|---|
| Script | File name. Change scripts are marked *(changes data)* |
| Folder | Link to the topic folder |
| Level | What it reports on: Tenant, Site, Library, List, User, or a combination |
| Requires | The sign-in it needs: PnP, Graph, SPO or None, as in the sign-in table above |
| Blog post | Direct link to the post, not the blog home page |

## Before every push

- No real tenant names, URLs, IDs, client IDs, secrets or certificates. Use `contoso` in examples, or the MST demo tenant in samples.
- No personal email addresses in scripts, READMEs or sample CSVs.
- The `Tested:` line is filled in for any function that is ready for the module.

## Commits and versions

- Commit messages: `feat:`, `fix:`, `docs:`, `refactor:` and `chore:`. A conversion is committed as `refactor: convert <old name> to <new name>`.
- One commit per function where practical.
- Module versions follow `0.x` while functions are being added. `1.0.0` means function names and output properties are stable.
