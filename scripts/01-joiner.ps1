# 01-joiner.ps1
# Joiner: create a new user in their department OU and grant access through the department group.
# Example: .\01-joiner.ps1 -Name "Jane Doe" -Username jdoe -Department HR -Title "HR Specialist"

param(
    [Parameter(Mandatory)] [string]$Name,
    [Parameter(Mandatory)] [string]$Username,
    [Parameter(Mandatory)] [ValidateSet("IT", "HR", "Finance", "Sales")] [string]$Department,
    [string]$Title = ""
)

Import-Module ActiveDirectory

$Domain = "DC=masoncyber10,DC=com"
$OU     = "OU=$Department,OU=Users,OU=Corp,$Domain"
$Group  = "GG_$($Department)_Staff"
$First, $Last = $Name -split " ", 2

# Create the account in the department OU (password is typed at runtime, never stored)
New-ADUser -Name $Name -GivenName $First -Surname $Last `
    -SamAccountName $Username -UserPrincipalName "$Username@masoncyber10.com" `
    -Department $Department -Title $Title -Path $OU `
    -AccountPassword (Read-Host -AsSecureString "Temporary password for $Username") `
    -ChangePasswordAtLogon $true -Enabled $true

# Grant access through group membership, not direct permissions
Add-ADGroupMember -Identity $Group -Members $Username

# Verify
Get-ADUser $Username -Properties Department, MemberOf |
    Select-Object Name, Enabled, Department, DistinguishedName, MemberOf
