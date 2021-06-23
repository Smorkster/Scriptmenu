<#
.Synopsis Add AD-groups, pasted in console [BO]
.Requires Role_Backoffice
.Description Creates permissions for multiple given AD-groups.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force -Argumentlist $args[1]
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -Argumentlist $args[1]

$User = Read-Host $msgTable.QID
if ( dsquery user -samid $User )

{
	Write-Host $msgTable.QIDList
	$Groups = GetConsolePasteInput -Folders | Where-Object { $_ -ne "" }

	$added = @()
	$noPermission = @()
	$other = @()
	foreach ( $group in $Groups )
	{
		try
		{
			if ( dsquery group -samid $group )
			{
				Add-ADGroupMember -Identity $group -Members $User
				$t = "$( $msgTable.WAdded ) '$group'"
				$added += $group
			}
			else
			{
				$t =  "$( $msgTable.ErrNoADGroup ) '$group'"
			}
		}
		catch
		{
			WriteErrorLog -LogText $_
			if ( $_.Exception.Message -eq "Insufficient access rights to perform the operation" )
			{
				$noPermission += $group
				$t = "$( $msgTable.ErrNoPermission ) '$group'"
			}
			else
			{
				$other += ,@( $group, $_.Exception.Message )
				$t = "$( $msgTable.ErrOther ) '$group':`n`t$_.Exception.Message"
			}
		}
		Write-Host $t
	}

	Write-Host "`n$( $msgTable.WAddedGroupCount ) $( ( Get-ADUser $User ).Name ): $( @( $added ).Count )."
	if ( $noPermission.Count -gt 0 )
	{
		if ( ( Read-Host "$( $msgTable.QOtherPermissions ) ( Y / N ) " ) -eq "Y" )
		{
			"$( $msgTable.WQuestion ) $User :`n`n$noPermission" | clip
			Write-Host $( $msgTable.WMessage )
		}
	}
	$logText = "$User $( @( $added ).Count ) $( $msgTable.WLogGroupsCount )"
}
else
{
	Write-Host "$( $msgTable.ErrNoAccount ) '$User'"
	$logText = $msgTable.WErrMessage
}


WriteLog -LogText $logText | Out-Null
EndScript