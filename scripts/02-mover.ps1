# 02-mover.ps1
# Mover: move a user to a new department OU, remove old access and grant new access.
# Example: .\02-mover.ps1 -Username jdoe -FromDepartment HR -ToDepartment Finance -Title "Financial Analyst"

param(
    [Parameter(Mandatory)] [string]$Username,
    [Parameter(Mandatory)] [ValidateSet("IT", "HR", "Finance", "Sales")] [string]$FromDepartment,
    [Parameter(Mandatory)] [ValidateSet("IT", "HR", "Finance", "Sales")] [string]$ToDepartment,
    [string]$Title = ""
)

Import-Module ActiveDirectory

$Domain   = "DC=masoncyber10,DC=com"
$TargetOU = "OU=$ToDepartment,OU=Users,OU=Corp,$Domain"

# Move the account (OU placement controls which GPOs apply)
Get-ADUser $Username | Move-ADObject -TargetPath $TargetOU

# Remove old access first to prevent privilege creep, then add new access
Remove-ADGroupMember -Identity "GG_$($FromDepartment)_Staff" -Members $Username -Confirm:$false
Add-ADGroupMember   -Identity "GG_$($ToDepartment)_Staff"   -Members $Username

# Update directory attributes
if ($Title) { Set-ADUser $Username -Department $ToDepartment -Title $Title }
else        { Set-ADUser $Username -Department $ToDepartment }

# Verify (the user must sign out and back in for new group membership to take effect)
Get-ADUser $Username -Properties Department, MemberOf |
    Select-Object Name, Department, DistinguishedName, MemberOf
