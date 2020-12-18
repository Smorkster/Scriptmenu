<#
.Synopsis List ALL folderpermissions for one or more users
.Description List ALL folderpermissions for one or more users.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

# Set global TimeOut for session to one hour
[System.Net.ServicePointManager]::MaxServicePointIdleTime = 3600000

$CaseNr = Read-Host "Related casenumber (if any) "
Write-Host "`n`nNotepad opens, enter users`n"
$UsersIn = GetUserInput -DefaultText "Write user-ids, one per row"

$OutputFiles = @()
Start-Sleep -Seconds 1

foreach( $User in $UsersIn )
{
	$Read = @()
	$Change = @()
	$Full = @()
	$Other = @()

	Write-Host "`n`n*****************************`nFetching all groups for $User. This might take a while."
	$dn = ( Get-ADUser $User ).DistinguishedName
	$Groups1 = Get-ADGroup -LDAPFilter ( "(member:1.2.840.113556.1.4.1941:={0})" -f $dn )  | Select-Object -ExpandProperty Name | Sort-Object Name

	# Sort and create list only containing File-groups without "_User_". (I.e. those ending with _F, _C eller _R)
	$Groups2 = $Groups1 -like "*_File_*"
	$Groups3 = $Groups2 -inotlike "*_User_*"

	foreach( $Group in $Groups3 )
	{
		# Rewrite groupnames as searchable strings.
		if ( $Group -notcontains "*_Grp_*" -or "*_Gem_*" -or "*_App_*" )
		{
			$X = $Group.Substring( 8 )
			$Server = $X.Substring( 0, $X.IndexOf( '_' ) )
			$Y = $X.Substring( $X.IndexOf( '_' ) )
			if ( ( $Group.Substring( $Group.LastIndexOf( '_' ) ) -notcontains "_R" -or "_C" -or "_F" ) )
			{
				$Folder = $Y.Substring( 1, $Y.Length -1 )
			}
			else
			{
				$Folder = $Y.Substring( 1, $Y.Length -3 )
			}
			$Path = "\\$Server\$Folder"
		}
		else
		{
			if ( $Group -like "*_Grp_*" )
			{
				$Type = "Grp_"
			}
			elseif ( $Group -like "*_Gem_*" )
			{
				$Type = "Gem_"
			}
			elseif ( $Group -like "*_App_*" )
			{
				$Type = "App_"
			}
			$Customer = $Group.SubString( 0, 3 )
			$X = $Group.Substring( $Group.LastIndexOf( 'Grp_' ) )
			if ( ( $Group.Substring( $Group.LastIndexOf( '_' ) ) -eq "_R" -or "_C" -or "_F" ) )
			{
				$Y = $Group.Substring( $Group.LastIndexOf( '_' ) )
			}
			else
			{
				$Y = ""
			}
			$Z = $X.Replace( "Grp_", "" )
			$Folder = $Z.Replace( "$Y", "" )
			$Path = "G:\$Customer\$Folder"
		}

		# Depending on the ending of groupname, put pathway in correct array. Default is for groups without F, C or R at the end.
		switch ( $Group.Substring( $Group.LastIndexOf( '_' ) ) )
		{
			"_R" { $Read += "$Path`r`n" }
			"_C" { $Change += "$Path`r`n" }
			"_F" { $Full += "$Path`r`n" }
			default { $Other += "$Path`r`n" }
		}
	}

	# Remove pathways created due to groups giving readpermission on DFS-links
	$Read = $Read | Where-Object { $_ -Notlike "*\R" } | Where-Object { $_ -Notlike "*\Ext" }
	$Other = $Other | Where-Object { $_ -Notlike "*\R" } | Where-Object { $_ -Notlike "*\Ext" }

	# Sort and remove any douplets from each array
	$Read = $Read | Sort-Object | Select-Object -Unique
	$Change = $Change | Sort-Object | Select-Object -Unique
	$Full = $Full | Sort-Object | Select-Object -Unique
	$Other = $Other | Sort-Object | Where-Object { $Read -notcontains $_ } | Where-Object { $Change -notcontains $_ } | Where-Object { $Full -notcontains $_ } | Select-Object -Unique

	$outputInfo = "OBS!!!`r`nThere might be some errors in these lists. '_' can be spaces in actual pathway.`r`nFoldernames for permissions outside G, R and S can be wrong or don't exist.`r`nSome shares can be old and don't exist anymore."
	$outputInfo += "`r`n`r`n$User have Read permission for these folders:`r`n"
	$outputInfo += $Read
	$outputInfo += "`r`n`r`n$User have Change permission for these folders:`r`n"
	$outputInfo += $Change
	$outputInfo += "`r`n`r`n$User have Full permission for these folders:`r`n"
	$outputInfo += $Full
	$outputInfo += "`r`n`r`n$User have unknown permission for these folders:`r`n"
	$outputInfo += $Other

	# Exportera behörigheter till en textfil
	Write-Host $outputInfo

	$outputFile = WriteOutput -FileNameAddition $User -Output $outputInfo
	Write-Host "A list of permissions for $User have been written to:`n$outputFile"
	$OutputFiles += $outputFile
}

WriteLog -LogText "$CaseNr $UsersIn"

foreach ( $file in $OutputFiles )
{
	Start-Process notepad $file
}

EndScript
