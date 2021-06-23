<#
.Synopsis List folders for wich a user is listed as owner
.Description List folders for wich a user is listed as owner.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$Folders = @()

$UserInput = Read-Host "$( $msgTable.QID )"

try
{
	$User = Get-ADUser -Identity $Input -Properties *

	$Groups = Get-ADGroup -LDAPFilter "(ManagedBy=$( $User.DistinguishedName ))" | Where-Object { $_ -like "*_Fil_*_Grp_*_User_*" } | Select-Object -ExpandProperty SamAccountName

	foreach ( $Group in $Groups )
	{
		$Folders += "G:$( ( ( ( ( Get-ADGroup $Group -Properties Description | Select-Object -ExpandProperty Description ) -split "\$" )[1] ) -split "\." )[0] )"
	}

	Write-Host "`n$( $User.Name ) $( $msgTable.StrSumTitle ) " -NoNewline
	if ( $Folders.Count -gt 0 )
	{
		Write-Host "$( $msgTable.StrOwner ):"
		$Folders | Sort-Object -Unique
		$outputFile = WriteOutput -Output $Folders
		$logText = "$Input $outputFile"
	}
	else
	{
		Write-Host "$( $msgTable.StrNotOwner )."
		$logText = "$User $( $msgTable.StrLogNotOwner )"
	}
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
{
	Write-Host "$( $msgTable.StrNoUser ) $Input"
	$logText = "$Input $( $msgTable.StrLogNoUser )"
	WriteErrorLog -LogText $_
}
catch { WriteErrorLog -LogText $_ }

WriteLog -LogText "$logText" | Out-Null
EndScript
