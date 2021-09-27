<#
.Synopsis List users that have permissions for a file
.Description For given file, list all users with permission for it. The list sorts the users by permissionlevel.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

function GetMember
{
	param ( $Member )

	try
	{
		return ( Get-ADUser $member ).Name
	}
	catch
	{
		try
		{
			$groupMembers = Get-ADGroup $member -Properties members
			$groupMembers.members | ForEach-Object { GetMember $_ }
		}
		catch
		{
			$eh += WriteErrorlogTest -LogText "GetMember:`n$_" -UserInput $Member -Severity "UserInputFail"
			return $null
		}
	}
}

Write-Host " $( $msgTable.StrTitle )"
$File = ( Read-Host "$( $msgTable.QPath )" ).Trim()

if ( Test-Path $File )
{
	Write-Host $msgTable.StrSearching
	$output = "$( $msgTable.StrOutTitle ):`r`n$File"
	$FileSystemRights = @{}
	$memCount = 0
	$PermissionList = Get-Acl $File | Select-Object -ExpandProperty Access | Select-Object -Property @{ Name = "IdentityReference"; Expression = { ( [string]$_.IdentityReference -split "\\" )[1] } }, FileSystemRights
	$PermissionList | Group-Object FileSystemRights | Foreach-Object { $FileSystemRights += @{ $_.Name = New-Object System.Collections.ArrayList } }

	foreach ( $rightsType in $FileSystemRights.Keys )
	{
		$output += "`r`n===========================================`r`n$rightsType`r`n==========================================`r`n"
		$members = @()
		$rightsHolder = $PermissionList.Where( { $_.FileSystemRights -eq $rightsType } )
		foreach ( $holder in $rightsHolder )
		{
			$member = GetMember $holder.IdentityReference
			if ( $null -ne $member )
			{ $member | Where-Object { $_ -match "\(" } | Foreach-Object { $members += $_ } }
		}
		$members | Select-Object -Unique | Sort-Object | Foreach-Object { $output += "$_`r`n" ; $memCount += 1 }
	}

	$outputfile = WriteOutput -Output $output
	Write-Host "`n$( $msgTable.StrSumPath ) $outputfile"
	$disp = AskDisplayOption -File $outputfile -NoGW
	$logText = "$memCount $( $msgTable.LogMemCount ) $( $FileSystemRights.Keys.Count ) $LogRightsCount"
}
else
{
	Write-Host $msgTable.ErrMsgPathNotFound
	$eh = WriteErrorlogTest -LogText "Path not found" -UserInput $File -Severity "UserInputFail"
	$logText = $msgTable.LogErrPathNotFound
}

WriteLogTest -Text $logText -UserInput "$( $msgTable.LogPath )$File`n$( $msgTable.LogDisplayOption ) $disp" -OutputPath $outputfile -Success ( $null -eq $eh ) -ErrorLoghash $eh | Out-Null
EndScript
