<#
.Synopsis List permissions and owner for one or more folders
.Description For given shared folders, list its owner and users with permission for it.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

do
{
	$Customer = Read-Host $msgTable.QCustomer
} until ( $msgTable.CodeOrgList -match $Customer )

Write-Host $msgTable.QFolders
$FoldersIn = GetConsolePasteInput -Folders

$FailedFolders = @()
$Folders = @()

foreach ( $Folder in $FoldersIn )
{
	if ( -not ( $Folder.StartsWith( "G:\$Customer\" ) ) ) { $Folder = "G:\$Customer\$Folder" }

	if ( Test-Path $Folder )
	{
		$Folders += $Folder
	}
	else
	{
		Write-Host "'$Folder' $( $msgTable.StrNotFound )"
		$FailedFolders += $Folder
	}
}

Write-Host $msgTable.StrSearching

$output = @()
$output += "------------------------------------------------------------------------------"
$output += "$( $msgTable.StrOutTitle )`r`n"
$output += $Folders
if ( $FailedFolders.Count -gt 0 )
{
	$output += "`r`n$( $msgTable.StrOutNotFoundTitle )`r`n"
	$output += $FailedFolders
}
$output += "`r`n------------------------------------------------------------------------------"

Start-Sleep 3

foreach ( $Folder in $Folders )
{
	$GroupPrefix = ( Invoke-Expression $msgTable.CodeGP ).( $Folder.Substring( 3, 3 ) )
	$FolderName = $Folder.Substring( 7 )
	$output += "`r`n************************`r`n$Folder`r`n"
	$Owner = Get-ADGroup ( ( $GroupPrefix + $FolderName + $msgTable.StrGrpNameSuffixWrite ) -replace "å", "a" -replace "ä", "a" -replace "ö", "o" -replace " ", "_" -replace "é", "e" ) -Properties ManagedBy | Select-Object -ExpandProperty Managedby

	if ( $null -ne $Owner )
	{
		$output += "$( $msgTable.StrOwner ) $( ( Get-ADUser $Owner ).Name )"
	}
	else
	{
		$output += $msgTable.StrOwnerMissing
	}

	$output += "`r`n$( $msgTable.StrReadPerm ) "

	$RGroups = Get-ADGroupMember ( ( $GroupPrefix + $FolderName + $msgTable.StrGrpNameSuffixRead ) -replace "å", "a" -replace "ä", "a" -replace "ö", "o" -replace " ", "_" -replace "é", "e" ) | Select-Object -ExpandProperty Name
	$ROrgGroups = $RGroups | Where-Object { $_ -like ( $Customer + "_org_*" ) }
	$RGroups = $RGroups | Where-Object { $_ -notlike ( $Customer + "_org_*" ) }

	if ( $RGroups.Count -eq 0 )
	{
		$output += $msgTable.StrNoRead
	}
	else
	{
		$output += $RGroups | Sort-Object
	}

	if ( $null -ne $ROrgGroups )
	{
		foreach ( $OrgGroup in $ROrgGroups )
		{
			$OrgGroupID = ( Get-ADGroup $OrgGroup -Properties * | Select-Object -ExpandProperty $msgTable.StrAdIdPropPrefix ) -replace $msgTable.StrAdIdPrefix, ""

			if ( -not ( $OrgGroupMembers = ( Invoke-Expression $msgTable.CodeOrgGrpMembers ) ) )
			{
				$OrgGroupMembers = Get-ADGroupMember $OrgGroup | Select-Object -ExpandProperty Name
			}

			$output += "`r`n$( Invoke-Expression $msgTable.CodeOrgGrpMembersOutput )"
			$output += $OrgGroupMembers | Sort-Object
		}
	}

	$output += "`r`n$( $msgTable.StrWritePerm ) "

	$CGroups = Get-ADGroupMember ( ( $GroupPrefix + $FolderName + "_User_C" ) -replace "å", "a" -replace "ä", "a" -replace "ö", "o" -replace " ", "_" -replace "é", "e" ) | Select-Object -ExpandProperty Name
	$COrgGroups = $CGroups | Where-Object { $_ -like ( $Customer + "_org_*" ) }
	$CGroups = $CGroups | Where-Object { $_ -notlike ( $Customer + "_org_*" ) }

	if ( $CGroups.Count -eq 0 )
	{
		$output += $msgTable.StrNoWrite
	}
	else
	{
		$output += $CGroups | Sort-Object
	}

	if ( $null -ne $COrgGroups )
	{
		foreach ( $OrgGroup in $COrgGroups )
		{
			$OrgGroupID = ( Get-ADGroup $OrgGroup -Properties * | Select-Object -ExpandProperty $msgTable.StrAdIdPropPrefix ) -replace $msgTable.StrAdIdPrefix, ""

			if ( -not ( $OrgGroupMembers = ( Invoke-Expression $msgTable.CodeOrgGrpMembers ) ) )
			{
				$OrgGroupMembers = Get-ADGroupMember $OrgGroup | Select-Object -ExpandProperty Name
			}
			$output += "`r`n$( Invoke-Expression $msgTable.CodeOrgGrpMembersOutput )"
			$output += $OrgGroupMembers | Sort-Object
		}
	}
}

$outputFile = WriteOutput -Output $output
Write-Host "$( $msgTable.StrOutSum ) '$outputFile'"
if ( ( $openSum = Read-Host "$( $msgTable.QOpenSum ) ( Y / N )" ) -eq "Y" ) { Start-Process notepad $outputFile -Wait }

WriteLogTest -Text "$( $msgTable.StrSum )" -UserInput "$( $msgTable.LogFolders )`n$FoldersIn`n$( $msgTable.LogOrg ) $( $Customer )`n$( $msgTable.LogOpenSum ) $openSum" -Success $true -OutputPath $outputFile | Out-Null
EndScript
