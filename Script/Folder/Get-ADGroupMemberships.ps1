<#
.Synopsis List ALL folderpermissions for one or more users
.Description List ALL folderpermissions for one or more users.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

class User
{
	$Id
	$Read
	$Change
	$Full
	$Other
	$OutputFile
	$msgTable

	User ( $id, $msgTable )
	{
		$this.Id = $id
		$this.Read = @()
		$this.Change = @()
		$this.Full = @()
		$this.msgTable = $msgTable
	}

	[string] Out ()
	{
		$OFS = "`n`t"
		$outputInfo = "$( $this.Id ) $( $this.msgTable.StrOutTitle )`r`n"
		$outputInfo += "`r`n`r`n$( $this.msgTable.StrOutTitleRead ):`r`n"
		$outputInfo += "`t"+$this.Read
		$outputInfo += "`r`n`r`n$( $this.msgTable.StrOutTitleChange ):`r`n"
		$outputInfo += "`t"+$this.Change
		$outputInfo += "`r`n`r`n$( $this.msgTable.StrOutTitleFull ):`r`n"
		$outputInfo += "`t"+$this.Full
		$outputInfo += "`r`n`r`n$( $this.msgTable.StrOutTitleUnknown ):`r`n"
		$outputInfo += "`t"+$this.Other
		return $outputInfo
	}
}

$UsersIn = [System.Collections.ArrayList]::new()
Write-Host "`n$( $msgTable.StrTitle )`n"
Write-Host "$( $msgTable.StrNotepad )`n"
GetUserInput -DefaultText $msgTable.StrNotepadTitle | ForEach-Object { [void] $UsersIn.Add( [User]::new( $_, $msgTable ) ) }

$OutputFiles = @()
$ErrorHashes = @()
$Success = $true
$LogText = ""
$Processed = [System.Collections.ArrayList]::new()
Start-Sleep -Seconds 1

if ( $UsersIn.Count -eq 1 )
{ $ExportType = 1 }
else
{ $ExportType = GetUserChoice -MaxNum 2 -ChoiceText $msgTable.QOutputFile }

foreach ( $User in $UsersIn )
{
	Write-Host "`n*****************************`n$( $msgTable.StrOpTitle ) $( $User.Id )."
	try { $dn = ( Get-ADUser $User.Id ).DistinguishedName }
	catch
	{
		$dn = $null
		Write-Host "$( $msgTable.StrUserNotFound ) $( $User.Id )"
		$ErrorHashes += WriteErrorLogTest -LogText $msgTable.ErrLogUserNotFound -UserInput $User.Id -Severity "UserInputFail"
		$Success = $false
	}

	if ( $null -ne $dn )
	{
		$Read = @()
		$Change = @()
		$Full = @()
		$Other = @()

		$Groups1 = Get-ADGroup -LDAPFilter ( "(member:1.2.840.113556.1.4.1941:={0})" -f $dn ) | Select-Object -ExpandProperty Name | Sort-Object Name

		# Sort groups and create list of groups whos name contains '_Fil_' but not '_User_' (i.e. a groupname ending in _F, _C or _R)
		$Groups2 = $Groups1 -like "*_Fil_*"
		$Groups3 = $Groups2 -inotlike "*_User_*"

		# Run for each groups in $Groups3
		foreach( $Group in $Groups3 )
		{
			# Creates groupnames and transforms into proper pathway. First if handles permissions outside G, R and S
			if ( $Group -notcontains "*_Grp_*" -or "*_Gem_*" -or "*_App_*" )
			{
				$X = $Group.Substring( 8 )
				$Server = $X.Substring( 0, $X.IndexOf( '_' ) )
				$Y = $X.Substring( $X.IndexOf( '_' ) )
				if ( $Group -notmatch "_R$|_C$|_F$" ) { $Mapp = $Y.Substring( 1, $Y.Length -1 ) }
				else { $Mapp = $Y.Substring( 1, $Y.Length -3 ) }
				$Path = "\\$Server\$Mapp"
			}
			else
			{
				switch ( $Group )
				{
					"*_Grp_*" { $Type = "Grp_" }
					"*_Gem_*" { $Type = "Gem_" }
					"*_App_*" { $Type = "App_" }
				}

				$Kund = $Group.SubString( 0, 3 )
				$X = $Group.Substring( $Group.LastIndexOf( 'Grp_' ) )
				if ( ( $Group -match "_R$|_C$|_F$" ) ) { $Y = $Group.Substring( $Group.LastIndexOf( '_' ) ) }
				else { $Y = "" }

				$Z = $X.Replace( $Type, "" )
				$Mapp = $Z.Replace( $Y, "" )
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
		$Read = $Read | Where-Object { $_ -Notlike "*\R" -and $_ -Notlike "*\Ext" }
		$Other = $Other | Where-Object { $_ -Notlike "*\R" -and $_ -Notlike "*\Ext" }

		# Sort and remove duplicates in each array
		$User.Read = $Read | Sort-Object | Select-Object -Unique
		$User.Change = $Change | Sort-Object | Select-Object -Unique
		$User.Full = $Full | Sort-Object | Select-Object -Unique
		$User.Other = $Other | Sort-Object | Where-Object { $Read -notcontains $_ -and $Change -notcontains $_ -and $Full -notcontains $_ } | Select-Object -Unique

		if ( $ExportType -eq 2 )
		{
			$User.OutputFile = WriteOutput -Output "$( $msgTable.StrOutInfo1 )`r`n$( $msgTable.StrOutInfo2 )`r`n$( $msgTable.StrOutInfo3 )`r`n$( [string]$User.Out() )"
		}
	}
}

if ( $ExportType -eq 1 )
{
	$OFS = "`r`n`r`n*****************************`r`n`r`n"
	$outputFile = WriteOutput -Output "$( $msgTable.StrOutInfo1 )`r`n$( $msgTable.StrOutInfo2 )`r`n$( $msgTable.StrOutInfo3 )`r`n`r`n$( [string]$UsersIn.Out() )"
	Write-Host "$( $msgTable.StrOutPath )`n$outputFile"
	$OutputFiles += $outputFile
	$LogText += "$( $msgTable.LogUserFile ) $User - $( ( $outputFile -split "\\" )[-1] )`n"
}
else
{
	$OFS = "`n"
	$OutputFiles = $UsersIn.OutputFile
}

WriteLogTest -Text "$( $LogText.Trim() )`n`n$( $msgTable.LogSummary )" -UserInput ( [string]$UsersIn.Id ) -Success $Success -ErrorLogHash $ErrorHashes -OutputPath $OutputFiles | Out-Null

if ( ( Read-Host "`n$( $msgTable.StrOpenFiles )" ) -eq "Y" )
{
	foreach ( $file in $OutputFiles )
	{
		Start-Process notepad $file
	}
}

Write-Host "$( $msgTable.StrEnd )"
EndScript
