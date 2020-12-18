<#
.Synopsis List groups a user is member of
.Description List groups a user is member of.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CopyToClipBoard = @()

$CaseNr = Read-Host "Related casenumber (if any) "
$UserID = Read-Host "User id "

if ( !( dsquery User -samid $UserID ) )
{
	Write-Host "`nNo user with id $UserID was found!" -ForegroundColor Red
	$outputFile = "$UserID does not exist"
}
else
{
	$output = @()
	$User = Get-ADUser $UserID -Properties *
	if ( $GaiaGroups = Get-ADPrincipalGroupMembership $User | Where-Object { $_.SamAccountName -notlike "*_org_*" } | Where-Object { $_.SamAccountName -ne "Domain Users" } | Select-Object -ExpandProperty SamAccountName | Sort-Object )
	{
		$output += $User.Name + " have permission for these AD-groups:"
		$GaiaGroups | Sort-Object | ForEach-Object { $output += "`t$( $_ )" }
	}
	else
	{
		$output += $User.Name + " does not have any group-permissions in AD."
	}

	if ( $OrgGroups = Get-ADPrincipalGroupMembership $User | Where-Object { $_.SamAccountName -like "*_org_*" } | Select-Object -ExpandProperty SamAccountName | Sort-Object )
	{
		$output += "`r`nAnd permissions for these sync org-groups:"
		foreach ( $g in $orggroups )
		{
			Get-ADGroup $g -Properties hsaidentity | ForEach-Object { $output += "$( $_.Name ) - $( $_.orgIdentity )" }
			Get-ADPrincipalGroupMembership $g | Sort-Object | ForEach-Object { $output += "`t" + $_.Name }
		}
	}
	else
	{
		$output += "`nNo permissions for sync org-groups"
	}

	Start-Sleep -Milliseconds 500
}

if ( $output )
{
	$outputFile = WriteOutput -Output $output
	Write-Host "Results written to`n'$outputFile'"
	Start-Process notepad $outputFile
}

WriteLog -LogText "$CaseNr $UserID`r`n`tOutput: $outputFile"
EndScript
