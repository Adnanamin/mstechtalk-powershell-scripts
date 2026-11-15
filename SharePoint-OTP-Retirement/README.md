# SharePoint OTP retirement: give a guest access back

After SharePoint one-time passcode (SPO OTP) authentication retires, external users need a matching Microsoft Entra B2B guest account to open specific people links shared with them before the change. `New-GuestInvitation.ps1` creates that guest account by sending an Entra B2B invitation.

**This script makes a change:** it creates a guest user in your directory. It has not been tested on the demo tenant.

## Requirements

- Microsoft.Graph.Identity.SignIns module, delegated `User.Invite.All`.
- Your Entra external collaboration settings must allow you to invite guests.

## Usage

```powershell
.\New-GuestInvitation.ps1 -GuestEmail <guest-email-address> -RedirectUrl https://contoso.sharepoint.com/sites/Finance
```

The other way to restore access is to share or reshare any one file, folder or site with the guest, which creates the account automatically.

## Author

**Adnan Amin** is a Microsoft MVP since 2015 and a Microsoft technology consultant with over 20 years of experience in Microsoft technologies.

- **Blog:** https://mstechtalk.com
- **GitHub:** https://github.com/adnanamin

## Disclaimer

These scripts are provided as-is, without warranties. Review the code and test it in a suitable environment before production use.

## Related article

- [Guests getting access denied on old SharePoint links after OTP retirement](https://mstechtalk.com/sharepoint-otp-retirement-guest-access-denied/)
