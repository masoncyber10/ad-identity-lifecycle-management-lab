# 03-leaver.ps1
# Leaver: disable the account, record and remove its access, and move it to Disabled Users.
# Example: .\03-leaver.ps1 -Username jdoe -Reason "Termination"

param(
    [Parameter(Mandatory)] [string]$Username,
    [string]$Reason = "Termination"
)

Import-Module ActiveDirectory

$Domain     = "DC=masoncyber10,DC=com"
$DisabledOU = "OU=Disabled Users,OU=Corp,$Domain"
$Today      = Get-Date -Format yyyy-MM-dd

# 1. Disable first so sign-in is blocked immediately
Disable-ADAccount -Identity $Username

# 2. Record current groups before removing them (for audits or rehire)
$Groups = Get-ADPrincipalGroupMembership $Username | Where-Object Name -ne "Domain Users"
$GroupNames = ($Groups | Select-Object -ExpandProperty Name) -join ", "

# 3. Strip all group memberships except Domain Users (primary group, cannot be removed)
$Groups | ForEach-Object { Remove-ADGroupMember -Identity $_ -Members $Username -Confirm:$false }

# 4. Note the date, reason and removed groups on the account
Set-ADUser $Username -Description "Disabled $Today - $Reason - Groups removed: $GroupNames"

# 5. Move to Disabled Users
Get-ADUser $Username | Move-ADObject -TargetPath $DisabledOU

# Verify: Enabled should be False and MemberOf should be empty
Get-ADUser $Username -Properties Description, MemberOf |
    Select-Object Name, Enabled, Description, DistinguishedName, MemberOf
