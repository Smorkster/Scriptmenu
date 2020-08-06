#Description = Edit AD-Groups for applications
Import-Module "$( $args[0] )\Modules\FileOps.psm1"

##########################################
# Verify if operations is ready to perform
function CheckReady
{
	if ( ( $lbGroupsChosen.Items.Count -gt 0 ) -and ( ( $txtUsersAddPermission.Text.Length -ge 4 ) -or ( $txtUsersRemovePermission.Text.Length -ge 4 ) ) )
	{
		$btnPerform.IsEnabled = $true
	}
	else
	{
		$btnPerform.IsEnabled = $false
	}
}

############################
# Check if user exists in AD
function CheckUser
{
	param ( $Id )

	if ( dsquery User -samid $Id )
	{
		return "User"
	}
	else
	{
		$Script:ErrorUsers += $Id
		return "NotFound"
	}
}

##############################
# Collect input from textboxes
function CollectEntries
{
	if ( ( $LineCount = $txtUsersAddPermission.LineCount ) -gt 0 )
	{
		$lines = @()
		for ( $i = 0; $i -lt $LineCount; $i++ ) { ( $txtUsersAddPermission.GetLineText( $i ) ).Split( ";""," ) | foreach { $lines += ( $_ ).Trim() } }
		CollectUsers -entries ( $lines | where { $_ -ne "" } ) -PermissionType "Add"
	}
	if ( ( $LineCount = $txtUsersRemovePermission.LineCount ) -gt 0 )
	{
		$lines = @()
		for ( $i = 0; $i -lt $LineCount; $i++ ) { ( $txtUsersRemovePermission.GetLineText( $i ) ).Split( ";""," ) | foreach { $lines += ( $_ ).Trim() } }
		CollectUsers -entries ( $lines | where { $_ -ne "" } ) -PermissionType "Remove"
	}
}

#####################################################
# Get users in the textbox corresponding to operation
function CollectUsers
{
	param ( $entries, $PermissionType )

	$loopCounter = 0

	switch ( $PermissionType )
	{
		"Add" { $Script:WriteUsers = @() }
		"Remove" { $Script:RemoveUsers = @() }
	}

	foreach ( $entry in $entries )
	{
		$Window.Title = "Fetching users for $PermissionType-permission $( [Math]::Floor( $loopCounter / $entries.Count * 100 ) )"
		$User = CheckUser -Id $entry
		if ( $User -eq "NotFound" )
		{
			$Script:ErrorUsers += @{ "Id" = $entry }
		}
		else
		{
			$object = $null
			$object = @{ "Id" = $entry.ToString().ToUpper(); "AD" = ( Get-ADUser -Identity $entry -Properties otherMailbox ); "PW" = GeneratePassword }
			if ( ( ( $Script:AddUsers | where { $_.Id -eq $object.Id } ).Count + ( $Script:RemoveUsers | where { $_.Id -eq $object.Id } ).Count ) -gt 1 )
			{
				$Script:Duplicates += $object.Id
			}
			else
			{
				switch ( $PermissionType )
				{
					"Add"
						{ $Script:AddUsers += $object }
					"Remove"
						{ $Script:RemoveUsers += $object }
				}
			}
		}
		$loopCounter++
	}
}

#########################
# Create text for logfile
function CreateLogText
{
	$LogText = ""
	$LogText += "$( Get-Date -Format "yyyy-MM-dd HH:mm:ss" )"
	$lbGroupsChosen.Items | foreach { $LogText += "`n$_" }
	if ( $Script:AddUsers )
	{
		$LogText += "`nNew permission"
		$Script:AddUsers.AD | foreach { $LogText += "`n`t$( $_.Name )" }
	}

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

	$LogText += "`n------------------------------"
	WriteToLog -Text $LogText
}

##########################################
# Generate message for performed operation
function CreateMessage
{
	$Message = @()
	$Message += "Hello!`n`nFor these $Script:GroupType"
	$lbGroupsChosen.Items | foreach { $Message += "`t$_" }
	$Message += "these permission changes have been made:"
	if ( $Script:AddUsers )
	{
		$Message += "`nCreate permission for:"
		$Script:AddUsers | foreach { $Message += "`t$( $_.AD.Name )$( if ( $_.AD.otherMailbox -match "org7" ) { "( new password: $( $_.PW ) )" } )" }
	}
	if ( $Script:RemoveUsers )
	{
		$Message += "`nRemoved permission for:"
		$Script:RemoveUsers.AD | foreach { $Message += "`t$( $_.Name )" }
	}
	if ( $Script:ErrorUsers )
	{
		$Message += "`nFound no account for these input:"
		$Script:ErrorUsers.Id | foreach { $Message += "`t$_" }
	}
	$Message += $Script:Signatur
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$Message | clip
}

########################################
# Call generator for each of the strings
function GeneratePassword
{
	$p = Get-RandomCharacters -length 1 -characters 'abcdefghikmnprstuvwxyz'
	$p += Get-RandomCharacters -length 1 -characters 'ABCDEFGHKLMNPRSTUVWXYZ'
	$p += Get-RandomCharacters -length 1 -characters '123456789'
	$p += Get-RandomCharacters -length 5 -characters 'abcdefghikmnprstuvwxyzABCDEFGHKLMNPRSTUVWXYZ123456789'
	$p = Scramble-String $p
	return $p
}

##########################################################
# Pick random number up to $length as index in $characters
function Get-RandomCharacters
{
	param ( $length, $characters )
	$random = 1..$length | foreach { Get-Random -Maximum $characters.Length }
	$private:ofs = ""
	return [string]$characters[$random]
}

########################################
# Randomize order of charaters in string
function Scramble-String
{
	param ( [string]$inputString )
	$characterArray = $inputString.ToCharArray()
	$scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length
	return -join $scrambledStringArray
}

#############################################
# A selected group was doubleclicked
# Remove from selected list, add to grouplist
function GroupDeselected
{
	if ( $lbGroupsChosen.SelectedItem -ne $null )
	{
		$lbAppGroupList.Items.Add( $lbGroupsChosen.SelectedItem )
		$lbGroupsChosen.Items.Remove( $lbGroupsChosen.SelectedItem )
		CheckReady
		UpdateAppGroupListItems
	}
}

#############################################
# A group was doubleclicked
# Remove from grouplist, add to selected list
function GroupSelected
{
	if ( $lbAppGroupList.SelectedItem -ne $null )
	{
		$lbGroupsChosen.Items.Add( $lbAppGroupList.SelectedItem )
		$lbAppGroupList.Items.Remove( $lbAppGroupList.SelectedItem )
		CheckReady
		UpdateAppGroupListItems
	}
}

#############################
# Start performing operations
function PerformPermissions
{
	CollectEntries

	if ( $Script:Duplicates )
	{
		ShowMessageBox -Text "There are doublet values in input.`nCorrect these and run again:`n$( $Script:Duplicates | select -Unique )" -Title "Doublets" -Icon "Stop"
	}
	else
	{
		$Continue = ShowMessageBox -Text "Do you for $( $lbGroupsChosen.Items.Count ) $( $Script:GroupType ) perform $( @( $Script:AddUsers ).Count + @( $Script:RemoveUsers ).Count ) changes?$( if ( $Script:ErrorUsers ) { "`nSome ids does not have an AD-account." } )" -Title "Continue?" -Button "OKCancel"
		if ( $Continue -eq "OK" )
		{
			$loopCounter = 0
			foreach ( $Group in $lbGroupsChosen.Items )
			{
				$Window.Title = "Applying grouppermissions$( [Math]::Floor( $loopCounter / $lbGroupsChosen.Items.Count * 100 ) )%"
				if ( $Script:AddUsers )
				{
					Add-ADGroupMember -Identity $Group -Members $Script:AddUsers.Id -Confirm:$false
				}

				if ( $Script:RemoveUsers )
				{
					Remove-ADGroupMember -Identity $Group -Members $Script:RemoveUsers.Id -Confirm:$false
				}
				$loopCounter++
			}
			foreach ( $u in ( $Script:AddUsers | where { $_.AD.otherMailbox -match "org7" } ) )
			{
				Set-ADAccountPassword -Identity $u.AD -Reset -NewPassword ( ConvertTo-SecureString -AsPlainText $u.PW -Force )
				Set-ADUser -Identity $u.AD -ChangePasswordAtLogon $false -Confirm:$false
			}
			CreateLogText
			WriteToLogFile
			CreateMessage
			ShowMessageBox -Text "Performed $( $lbGroupsChosen.Items.Count * ( @( $Script:AddUsers ).Count + @( $Script:RemoveUsers ).Count ) ) changes.`nA message was copied to clipboard" -Title "Done"

			UndoInput
			$Window.Title = $Script:Title
		}
	}
}

##################
# Resets variables
function ResetVariables
{
	$Script:ADGroups = @()
	$Script:Duplicates = @()
	$Script:ErrorUsers = @()
	$Script:AddUsers = @()
	$Script:RemoveUsers = @()
}

#################################################
# Depending on user, set its appropriate settings
function SetUserSettings
{
	try
	{
		$a = Get-ADPrincipalGroupMembership $env:USERNAME
		if ( $a.SamAccountName -match "Role_Operations" )
		{
			$Script:LogFilePath = "\\domain\Results\FolderTool"
			$Script:ErrorLogFilePath = "$LogFilePath\Errorlogs\$env:USERNAME-Errorlog.txt"

			$Script:Signatur = "`nBest regards`n`nOperations"
		}
		elseif ( ( Get-ADGroupMember "Role_Servicedesk_Operations" ).Name -contains ( Get-ADUser $env:USERNAME ).Name )
		{
			$Script:Signatur = "`nBest regards`n`nServicedesk"
		}
		else
		{ throw }
	}
	catch
	{
		ShowMessageBox -Text "You don't have proper permissions to run this script." -Title "Permission problem" -Icon "Stop"
		Exit
	}
}

###########################################
# Add names for applications with AD-Groups
function UpdateAppList
{
	[void] $cbApp.Items.Add( "App1" )
	[void] $cbApp.Items.Add( "App2" )
	[void] $cbApp.Items.Add( "App3" )
	[void] $cbApp.Items.Add( "App4" )
}

#########################################################################
# Item in combobox has changed, get that applications group and list them
function UpdateAppGroupList
{
	$lbGroupsChosen.Items.Clear()
	$Window.Title = "Fetching app-groups..."
	$Script:GroupList = @()

	switch ( $cbApp.SelectedItem )
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
	{ $Script:GroupList = Get-ADGroup -LDAPFilter $AppFilter | where { $Exclude -notcontains $_.Name.Split( $split )[$index] } | select -ExpandProperty Name }
	else
	{ $Script:GroupList = Get-ADGroup -LDAPFilter "$AppFilter" | select -ExpandProperty Name | sort }

	UpdateAppGroupListItems
	$Window.Title = $Script:Title
}

#########################################################
# Update the list of groups, excluding any selected group
function UpdateAppGroupListItems
{
	$lbAppGroupList.Items.Clear()
	foreach ( $item in ( $Script:GroupList | where { $lbGroupsChosen.Items -notcontains $_ } ) )
	{
		[void] $lbAppGroupList.Items.Add( $item )
	}
}

########################################
# Deletes all userinput and resets lists
function UndoInput
{
	$txtUsersAddPermission.Text = ""
	$txtUsersRemovePermission.Text = ""
	$lbGroupsChosen.Items.Clear()
	UpdateAppList
}

###############################
# Write the work to log listbox
function WriteToLog
{
	param (
		$Text
	)

	$lbLog.Items.Insert( 0, $Text )
}

######################################
# Write finished operations to logfile
function WriteToLogFile
{
	# One line per group/user
	$LogText = @()
	foreach ( $group in $Script:ADGroups )
	{
		foreach ( $u in $Script:AddUsers )
		{
			$LogText += "$( $u.Id ) > Add '$( $group.Id )'$( if ( $_.AD.otherMailbox -match "org7" ) { " new password: $( $_.PW )" } )"
		}
		foreach ( $u in $Script:RemoveUsers )
		{
			$LogText += "$( $u.Id ) > Remove '$( $group.Id )'"
		}
	}
	$LogText | foreach { WriteLog -LogText $_ }
}

######################### Scriptet begins #########################
SetUserSettings
$Window, $vars = CreateWindow
$vars | foreach { Set-Variable -Name $_ -Value $Window.FindName( $_ ) }

$btnPerform.Add_Click( { PerformPermissions } )
$btnUndo.Add_Click( { UndoInput } )
$cbApp.Add_DropDownClosed( { if ( $cbApp.SelectedItem -ne $null ) { UpdateAppGroupList } } )
$lbAppGroupList.Add_MouseDoubleClick( { GroupSelected } )
$lbGroupsChosen.Add_MouseDoubleClick( { GroupDeselected } )
$txtUsersAddPermission.Add_TextChanged( { CheckReady } )
$txtUsersRemovePermission.Add_TextChanged( { CheckReady } )
$Window.Add_ContentRendered( { $Window.Title = "Preparing..."; $Window.Top = 20; $Window.Activate(); UpdateAppList; $Window.Title = $Script:Title ; $MainGrid.IsEnabled = $true } )

$Script:Title = "Add / remove app permissions"
$Script:ErrorLogFilePath = ""
$Script:HandledFolders = @()
$Script:LogFilePath = ""
ResetVariables

[void] $Window.ShowDialog()
$Window.Close()
