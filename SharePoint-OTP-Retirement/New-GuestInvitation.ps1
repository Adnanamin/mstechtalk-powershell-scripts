<#
.SYNOPSIS
    Creates an Entra B2B guest account so an external user regains access to old SharePoint links.
.DESCRIPTION
    After SharePoint one-time passcode (SPO OTP) retirement, external users need a matching Entra B2B
    guest account. This sends a guest invitation. It CREATES a user in your directory: not part of the
    test runners on purpose.
.NOTES
    Author:      Adnan Amin
    Blog:        https://mstechtalk.com
    GitHub:      https://github.com/adnanamin/mstechtalk-powershell-scripts
    Module:      Microsoft.Graph.Identity.SignIns
    Permissions: Delegated User.Invite.All
    Tested:      Not yet tested (it creates a real guest account)
.LINK
    https://mstechtalk.com/sharepoint-otp-retirement-guest-access-denied/
#>
param(
    [Parameter(Mandatory)][string]$GuestEmail,
    [string]$RedirectUrl = "https://mstalk.sharepoint.com/sites/MST-Finance"  # Replace with your own
)

Connect-MgGraph -Scopes "User.Invite.All" -NoWelcome

try {
    New-MgInvitation -InvitedUserEmailAddress $GuestEmail `
        -InviteRedirectUrl $RedirectUrl `
        -SendInvitationMessage:$true -ErrorAction Stop
}
catch {
    Write-Warning "Invitation failed: $($_.Exception.Message)"
}
