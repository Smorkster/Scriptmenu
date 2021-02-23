<#
.Synopsis Compare groupmembership for two or more users
.Description By given users id's, compare each users AD-groupmemberships. List is written to a CSV-file.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

Write-Host "$( $msgTable.WAlternatives ):`n"
Write-Host "[1] - $( $msgTable.WAlternative1 )."
Write-Host "[2] - $( $msgTable.WAlternative2 ).`n"
do
{
	$Choice = Read-Host "$( $msgTable.QAlternative )"
}
until ( ( $Choice -eq 1 ) -or ( $Choice -eq 2 ) )

Write-Host "`n"

$UsersIn = @()
$Users = @()
$AllGroups = @()

if ( $Choice -eq 1 )
{
	$UsersIn += Read-Host "1 ) $( $msgTable.QID ) "
	$UsersIn += Read-Host "2 ) $( $msgTable.QID )"
	Write-Host "`n"

}
elseif ( $Choice -eq 2 )
{
	$UsersIn = GetUserInput -DefaultText $msgTable.QIDList
}
else
{
	Write-Host "$( $msgTable.ErrID )" -ForegroundColor Red
}

if ( $UsersIn.Count -gt 1 )
{
	foreach ( $u in $UsersIn )
	{
		$user = New-Object -TypeName psobject
		$user | Add-Member -MemberType NoteProperty -Name Groups -Value ( Get-ADPrincipalGroupMembership -Identity $u | Select-Object -ExpandProperty Name )
		$user | Add-Member -MemberType NoteProperty -Name UserName -Value $u
		$Users += $user
		$AllGroups += $user.Groups
	}

	$AllGroups = $AllGroups | Sort-Object | Select-Object -Unique

	$groups = @()
	foreach ( $g in $Allgroups )
	{
		$group = New-Object -TypeName psobject
		$group | Add-Member -MemberType NoteProperty -Name GroupName -Value $g
		$group | Add-Member -MemberType NoteProperty -Name Users -Value @()
		foreach ($u in $users)
		{
			if ( $u.Groups -contains $group.Groupname )
			{
				$group.Users += $u.UserName
			}
		}
		$groups += $group
	}

	$users | Select-Object UserName
	$file = @()
	Write-Host "`n$( $msgTable.WGroups )`n------"
	foreach ( $g in $groups )
	{
		Write-Host "$( $g.GroupName ): " -NoNewline
		$row = [pscustomobject]@{ "GroupName" = $g.GroupName }
		if ( $g.Users.Count -eq $users.Count )
		{
			if ( $users.Count -eq 2 )
			{ $members = $msgTable.WBoth }
			else
			{ $members = $msgTable.WAll }
		}
		else
		{
			$members = ""
			$g.Users | ForEach-Object { $members += "$_ " }
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
		{ $fna += "$( $usersIn.Count.ToString() ) $( $msgTable.WUserCount )" }
		$file = $file | ConvertTo-Csv -NoTypeInformation -Delimiter ';'

		$outputFile = WriteOutput -FileNameAddition $fna -Output $file -FileExtension "csv"
		Write-Host "`n$( $msgTable.WSummary ) '$outputFile'"

		$logText = "$fna`r`n`t$( $msgTable.WLogOutputTitle ): $outputFile"
	}
}
else
{
	$logText = $msgTable.ErrToFew
}

WriteLog -LogText $logText | Out-Null
EndScript
