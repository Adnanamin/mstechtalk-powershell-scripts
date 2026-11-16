# SharePoint OTP retirement: give a guest access back

After SharePoint one-time passcode (SPO OTP) authentication retires, external users need a matching Microsoft Entra B2B guest account to open specific people links shared with them before the change. `New-GuestInvitation.ps1` checks which of them already have an account and invites the ones that don't.

> **Warning:** with `-Invite` this script makes a change. Each invitation creates a guest user in your directory and, unless you add `-NoInvitationMessage`, sends that person an email.

`New-GuestInvitation.ps1` is a change script, not a module function (see [CONVENTIONS.md](../CONVENTIONS.md)). It signs in to Microsoft Graph itself.

## Requirements

- Microsoft.Graph.Authentication module.
- Delegated `User.Invite.All` (to invite) and `User.Read.All` (to look for existing accounts).
- Your Entra role or external collaboration settings must allow you to invite guests.

## Usage

**Plan first.** Without `-Invite` nothing changes. The script writes a plan CSV that says, for each address, whether an account already exists or the address would be invited:

```powershell
.\New-GuestInvitation.ps1 -GuestEmail partner@fabrikam.com -RedirectUrl https://contoso.sharepoint.com/sites/Finance
```

For many guests, use a CSV with an `Email` column:

```powershell
Import-Csv .\Guests.csv | .\New-GuestInvitation.ps1 -RedirectUrl https://contoso.sharepoint.com/sites/Finance
```

**Test with one guest first,** then invite the rest. `-WhatIf` shows the invitations without sending them; without it you're asked to confirm each one. Addresses that already have an account are skipped:

```powershell
.\New-GuestInvitation.ps1 -GuestEmail partner@fabrikam.com -RedirectUrl https://contoso.sharepoint.com/sites/Finance -Invite -WhatIf
.\New-GuestInvitation.ps1 -GuestEmail partner@fabrikam.com -RedirectUrl https://contoso.sharepoint.com/sites/Finance -Invite
```

| Parameter | Description |
|---|---|
| `-GuestEmail` | One or more email addresses (aliases `Email`, `Mail`). Accepts pipeline input. |
| `-RedirectUrl` | Where the guest lands after accepting, for example the site the old links point to. |
| `-NoInvitationMessage` | Create the guest account without sending the email. |
| `-PlanPath` | Where to write the plan CSV. Defaults to `GuestInvitationPlan-<date>.csv` in the current folder. |
| `-Invite` | Send the invitations. Without it the script only writes the plan. |

With `-Invite` the plan CSV is written again at the end, with the new guest's `UserId` and the result for each address.

## How to undo

Delete the guest user in the Microsoft Entra admin center (**Users**), or with `Remove-MgUser -UserId <UserId from the plan CSV>`. A deleted user can be restored from **Deleted users** for 30 days. An invitation email that was already sent can't be recalled; once the account is deleted the link in it no longer works.

The other way to restore access is to share or reshare any one file, folder or site with the guest, which creates the account automatically.

| | |
|---|---|
| **Requires** | Graph |
| **Level** | User |
| **Permissions** | `User.Invite.All`, `User.Read.All` (delegated) |

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.

## Related article

- [Guests getting access denied on old SharePoint links after OTP retirement](https://mstechtalk.com/sharepoint-otp-retirement-guest-access-denied/)
