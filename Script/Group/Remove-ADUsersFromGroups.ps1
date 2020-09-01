<#
.Synopsis Remove multiple users from one or more AD-groups
.Description Remove multiple users from one or more AD-groups.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force
Import-Module ActiveDirectory

$output = ""

$CaseNr = Read-Host "Related casenumber (if any) "
Write-Host "Name one or more groups where users is to be removed (type Enter twice to finish)"
$Groups = GetConsolePasteInput

Start-Sleep -Seconds 1
Write-Host "Name one or more users whos permissions are to be removed"
$Users = GetConsolePasteInput

foreach ( $GroupId in $Groups )
{
	# Get group and its members
	$Group = Get-ADGroup $GroupId
	$GroupMembers = $Group | Get-ADGroupMember | select -ExpandProperty SamAccountName
	Write-Host "Fetching members for $Group `n" -ForegroundColor Cyan
	# Array for removal
	$UserRemoval = @()
	$AllUsers = @()
	$nRow = ""
	$Row = ""

	foreach ( $UserId in $Users )
	{
		$AllUsers += $UserId
		# If user exists in the group, add it to array
		if ( ( $GroupMembers -contains $UserId ) )
		{
			$UserRemoval += Get-ADUser $UserId
		}
	}

	Write-Host "`nRemove users from group $( $Group.Name ): `n" -ForegroundColor Cyan

	$output += "`r`nGroupname: $Group`r`n`t"
	$UserRemoval | Remove-ADPrincipalGroupMembership -MemberOf $Group -Confirm:$false
	foreach ( $User in $UserRemoval )
	{
		Write-Host "$User " -ForegroundColor Green -NoNewline
		$Row += "$User, "
	}
	$AllUsers | foreach { if ( $UserRemoval.SamAccountName -notcontains $_ ) ) { $nRow += "$nRow " } }
	if ( $nRow -ne "" )
	{
		Write-Host "These were not members and were not removed:`n$nRow"
	}
	$output += $Row.Substring( 0, $Row.Length - 2 )
	$output += "`r`n-------------------------------------------------"
}

$outputFile = WriteOutput -Output $output.Trim()
Write-Host "Output written to file '$outputFile'"

WriteLog -LogText "$CaseNr $( $AllUsers.Count ) users, $( $Groups.Count )`r`n`t$outputFile"
EndScript
