<#
.Synopsis Remove multiple users from one or more AD-groups
.Description Remove multiple users from one or more AD-groups.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module ActiveDirectory

$output = ""
$failGroups = @()
$failUsers = @()

Write-Host "`n $( $msgTable.StrTitle ) `n" -ForegroundColor Cyan
Write-Host "`n`n$( $msgTable.QGroups )"
$GroupsIn = GetConsolePasteInput -Folders
[array]$Groups = $GroupsIn | ForEach-Object {
	try { Get-ADGroup -Identity $_ }
	catch
	{
		$eh += WriteErrorlogTest -LogText $_ -UserInput "Get-ADGroup $_" -Severity "UserInputFail"
		$failGroups += $_
	}
}

Start-Sleep -Seconds 1
Write-Host "`n`n$( $msgTable.QUsers )"
$UsersIn = GetConsolePasteInput
[array]$Users = $UsersIn | ForEach-Object {
	try { Get-ADUser -Identity $_ }
	catch
	{
		$eh += WriteErrorlogTest -LogText $_ -UserInput "Get-ADUser $_" -Severity "UserInputFail"
		$failUsers += $_
	}
}

$NumRem = 0
$OFS = ", "

foreach ( $Group in $Groups )
{
	try
	{
		Write-Host "$( $msgTable.StrGettingUsers ) $( $Group.Name ) `n" -ForegroundColor Cyan
		# Get the groups users
		$GroupMembers = $Group | Get-ADGroupMember

		# Remove user from groups
		Write-Host "`n$( $msgTable.StrRemoveUser ) $( $Group.Name ): `n" -ForegroundColor Cyan
		$output += "`r`n$( $msgTable.OutputGroup ) $( $Group.Name )`r`n$( $msgTable.OutputUsers )`r`n"
		foreach ( $User in ( $GroupMembers.Where( { $_.SamAccountName-in $Users.SamAccountName } ) ) )
		{
			Remove-ADPrincipalGroupMembership -MemberOf $Group -Identity $User -Confirm:$false
			Write-Host "`t$( $User.Name )"
			$output += "$( $User.Name )"
			$NumRem += 1
		}
		$output += "`r`n`r`n-------------------------------------------------"
	}
	catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
	{
		$eh += WriteErrorlogTest -LogText $_ -UserInput "$( $msgTable.LogErrRetGroup ) $Group" -Severity "UserInputFail"
	}
	catch
	{
		$eh += WriteErrorlogTest -LogText $_ -UserInput "$( $msgTable.LogErrRetGroup ) $Group" -Severity "OtherFail"
	}
}

if ( $output.Trim() -ne "" )
{
	$outputFile = WriteOutput -Output $output.Trim()
	Write-Host "`n$( $msgTable.StrSummaryPath )`n$outputFile"
	$logText = "$NumRem $$( $msgTable.LogRemCount )"
}
else
{
	Write-Host $msgTable.LogErrNoOutput
	$logText = $msgTable.LogErrNoOutput
}

if ( $failGroups.Count -gt 0 ) { $logText += "`n`n$( $failGroups.Count ) $( $msgTable.LogFailGroups )`n$failGroups" }
if ( $failUsers.Count -gt 0 ) { $logText += "`n`n$( $failUsers.Count ) $( $msgTable.LogFailUsers )`n$failUsers" }

WriteLogTest -Text $logText -UserInput "$( $msgTable.LogUsers )`n$UsersIn`n`n$( $msgTable.LogGroups )`n$GroupsIn" -Success ( $null -eq $eh ) -ErrorLogHash $eh -OutputPath $outputFile | Out-Null
EndScript
