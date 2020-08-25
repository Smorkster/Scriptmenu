#Description = Add AD-groups, pasted in console [BO]
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CaseNr = Read-Host "Casenumber (if any) "
$User = Read-Host "UserId for the user to get the grouppermissions "
if ( dsquery user -samid $User )
{
	Write-Host "Paste a list of groupnames to which the users should get permissions. The press Enter two times to continue."
	$Groups = GetConsolePasteInput

	$added = @()
	$noPermission = @()
	$other = @()
	foreach ( $group in $Groups )
	{
		try
		{
			if ( dsquery group -samid $group )
			{
				Add-ADGroupMember -Identity $group -Members $User
			}
			else
			{
				Write-Host "Found no AdD-group with the name '$group'"
			}
		}
		catch
		{
			if ( $_.Exception.Message -eq "Insufficient access rights to perform the operation" )
			{
				$noPermission += $group
			}
			else
			{
				$other += ,@( $group, $_.Exception.Message )
			}
		}
	}
}
else
{
	Write-Host "Found no AD-user with id '$User'"
	$logText = "No account"
}

Write-Host "Added $( @( $added ).Count ) groups for $( ( Get-ADUser $User ).Name )."
if ( $noPermission.Count -gt 0 )
{
	if ( ( Read-Host "Some of the groups need other permissionlevels.`n`nCopy groupnames and question for task to Operations-group, to clipboard? ( Y / N ) " ) -eq "Y" )
	{
		"Need help adding $User as a user for these groups:`n`n$noPermission" | clip
		Write-Host "Copied clipboard"
	}
}

WriteLog -LogText "$CaseNr $User $( @( $added ).Count ) grupper"

EndScript
