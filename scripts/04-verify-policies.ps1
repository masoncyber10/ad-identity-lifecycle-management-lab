# 04-verify-policies.ps1
# Verification commands for the Group Policy and access-control parts of the lab.
# Run on the domain controller as an administrator.

Import-Module ActiveDirectory

$SalesOU = "OU=Sales,OU=Users,OU=Corp,DC=masoncyber10,DC=com"

# Domain password and lockout policy (set in Default Domain Policy)
Get-ADDefaultDomainPasswordPolicy

# GPOs linked to and inherited by the Sales OU
Get-GPInheritance -Target $SalesOU

# Lockout test: after 5 failed sign-ins, LockedOut should be True
Get-ADUser tuser -Properties LockedOut, BadLogonCount |
    Select-Object Name, LockedOut, BadLogonCount
# Unlock-ADAccount tuser

# HR share: share permissions (expect GG_HR_Staff = Change)
Get-SmbShareAccess -Name HR

# HR folder: NTFS permissions (expect GG_HR_Staff = Modify)
(Get-Acl C:\Shares\HR).Access | Select-Object IdentityReference, FileSystemRights

# On the client, signed in as the test user:
#   gpresult /r /scope user          -> Sales - Workstation Restrictions should be listed
#   whoami /groups | findstr GG_     -> shows the groups the current sign-in session has
