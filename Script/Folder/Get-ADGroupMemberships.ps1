<#
.Synopsis List ALL folderpermissions for one or more users
.Description List ALL folderpermissions for one or more users.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

Write-Host "`n$( $msgTable.StrTitle )`n"
Write-Host "$( $msgTable.StrNotepad )`n"
$UsersIn = GetUserInput -DefaultText $msgTable.StrNotepadTitle

$OutputFiles = @()
$ErrorHashes = @()
$success = $true
$LogText = ""
Start-Sleep -Seconds 1

foreach ( $User in $UsersIn )
{
	Write-Host "`n*****************************`n$( $msgTable.StrOpTitle ) $User."
	try { $dn = ( Get-ADUser $User ).DistinguishedName }
	catch
	{
		$dn = $null
		Write-Host "$( $msgTable.StrUserNotFound ) $User"
		$ErrorHashes += WriteErrorLogTest -LogText $msgTable.ErrLogUesrNotFound -UserInput $User -Severity "UserInputFail"
		$success = $false
	}
	if ( $null -ne $dn )
	{
		$Read = @()
		$Change = @()
		$Full = @()
		$Other = @()

		$Groups1 = Get-ADGroup -LDAPFilter ( "(member:1.2.840.113556.1.4.1941:={0})" -f $dn ) | Select-Object -ExpandProperty Name | Sort-Object Name

		# Sort groups and create list of groups whos name contains '_Fil_' but not '_User_' (this being groupname ending in _F, _C or _R)
		$Groups2 = $Groups1 -like "*_Fil_*"
		$Groups3 = $Groups2 -inotlike "*_User_*"

		# Run for each groups in $Groups3
		foreach( $Group in $Groups3 )
		{
			# Creates groupnames and transforms into proper pathway. First If handles permissions outside G, R and S
			if ( $Group -notcontains "*_Grp_*" -or "*_Gem_*" -or "*_App_*" )
			{
				$X = $Group.Substring( 8 )
				$Server = $X.Substring( 0, $X.IndexOf( '_' ) )
				$Y = $X.Substring( $X.IndexOf( '_' ) )
				if ( ( $Group.Substring( $Group.LastIndexOf( '_' ) ) -notcontains "_R" -or "_C" -or "_F" ) )
				{
					$Mapp = $Y.Substring( 1, $Y.Length -1 )
				}
				else
				{
					$Mapp = $Y.Substring( 1, $Y.Length -3 )
				}
				$Path = "\\$Server\$Mapp"
			}
			else
			{
				if ( $Group -like "*_Grp_*" ) { $Type = "Grp_" }
				elseif ( $Group -like "*_Gem_*" ) { $Type = "Gem_" }
				elseif ( $Group -like "*_App_*" ) { $Type = "App_" }

				$Kund = $Group.SubString( 0, 3 )
				$X = $Group.Substring( $Group.LastIndexOf( 'Grp_' ) )
				if ( ( $Group.Substring( $Group.LastIndexOf( '_' ) ) -eq "_R" -or "_C" -or "_F" ) ) { $Y = $Group.Substring( $Group.LastIndexOf( '_' ) ) }
				else { $Y = "" }

				$Z = $X.Replace( "Grp_", "" )
				$Mapp = $Z.Replace( "$Y", "" )
				$Path = "G:\$Kund\$Mapp"
			}

			# Depending of name-suffix pathway is sorted to correct array.
			switch ( $Group.Substring( $Group.LastIndexOf( '_' ) ) )
			{
				"_R" { $Read += "$Path`r`n" }
				"_C" { $Change += "$Path`r`n" }
				"_F" { $Full += "$Path`r`n" }
				default { $Other += "$Path`r`n" }
			}
		}

		# Remove pathway created due to groups giving read-permission for DFS-links
		$Read = $Read | Where-Object { $_ -Notlike "*\R" } | Where-Object { $_ -Notlike "*\Ext" }
		$Other = $Other | Where-Object { $_ -Notlike "*\R" } | Where-Object { $_ -Notlike "*\Ext" }

		# Sort and remove duplicates in each array
		$Read = $Read | Sort-Object | Select-Object -Unique
		$Change = $Change | Sort-Object | Select-Object -Unique
		$Full = $Full | Sort-Object | Select-Object -Unique
		$Other = $Other | Sort-Object | Where-Object { $Read -notcontains $_ } | Where-Object { $Change -notcontains $_ } | Where-Object { $Full -notcontains $_ } | Select-Object -Unique

		$outputInfo = "$( $msgTable.StrOutInfo1 )`r`n$( $msgTable.StrOutInfo2 )`r`n$( $msgTable.StrOutInfo3 )"
		$outputInfo += "`r`n`r`n$User $( $msgTable.StrOutTitle )`r`n"
		$outputInfo += "`r`n`r`n$( $msgTable.StrOutTitleRead ):`r`n"
		$outputInfo += $Read
		$outputInfo += "`r`n`r`n$( $msgTable.StrOutTitleChange ):`r`n"
		$outputInfo += $Change
		$outputInfo += "`r`n`r`n$( $msgTable.StrOutTitleFull ):`r`n"
		$outputInfo += $Full
		$outputInfo += "`r`n`r`n$( $msgTable.StrOutTitleUnknown ):`r`n"
		$outputInfo += $Other

		Write-Host $outputInfo

		# Export to textfile
		$outputFile = WriteOutput -FileNameAddition $User -Output $outputInfo
		Write-Host "$( $msgTable.StrOutPath )`n$outputFile"
		$OutputFiles += $outputFile
		$LogText += "$User $outputFile`n`t"
	}
}

WriteLogTest -Text $LogText.Trim() -UserInput ( [string]$UsersIn ) -Success $success -ErrorLogHash $ErrorHashes -OutputPath $OutputFiles | Out-Null

if ( ( Read-Host "`n$( $msgTable.StrOpenFiles )" ) -eq "Y" )
{
	foreach ( $file in $OutputFiles )
	{
		Start-Process notepad $file
	}
}

Write-Host "$( $msgTable.StrEnd )"
EndScript
