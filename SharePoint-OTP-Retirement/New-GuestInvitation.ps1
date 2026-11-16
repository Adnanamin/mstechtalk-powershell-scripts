#Requires -Version 5.1
#Requires -Modules Microsoft.Graph.Authentication

<#
.SYNOPSIS
    Checks which external users already have an Entra B2B guest account and, with -Invite, invites the ones that
    don't, so they regain access to old SharePoint links.

.DESCRIPTION
    After SharePoint one-time passcode (SPO OTP) retirement, external users need a matching Microsoft Entra B2B
    guest account to open specific people links shared with them before the change.

    Without -Invite the script changes nothing. For each email address it looks for an existing user (by mail or
    other mail addresses), writes a plan CSV that says which addresses would be invited and which already have an
    account, and shows it.

    With -Invite it writes the same plan, then asks you to confirm each invitation. Each one CREATES a guest user
    in your directory and, unless you add -NoInvitationMessage, sends the guest an email. Use -WhatIf with -Invite
    to see the invitations without sending them. Addresses that already have an account are skipped.

    It signs in with Connect-MgGraph unless you are already connected with the scopes it needs.

    Module      : Microsoft.Graph.Authentication
    Permissions : Delegated User.Invite.All (to invite) and User.Read.All (to look for existing accounts), and an
                  Entra role or external collaboration setting that lets you invite guests
    Docs        : https://learn.microsoft.com/graph/api/invitation-post

.PARAMETER GuestEmail
    One or more email addresses. Accepts pipeline input, for example from Import-Csv with an Email column.
.PARAMETER RedirectUrl
    Where the guest lands after accepting, for example the SharePoint site the old links point to.
.PARAMETER NoInvitationMessage
    Create the guest account without sending the invitation email.
.PARAMETER PlanPath
    Where to write the plan CSV. Defaults to GuestInvitationPlan-<yyyyMMdd-HHmm>.csv in the current folder.
.PARAMETER Invite
    Send the invitations. Without it the script only writes the plan.

.EXAMPLE
    # Plan only: nothing changes
    .\New-GuestInvitation.ps1 -GuestEmail partner@fabrikam.com -RedirectUrl https://contoso.sharepoint.com/sites/Finance

.EXAMPLE
    # Test with one guest first, then invite
    .\New-GuestInvitation.ps1 -GuestEmail partner@fabrikam.com -RedirectUrl https://contoso.sharepoint.com/sites/Finance -Invite -WhatIf
    .\New-GuestInvitation.ps1 -GuestEmail partner@fabrikam.com -RedirectUrl https://contoso.sharepoint.com/sites/Finance -Invite

.EXAMPLE
    # Many guests from a CSV with an Email column
    Import-Csv .\Guests.csv | .\New-GuestInvitation.ps1 -RedirectUrl https://contoso.sharepoint.com/sites/Finance

.NOTES
    Author:      Adnan Amin
    Blog:        https://mstechtalk.com
    GitHub:      https://github.com/adnanamin/mstechtalk-powershell-scripts
    Tested:      16 November 2026 on the MST demo tenant (Windows PowerShell 5.1 and PowerShell 7.6.9): plan mode found an
                 existing account and marked a new address to invite; -Invite -WhatIf. No real invitation was sent.
.LINK
    https://mstechtalk.com/sharepoint-otp-retirement-guest-access-denied/
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
    [Alias('Email', 'Mail')]
    [string[]]$GuestEmail,

    [Parameter(Mandatory = $true)]
    [string]$RedirectUrl,

    [switch]$NoInvitationMessage,

    [string]$PlanPath = (Join-Path (Get-Location) ("GuestInvitationPlan-{0:yyyyMMdd-HHmm}.csv" -f (Get-Date))),

    [switch]$Invite
)

begin {
    $ErrorActionPreference = 'Stop'
    $scopes = @('User.Invite.All', 'User.Read.All')
    $context = Get-MgContext
    if (-not $context -or ($scopes | Where-Object { $context.Scopes -notcontains $_ })) {
        Connect-MgGraph -Scopes $scopes -NoWelcome
    }
    $addresses = New-Object System.Collections.Generic.List[string]
}

process {
    foreach ($address in $GuestEmail) {
        $trimmed = $address.Trim()
        if ($trimmed -and -not $addresses.Contains($trimmed.ToLowerInvariant())) {
            $addresses.Add($trimmed.ToLowerInvariant())
        }
    }
}

end {
    # --- 1. Look for existing accounts and build the plan --------------------------------------------------------
    $plan = foreach ($address in $addresses) {
        $value = $address.Replace("'", "''")
        $filter = [uri]::EscapeDataString("mail eq '$value' or otherMails/any(m:m eq '$value')")
        $uri = "https://graph.microsoft.com/v1.0/users?`$filter=$filter&`$count=true&`$select=id,displayName,userType,externalUserState"
        $found = @((Invoke-MgGraphRequest -Method GET -Uri $uri -Headers @{ ConsistencyLevel = 'eventual' }).value)

        if ($found.Count -gt 0) {
            [pscustomobject]@{
                GuestEmail = $address
                Action     = 'Skip: account already exists'
                UserType   = $found[0].userType
                State      = $found[0].externalUserState
                UserId     = $found[0].id
                Result     = ''
            }
        }
        else {
            [pscustomobject]@{
                GuestEmail = $address
                Action     = 'Invite'
                UserType   = ''
                State      = ''
                UserId     = ''
                Result     = ''
            }
        }
    }
    $plan = @($plan)
    $plan | Export-Csv -Path $PlanPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    $plan | Format-Table GuestEmail, Action, UserType, State -AutoSize | Out-String | Write-Host
    Write-Host "Plan saved to $PlanPath"

    if (-not $Invite) {
        Write-Host 'Nothing was changed. Review the plan, then run again with -Invite.'
        return
    }

    # --- 2. Invite ------------------------------------------------------------------------------------------------
    foreach ($row in ($plan | Where-Object { $_.Action -eq 'Invite' })) {
        if ($PSCmdlet.ShouldProcess($row.GuestEmail, 'Create a guest account and invite it')) {
            try {
                $body = @{
                    invitedUserEmailAddress = $row.GuestEmail
                    inviteRedirectUrl       = $RedirectUrl
                    sendInvitationMessage   = -not $NoInvitationMessage
                }
                $result = Invoke-MgGraphRequest -Method POST -Uri 'https://graph.microsoft.com/v1.0/invitations' -Body ($body | ConvertTo-Json) -ContentType 'application/json'
                $row.UserId = $result.invitedUser.id
                $row.State  = $result.status
                $row.Result = 'Invited'
            }
            catch {
                $row.Result = "Failed: $($_.Exception.Message)"
                Write-Warning "Invitation for $($row.GuestEmail) failed: $($_.Exception.Message)"
            }
        }
    }
    $plan | Export-Csv -Path $PlanPath -NoTypeInformation -Encoding UTF8 -WhatIf:$false
    $plan
}
