<#
.Synopsis List groups a user is member of
.Description List groups a user is member of.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$UserInput = Read-Host $msgTable.QID
$success = $true

if ( !( dsquery User -samid $UserInput ) )
{
	Write-Host "`n$( $msgTable.ErrWID ) $UserInput!" -ForegroundColor Red
	$errorHash = WriteErrorLogTest -LogText $msgTable.ErrID -UserInput $UserInput -Severity "UserInputFail"
	$success = $false
}
else
{
	$output = @()
	$User = Get-ADUser $UserInput -Properties *
	if ( $GaiaGroups = Get-ADPrincipalGroupMembership $User | Where-Object { $_.SamAccountName -notlike "*_org_*" } | Where-Object { $_.SamAccountName -ne "Domain Users" } | Select-Object -ExpandProperty SamAccountName | Sort-Object )
	{
		$output += $User.Name + " $( $msgTable.WGroupTitle ):"
		$GaiaGroups | Sort-Object | ForEach-Object { $output += "`t$( $_ )" }
	}
	else
	{
		$output += $User.Name + " $( $msgTable.WNoGroups )."
	}

	if ( $OrgGroups = Get-ADPrincipalGroupMembership $User | Where-Object { $_.SamAccountName -like "*_org_*" } | Select-Object -ExpandProperty SamAccountName | Sort-Object )
	{
		$output += "`r`n$( $msgTable.WGroupCont ):"
		foreach ( $g in $orggroups)
		{
			Get-ADGroup $g -Properties hsaidentity | ForEach-Object { $output += "$( $_.Name ) - $( $_.hsaidentity )" }
			Get-ADPrincipalGroupMembership $g | Sort-Object | ForEach-Object { $output += "`t" + $_.Name }
		}
	}
	else
	{
		$output += "`n$( $msgTable.WGroupNoCont )"
	}

	Start-Sleep -Milliseconds 500
}

if ( $output )
{
	$outputFile = WriteOutput -Output $output
	Write-Host "$( $msgTable.WSummaryFile ) '$outputFile'"
	Start-Process notepad $outputFile
}

if ( ( $copy = Read-Host "$( $msgTable.QQuestion )? ( Y / N )" ) -eq "Y" )
{
	$cloneTarget = Read-Host "$( $msgTable.QQID )"
	$message = @("$( $msgTable.MQ1 ) $( $User.Name ) $( $msgTable.MQ2 ):")
	$GaiaGroups | Sort-Object | ForEach-Object { $message += "`t$( $_ )" }
	$message += "$( $msgTable.MQ3 ) [ $( ( Get-ADUser $cloneTarget ).Name ) ]."
	$message += $msgTable.MQ4
	$message += $msgTable.MQ5
	$message += $msgTable.MQ6
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$message | clip
	Write-Host "$( $msgTable.WQCopy )"
}

WriteLogTest -Text "$( $msgTable.LogMessage ) $UserInput `n$( $msgTable.LogMessageCloneTarget ): $cloneTarget`n$( $msgTable.LogMessageCopy ): $copy" -Success $success -UserInput $UserInput -ErrorLogHash $errorHash -OutputPath $outputFile | Out-Null
EndScript
