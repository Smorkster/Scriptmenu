<#
.Synopsis Get AD-group for department by its Id
.Description Get AD-group for department by its Id.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$UserInput = Read-Host "$( $msgTable.QID )"

if ( $UserInput.Length -eq 4 )
{
	$Filter = "($( $msgTable.CodeOrgIdPropName )=$( $msgTable.CodeOrgIdPropPrefix )-$UserInput)"
}
else
{
	$Filter = "(Name=$UserInput)"
}

$Group = Get-ADGroup -LDAPFilter $Filter -Properties ( $msgTable.CodeOrgIdPropName ) | Select-Object @{ Name = ( $msgTable.CodePropTitleOrg ); Expression = { $_.Name } }, @{ Name = ( $msgTable.CodePropTitleId ); Expression = { $_.( $msgTable.CodeOrgIdPropName ) -replace "$( $msgTable.CodeOrgIdPropPrefix )-", "" } }

if ( $Group -eq $null )
{
	Write-Host "$( $msgTable.StrNotFound ) $UserInput"
}
else
{
	$Group | Out-Host
}

WriteLog -LogText "$UserInput" | Out-Null
EndScript
