<#
.Synopsis Get AD-group for department by its Id
.Description Get AD-group for department by its Id.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CaseNr = Read-Host "Related casenumber (if any) "
$UserInput = Read-Host "Give Id for department or name in AD (t.ex. 'ABCD' or 'Org_A_Users')"

if ( $UserInput.Length -eq 4 )
{
	$Filter = "(orgIdentity=$UserInput)"
}
else
{
	$Filter = "(Name=$UserInput)"
}

$Group = Get-ADGroup -LDAPFilter $Filter -Properties hsaIdentity | select @{ Name = "Org-group name"; Expression = { $_.Name } }, @{ Name = "Department Id"; Expression = { $_.orgIdentity } }

if ( $Group -eq $null )
{
	Write-Host "No AD-group found by input '$UserInput'"
}
else
{
	$Group
}

WriteLog -LogText "$CaseNr $UserInput"
EndScript
