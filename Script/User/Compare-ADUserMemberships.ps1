#Description = Compare groupmembership for two or more users
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CaseNr = Read-Host "Related casenumber (if any) "
Write-Host "Chose one:`n"
Write-Host "[1] - Compare 2 users, Ids is written in console."
Write-Host "[2] - Compare 2 or more users and/or groups, Ids is entered in file.`n"
do
{
	$Choice = Read-Host "Write your choice (1 or 2)"
}
until ( ( $Choice -eq 1 ) -or ( $Choice -eq 2 ) )

Write-Host "`n"

$UsersIn = @()
$Users = @()
$AllGroups = @()

if ( $Choice -eq 1 )
{
	$UsersIn += Read-Host "Write first Id "
	$UsersIn += Read-Host "Write second Id "
	Write-Host "`n"

}
elseif ( $Choice -eq 2 )
{
	$UsersIn = GetUserInput -DefaultText "Write Id for users to compare membership for"
}
else
{
	Write-Host "Wrong choice! Run script again and enter correct choice." -ForegroundColor Red
}

if ( $UsersIn.Count -gt 1 )
{
	foreach ( $u in $UsersIn )
	{
		$user = New-Object -TypeName psobject
		$user | Add-Member -MemberType NoteProperty -Name Groups -Value ( Get-ADPrincipalGroupMembership -Identity $u | select -ExpandProperty Name )
		$user | Add-Member -MemberType NoteProperty -Name UserName -Value $u
		$Users += $user
		$AllGroups += $user.Groups
	}

	$AllGroups = $AllGroups | sort | select -Unique

	$groups = @()
	foreach ( $g in $Allgroups )
	{
		$group = New-Object -TypeName psobject
		$group | Add-Member -MemberType NoteProperty -Name GroupName -Value $g
		$group | Add-Member -MemberType NoteProperty -Name Users -Value @()
		foreach ( $u in $users )
		{
			if ( $u.Groups -contains $group.Groupname )
			{
				$group.Users += $u.UserName
			}
		}
		$groups += $group
	}

	$users | select UserName
	$file = @()
	Write-Host "`nGroups`n------"
	foreach ( $g in $groups )
	{
		Write-Host "$( $g.GroupName ): " -NoNewline
		$row = [pscustomobject]@{ "GroupName" = $g.GroupName }
		if ( $g.Users.Count -eq $users.Count )
		{
			if ( $users.Count -eq 2 )
			{ $members = "both are members" }
			else
			{ $members = "all are members" }
		}
		else
		{
			$members = ""
			$g.Users | foreach { $members += "$_ " }
		}
		Write-Host $members.Trim()
		Add-Member -InputObject $row -MemberType NoteProperty -Name "Members" -Value $members.Trim()
		$file += $row
	}

	if ( $file )
	{
		# Output
		if ( $UsersIn.Count -eq 2 )
		{ $fna += "$( $UsersIn[0] ), $( $UsersIn[1] )" }
		else
		{ $fna += "$( $usersIn.Count.ToString() ) users" }
		$file = $file | ConvertTo-Csv -NoTypeInformation -Delimiter ';'

		$outputFile = WriteOutput -FileNameAddition $fna -Output $file -FileExtension "csv"
		Write-Host "`nResults written to '$outputFile'"

		$logText = "$CaseNr $fna`r`n`tOutput: $outputFile"
	}
}
else
{
	$logText = "No comparision, to few users entered"
}

WriteLog -LogText $logText

EndScript
