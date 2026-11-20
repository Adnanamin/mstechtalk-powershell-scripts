#Requires -Version 7.4
#Requires -Modules PnP.PowerShell

function Get-MttListItem {
    <#
    .SYNOPSIS
        Reads items from a SharePoint list of any size, including lists over the 5,000-item list view threshold.
    .DESCRIPTION
        Reads the list in pages, so a list of any size can be read without hitting the list view threshold.
        With -FilterField and -FilterValue, the filter runs on the server as a CAML query, which stays under the
        threshold only when the filter column is indexed and fewer than 5,000 items match. The function warns
        before it runs a filter on a column that isn't indexed on a list over 5,000 items.

        Each row has SiteUrl, List and Id, then one property for each column in -Field. Lookup and person
        columns return their display value; multi-value columns are joined with "; ".

        The function is read-only. It doesn't connect and doesn't export: sign in with Connect-PnPOnline first,
        and pipe the result to Export-Csv.
    .PARAMETER SiteUrl
        Site the list is on. It must be the site the current PnP connection is signed in to. Accepts pipeline
        input from Get-MttSite.
    .PARAMETER Library
        Title of the list or library to read.
    .PARAMETER Field
        Internal names of the columns to return. Defaults to Title, Created and Modified.
    .PARAMETER FilterField
        Internal name of the column to filter on. Index it first on a list over 5,000 items.
    .PARAMETER FilterValue
        Value the filter column must equal. Used with -FilterField.
    .PARAMETER PageSize
        Items read per request, from 1 to 5000. Defaults to 500.
    .EXAMPLE
        Get-MttListItem -SiteUrl https://contoso.sharepoint.com/sites/ServiceDesk -Library "Tickets" -Field Title, Status, Opened

        Reads every item in the Tickets list, in pages of 500.
    .EXAMPLE
        Get-MttListItem -SiteUrl https://contoso.sharepoint.com/sites/ServiceDesk -Library "Tickets" -FilterField Status -FilterValue "In progress"

        Reads only the items whose Status is In progress, filtered on the server.
    .EXAMPLE
        Get-MttListItem -SiteUrl https://contoso.sharepoint.com/sites/ServiceDesk -Library "Tickets" -Field Title, Status | Export-Csv .\Tickets.csv -NoTypeInformation -Encoding UTF8

        Saves the items as a CSV file.
    .EXAMPLE
        Get-MttListItem -SiteUrl https://contoso.sharepoint.com/sites/ServiceDesk -Library "Tickets" -Field Status | Group-Object Status | Select-Object Name, Count

        Counts the items per status.
    .OUTPUTS
        MSTechTalk.ListItem

        SiteUrl   Site the row belongs to
        List      Title of the list
        Id        Item ID
        <Field>   One property for each column in -Field
    .NOTES
        Author:      Adnan Amin (MSTechTalk.com)
        Module:      PnP.PowerShell 3.x
        Requires:    PnP
        Permissions: Read access to the list; your own Entra app registration for Connect-PnPOnline
        Level:       List
        Tested:      16 November 2026 on the MST demo tenant (PowerShell 7.6.9, PnP.PowerShell 3.5.0)
    .LINK
        https://mstechtalk.com/sharepoint-list-view-threshold-5000-fix/
    #>
    [CmdletBinding()]
    [OutputType('MSTechTalk.ListItem')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Url')]
        [string]$SiteUrl,

        [Parameter(Mandatory)]
        [Alias('List')]
        [string]$Library,

        [string[]]$Field = @('Title', 'Created', 'Modified'),

        [string]$FilterField,

        [string]$FilterValue,

        [ValidateRange(1, 5000)]
        [int]$PageSize = 500
    )

    begin {
        $connectHint = 'Connect-PnPOnline -Url <site URL> -Interactive -ClientId <your Entra app client ID>'
        try { $connection = Get-PnPConnection -ErrorAction Stop -Verbose:$false } catch { $connection = $null }
        if (-not $connection) {
            throw "Get-MttListItem needs a PnP PowerShell connection. Run: $connectHint"
        }
        if ($PSBoundParameters.ContainsKey('FilterField') -xor $PSBoundParameters.ContainsKey('FilterValue')) {
            throw 'Use -FilterField and -FilterValue together.'
        }

        function ConvertTo-MttFieldValue {
            param($Value)
            if ($null -eq $Value) { return $null }
            if ($Value -is [string] -or $Value -is [ValueType]) { return $Value }
            if ($Value -is [Collections.IEnumerable]) {
                return (@($Value | ForEach-Object { ConvertTo-MttFieldValue $_ }) -join '; ')
            }
            if ($Value.PSObject.Properties['LookupValue']) { return $Value.LookupValue }
            if ($Value.PSObject.Properties['Label']) { return $Value.Label }
            if ($Value.PSObject.Properties['Url']) { return $Value.Url }
            return "$Value"
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
            $list = Get-PnPList -Identity $Library -ErrorAction Stop -Verbose:$false
            if (-not $list) {
                Write-Warning "Skipped ${site}: no list named '$Library'."
                return
            }
        }
        catch {
            Write-Warning "Skipped ${site}: $($_.Exception.Message)"
            return
        }

        try {
            if ($FilterField) {
                $filterColumn = Get-PnPField -List $list -Identity $FilterField -ErrorAction Stop -Verbose:$false
                if ($list.ItemCount -gt 5000 -and -not $filterColumn.Indexed) {
                    Write-Warning "$FilterField isn't indexed and '$($list.Title)' has $($list.ItemCount) items. The filter will fail with the list view threshold error until the column is indexed."
                }

                $value = [Security.SecurityElement]::Escape($FilterValue)
                $viewFields = ($Field | ForEach-Object { "<FieldRef Name='$([Security.SecurityElement]::Escape($_))'/>" }) -join ''
                $query = "<View><ViewFields>$viewFields</ViewFields><Query><Where><Eq><FieldRef Name='$($filterColumn.InternalName)'/><Value Type='$($filterColumn.TypeAsString)'>$value</Value></Eq></Where></Query><RowLimit Paged='TRUE'>$PageSize</RowLimit></View>"
                Write-Verbose "Reading '$($list.Title)' where $FilterField = $FilterValue"
                $items = Get-PnPListItem -List $list -Query $query -PageSize $PageSize -ErrorAction Stop -Verbose:$false
            }
            else {
                Write-Verbose "Reading '$($list.Title)' ($($list.ItemCount) items) in pages of $PageSize"
                $items = Get-PnPListItem -List $list -PageSize $PageSize -Fields $Field -ErrorAction Stop -Verbose:$false
            }
        }
        catch {
            Write-Warning "Skipped $($list.Title): $($_.Exception.Message)"
            return
        }

        $count = 0
        foreach ($item in $items) {
            $count++
            $row = [ordered]@{
                PSTypeName = 'MSTechTalk.ListItem'
                SiteUrl    = $site
                List       = $list.Title
                Id         = $item.Id
            }
            foreach ($name in $Field) {
                if ($row.Contains($name)) { continue }
                $row[$name] = ConvertTo-MttFieldValue $item.FieldValues[$name]
            }
            [PSCustomObject]$row
        }
        Write-Verbose "Read $count items from '$($list.Title)'"
    }
}
