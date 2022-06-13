<#
.Synopsis List all folderpermissions for one or more users
.Description List all folderpermissions for one or more users.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

class User
{
	$Ad
	$AllGroups
	$Id
	$OutputFile
	$AppFolder
	$GFolder
	$RFolder
	$SFolder
	$OtherFolder
	$Other
	$Summary

	User ( $id )
	{
		$this.Ad = Get-ADUser $id
		$this.Id = $id
		$this.AllGroups = [System.Collections.ArrayList]::new()
		$this.GFolder = [System.Collections.ArrayList]::new()
		$this.AppFolder = [System.Collections.ArrayList]::new()
		$this.RFolder = [System.Collections.ArrayList]::new()
		$this.SFolder = [System.Collections.ArrayList]::new()
		$this.OtherFolder = [System.Collections.ArrayList]::new()
		$this.Other = [System.Collections.ArrayList]::new()
		$this.Summary = ""
	}
}

function StripDescription
{
	param (
		[string] $Text
	)
	$Text -replace $msgTable.CodeDescReplace -replace $msgTable.CodeMatchDescGGroup, "G:\" -replace $msgTable.CodeMatchDescSGroup, "S:\" 
}

Write-Host "`n$( $msgTable.StrTitle )`n"
Write-Host "$( $msgTable.StrNotepad )`n"
$UsersIn = [System.Collections.ArrayList]::new()
$UnknownIds = [System.Collections.ArrayList]::new()
$ErrorHashes = [System.Collections.ArrayList]::new()
$Success = $true

$UserInput = GetUserInput -DefaultText $msgTable.StrNotepadTitle
$UserInput | Where-Object { $_ } | ForEach-Object {
	$id = $_
	try { [void] $UsersIn.Add( [User]::new( $id ) ) }
	catch
	{
		[void] $UnknownIds.Add( $id )
		[void] $ErrorHashes.Add( ( WriteErrorLogTest -LogText $msgTable.ErrLogUserNotFound -UserInput $id -Severity "UserInputFail" ) )
	}
}
if ( $UsersIn.Count -gt 0 )
{
	$Granularity = GetUserChoice -YesNo -ChoiceText $msgTable.QSearchGranularity
	$OFS = ""

	foreach ( $User in $UsersIn )
	{
		$title = "$( $msgTable.StrOpTitle ) $( $User.Ad.Name )"
		Write-Host "`n$( 0..( $title.Length - 1 ) | ForEach-Object { "*" } )`n$title`n`n"
		if ( $User.Ad -eq $null )
		{
			Write-Host "$( $msgTable.StrUserNotFound ) $( $User.Id )"
			$ErrorHashes += WriteErrorLogTest -LogText $msgTable.ErrLogUserNotFound -UserInput $User.Id -Severity "UserInputFail"
			$Success = $false
		}
		else
		{
			if ( $Granularity -eq "Y" )
			{ $User.AllGroups = Get-ADGroup -LDAPFilter "(member:1.2.840.113556.1.4.1941:=$( $User.Ad ))" -Properties Description }
			else
			{ $User.AllGroups = ( Get-ADUser $User.Ad -Properties memberof ).memberof | Get-ADGroup -Properties Description }

			$User.AllGroups | ForEach-Object {
				if ( $_.name -match ".*_Fil_.*" )
				{
					if ( $_.Name -match $msgTable.CodeMatchReadPermGrp )
					{ $PLvl = $msgTable.StrPLvlRead }
					elseif ( $_.Name -match $msgTable.CodeMatchWritePermGrp )
					{ $PLvl = $msgTable.StrPLvlChange }
					elseif ( $_.Name -match $msgTable.CodeMatchFullPermGrp )
					{ $PLvl = $msgTable.StrPLvlFull }
					else
					{ $PLvl = $msgTable.StrUnknownPerm }
					$grp = [pscustomobject]@{ PLvl = $PLvl ; Group = $_ }

					if ( $_.Name -match $msgTable.CodeMatchSpecialArea )
					{
						[void] $User.RFolder.Add( $grp )
					}
					elseif ( $_.Description -match $msgTable.CodeMatchDescSGroup )
					{
						[void] $User.SFolder.Add( $grp )
					}
					elseif ( $_.Description -match $msgTable.CodeMatchAppGrp )
					{
						[void] $User.AppFolder.Add( $grp )
					}
					elseif ( $_.Name -match "User_C$" )
					{
						[void] $User.GFolder.Add( $grp )
					}
					elseif ( $_.Name -match "User_R$" )
					{
						[void] $User.GFolder.Add( $grp )
					}
					else
					{
						[void] $User.OtherFolder.Add( $grp )
					}

				}
				else
				{ [void] $User.Other.Add( [pscustomobject]@{ Grp = [string]$_.Name[0..2] ; Group = $_ } ) }
			}

			$User.Summary = "$( $User.Ad.Name ) $( $msgTable.StrOutTitle )`r`n"

			if ( $User.GFolder.Count -gt 0 )
			{
				$User.Summary += "`r`n================ $( $msgTable.StrFolderPermissionsG ) ================`r`n"
				$User.GFolder | Group-Object PLvl | ForEach-Object {
					$User.Summary += "`r`n$( $_.Name )`r`n"
					$_.Group | ForEach-Object {
						$User.Summary += "$( StripDescription $_.Group.Description )`r`n`t$( $_.Group.Name )`r`n"
						}
					}
			}

			if ( $User.RFolder.Count -gt 0 )
			{
				$User.Summary += "`r`n================ $( $msgTable.StrFolderPermissionsR ) ================`r`n"
				$User.RFolder | Group-Object PLvl | ForEach-Object {
					$User.Summary += "`r`n$( $_.Name )`r`n"
					$_.Group | ForEach-Object {
						$User.Summary += "$( StripDescription $_.Group.Description )`r`n`t$( $_.Group.Name )`r`n"
						}
					}
			}

			if ( $User.SFolder.Count -gt 0 )
			{
				$User.Summary += "`r`n================ $( $msgTable.StrFolderPermissionsS ) ================`r`n"
				$User.SFolder | Group-Object PLvl | ForEach-Object {
					$User.Summary += "`r`n$( $_.Name )`r`n"
					$_.Group | ForEach-Object {
						$User.Summary += "$( StripDescription $_.Group.Description )`r`n`t$( $_.Group.Name )`r`n"
						}
					}
			}

			if ( $User.OtherFolder.Count -gt 0 )
			{
				$User.Summary += "`r`n================ $( $msgTable.StrTitleOtherFiles ) ================`r`n"
				$User.OtherFolder | Group-Object PLvl | Sort-Object Name | ForEach-Object {
					$User.Summary += "`r`n$( $_.Name )`r`n"
					$_.Group.Group | Sort-Object Name | ForEach-Object {
						$User.Summary += "$( $_.Name )`r`n`t$( StripDescription $_.Description )`r`n"
						}
					}
			}

			if ( $User.AppFolder.Count -gt 0 )
			{
				$User.Summary += "`r`n================ $( $msgTable.StrTitleAppGroups ) ================`r`n"
				$User.Appfolder | Group-Object PLvl | Sort-Object Name | ForEach-Object {
					$User.Summary += "`r`n$( $_.Name )`r`n"
					$_.Group.Group | Sort-Object Name | ForEach-Object {
						$User.Summary += "$( $_.Name )`r`n`t$( StripDescription $_.Description )`r`n"
						}
					}
			}

			if ( $User.Other.Count -gt 0 )
			{
				$User.Summary += "`r`n================ $( $msgTable.StrTitleOtherGroups ) ================`r`n"
				$User.Other | Group-Object Grp | Sort-Object Name | ForEach-Object {
					$User.Summary += "`r`n`r`n======== $( $_.Name ) $( $msgTable.StrTitleSubGroups ) ========`r`n"
					$_.Group | ForEach-Object {
						$User.Summary += "$( $_.Group.Name )`r`n`t$( $_.Group.Description )`r`n"
					}
				}
				$User.OutputFile = WriteOutput -FileNameAddition $User.Id -Output $User.Summary
			}
		}
	}

	if ( ( GetUserChoice -MaxNum 2 -ChoiceText $msgTable.QDisplayOptions ) -eq 1 )
	{
		$OFS = "`r`n`r`n"
		$UsersIn.Summary
	}
	else
	{
		$UsersIn | ForEach-Object {
			Write-Host "$( $msgTable.StrOpeningFile ) $( $_.Ad.Name )"
			Start-Process notepad $_.OutputFile
		}
	}
}

if ( $UnknownIds.Count -gt 0 )
{ Write-Host "$( $UnknownIds.Count ) $( $msgTable.StrUnknownIdsCount )" -Foreground Cyan }

WriteLogTest -Text "$( $UsersIn.Count ) $( $msgTable.LogUserCount )`r`n`r`n$( ( $UsersIn.AllGroups | Select-Object -Unique ).Count ) $( $msgTable.LogGroupCount )" -UserInput ( [string] $UserInput ) -Success $Success -ErrorLogHash $ErrorHashes -OutputPath $UsersIn.OutputFile | Out-Null

Write-Host "`r`n$( $msgTable.StrEnd )"
EndScript
