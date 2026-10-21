# Project notes: Active Directory Identity Lifecycle Management Lab


## Environment
- Hypervisor: Oracle VirtualBox
- Domain controller: Windows Server 2019, domain `masoncyber10.com`
- Client: Windows 10, joined to the domain

## OU and group design
```
masoncyber10.com
├── Admin                 (privileged accounts, kept separate from Corp)
└── Corp
    ├── Users
    │   ├── IT
    │   ├── HR
    │   ├── Finance
    │   └── Sales
    ├── Groups            (GG_IT_Staff, GG_HR_Staff, GG_Finance_Staff, GG_Sales_Staff)
    ├── Computers
    │   ├── Workstations
    │   └── Servers
    ├── Service Accounts
    └── Disabled Users
```
<img width="170" height="215" alt="01-ou-structure" src="https://github.com/user-attachments/assets/93f48487-a7c1-43a8-816a-5c53a19ef322" />

- Built-in containers (Users, Computers, Builtin) were left alone: GPOs cannot be linked to containers.
- Access is granted through global security groups (GG_ prefix), never directly to users.
- Groups were created in ADUC as a Group object (not an OU), with Group scope = Global and Group type = Security.

<img width="214" height="98" alt="02-security-groups" src="https://github.com/user-attachments/assets/2586e0f2-7ff6-4179-ae31-55e0fca7a217" />

## Joiner-mover-leaver (test user: Jane Doe, jdoe)
- Joiner: created in HR, added to GG_HR_Staff, forced password change at first sign-in.
- Mover: moved to Finance, removed from GG_HR_Staff, added to GG_Finance_Staff.
- Leaver: disabled, groups recorded then removed, Description set with date and reason, moved to Disabled Users.

<img width="354" height="35" alt="03-leaver-jane-disabled" src="https://github.com/user-attachments/assets/419c3e60-6e0f-4797-b49d-b6b2de65d98a" />


## Group Policy
- Default Domain Policy: 12-character minimum, complexity on, 90-day max age, 1-day min age, 24-password history, reversible encryption disabled.
- Configured in Group Policy Management: Default Domain Policy > Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies.
- Lockout: 5 invalid attempts, 15-minute duration, 15-minute counter reset.

<img width="1136" height="558" alt="04-password-policy" src="https://github.com/user-attachments/assets/51481d04-556b-4fea-8365-1c2f881c4b65" />
<img width="1137" height="566" alt="05-lockout-policy" src="https://github.com/user-attachments/assets/071bb72b-e8ee-4359-b0bc-e2583eb5d2f8" />

- Lockout test: created test user `tuser` in Sales, ran `runas /user:masoncyber10\tuser cmd` and entered a wrong password 5 times,
  confirmed `LockedOut = True` with `Get-ADUser tuser -Properties LockedOut, BadLogonCount`.
  Unlocked with `Unlock-ADAccount tuser` (or in ADUC: user Properties > Account > Unlock account).
- "Sales - Workstation Restrictions" GPO linked to the Sales OU: blocks Control Panel and Command Prompt.
  Created in Group Policy Management by right-clicking the Sales OU > Create a GPO in this domain, and Link it here.
  Settings under User Configuration > Policies > Administrative Templates:
  Control Panel > Prohibit access to Control Panel and PC settings; System > Prevent access to the command prompt.
  Tested by signing in to the client as a Sales user and an IT user: only the Sales user was restricted.
  Verified with `gpresult /r` as the Sales user.

  <img width="1221" height="558" alt="06-sales-gpo-control-panel" src="https://github.com/user-attachments/assets/a2af6a69-e19e-40c2-b048-1539d15da171" />



## Access proof (test user: Bob Smith, bsmith)
- HR share `C:\Shares\HR`: share permission GG_HR_Staff = Change, NTFS GG_HR_Staff = Modify, inheritance disabled, Users removed.
- Created test user Bob Smith in the HR OU and added him to GG_HR_Staff.
- On the client VM, signed in as Bob, opened `\\DCDC\HR` with Win + R and created a text file.
- Moved Bob to the Finance OU, removed him from GG_HR_Staff and added him to GG_Finance_Staff.
- After signing out and back in, opening `\\DCDC\HR` returned "Access is denied."

<img width="397" height="200" alt="07-hr-share-run-path" src="https://github.com/user-attachments/assets/526bdb12-230d-4cf2-a3d0-a1c909d5e119" />
<img width="1130" height="594" alt="08-hr-access-denied-after-move" src="https://github.com/user-attachments/assets/d91c9635-6e89-41bf-858f-1a2d6edf3a4b" />


## Troubleshooting
- Move-ADObject failed ("object's parent is either uninstantiated or deleted"): the target OU path didn't match.
  The OU is named `Users` (plural), not `User`.
  Fix: looked up the exact path with `Get-ADOrganizationalUnit -Filter 'Name -eq "Finance"'` and removed spaces after commas.
- `\\masoncyber10.com\HR` showed "Item Not Found": domain-name paths are for domain-based shares (SYSVOL, NETLOGON).
  Fix: used the server name, `\\DCDC\HR`.
- Leaver still showed `Enabled: True` during verification: the disable step hadn't run. Caught by checking, then re-ran `Disable-ADAccount`.
- Access denied for a user already in GG_HR_Staff: Windows reads group membership at sign-in.
  Fix: signed out and back in, confirmed with `whoami /groups`.
- Client VM froze with two VMs running: not enough RAM. Fix: adjusted VM memory and installed Guest Additions.

## Production considerations
- Joiner-mover-leaver would be triggered by an HR system (e.g. Workday), not done by hand.
- Manager approval before access is granted; periodic access reviews to catch privilege creep.
- Automation through tools such as Entra ID, Okta or SailPoint.
- Disabled accounts deleted after a 30-90 day retention period.
