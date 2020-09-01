<#
.Synopsis List groups a user is member of
.Description List groups a user is member of.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CopyToClipBoard = @()

$CaseNr = Read-Host "Related casenumber (if any) "
$Input = Read-Host "User id "

if ( !( dsquery User -samid $Input ) )
{
	Write-Host "`nNo user with id $Input was found!" -ForegroundColor Red
	$outputFile = "$Input does not exist"
}
else
{
	$output = @()
	$User = Get-ADUser $Input -Properties *
	if ( $GaiaGroups = Get-ADPrincipalGroupMembership $User | where { $_.SamAccountName -notlike "*_org_*" } | where { $_.SamAccountName -ne "Domain Users" } | select -ExpandProperty SamAccountName | sort )
	{
		$output += $User.Name + " have permission for these AD-groups:"
		$GaiaGroups | sort | foreach { $output += "`t$( $_ )" }
	}
	else
	{
		$output += $User.Name + " does not have any group-permissions in AD."
	}

	if ( $OrgGroups = Get-ADPrincipalGroupMembership $User | where { $_.SamAccountName -like "*_org_*" } | select -ExpandProperty SamAccountName | sort )
	{
		$output += "`r`nAnd permissions for these sync org-groups:"
		foreach ( $g in $orggroups )
		{
			Get-ADGroup $g -Properties hsaidentity | foreach { $output += "$( $_.Name ) - $( $_.orgIdentity )" }
			Get-ADPrincipalGroupMembership $g | sort | foreach { $output += "`t" + $_.Name }
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

WriteLog -LogText "$CaseNr $Input`r`n`tOutput: $outputFile"
EndScript
