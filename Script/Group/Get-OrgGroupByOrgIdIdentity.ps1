<#
.Synopsis Get AD-group for department by its Id
.Description Get AD-group for department by its Id.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$UserInput = Read-Host "$( $msgTable.QID )"

if ( $UserInput.Length -eq 4 ) { $Filter = "($( $msgTable.CodeOrgIdPropName )=$( $msgTable.CodeOrgIdPropPrefix )-$UserInput)" }
else { $Filter = "(Name=$UserInput)" }

try
{
	$Group = Get-ADGroup -LDAPFilter $Filter -Properties ( $msgTable.CodeOrgIdPropName ) | Select-Object @{ Name = ( $msgTable.CodePropTitleOrg ); Expression = { $_.Name } }, @{ Name = ( $msgTable.CodePropTitleId ); Expression = { $_.( $msgTable.CodeOrgIdPropName ) -replace "$( $msgTable.CodeOrgIdPropPrefix )-", "" } }
	$Group | Out-Host
}
catch
{
	Write-Host "$( $msgTable.StrNotFound ) $UserInput"
	$eh = WriteErrorlogTest -LogText $_ -UserInput $UserInput -Severity "UserInputFail"
}

WriteLogTest -Text $Group.Name -UserInput $UserInput -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
EndScript
