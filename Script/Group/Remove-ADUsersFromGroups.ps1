<#
.Synopsis Remove multiple users from one or more AD-groups
.Description Remove multiple users from one or more AD-groups.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module ActiveDirectory

$output = ""

Write-Host "`n $( $msgTable.StrTitle ) `n" -ForegroundColor Cyan
Write-Host "`n`n$( $msgTable.QGroups )"
$Groups = GetConsolePasteInput

Start-Sleep -Seconds 1
Write-Host "`n`n$( $msgTable.QUsers )"
$Users = GetConsolePasteInput

foreach ( $GroupId in $Groups )
{
	# Get group and its users
	$Group = Get-ADGroup $GroupId
	$GroupMembers = $Group | Get-ADGroupMember | Select-Object -ExpandProperty SamAccountName
	Write-Host "$( $msgTable.StrGettingUsers ) $Group `n" -ForegroundColor Cyan

	$UserRemoval = @()
	$AllUsers = @()
	$nRow = ""
	$Row = ""

	foreach ( $UserId in $Users )
	{
		$AllUsers += $UserId
		# If list contains user, add user to array for removal
		if ( ( $GroupMembers -contains $UserId ) )
		{
			$UserRemoval += Get-ADUser $UserId
		}
	}

	# Remove user from groups, based on array
	Write-Host "`n$( $msgTable.StrRemoveUser ) $( $Group.Name ): `n" -ForegroundColor Cyan

	$output += "`r`nGruppnamn: $Group`r`n`t"
	$UserRemoval | Remove-ADPrincipalGroupMembership -MemberOf $Group -Confirm:$false
	foreach ( $User in $UserRemoval )
	{
		Write-Host "$User " -ForegroundColor Green -NoNewline
		$Row += "$User, "
	}
	$AllUsers | ForEach-Object { if ( $UserRemoval.SamAccountName -notcontains $_ ) { $nRow += "$nRow " } }
	if ( $nRow -ne "" )
	{
		Write-Host "$( $msgTable.StrNotMembers ):`n$nRow"
	}
	$output += $Row.Substring( 0, $Row.Length - 2 )
	$output += "`r`n-------------------------------------------------"
}

$outputFile = WriteOutput -Output $output.Trim()
Write-Host "$( $msgTable.StrSummaryPath ) '$outputFile'"

WriteLog -LogText "$( $AllUsers.Count ) $( $msgTable.StrUsers ), $( $Groups.Count )`r`n`t$outputFile" | Out-Null
EndScript
