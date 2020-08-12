#Description = List who, and at what level, users have permissions for a file
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

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
			$groupMembers.members | foreach { GetMember $_ }
		}
		catch { return $null }
	}
}

$CaseNr = Read-Host "Casenumber (if any) "
$File = Read-Host "Pathway for file"

$output = "Permissiongroups and its members for file:`n$File"
$FileSystemRights = @{}
$PermissionList = Get-Acl $File | select -ExpandProperty Access | select -Property @{ Name = "IdentityReference"; Expression = { ( [string]$_.IdentityReference -split "\\" )[1] } }, FileSystemRights
$PermissionList | group FileSystemRights | foreach { $FileSystemRights += @{ $_.Name = New-Object System.Collections.ArrayList } }

foreach ( $rightsType in $FileSystemRights.Keys )
{
	$output += "`n`n===========================================`n$rightsType`n===========================================`n"
	$toutput = @()
	$rightsHolder = $PermissionList.Where( { $_.FileSystemRights -eq $rightsType } )
	foreach ( $holder in $rightsHolder )
	{
		$member = GetMember $holder.IdentityReference
		if ( $member -ne $null )
		{ $member | where { $_ -match "\(" } | foreach { $toutput += $_ } }
	}
	$toutput | select -Unique | sort | foreach { $output += "$_`n" }
}

$outputfile = WriteOutput -Output $output
WriteLog -LogText "$File`n`tSummary: $outputfile"
EndScript
