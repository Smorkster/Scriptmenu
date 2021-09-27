<#
.Synopsis List folders for wich a user is listed as owner
.Description List folders for wich a user is listed as owner.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$UserInput = Read-Host "$( $msgTable.QID )"

try
{
	$User = Get-ADUser -Identity $UserInput -Properties *

	$Folders = Get-ADGroup -LDAPFilter "(&(ManagedBy=$( $User.DistinguishedName ))(&(Name=*_Fil_*_Grp_*_User_*)(|(Name=*User_C)(Name=*User_R))))" -Properties Description  | ForEach-Object { ( ( $_.Description -split "\." )[0] -split "\$" )[1] } | Select-Object -Unique | ForEach-Object { "G:$_" }

	Write-Host "`n$( $User.Name ) $( $msgTable.StrSumTitle ) " -NoNewline
	if ( $Folders.Count -gt 0 )
	{
		Write-Host "$( $msgTable.StrOwner ):"
		$Folders | Sort-Object -Unique | Out-Host
		$outputFile = WriteOutput -Output "$( $msgTable.OutIsOwnerOf )`n$Folders"
		$logText = "$( $User.Name ) $( $msgTable.LogOwnerCount ) $( @( $Folders ).Count ) $( $msgTable.LogOwnerCount2 )"
	}
	else
	{
		Write-Host "$( $msgTable.StrNotOwner )."
		$logText = "$( $User.Name ) $( $msgTable.StrLogNotOwner )"
	}
}
catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
{
	Write-Host "$( $msgTable.StrNoUser ) $UserInput"
	$logText = "$UserInput $( $msgTable.StrLogNoUser )"
	$eh = WriteErrorlogTest -LogText $_ -UserInput $UserInput -Severity "UserInputFail"
}
catch { $eh = WriteErrorlogTest -LogText $_ -UserInput $UserInput -Severity "OtherFail" }

WriteLogTest -Text $logText -UserInput $UserInput -Success ( $null -eq $eh ) -ErrorLogHash $eh -OutputPath $outputFile | Out-Null
EndScript
