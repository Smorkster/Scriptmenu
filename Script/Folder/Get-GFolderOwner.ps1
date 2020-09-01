<#
.Synopsis List folders for wich a user is listed as owner
.Description List folders for wich a user is listed as owner.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$Folders = @()

$CaseNr = Read-Host "Related casenumber (if any) "
$Input = Read-Host "User-id"

try
{
	$User = Get-ADUser -Identity $Input -Properties *

	$Groups = Get-ADGroup -LDAPFilter "(ManagedBy=$( $User.DistinguishedName ))" | where { $_ -like "*_File_*_Grp_*_User_*" } | select -ExpandProperty SamAccountName

	foreach ( $Group in $Groups )
	{
		$Folders += "G:$( ( ( ( ( Get-ADGroup $Group -Properties Description | Select -ExpandProperty Description ) -split "\$" )[1] ) -split "\." )[0] )"
	}

	Write-Host "`nUser $( $User.Name ) is " -NoNewline
	if ( $Folders.Count -gt 0 )
	{
		Write-Host "owner of these folders:"
		$Folders | Sort-Object -Unique
		$outputFile = WriteOutput -Output $Folders
		$logText = "$Input $outputFile"
	}
	else
	{
		Write-Host "not owner of any folder."
		$logText = "$User not owner"
	}
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
{
	Write-Host "Found no useraccount for $Input"
	$logText = "$Input does not exist in AD"
}

WriteLog -LogText "$CaseNr $logText"

EndScript
