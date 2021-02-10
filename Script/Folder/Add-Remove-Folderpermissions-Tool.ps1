<#
.Synopsis Add and remove folderpermissions, with GUI
.Description Add/remove permissions for shared folders.
.Author Someone
#>

####################  Operational functions  ####################

#######################
# Check type of AD-user
function CheckUser
{
	param (
		[string] $Id
	)

	if ( dsquery User -samid $Id )
	{
		return "User"
	}
	elseif ( dsquery Group -samid $Id )
	{
		return "Group"
	}
	elseif ( $EKG = Get-ADGroup -LDAPFilter "($( $msgTable.StrEGroupIdName )=$( $msgTable.StrEGroupOrg )-$Id)" )
	{
		if ( $EKG.Count -gt 1 )
		{
			return "EGroups"
		}
		else
		{
			return "EGroup"
		}
	}
	else
	{
		$syncHash.Data.ErrorUsers += $Id
		return "NotFound"
	}
}

###################################
# Collect AD-groups for folders / app
function CollectADGroups
{
	if ( $syncHash.DC.cbDisk[1].Substring( 1, 2 ) -eq ":\" )
	{
		switch ( $syncHash.DC.cbDisk[1].Substring( 0, 1 ) )
		{
			"G"
			{
				CollectADGroupsG -Entries $syncHash.DC.lbFoldersChosen[0]
			}
			"R"
			{
				CollectADGroupsR -Entries $syncHash.DC.lbFoldersChosen[0]
			}
			"S"
			{
				CollectADGroupsS -Entries $syncHash.DC.lbFoldersChosen[0]
			}
		}
	}
	else
	{
		foreach ( $entry in $syncHash.DC.lbFoldersChosen[0] )
		{ $syncHash.Data.ADGroups += @{ "Id" = $entry } }
	}
}

#############################################
# Get the AD-groups for the listed G:-folders
function CollectADGroupsG
{
	param (
		$Entries
	)
	$loopCounter = 0

	$Customer = ( ( $syncHash.DC.cbDisk[1] -split "\\" )[1] )
	foreach ( $entry in $Entries )
	{
		SetWinTitle -Text $msgTable.StrTitleProgressGroups -Progress $loopCounter -Max $Entries.Count

		$FolderName = $syncHash.DC.cbDisk[1].ToString() + "\" + $entry
		$entry = $entry -replace " ", "_"
		try
		{
			$WriteGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetGGroupWrite1 )
		}
		catch
		{
			try
			{
				$WriteGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetGGroupWrite2 )
			}
			catch
			{
				WriteErrorLog -LogText "CollectADGroupsG WriteGroup:`n`t$_`n`t$FolderName`n`t$entry"
				$WriteGroup = $null
			}
		}

		try
		{
			$ReadGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetGGroupRead1 )
		}
		catch
		{
			try
			{
				$ReadGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetGGroupRead2 )
			}
			catch
			{
				WriteErrorLog -LogText "CollectADGroupsG ReadGroup:`n`t$_`n`t$FolderName`n`t$entry"
				$ReadGroup = $null
			}
		}
		if ( $WriteGroup -and $ReadGroup )
		{ $syncHash.Data.ADGroups += @{ "Id" = $FolderName; "Write" = $WriteGroup.SamAccountName; "Read" = $ReadGroup.SamAccountName } }
		else
		{ $syncHash.Data.ErrorGroups += $FolderName }

		$loopCounter++
	}
}

#############################################
# Get the AD-groups for the listed R:-folders
function CollectADGroupsR
{
	param (
		$Entries
	)
	$loopCounter = 0

	$Customer = ( ( $syncHash.DC.cbDisk[1] -split "\\" )[1] )
	foreach ( $entry in $Entries )
	{
		SetWinTitle -Text ( Invoke-Expression $msgTable.StrTitleProgressGroups ) -Progress $loopCounter -Max $Entries.Count

		$FolderName = $syncHash.DC.cbDisk[1].ToString() + "\" + $entry
		$entry = $entry -replace " ", "_"
		try
		{
			$WriteGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetRGroupWrite1 )
		}
		catch
		{
			try
			{
				$WriteGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetRGroupWrite2 )
			}
			catch
			{
				try
				{
					$WriteGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetRGroupWrite3 )
				}
				catch
				{
					try
					{
						$WriteGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetRGroupWrite4 )
					}
					catch
					{
						WriteErrorLog -LogText "CollectADGroupsR WriteGroup:`n`t$_`n`t$FolderName`n`t$entry"
						$WriteGroup = $null
					}
				}
			}
		}

		try
		{
			$ReadGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetRGroupRead1 )
		}
		catch
		{
			try
			{
				$ReadGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetRGroupRead2 )
			}
			catch
			{
				try
				{
					$ReadGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetRGroupRead3 )
				}
				catch
				{
					try
					{
						$ReadGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetRGroupRead4 )
					}
					catch
					{
						WriteErrorLog -LogText "CollectADGroupsR ReadGroup:`n`t$_`n`t$FolderName`n`t$entry"
						$ReadGroup = $null
					}
				}
			}
		}
		if ( $WriteGroup -and $ReadGroup )
		{ $syncHash.Data.ADGroups += @{ "Id" = $FolderName; "Write" = $WriteGroup.SamAccountName; "Read" = $ReadGroup.SamAccountName } }
		else
		{ $syncHash.Data.ErrorGroups += $FolderName }

		$loopCounter++
	}
}

#############################################
# Get the AD-groups for the listed S:-folders
function CollectADGroupsS
{
	param (
		$Entries
	)
	$loopCounter = 0

	$Customer = ( ( $syncHash.DC.cbDisk[1] -split "\\" )[1] )
	foreach ( $entry in $entries )
	{
		SetWinTitle -Text ( Invoke-Expression $msgTable.StrTitleProgressGroups ) -Progress $loopCounter -Max $entries.Count

		$FolderName = $syncHash.DC.cbDisk[1].ToString() + "\" + $entry
		$entry = $entry -replace " ", "_"
		try
		{
			$WriteGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetSGroupWrite1 )
		}
		catch
		{
			try
			{
				$WriteGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetSGroupWrite2 )
			}
			catch
			{
				WriteErrorLog -LogText "CollectADGroupsS WriteGroup:`n`t$_`n`t$FolderName`n`t$entry"
				$WriteGroup = $null
			}
		}

		try
		{
			$ReadGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetSGroupRead1 )
		}
		catch
		{
			try
			{
				$ReadGroup = Get-ADGroup ( Invoke-Expression $msgTable.CodeGetSGroupRead2 )
			}
			catch
			{
				WriteErrorLog -LogText "CollectADGroupsS ReadGroup:`n`t$_`n`t$FolderName`n`t$entry"
				$ReadGroup = $null
			}
		}
		if ( $WriteGroup -and $ReadGroup )
		{ $syncHash.Data.ADGroups += @{ "Id" = $FolderName; "Write" = $WriteGroup.SamAccountName; "Read" = $ReadGroup.SamAccountName } }
		else
		{ $syncHash.Data.ErrorGroups += $FolderName}

		$loopCounter++
	}
}

##############################
# Collect input from textboxes
function CollectEntries
{
	if ( ( $LineCount = $syncHash.txtUsersForWritePermission.LineCount ) -gt 0 )
	{
		$lines = @()
		for ( $i = 0; $i -lt $LineCount; $i++ ) { ( $syncHash.txtUsersForWritePermission.GetLineText( $i ) ).Split( ";""," ) | ForEach-Object { $lines += ( $_ ).Trim() } }
		CollectUsers -entries ( $lines | Where-Object { $_ -ne "" } ) -PermissionType "Write"
	}
	if ( ( $LineCount = $syncHash.txtUsersForReadPermission.LineCount ) -gt 0 )
	{
		$lines = @()
		for ( $i = 0; $i -lt $LineCount; $i++ ) { ( $syncHash.txtUsersForReadPermission.GetLineText( $i ) ).Split( ";""," ) | ForEach-Object { $lines += ( $_ ).Trim() } }
		CollectUsers -entries ( $lines | Where-Object { $_ -ne "" } ) -PermissionType "Read"
	}
	if ( ( $LineCount = $syncHash.txtUsersForRemovePermission.LineCount ) -gt 0 )
	{
		$lines = @()
		for ( $i = 0; $i -lt $LineCount; $i++ ) { ( $syncHash.txtUsersForRemovePermission.GetLineText( $i ) ).Split( ";""," ) | ForEach-Object { $lines += ( $_ ).Trim() } }
		CollectUsers -entries ( $lines | Where-Object { $_ -ne "" } ) -PermissionType "Remove"
	}
}

###############
# Collect users
function CollectUsers
{
	param (
		[array] $entries,
		[string] $PermissionType
	)
	$loopCounter = 0

	switch ( $PermissionType )
	{
		"Write"
		{ $syncHash.Data.WriteUsers = @() }
		"Read"
		{ $syncHash.Data.ReadUsers = @() }
		"Remove"
		{ $syncHash.Data.RemoveUsers = @() }
	}

	foreach ( $entry in $entries )
	{
		SetWinTitle -Text "$( $msgTable.StrStartPrep ) '$PermissionType'" -Progress $loopCounter -Max $entries.Count
		$UserType = CheckUser -Id $entry
		if ( $UserType -eq "NotFound" )
		{
			$syncHash.Data.ErrorUsers += @{ "Id" = $entry }
		}
		else
		{
			$o = $null
			$ADObj = $null
			switch ( $UserType )
			{
				"User" { $ADObj = Get-ADUser -Identity $entry }
				"Group" { $ADObj = Get-ADGroup -Identity $entry -Properties $msgTable.StrEGroupIdName, $msgTable.StrEGroupDn }
				{ $_ -match "^EGroup" } { $ADObj = Get-ADGroup -LDAPFilter "($( $msgTable.StrEGroupIdName )=$( $msgTable.StrEGroupOrg )-$entry)" -Properties $msgTable.StrEGroupIdName, $msgTable.StrEGroupDn }
			}
			foreach ( $u in $ADObj )
			{
				if ( $u.ObjectClass -eq "User" )
				{ $name = $u.Name }
				else
				{ $name = "$( ( $u.$( $msgTable.StrEGroupDn ) -replace "," -split "ou=" )[1] ) ($( ( $u.$( $msgTable.StrEGroupIdName ) -split "-" )[1] ))" }
				$o = @{ "Id" = $entry.ToString().ToUpper(); "AD" = $u; "Type" = $UserType -replace "EGroups", "EGroup"; "Name" = $name }
				if ( ( $syncHash.Data.WriteUsers | Where-Object { $_.Id -eq $o.Id } ) -or
					( $syncHash.Data.ReadUsers | Where-Object { $_.Id -eq $o.Id } ) -or
					( $syncHash.Data.RemoveUsers | Where-Object { $_.Id -eq $o.Id } ) )
				{
					$syncHash.Data.Duplicates += $o.Id
				}
				else
				{
					switch ( $PermissionType )
					{
						"Write"
							{ $syncHash.Data.WriteUsers += $o }
						"Read"
							{ $syncHash.Data.ReadUsers += $o }
						"Remove"
							{ $syncHash.Data.RemoveUsers += $o }
					}
				}
			}
		}
		$loopCounter++
	}
}

############################
# Creates text for logoutput
function CreateLogText
{
	$LogText = "$( Get-Date -Format "yyyy-MM-dd HH:mm:ss" )"
	$syncHash.Data.ADGroups.Id | ForEach-Object { $LogText += "`n$_" }
	if ( $syncHash.Data.WriteUsers )
	{
		$LogText += "`n$( $msgTable.StrPermReadWrite )"
		$syncHash.Data.WriteUsers | ForEach-Object { $LogText += "`n`t$( $_.Name )" }
	}

	if ( $syncHash.Data.ReadUsers )
	{
		$LogText += "`n$( $msgTable.StrPermRead )"
		$syncHash.Data.ReadUsers | ForEach-Object { $LogText += "`n`t$( $_.Name )" } }

	if ( $syncHash.Data.RemoveUsers )
	{
		$LogText += "`n$( $msgTable.StrPermRemove )"
		$syncHash.Data.RemoveUsers | ForEach-Object { $LogText += "`n`t$( $_.Name )" }
	}

	if ( $syncHash.Data.ErrorUsers )
	{
		$LogText += "`n$( $msgTable.StrFinNoAccounts )"
		$syncHash.Data.ErrorUsers | ForEach-Object { $LogText += "`n`t$_" }
	}

	if ( $syncHash.Data.ErrorGroups )
	{
		$LogText += "`n$( $msgTable.StrFinNoAdGroups )"
		$syncHash.Data.ErrorGroups | ForEach-Object { $LogText += "`n`t$_" }
	}

	$LogText += "`n------------------------------"
	WriteToLog -Text $LogText
}

################
# Create message
function CreateMessage
{
	$Message = @( $msgTable.StrFinIntro )
	$syncHash.Data.ADGroups.Id | ForEach-Object { $Message += "`t$_" }
	if ( $syncHash.Data.WriteUsers )
	{
		$Message += "`n$( $msgTable.StrFinPermWrite ):"
		$syncHash.Data.WriteUsers | ForEach-Object { $Message += "`t$( $_.Name )" }
	}
	if ( $syncHash.Data.ReadUsers )
	{
		$Message += "`n$( $msgTable.StrFinPermRead ):"
		$syncHash.Data.ReadUsers | ForEach-Object { $Message += "`t$( $_.Name )" }
	}
	if ( $syncHash.Data.RemoveUsers )
	{
		$Message += "`n$( $msgTable.StrFinPermRem ):"
		$syncHash.Data.RemoveUsers | ForEach-Object { $Message += "`t$( $_.Name )" }
	}
	if ( $syncHash.Data.ErrorUsers )
	{
		$Message += "`n$( $msgTable.StrFinNoAccounts ):"
		$syncHash.Data.ErrorUsers | ForEach-Object { $Message += "`t$_" }
	}
	if ( $syncHash.Data.ErrorGroups )
	{
		$Message += "`n$( $msgTable.StrFinNoAdGroups ):"
		$syncHash.Data.ErrorGroups | ForEach-Object { $Message += "`t$_" }
	}
	$Message += $Script:Signatur
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$Message | clip
}

###############################
# Initiate scriptwide variables
function ResetVariables
{
	$syncHash.Data.ADGroups = @()
	$syncHash.Data.Duplicates = @()
	$syncHash.Data.ErrorUsers = @()
	$syncHash.Data.ErrorGroups = @()
	$syncHash.Data.WriteUsers = @()
	$syncHash.Data.ReadUsers = @()
	$syncHash.Data.RemoveUsers = @()
}

##########################
# Start permission editing
function PerformPermissions
{
	CollectEntries
	CollectADGroups

	if ( $syncHash.Data.Duplicates )
	{
		ShowMessageBox -Text "$( $msgTable.StrConfirmDups )`n$( $syncHash.Data.Duplicates | Select-Object -Unique )" -Title $msgTable.StrConfirmDupsTitle -Icon "Stop"
	}
	else
	{
		$Continue = ShowMessageBox -Text "$( $msgTable.StrConfirm1 ) $( @( $syncHash.Data.ADGroups ).Count ) $( $msgTable.StrConfirm2) $( @( $syncHash.Data.WriteUsers ).Count + @( $syncHash.Data.ReadUsers ).Count + @( $syncHash.Data.RemoveUsers ).Count ) $( $msgTable.StrConfirm3 )?$( if ( $syncHash.Data.ErrorGroups -or $syncHash.Data.ErrorUsers ) { "`n$( $msgTable.StrConfirmErr )" } )" -Title $msgTable.StrConfirmTitle -Button "OKCancel"
		if ( $Continue -eq "OK" )
		{
			$loopCounter = 0
			foreach ( $Group in $syncHash.Data.ADGroups )
			{
				SetWinTitle -Text $msgTable.StrStart -Progress $loopCounter -Max $syncHash.Data.ADGroups.Count
				if ( $syncHash.Data.WriteUsers )
				{
					if ( $Group.Write )
					{
						Add-ADGroupMember -Identity $Group.Write -Members $syncHash.Data.WriteUsers.AD.DistinguishedName -Confirm:$false
					}
				}

				if ( $syncHash.Data.ReadUsers )
				{
					if ( $Group.Read )
					{
						Add-ADGroupMember -Identity $Group.Read -Members $syncHash.Data.ReadUsers.AD.DistinguishedName -Confirm:$false 
					}
				}

				if ( $syncHash.Data.RemoveUsers )
				{
					if ( $Group.Write -and $Group.Read )
					{
						Remove-ADGroupMember -Identity $Group.Write -Members $syncHash.Data.RemoveUsers.AD.DistinguishedName -Confirm:$false
						Remove-ADGroupMember -Identity $Group.Read -Members $syncHash.Data.RemoveUsers.AD.DistinguishedName -Confirm:$false
					}
				}
				$loopCounter++
			}

			CreateLogText
			WriteToLogFile
			CreateMessage
			ShowMessageBox -Text "$( @( $syncHash.Data.ADGroups ).Count * ( @( $syncHash.Data.WriteUsers ).Count + @( $syncHash.Data.ReadUsers ).Count + @( $syncHash.Data.RemoveUsers ).Count ) ) $( $msgTable.StrFinished1 ).`n$( $msgTable.StrFinished2 )" -Title "Klar"
			UndoInput
			SetWinTitle -Text $msgTable.StrTitle
		}
	}
	ResetVariables
}

############################
# Set userdepending settings
function SetUserSettings
{
	try
	{
		$a = Get-ADPrincipalGroupMembership $env:USERNAME
		if ( $a.SamAccountName -match $msgTable.StrOpGroup )
		{
			$syncHash.LogFilePath = $msgTable.StrOpLogPath
			$syncHash.ErrorLogFilePath = "$( $msgTable.StrOpLogPath )$( $msgTable.StrOpErrLogFile )$( $env:USERNAME ).log"

			$syncHash.HandledFolders = $syncHash.Data.OperationsHandledFolders
			$syncHash.Signatur += "`n`n$( $msgTable.StrSignOp )"
		}
		elseif ( $a.SamAccountName -match $msgTable.StrSDGroup )
		{
			$syncHash.ErrorLogFilePath = ( ( Get-Item $PSScriptRoot ).Parent.FullName ) + "\ErrorLogs\" + ( Get-Item $PSCommandPath ).BaseName + "\" + $env:USERNAME + " ErrorLog.txt"
			$syncHash.LogFilePath = ( ( Get-Item $PSScriptRoot ).Parent.FullName) + "\Log\" + $( [datetime]::Now.Year ) + "\" + [datetime]::Now.Month + "\" + ( Get-Item $PSCommandPath ).BaseName + "\"

			$syncHash.HandledFolders = $syncHash.Data.ServicedeskHandledFolders
			$syncHash.Signatur += "`n`n$( $msgTable.StrSignSD )"
		}
		else
		{ throw }
	}
	catch
	{
		ShowMessageBox -MessageText $msgTable.StrNoPerm -Title $msgTable.StrNoPermTitle -Icon "Stop"
		WriteErrorLog -LogText "SetUserSettings:`n$_"
		Exit
	}
}

#######################
# Sets the window title
function SetWinTitle
{
	param ( $Text, $Progress, $Max )

	if ( $Progress )
	{
		$Text += " $( [Math]::Floor( $Progress / $Max * 100 ) )%"
	}
	$syncHash.DC.Window[0] = $Text
}

######################################
# Fill combobox list with disk-folders
function UpdateDiskList
{
	"G:\", "S:\", "R:\" | Get-ChildItem2 -Directory | Where-Object { $_.FullName -in $syncHash.HandledFolders } | Select-Object -ExpandProperty FullName | ForEach-Object { [void] $syncHash.DC.cbDisk[0].Add( $_ ) }
	SetWinTitle -Text $msgTable.StrTitle
}

#############
# Get folders
function UpdateFolderList
{
	SetWinTitle -Text $msgTable.StrGetFolders
	$syncHash.DC.lbFoldersChosen[0].Clear()
	$syncHash.Folder = @()

	if ( $syncHash.DC.cbDisk[1].Length -gt 0 )
	{
		if ( $syncHash.DC.cbDisk[1][0] -eq "S" )
		{
			$syncHash.Folders = ( ( Get-ChildItem $syncHash.DC.cbDisk[1] -Directory ).FullName | Get-ChildItem ).FullName.Replace( "$( $syncHash.DC.cbDisk[1] )\", "" ) | Sort-Object
		}
		else
		{
			$syncHash.Folders = Get-ChildItem $syncHash.DC.cbDisk[1] -Directory | Where-Object { $_.FullName -notin $syncHash.Data.ExceptionFolders } | Select-Object -ExpandProperty Name | Sort-Object
		}
		$syncHash.txtFolderSearch.Focus()
		UpdateFolderListItems
	}
	SetWinTitle -Text $msgTable.StrTitle
}

######################
# Fill list of folders
function UpdateFolderListItems
{
	$syncHash.DC.lbFolderList[0].Clear()
	foreach ( $Folder in ( $syncHash.Folders | Where-Object { $syncHash.DC.lbFoldersChosen[0] -notcontains $_ } ) )
	{
		[void] $syncHash.DC.lbFolderList[0].Add( $Folder )
	}
}

##############################
# Write information to logfile
function WriteToLogFile
{
	# One line per group/user
	$LogText = @()
	foreach ( $group in $syncHash.Data.ADGroups )
	{
		foreach ( $u in $syncHash.Data.WriteUsers ) { $LogText += "$( $u.Id ) > Add '$( $group.Write )'" }
		foreach ( $u in $syncHash.Data.ReadUsers ) { $LogText += "$( $u.Id ) > Add '$( $group.Read )'" }
		foreach ( $u in $syncHash.Data.RemoveUsers ) { $LogText += "$( $u.Id ) > Remove '$( $group.Write )' & '$( $group.Read )'" }
	}
	$LogText | ForEach-Object { WriteLog -LogText $_ | Out-Null }
}

####################  End Operational functions  ####################

####################  Control functions  ####################

#####################################################################################
# Some input is entered, check if necessary input is given, enabled button to perform
function CheckReady
{
	if ( ( $syncHash.DC.lbFoldersChosen[0].Count -gt 0 ) -and ( ( $syncHash.txtUsersForWritePermission.Text.Length -ge 4 ) -or ( $syncHash.txtUsersForReadPermission.Text.Length -ge 4 ) -or ( $syncHash.txtUsersForRemovePermission.Text.Length -ge 4 ) ) )
	{
		$syncHash.DC.btnPerform[0] = $true
	}
	else
	{
		$syncHash.DC.btnPerform[0] = $false
	}
}

##############################
# A selected folder is removed
function FolderDeselected
{
	$syncHash.DC.lbFolderList[0].Add( $syncHash.DC.lbFoldersChosen[2] )
	$syncHash.DC.lbFoldersChosen[0].Remove( $syncHash.DC.lbFoldersChosen[2] )
	CheckReady
	UpdateFolderListItems
	$syncHash.txtFolderSearch.Text = ""
	$syncHash.txtFolderSearch.Focus()
}

###############################################
# A folder is selected, move to lbFoldersChosen
function FolderSelected
{
	$syncHash.DC.lbFoldersChosen[0].Add( $syncHash.DC.lbFolderList[2] )
	$syncHash.DC.lbFolderList[0].Remove( $syncHash.DC.lbFolderList[2] )
	CheckReady
	UpdateFolderListItems
	$syncHash.txtFolderSearch.Text = ""
	$syncHash.txtFolderSearch.Focus()
}

##############################################
# Search for any of item containing searchword
function SearchListboxItem
{
	$list = $syncHash.Folders | Where-Object { $syncHash.DC.lbFoldersChosen[0] -notcontains $_ }
	if ( $syncHash.txtFolderSearch.Text.Length -eq 0 )
	{
		$syncHash.DC.lbFolderList[1] = -1
	}
	else
	{
		$list = $list | Where-Object { $_ -like "*$( $syncHash.txtFolderSearch.Text.Replace( "\\", "\\\\" ) )*" }
	}
	$syncHash.DC.lbFolderList[0].Clear()
	foreach ( $i in $list )
	{
		$syncHash.DC.lbFolderList[0].Add( $i )
	}
}

#################
# Clear all input
function UndoInput
{
	$syncHash.txtUsersForWritePermission.Text = ""
	$syncHash.txtUsersForReadPermission.Text = ""
	$syncHash.txtUsersForRemovePermission.Text = ""
	$syncHash.DC.lbFoldersChosen[0].Clear()
	UpdateFolderList
}

#################################
# Write information to loglistbox
function WriteToLog
{
	param (
		$Text
	)

	$syncHash.DC.lbLog[0].Insert( 0, $Text )
}

####################  End Control functions  ####################

######################################### Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force

$controlProperties = New-Object Collections.ArrayList
[void]$controlProperties.Add( @{ CName = "Window"
	Props = @(
		@{ PropName = "Title"; PropVal = $msgTable.StrTitle }
	) } )
[void]$controlProperties.Add( @{ CName = "MainGrid"
	Props = @(
		@{ PropName = "IsEnabled"; PropVal = $false }
	) } )
[void]$controlProperties.Add( @{ CName = "cbDisk"
	Props = @(
		@{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) },
		@{ PropName = "SelectedItem"; PropVal = "" }
	) } )
[void]$controlProperties.Add( @{ CName = "lbLog"
	Props = @(
		@{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) }
	) } )
[void]$controlProperties.Add( @{ CName = "lbFoldersChosen"
	Props = @(
		@{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) },
		@{ PropName = "SelectedIndex"; PropVal = -1 },
		@{ PropName = "SelectedItem"; PropVal = "" }
	) } )
[void]$controlProperties.Add( @{ CName = "lbFolderList"
	Props = @(
		@{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) },
		@{ PropName = "SelectedIndex"; PropVal = -1 },
		@{ PropName = "SelectedItem"; PropVal = "" }
	) } )
[void]$controlProperties.Add( @{ CName = "btnPerform"
	Props = @(
		@{ PropName = "IsEnabled"; PropVal = $false }
		@{ PropName = "Content"; PropVal = $msgTable.ContentbtnPerform }
	) } )
[void]$controlProperties.Add( @{ CName = "btnUndo"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentbtnUndo }
	) } )
[void]$controlProperties.Add( @{ CName = "lblFoldersChosen"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentFoldersChosen }
	) } )
[void]$controlProperties.Add( @{ CName = "lblFolderSearch"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblFolderSearch }
	) } )
[void]$controlProperties.Add( @{ CName = "lblDisk"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblDisk }
	) } )
[void]$controlProperties.Add( @{ CName = "lblFolderList"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblFolderList }
	) } )
[void]$controlProperties.Add( @{ CName = "lblLog"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblLog }
	) } )
[void]$controlProperties.Add( @{ CName = "lblUsersForWritePermission"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblUsersForWritePermission }
	) } )
[void]$controlProperties.Add( @{ CName = "lblUsersForReadPermission"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblUsersForReadPermission }
	) } )
[void]$controlProperties.Add( @{ CName = "lblUsersForRemovePermission"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblUsersForRemovePermission }
	) } )

$syncHash = CreateWindowExt $controlProperties

$syncHash.Data.ErrorLogFilePath = ""
$syncHash.Data.HandledFolders = @()
$syncHash.Data.LogFilePath = ""
$syncHash.Data.Signatur = $msgTable.StrSign

####################  Control event functions  ####################
$syncHash.btnPerform.Add_Click( { PerformPermissions } )
$syncHash.btnUndo.Add_Click( { UndoInput } )
$syncHash.cbDisk.Add_DropDownClosed( { if ( $syncHash.DC.cbDisk[1] -ne $null ) { UpdateFolderList } } )
$syncHash.txtFolderSearch.Add_TextChanged( { SearchListboxItem } )
$syncHash.lbFolderList.Add_MouseDoubleClick( { FolderSelected } )
$syncHash.lbFoldersChosen.Add_MouseDoubleClick( { FolderDeselected } )
$syncHash.txtUsersForWritePermission.Add_TextChanged( { CheckReady } )
$syncHash.txtUsersForReadPermission.Add_TextChanged( { CheckReady } )
$syncHash.txtUsersForRemovePermission.Add_TextChanged( { CheckReady } )
$syncHash.Window.Add_ContentRendered( { SetWinTitle -Text $msgTable.StrPreping; $syncHash.Window.Top = 20; $syncHash.Window.Activate(); SetUserSettings; UpdateDiskList; $syncHash.DC.MainGrid[0] = $true } )
####################  End Control event functions  ####################

####################  Initialization  ####################

# Folders depending on user AD-groups
$syncHash.Data.OperationsHandledFolders =
"G:\Org1",
"G:\Org2",
"G:\Org3",
#"G:\Org5",
"G:\Org4",

"R:\Org1",
"R:\Org2",
"R:\Org3",
"R:\Org4",
#"R:\Org5",

"S:\Org1",
"S:\Org2",
"S:\Org3",
#"S:\Org4",
"S:\Org5"

$syncHash.Data.ServicedeskHandledFolders =
"G:\Org1",
"G:\Org2",
"G:\Org3",
#"G:\Org5",
"G:\Org4",

"R:\Org1",
#"R:\Org2",
#"R:\Org3",
#"R:\Org4",
#"R:\Org5",

"S:\Org1",
#"S:\Org2",
"S:\Org3",
#"S:\Org4",
#"S:\Org5"

# Folders to exclude
$syncHash.Data.ExceptionFolders = "R:\Org2\DFSFolderLink", "R:\Org4\DFSFolderLink"

ResetVariables

####################  End Initialization  ####################

[void] $syncHash.Window.ShowDialog()
$syncHash.Window.Close()
#$global:syncHash = $syncHash
