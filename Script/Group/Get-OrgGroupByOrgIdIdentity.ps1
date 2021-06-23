<#
.Synopsis Get AD-group for department by its Id
.Description Get AD-group for department by its Id.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

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

if ( $null -eq $Group )
{
	Write-Host "$( $msgTable.StrNotFound ) $UserInput"
}
else
{
	$Group | Out-Host
}

WriteLog -LogText "$UserInput" | Out-Null
EndScript
