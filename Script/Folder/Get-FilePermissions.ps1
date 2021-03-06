<#
.Synopsis List users that have permissions for a file
.Description For given file, list all users with permission for it. The list sorts the users by permissionlevel.
.Author Smorkster (smorkster)
#>

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
			WriteErrorLog -LogText "GetMember:`n$_"
			return $null
		}
	}
}

Write-Host " $( $msgTable.StrTitle )"
$File = Read-Host "$( $msgTable.QPath )"

$output = "$( $msgTable.StrOutTitle ):`n$File"
$FileSystemRights = @{}
$PermissionList = Get-Acl $File | Select-Object -ExpandProperty Access | Select-Object -Property @{ Name = "IdentityReference"; Expression = { ( [string]$_.IdentityReference -split "\\" )[1] } }, FileSystemRights
$PermissionList | Group-Object FileSystemRights | Foreach-Object { $FileSystemRights += @{ $_.Name = New-Object System.Collections.ArrayList } }

foreach ( $rightsType in $FileSystemRights.Keys )
{
	$output += "`n`n===========================================`n$rightsType`n===========================================`n"
	$toutput = @()
	$rightsHolder = $PermissionList.Where( { $_.FileSystemRights -eq $rightsType } )
	foreach ( $holder in $rightsHolder )
	{
		$member = GetMember $holder.IdentityReference
		if ( $null -ne $member )
		{ $member | Where-Object { $_ -match "\(" } | Foreach-Object { $toutput += $_ } }
	}
	$toutput | Select-Object -Unique | Sort-Object | Foreach-Object { $output += "$_`n" }
}

$outputfile = WriteOutput -Output $output
WriteLog -LogText "$File`n`t$( $msgTable.StrLogSum ): $outputfile" | Out-Null
Write-Host "$( $msgTable.StrSumPath ) $outputfile"
EndScript
