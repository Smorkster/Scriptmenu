<#
.Synopsis Compare groupmembership for two or more users
.Description By given users id's, compare each users AD-groupmemberships. List is written to a CSV-file.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

Write-Host "$( $msgTable.WAlternatives ):`n"
Write-Host "[1] - $( $msgTable.WAlternative1 )."
Write-Host "[2] - $( $msgTable.WAlternative2 ).`n"
do
{
	$Choice = Read-Host "$( $msgTable.QAlternative )"
}
until ( $Choice -in 1, 2 )

Write-Host "`n"

$UsersIn = @()
$Users = [System.Collections.ArrayList]::new()
$InputNotFound = @()
$AllGroups = @()
$success = $true

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
	$success = $false
}

$UsersIn | Select-Object -Unique | ForEach-Object {
	try
	{
		$a = Get-ADUser $_
		$b = ( Get-ADPrincipalGroupMembership -Identity $a | Select-Object -ExpandProperty Name )
		$Users.Add( [pscustomobject]@{ "User" = $a; "Groups" = $b } )
	}
	catch { $InputNotFound += $_ }
}

if ( $Users.Count -gt 1 )
{
	$AllGroups = $Users.Groups | Select-Object -Unique

	if ( $AllGroups.Count -gt 0 )
	{
		$groups = @()
		foreach ( $g in $AllGroups )
		{
			$group = [pscustomobject]@{ "GroupName" = $g; Users = @() }

			foreach ( $u in $Users )
			{
				if ( $u.Groups -contains $group.Groupname )
				{
					$group.Users += $u
				}
			}
			$groups += $group
		}

		$file = @()
		Write-Host "`n$( $msgTable.WGroups )`n------"
		foreach ( $g in ( $groups.GetEnumerator() | Sort-Object GroupName ) )
		{
			Write-Host "$( $g.GroupName ): " -NoNewline
			$row = [pscustomobject]@{ "GroupName" = $g.GroupName; "Members" = $null }
			if ( $g.Users.Count -eq $Users.Count )
			{
				if ( $Users.Count -eq 2 )
				{ $members = $msgTable.WBoth }
				else
				{ $members = $msgTable.WAll }
			}
			else
			{
				$members = ""
				$g.Users | ForEach-Object { $members += "$( $_.User.Name ) " }
			}
			Write-Host $members.Trim()
			$row.Members = $members.Trim()
			$file += $row
		}
	}

	if ( $file )
	{
		# Output
		if ( $UsersIn.Count -eq 2 ) { $fna += "$( $UsersIn[0] ), $( $UsersIn[1] )" }
		else { $fna += "$( $usersIn.Count.ToString() ) $( $msgTable.WUserCount )" }

		$file = $file | ConvertTo-Csv -NoTypeInformation -Delimiter ';'

		$outputFile = WriteOutput -Output $file -FileExtension "csv"
		Write-Host "`n$( $msgTable.WSummary ) '$outputFile'"

		$logText = "$fna`r`n`t$( $msgTable.WLogOutputTitle ): $outputFile"
	}
}
else
{
	Write-Host ( $logText = $msgTable.ErrToFew )

	$success = $false
	$errorlog = WriteErrorLogTest -LogText $logText -UserInput "$Users `n`n $AllGroups" -Severity "UserInputFail"
}

WriteLogTest -Text $logText -UserInput "$UsersIn" -Success $success -OutputPath $outputFile -ErrorLogHash $errorlog | Out-Null
EndScript
