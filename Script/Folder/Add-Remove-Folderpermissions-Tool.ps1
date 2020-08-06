#Description = Add and remove folderpermissions, with GUI

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
	elseif ( $EKG = Get-ADGroup -LDAPFilter "(orgIdentity=$Id)" -Properties SamAccountName )
	{
		if ( $EKG.Count -eq 1 )
		{
			return "orgGroup"
		}
		else
		{
			return "orgGroups"
		}
	}
	else
	{
		$Script:ErrorUsers += $Id
		return "NotFound"
	}
}

###################################
# Collect AD-groups for folders / app
function CollectADGroups
{
	if ( $cbDisk.SelectedItem.Substring( 1, 2 ) -eq ":\" )
	{
		switch ( $cbDisk.SelectedItem.Substring( 0, 1 ) )
		{
			"G"
			{
				CollectADGroupsG -Entries $lbFoldersChosen.Items
			}
			"R"
			{
				CollectADGroupsR -Entries $lbFoldersChosen.Items
			}
			"S"
			{
				CollectADGroupsS -Entries $lbFoldersChosen.Items
			}
		}
	}
	else
	{
		foreach ( $entry in $lbFoldersChosen.Items )
		{ $Script:ADGroups += @{ "Id" = $entry } }
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

	$Customer = ( ( $cbDisk.SelectedItem -split "\\" )[1] )
	foreach ( $entry in $Entries )
	{
		$Window.Title = "Fetching AD-groups for G:-folders $( [Math]::Floor( $loopCounter / $entries.Count * 100 ) )"

		$FolderName = $cbDisk.SelectedValue.ToString() + "\" + $entry
		try
		{
			$WriteGroup = Get-ADGroup "$( $Customer )_File_AD$( $Customer )$( if ( $Customer -eq "OrgA" ) { "02" } else { "01" } )_Grp_$entry_User_C" | select -ExpandProperty SamAccountName
		}
		catch
		{
			try
			{
				$WriteGroup = Get-ADGroup "$( ( ( ( Get-Acl $FolderName -ErrorAction Stop ).Access | where { ( $_.FileSystemRights -eq "Modify, Synchronize" ) -and ( $_.IsInherited -eq $false ) } | select -ExpandProperty IdentityReference ).Value -replace "AD\\" ).Substring( 0, ( ( ( Get-Acl $FolderName -ErrorAction Stop ).Access | where { ( $_.FileSystemRights -eq "Modify, Synchronize" ) -and ( $_.IsInherited -eq $false ) } | select -ExpandProperty IdentityReference ).Value -replace "AD\\" ).Length - 2 ) )_User_C" | select -ExpandProperty SamAccountName
			}
			catch
			{ $WriteGroup = $null }
		}

		try
		{
			$ReadGroup = Get-ADGroup "$( $Customer )_File_AD$( $Customer )$( if ( $Customer -eq "OrgA" ) { "02" } else { "01" } )_Grp_$entry_User_R" | select -ExpandProperty SamAccountName
		}
		catch
		{
			try
			{
				$ReadGroup = Get-ADGroup "$( ( ( ( Get-Acl $FolderName -ErrorAction Stop ).Access | where { ( $_.FileSystemRights -eq "ReadAndExecute, Synchronize" ) -and ( $_.IsInherited -eq $false ) } | select -ExpandProperty IdentityReference ).Value -replace "AD\\" ).Substring( 0, ( ( ( Get-Acl $FolderName -ErrorAction Stop ).Access | where { ( $_.FileSystemRights -eq "ReadAndExecute, Synchronize" ) -and ( $_.IsInherited -eq $false ) } | select -ExpandProperty IdentityReference ).Value -replace "AD\\" ).Length - 2 ) )_User_R" | select -ExpandProperty SamAccountName
			}
			catch
			{ $ReadGroup = $null }
		}
		if ( $WriteGroup -and $ReadGroup )
		{ $Script:ADGroups += @{ "Id" = $FolderName; "Write" = $WriteGroup; "Read" = $ReadGroup } }
		else
		{ $Script:ErrorGroups += $FolderName}

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

	$Customer = ( ( $cbDisk.SelectedItem -split "\\" )[1] )
	foreach ( $entry in $entries )
	{
		$Window.Title = "Fetching AD-groups for R:-folders $( [Math]::Floor( $loopCounter / $entries.Count * 100 ) )"

		$FolderName = $cbDisk.SelectedValue.ToString() + "\" + $entry
		try
		{
			$WriteGroup = Get-ADGroup "$( $Customer )_File_$( if ( $Customer -in "OrgA","OrgB" ) { "adServ1" } else { "adServ2" } )_$( $entry )_C" | select -ExpandProperty SamAccountName
		}
		catch
		{
			try
			{
				$WriteGroup = Get-ADGroup "$( $Customer )_File_$( if ( $Customer -in "OrgA", "OrgB" ) { "adServ1" } else { "adServ2" } )_App_$( $entry )_C" | select -ExpandProperty SamAccountName
			}
			catch
			{
				try
				{
					$WriteGroup = Get-ADGroup "$( $Customer )_File_AD$( $Customer )$( if ( $Customer -eq "OrgA" ) { "02" } else { "01" } )_App_$( $entry )_C" | select -ExpandProperty SamAccountName
				}
				catch
				{
					try
					{
						$WriteGroup = Get-ADGroup ( ( ( Get-Acl $FolderName -ErrorAction Stop ).Access | where { ( $_.FileSystemRights -eq "Modify, Synchronize" ) -and ( $_.IsInherited -eq $false ) } | select -ExpandProperty IdentityReference ).Value -replace "AD\\" ) | select -ExpandProperty SamAccountName
					}
					catch
					{ $WriteGroup = $null }
				}
			}
		}

		try
		{
			$ReadGroup = Get-ADGroup "$( $Customer )_File_$( if ( $Customer -in "OrgA", "OrgB" ) { "adServ1" } else { "adServ2" } )_$( $entry )_R" | select -ExpandProperty SamAccountName
		}
		catch
		{
			try
			{
				$ReadGroup = Get-ADGroup "$( $Customer )_File_$( if ( $Customer -in "OrgA", "OrgB" ) { "adServ1" } else { "adServ2" } )_App_$( $entry )_R" | select -ExpandProperty SamAccountName
			}
			catch
			{
				try
				{
					$ReadGroup = Get-ADGroup "$( $Customer )_File_AD$( $Customer )$( if ( $Customer -eq "OrgA" ) { "02" } else { "01" } )_App_$( $entry )_R" | select -ExpandProperty SamAccountName
				}
				catch
				{
					try
					{
						$ReadGroup = Get-ADGroup ( ( ( Get-Acl $FolderName -ErrorAction Stop ).Access | where { ( $_.FileSystemRights -eq "Read, Synchronize" ) -and ( $_.IsInherited -eq $false ) } | select -ExpandProperty IdentityReference ).Value -replace "AD\\" ) | select -ExpandProperty SamAccountName
					}
					catch
					{ $ReadGroup = $null }
				}
			}
		}
		if ( $WriteGroup -and $ReadGroup )
		{ $Script:ADGroups += @{ "Id" = $FolderName; "Write" = $WriteGroup; "Read" = $ReadGroup } }
		else
		{ $Script:ErrorGroups += $FolderName }

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

	$Customer = ( ( $cbDisk.SelectedItem -split "\\" )[1] )
	foreach ( $entry in $entries )
	{
		$Window.Title = "Fetching AD-groups for S:-folders $( [Math]::Floor( $loopCounter / $entries.Count * 100 ) )"

		$FolderName = $cbDisk.SelectedValue.ToString() + "\" + $entry
		try
		{
			$WriteGroup = Get-ADGroup "$( ( $FolderName -split "\\" )[1] )_File_AD$( $Customer )01_Gem_$( ( $FolderName -split "\\" )[2] )_$( ( ( $FolderName -split "\\" )[3] ) -replace " ","_" -replace "å","a" -replace "ä","a" -replace "ö","o" -replace "è","e" )_Ext_C" | select -ExpandProperty SamAccountName
		}
		catch
		{
			try
			{
				$WriteGroup = Get-ADGroup "$( ( ( ( Get-Acl $FolderName -ErrorAction Stop ).Access | where { ( $_.FileSystemRights -eq "Modify, Synchronize" ) -and ( $_.IsInherited -eq $false ) } | select -ExpandProperty IdentityReference ).Value -replace "AD\\" ).Substring( 0, ( ( ( Get-Acl $FolderName -ErrorAction Stop ).Access | where { ( $_.FileSystemRights -eq "Modify, Synchronize" ) -and ( $_.IsInherited -eq $false ) } | select -ExpandProperty IdentityReference ).Value -replace "AD\\" ).Length-2 ) )_Ext_C" | select -ExpandProperty SamAccountName
			}
			catch
			{ $WriteGroup = $null }
		}

		try
		{
			$ReadGroup = Get-ADGroup "$( ( $FolderName -split "\\" )[1] )_File_AD$( $Customer )01_Gem_$( ( $FolderName -split "\\" )[2] )_$( ( ( $FolderName -split "\\" )[3] ) -replace " ","_" -replace "å","a" -replace "ä","a" -replace "ö","o" -replace "è","e" )_Ext_R" | select -ExpandProperty SamAccountName
		}
		catch
		{
			try
			{
				$ReadGroup = Get-ADGroup "$( ( ( ( Get-Acl $FolderName -ErrorAction Stop ).Access | where { ( $_.FileSystemRights -eq "ReadAndExecute, Synchronize" ) -and ( $_.IsInherited -eq $false ) } | select -ExpandProperty IdentityReference ).Value -replace "AD\\" ).Substring( 0, ( ( ( Get-Acl $FolderName -ErrorAction Stop ).Access | where { ( $_.FileSystemRights -eq "ReadAndExecute, Synchronize" ) -and ( $_.IsInherited -eq $false ) } | select -ExpandProperty IdentityReference ).Value -replace "AD\\" ).Length - 2 ) )_Ext_R" | select -ExpandProperty SamAccountName
			}
			catch
			{ $ReadGroup = $null }
		}
		if ( $WriteGroup -and $ReadGroup )
		{ $Script:ADGroups += @{ "Id" = $FolderName; "Write" = $WriteGroup; "Read" = $ReadGroup } }
		else
		{ $Script:ErrorGroups += $FolderName}

		$loopCounter++
	}
}

##############################
# Collect input from textboxes
function CollectEntries
{
	if ( ( $LineCount = $txtUsersForWritePermission.LineCount ) -gt 0 )
	{
		$lines = @()
		for ( $i = 0; $i -lt $LineCount; $i++ ) { ( $txtUsersForWritePermission.GetLineText( $i ) ).Split( ";""," ) | foreach { $lines += ( $_ ).Trim() } }
		CollectUsers -entries ( $lines | where { $_ -ne "" } ) -PermissionType "Write"
	}
	if ( ( $LineCount = $txtUsersForReadPermission.LineCount ) -gt 0 )
	{
		$lines = @()
		for ( $i = 0; $i -lt $LineCount; $i++ ) { ( $txtUsersForReadPermission.GetLineText( $i ) ).Split( ";""," ) | foreach { $lines += ( $_ ).Trim() } }
		CollectUsers -entries ( $lines | where { $_ -ne "" } ) -PermissionType "Read"
	}
	if ( ( $LineCount = $txtUsersForRemovePermission.LineCount ) -gt 0 )
	{
		$lines = @()
		for ( $i = 0; $i -lt $LineCount; $i++ ) { ( $txtUsersForRemovePermission.GetLineText( $i ) ).Split( ";""," ) | foreach { $lines += ( $_ ).Trim() } }
		CollectUsers -entries ( $lines | where { $_ -ne "" } ) -PermissionType "Remove"
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
		{ $Script:WriteUsers = @() }
		"Read"
		{ $Script:ReadUsers = @() }
		"Remove"
		{ $Script:RemoveUsers = @() }
	}

	foreach ( $entry in $entries )
	{
		$Window.Title = "Getting users for $PermissionType-permission $( [Math]::Floor( $loopCounter / $entries.Count * 100 ) )"
		$User = CheckUser -Id $entry
		if ( $User -eq "NotFound" )
		{
			$Script:ErrorUsers += @{ "Id" = $entry }
		}
		else
		{
			$o = $null
			$AD = $null
			switch ( $User )
			{
				"User"
				{ $AD = Get-ADUser -Identity $entry }
				"Group"
				{ $AD = Get-ADGroup -Identity $entry }
				"EKGroup"
				{ $AD = Get-ADGroup -LDAPFilter "(orgIdentity=$entry)" -Properties SamAccountName }
			}
			foreach ( $u in $AD )
			{
				$o = @{ "Id" = $entry.ToString().ToUpper(); "AD" = $u; "Type" = $UserType -replace "OrgGroups", "OrgGroup" }
				if ( ( $Script:WriteUsers | where { $_.Id -eq $o.Id } ) -or
					( $Script:ReadUsers | where { $_.Id -eq $o.Id } ) -or
					( $Script:RemoveUsers | where { $_.Id -eq $o.Id } ) )
				{
					$Script:Duplicates += $o.Id
				}
				else
				{
					switch ( $PermissionType )
					{
						"Write"
							{ $Script:WriteUsers += $o }
						"Read"
							{ $Script:ReadUsers += $o }
						"Remove"
							{ $Script:RemoveUsers += $o }
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
	$LogText = ""
	$LogText += "$( Get-Date -Format "yyyy-MM-dd HH:mm:ss" )"
	$Script:ADGroups.Id | foreach { $LogText += "`n$_" }
	if ( $Script:WriteUsers )
	{
		if ( $cbDisk.SelectedItem.Substring( 1, 2 ) -eq ":\" )
		{ $LogText += "`nRead-/write permission" }
		else
		{ $LogText += "`nNew permission" }
		$Script:WriteUsers.AD | foreach { $LogText += "`n`t$( $_.Name )" }
	}

	if ( $Script:ReadUsers )
	{
		$LogText += "`nRead permission"
		$Script:ReadUsers.AD | foreach { $LogText += "`n`t$( $_.Name )" } }

	if ( $Script:RemoveUsers )
	{
		$LogText += "`nRemove permission"
		$Script:RemoveUsers.AD | foreach { $LogText += "`n`t$( $_.Name )" }
	}

	if ( $Script:ErrorUsers )
	{
		$LogText += "`nFound no account for:"
		$Script:ErrorUsers.Id | foreach { $LogText += "`n`t$_" }
	}

	if ( $Script:ErrorGroups )
	{
		$LogText += "`nFound no AD-group for:"
		$Script:ErrorGroups | foreach { $LogText += "`n`t$_" }
	}

	$LogText += "`n------------------------------"
	WriteToLog -Text $LogText
}

################
# Create message
function CreateMessage
{
	$Message = @()
	$Message += "Hello!`n`nFor these $Script:GroupType"
	$Script:ADGroups.Id | foreach { $Message += "`t$_" }
	$Message += "following permission changes have been made"
	if ( $Script:WriteUsers )
	{
		if ( $cbDisk.SelectedItem.Substring( 1, 2 ) -eq ":\" )
		{ $Message += "`Created read/write permission for:" }
		else
		{ $Message += "`nCreated permission for:" }
		$Script:WriteUsers.AD | foreach { $Message += "`t$( $_.Name )" }
	}
	if ( $Script:ReadUsers )
	{
		$Message += "`nCreated read permission for:"
		$Script:ReadUsers.AD | foreach { $Message += "`t$( $_.Name )" }
	}
	if ( $Script:RemoveUsers )
	{
		$Message += "`nRemoved permission for:"
		$Script:RemoveUsers.AD | foreach { $Message += "`t$( $_.Name )" }
	}
	if ( $Script:ErrorUsers )
	{
		$Message += "`nFound no account for these given values:"
		$Script:ErrorUsers.Id | foreach { $Message += "`t$_" }
	}
	if ( $Script:ErrorGroups )
	{
		$Message += "`nFound no permissiongroups for these folders:"
		$Script:ErrorGroups | foreach { $Message += "`t$_" }
	}
	$Message += $Script:Signatur
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$Message | clip
}

###############################
# Initiate scriptwide variables
function ResetVariables
{
	$Script:ADGroups = @()
	$Script:Duplicates = @()
	$Script:ErrorUsers = @()
	$Script:ErrorGroups = @()
	$Script:WriteUsers = @()
	$Script:ReadUsers = @()
	$Script:RemoveUsers = @()
}

##########################
# Start permission editing
function PerformPermissions
{
	CollectEntries
	CollectADGroups

	if ( $Script:Duplicates )
	{
		ShowMessageBox -Text "There are values for more than one permission type.`nCorrect the listings and try again.`n$( $Script:Duplicates | select -Unique )" -Title "Duplicates" -Icon "Stop"
	}
	else
	{
		$Continue = ShowMessageBox -Text "Do you for $( @( $Script:ADGroups ).Count ) $( $Script:GroupType ) perform $( @( $Script:WriteUsers ).Count + @( $Script:ReadUsers ).Count + @( $Script:RemoveUsers ).Count ) changes?$( if ( $Script:ErrorGroups -or $Script:ErrorUsers ) { "`nSome values have no AD-object." } )" -Title "Continue?" -Button "OKCancel"
		if ( $Continue -eq "OK" )
		{
			$loopCounter = 0
			foreach ( $Group in $Script:ADGroups )
			{
				$Window.Title = "Applying grouppermissions $( [Math]::Floor( $loopCounter / $Script:ADGroups.Count * 100 ) )"
				if ( $Script:WriteUsers )
				{
					if ( $cbDisk.SelectedItem.Substring( 1, 2 ) -eq ":\" )
					{
						if ( $Group.Write )
						{
							Add-ADGroupMember -Identity $Group.Write -Members $Script:WriteUsers.Id -Confirm:$false
						}
					}
					else
					{
						Add-ADGroupMember -Identity $Group.Id -Members $Script:WriteUsers.Id -Confirm:$false
					}
				}

				if ( $Script:ReadUsers )
				{
					if ( $Group.Read )
					{
						Add-ADGroupMember -Identity $Group.Read -Members $Script:ReadUsers.Id -Confirm:$false 
					}
				}

				if ( $Script:RemoveUsers )
				{
					if ( $cbDisk.SelectedItem.Substring( 1, 2 ) -eq ":\" )
					{
						if ( $Group.Write -and $Group.Read )
						{
							Remove-ADGroupMember -Identity $Group.Write -Members $Script:RemoveUsers.Id -Confirm:$false
							Remove-ADGroupMember -Identity $Group.Read -Members $Script:RemoveUsers.Id -Confirm:$false
						}
					}
					else
					{
						Remove-ADGroupMember -Identity $Group.Id -Members $Script:RemoveUsers.Id -Confirm:$false
					}
				}
				$loopCounter++
			}

			CreateLogText
			WriteToLogFile
			CreateMessage
			ShowMessageBox -Text "Performed $( @( $Script:ADGroups ).Count * ( @( $Script:WriteUsers ).Count + @( $Script:ReadUsers ).Count + @( $Script:RemoveUsers ).Count ) ) changes.`nA message have been copied to the clipboard" -Title "Done"
			UndoInput
			$Window.Title = $Title
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
		if ( $a.SamAccountName -match "Role_Operations" )
		{
			$Script:LogFilePath = "\\domain\\Results\FolderTool"
			$Script:ErrorLogFilePath = "$LogFilePath\Errorlogs\$env:USERNAME-Errorlog.txt"

			$Script:HandledFolders = $OperationsHandledFolders
			$Script:Signatur += "`nBest regards`n`nOperations"
		}
		elseif ( $a.SamAccountName -match "Role_Servicedesk" )
		{
			$Script:ErrorLogFilePath = ( ( Get-Item $PSScriptRoot ).Parent.FullName) + "\ErrorLogs\" + ( Get-Item $PSCommandPath ).BaseName + "\" + $env:USERNAME + " ErrorLog.txt"
			$Script:LogFilePath = ( ( Get-Item $PSScriptRoot ).Parent.FullName) + "\Log\" + $( [datetime]::Now.Year ) + "\" + [datetime]::Now.Month + "\" + ( Get-Item $PSCommandPath ).BaseName + "\"

			$Script:HandledFolders = $ServicedeskHandledFolders
			$Script:Signatur += "`nBest regards`n`nServicedesk"
		}
		else
		{ throw }
	}
	catch
	{
		ShowMessageBox -MessageText "You don't have the propper permissions to run this script." -Title "Permissionproblem" -Icon "Stop"
		Exit
	}
}

######################################
# Fill combobox list with disk-folders
function UpdateDiskList
{
	Get-ChildItem2 "G:\" -Directory | where { $_.FullName -in $Script:HandledFolders } | select -ExpandProperty FullName | foreach { [void] $cbDisk.Items.Add( $_ ) }
	Get-ChildItem2 "S:\" -Directory | where { $_.FullName -in $Script:HandledFolders } | select -ExpandProperty FullName | foreach { [void] $cbDisk.Items.Add( $_ ) }
	Get-ChildItem2 "R:\" -Directory | where { $_.FullName -in $Script:HandledFolders } | select -ExpandProperty FullName | foreach { [void] $cbDisk.Items.Add( $_ ) }

	[void] $cbDisk.Items.Add( "App1" )
	[void] $cbDisk.Items.Add( "App2" )
	[void] $cbDisk.Items.Add( "App3" )
	[void] $cbDisk.Items.Add( "App4" )
}

#########################
# Get folders / appgroups
function UpdateFolderList
{
	$Window.Title = "Fetching folders..."
	$lbFoldersChosen.Items.Clear()
	$Script:Folder = @()
	if ( $cbDisk.SelectedItem.Substring( 1, 2 ) -eq ":\" )
	{
		$Script:GroupType = "folders"
		$lblUsersForWritePermission.Content = "Read / write permissions"
		$ReadLabel.SharedSizeGroup = "Label"
		$ReadDist.Height = 3
		$ReadTxtb.Height = "*"
		$txtUsersForReadPermission.IsEnabled = $true
		$lblFoldersChosen.Content = "Chosen folders"

		if ( $cbDisk.SelectedItem.Substring( 0, 1 ) -eq "S" )
		{
			$Script:Folders = Get-ChildItem $cbDisk.SelectedItem -Directory | select -ExpandProperty FullName | foreach { ( Get-ChildItem2 $_ -Directory | select -ExpandProperty FullName ) -replace ( [System.Text.RegularExpressions.Regex]::Escape( "$( $cbDisk.SelectedItem )\" ) ) | sort }
		}
		else
		{
			$Script:Folders = Get-ChildItem $cbDisk.SelectedItem -Directory | where { $_.FullName -notin $ExceptionFolders } | select -ExpandProperty Name | sort
		}

		$txtFolderSearch.Focus()
	}
	else
	{
		$lblUsersForWritePermission.Content = "Add permission"
		$ReadLabel.SharedSizeGroup = "Del"
		$ReadLabel.Height = 0
		$ReadDist.Height = 0
		$ReadTxtb.Height = 0
		$txtUsersForReadPermission.IsEnabled = $false
		$lblFoldersChosen.Content = "Chosen app-groups"

		switch ( $cbDisk.SelectedItem )
		{
			"App1"
			{
				$Script:GroupType = "App1-groups"
				$AppFilter = "(Name=Org2_App1*)"
				$Exclude = $null
			}
			"App2"
			{
				$Script:GroupType = "App2-groups"
				$AppFilter = "(|(Name=Org3_Mig_App1*)(Name=Org3_Acc_App1*))"
				$Exclude = $null
			}
			"App3"
			{
				$Script:GroupType = "App3-groups"
				$AppFilter = "(&(Name=Org3_Acc_App3*_Users)(!(Name=*DNSReg*)))"
				$Exclude = @( "DNSReg", "Acceptans" )
				$split = "_"
				$index = 3
			}
			"App4"
			{
				$Script:GroupType = "App4-groups"
				$AppFilter = "(&(Name=App4*)(!(Name=*_Editor)))"
				$Exclude = @( "ALB", "ARM", "DOS", "HKN", "HP", "Innovation", "IoU", "IT", "PGS", "SMB" )
				$split = "_"
				$index = 2
			}
		}
		if ( $Exclude )
		{ $Script:Folders = Get-ADGroup -LDAPFilter $AppFilter | where { $Exclude -notcontains $_.Name.Split( $split )[$index] } | select -ExpandProperty Name }
		else
		{ $Script:Folders = Get-ADGroup -LDAPFilter "$AppFilter" | select -ExpandProperty Name | sort }
	}

	UpdateFolderListItems
	$Window.Title = $Script:Title
}

######################
# Fill list of folders
function UpdateFolderListItems
{
	$lbFolderList.Items.Clear()
	foreach ( $Folder in ( $Script:Folders | where { $lbFoldersChosen.Items -notcontains $_ } ) )
	{
		[void] $lbFolderList.Items.Add( $Folder )
	}
}

##############################
# Write information to logfile
function WriteToLogFile
{
	# One line per group/user
	$LogText = @()
	foreach ( $group in $Script:ADGroups )
	{
		foreach ( $u in $Script:WriteUsers )
		{
			if ( $cbDisk.SelectedItem.Substring( 1, 2 ) -eq ":\" ) { $LogText += "$( $u.Id ) > Add '$( $group.Write )'" }
			else { $LogText += "$( $u.Id ) > Add '$( $group.Id )'" }
		}
		foreach ( $u in $Script:ReadUsers )
		{
			$LogText += "$( $u.Id ) > Add '$( $group.Read )'"
		}
		foreach ( $u in $Script:RemoveUsers )
		{
			if ( $cbDisk.SelectedItem.Substring( 1, 2 ) -eq ":\" ) { $LogText += "$( $u.Id ) > Remove '$( $group.Write )' & '$( $group.Read )'" }
			else { $LogText += "$( $u.Id ) > Remove '$( $group.Id )'" }
		}
	}
	$LogText | foreach { WriteLog -LogText $_ }
}

####################  End Operational functions  ####################

####################  Control functions  ####################

#####################################################################################
# Some input is entered, check if necessary input is given, enabled button to perform
function CheckReady
{
	if ( ( $lbFoldersChosen.Items.Count -gt 0 ) -and ( ( $txtUsersForWritePermission.Text.Length -ge 4 ) -or ( $txtUsersForReadPermission.Text.Length -ge 4 ) -or ( $txtUsersForRemovePermission.Text.Length -ge 4 ) ) )
	{
		$btnPerform.IsEnabled = $true
	}
	else
	{
		$btnPerform.IsEnabled = $false
	}
}

##############################
# A selected folder is removed
function FolderDeselected
{
	$lbFolderList.Items.Add( $lbFoldersChosen.SelectedItem )
	$lbFoldersChosen.Items.Remove( $lbFoldersChosen.SelectedItem )
	CheckReady
	UpdateFolderListItems
	$txtFolderSearch.Text = ""
	$txtFolderSearch.Focus()
}

###############################################
# A folder is selected, move to lbFoldersChosen
function FolderSelected
{
	$lbFoldersChosen.Items.Add( $lbFolderList.SelectedItem )
	$lbFolderList.Items.Remove( $lbFolderList.SelectedItem )
	CheckReady
	UpdateFolderListItems
	$txtFolderSearch.Text = ""
	$txtFolderSearch.Focus()
}

##############################################
# Search for any of item containing searchword
function SearchListboxItem
{
	$list = $Script:Folders | where { $lbFoldersChosen.Items -notcontains $_ }
	if ( $txtFolderSearch.Text.Length -eq 0 )
	{
		$lbFolderList.SelectedIndex = -1
	}
	else
	{
		$list = $list | where { $_ -like "*$( $txtFolderSearch.Text.Replace( "\\", "\\\\" ) )*" }
	}
	$lbFolderList.Items.Clear()
	foreach ( $i in $list )
	{
		$lbFolderList.Items.Add( $i )
	}
}

#################
# Clear all input
function UndoInput
{
	$txtUsersForWritePermission.Text = ""
	$txtUsersForReadPermission.Text = ""
	$txtUsersForRemovePermission.Text = ""
	$lbFoldersChosen.Items.Clear()
	UpdateFolderList
}

#################################
# Write information to loglistbox
function WriteToLog
{
	param (
		$Text
	)

	$lbLog.Items.Insert( 0, $Text )
}

####################  End Control functions  ####################

########################################
# Script start
########################################
Import-Module "$( $args[0] )\Modules\FileOps.psm1"

####################  Create window  ####################
$Window, $vars = CreateWindow
$vars | foreach { Set-Variable -Name $_ -Value $Window.FindName( $_ ) -Scope script }
####################  End Create window  ####################

####################  Control event functions  ####################
$btnPerform.Add_Click( { PerformPermissions } )
$btnUndo.Add_Click( { UndoInput } )
$cbDisk.Add_DropDownClosed( { if ( $cbDisk.SelectedItem -ne $null ) { UpdateFolderList } } )
$txtFolderSearch.Add_TextChanged( { SearchListboxItem } )
$lbFolderList.Add_MouseDoubleClick( { FolderSelected } )
$lbFoldersChosen.Add_MouseDoubleClick( { FolderDeselected } )
$txtUsersForWritePermission.Add_TextChanged( { CheckReady } )
$txtUsersForReadPermission.Add_TextChanged( { CheckReady } )
$txtUsersForRemovePermission.Add_TextChanged( { CheckReady } )
$Window.Add_ContentRendered( { $Window.Title = "Förbereder..."; $Window.Top = 20; $Window.Activate(); SetUserSettings; UpdateDiskList; $Window.Title = $Script:Title; $MainGrid.IsEnabled = $true } )
####################  End Control event functions  ####################

####################  Initialization  ####################

# Folders depending on user AD-groups
$OperationsHandledFolders =
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

$ServicedeskHandledFolders =
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
$ExceptionFolders = "R:\Org2\DFSFolderLink", "R:\Org4\DFSFolderLink"

$Script:Title = "Add/remove folderpermissions"
$Script:ErrorLogFilePath = ""
$Script:HandledFolders = @()
$Script:LogFilePath = ""
$Script:Signatur = ""
ResetVariables

####################  End Initialization  ####################

[void] $Window.ShowDialog()
$Window.Close()
