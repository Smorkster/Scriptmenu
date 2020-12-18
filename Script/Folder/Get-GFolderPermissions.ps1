<#
.Synopsis List permissions and owner for one or more folders
.Description For given shared folders, list its owner and users with permission for it.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CaseNr = Read-Host "Related casenumber (if any) "

do
{
	$Customer = Read-Host "Name customer ( Org1, Org2, Org3 )"
} until ( "Org1", "Org2", "Org3" -contains $Customer )

Write-Host "Past a list of folders to list permissions for`nFull pathway or only foldername: (Press Enter twice to finish)"
$FoldersIn = GetConsolePasteInput -Folders

$FailedFolders = @()
$Folders = @()

foreach ( $Folder in $FoldersIn )
{
	if ( -not ( $Folder.StartsWith( "G:\$( ( Get-Culture ).TextInfo.ToTitleCase( $Customer ) )\" ) ) ) { $Folder = "G:\$Customer\$Folder" }

	if ( -not ( Test-Path $Folder ) )
	{
		Write-Host "Pathway '$Folder' couldn't be found! Verify name and run again."
		$FailedFolders += $Folder
	}
	else
	{
		$Folders += $Folder
	}
}

Write-Host "Geting information and writes to file"

$output = @()
$output += "------------------------------------------------------------------------------"
$output += "Listin permissions for these folders`r`n"
$output += $Folders
if ( $FailedFolders.Count -gt 0 )
{
	$output += "`r`nThese folders couldn't be found, and will not be listed:`r`n"
	$output += $FailedFolders
}
$output += "`r`n------------------------------------------------------------------------------"

Start-Sleep 3

foreach ( $Folder in $Folders )
{
	switch ( $Folder.Substring( 3, 3 ) )
	{
		"Org1" { $GroupPrefix = "Org1_Fil_AdOrg1_Grp_" }
		"Org2" { $GroupPrefix = "Org2_Fil_AdOrg2_Grp_" }
		"Org3" { $GroupPrefix = "Org3_Fil_AdOrg3_Grp_" }
	}
	$FolderName = $Folder.Substring( 7 )
	$output += "`r`n************************`r`n$Folder`r`n"
	$Owner = Get-ADGroup ( ( $GroupPrefix + $FolderName + "_User_C" ) -replace "å", "a" -replace "ä", "a" -replace "ö", "o" -replace " ", "_" -replace "é", "e" ) -Properties ManagedBy | Select-Object -ExpandProperty Managedby

	if ( $null -ne $Owner )
	{
		$output += "Owner: " + ( Get-ADUser $Owner | Select-Object -ExpandProperty Name )
	}
	else
	{
		$output += "Owner is missing"
	}

	$output += "`r`nRead-permission: "

	$RGroups = Get-ADGroupMember ( ( $GroupPrefix + $FolderName + "_User_R" ) -replace "å", "a" -replace "ä", "a" -replace "ö", "o" -replace " ", "_" -replace "é", "e" ) | Select-Object -ExpandProperty Name
	$ROrgGroups = $RGroups | Where-Object { $_ -like ( $Customer + "_org_*" ) }
	$RGroups = $RGroups | Where-Object { $_ -notlike ( $Customer + "_org_*" ) }

	if ( $RGroups.Count -eq 0 )
	{
		$output += "<No read permissions>"
	}
	else
	{
		$output += $RGroups | Sort-Object
	}

	if ( $null -ne $ROrgGroups )
	{
		foreach ( $ROrgGroup in $ROrgGroups )
		{
			$ROrgGroupID = ( Get-ADGroup $ROrgGroup -Properties * | Select-Object -ExpandProperty "orgIdentity" )

			switch ( $ROrgGroup )
			{
				"Org_1_Users" { $ROrgGroupMembers = "All users at Org1 " }
				"Org_2_Users" { $ROrgGroupMembers = "All users at Org2" }
				"Org_3_Users" { $ROrgGroupMembers = "All users at Org3" }
				default { $ROrgGroupMembers = Get-ADGroupMember $ROrgGroup | Select-Object -ExpandProperty Name }
			}

			$output += "`r`nSynced group $ROrgGroup (Department with Id $ROrgGroupID and its subdepartments) containing these users:"
			$output += $ROrgGroupMembers | Sort-Object
		}
	}

	$output += "`r`nWrite permission: "

	$CGroups = Get-ADGroupMember ( ( $GroupPrefix + $FolderName + "_User_C" ) -replace "å", "a" -replace "ä", "a" -replace "ö", "o" -replace " ", "_" -replace "é", "e" ) | Select-Object -ExpandProperty Name
	$COrgGroups = $CGroups | Where-Object { $_ -like ( $Customer + "_org_*" ) }
	$CGroups = $CGroups | Where-Object { $_ -notlike ( $Customer + "_org_*" ) }

	if ( $CGroups.Count -eq 0 )
	{
		$output += "<No permissions>"
	}
	else
	{
		$output += $CGroups | Sort-Object
	}

	if ( $null -ne $COrgGroups )
	{
		foreach ( $COrgGroup in $COrgGroups )
		{
			$COrgGroupID = ( Get-ADGroup $COrgGroup -Properties * | Select-Object -ExpandProperty "orgIdentity" )

			$output += "`r`nSynced group $COrgGroup (Department with Id $COrgGroupID and its subdepartments) containint these users"

			switch ( $COrgGroup )
			{
				"Org_1_Users" { $COrgGroupMembers = "All users at Org1" }
				"Org_2_Users" { $COrgGroupMembers = "All users at Org2" }
				"Org_3_Users" { $COrgGroupMembers = "All users at Org3" }
				default { $COrgGroupMembers = Get-ADGroupMember $COrgGroup | Select-Object -ExpandProperty Name }
			}
			$output += $COrgGroupMembers | Sort-Object
		}
	}
}

$outputFile = WriteOutput -Output $output
Write-Host "List written to '$outputFile'"
if ( ( Read-Host "Open file? (Y/N)" ) -eq "Y" ) { Start-Process notepad }

WriteLog -LogText "$CaseNr Summary > $outputFile"

Start-Process notepad $outputFile -Wait

EndScript
