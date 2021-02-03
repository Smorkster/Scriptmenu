<#
.Synopsis List groups a user is member of
.Description List groups a user is member of.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$UserInput = Read-Host $msgTable.QID

if ( !( dsquery User -samid $UserInput ) )
{
	Write-Host "`n$( $msgTable.ErrWID ) $UserInput!" -ForegroundColor Red
	$outputFile = "$UserInput $( $msgTable.ErrID )"
}
else
{
	$output = @()
	$User = Get-ADUser $UserInput -Properties *
	if ( $GaiaGroups = Get-ADPrincipalGroupMembership $User | where { $_.SamAccountName -notlike "*_org_*" } | where { $_.SamAccountName -ne "Domain Users" } | select -ExpandProperty SamAccountName | sort )
	{
		$output += $User.Name + " $( $msgTable.WGroupTitle ):"
		$GaiaGroups | sort | foreach { $output += "`t$( $_ )" }
	}
	else
	{
		$output += $User.Name + " $( $msgTable.WNoGroups )."
	}

	if ( $OrgGroups = Get-ADPrincipalGroupMembership $User | where { $_.SamAccountName -like "*_org_*" } | select -ExpandProperty SamAccountName | sort )
	{
		$output += "`r`n$( $msgTable.WGroupCont ):"
		foreach ( $g in $orggroups)
		{
			Get-ADGroup $g -Properties hsaidentity | foreach { $output += "$( $_.Name ) - $( $_.hsaidentity )" }
			Get-ADPrincipalGroupMembership $g | sort | foreach { $output += "`t" + $_.Name }
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

if ( ( Read-Host "$( $msgTable.QQuestion )? ( Y / N )" ) -eq "Y" )
{
	$cloneTarget = Read-Host "$( $msgTable.QQID ):"
	$message = @("$( $msgTable.MQ1 ) $( $User.Name ) $( $msgTable.MQ2 ):")
	$GaiaGroups | sort | foreach { $message += "`t$( $_ )" }
	$message += "$( $msgTable.MQ3 ) [ $( ( Get-ADUser $cloneTarget ).Name ) ]."
	$message += $msgTable.MQ4
	$message += $msgTable.MQ5
	$message += $msgTable.MQ6
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$message | clip
	Write-Host "$( $msgTable.WQCopy )"
}

WriteLog -LogText "$UserInput`r`n`t$( $msgTable.WLogOutputTitle ): $outputFile" | Out-Null
EndScript
