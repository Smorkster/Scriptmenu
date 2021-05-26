<#
.Synopsis Edit AD-Groups for applications
.Requires Role_Backoffice
.Description Add/remove permissions for applications. These applications are governed by AD-groups. When the permissions are set, a message with summary is copied to the clipboard.
.Author Smorkster (smorkster)
#>

##########################################
# Verify if operations is ready to perform
function CheckReady
{
	if ( ( $syncHash.lbGroupsChosen.Items.Count -gt 0 ) -and ( ( $syncHash.txtUsersAddPermission.Text.Length -ge 4 ) -or ( $syncHash.txtUsersRemovePermission.Text.Length -ge 4 ) ) )
	{
		$syncHash.btnPerform.IsEnabled = $true
	}
	else
	{
		$syncHash.btnPerform.IsEnabled = $false
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
		$syncHash.ErrorUsers += $Id
		return "NotFound"
	}
}

##############################
# Collect input from textboxes
function CollectEntries
{
	if ( ( $LineCount = $syncHash.txtUsersAddPermission.LineCount ) -gt 0 )
	{
		$lines = @()
		for ( $i = 0; $i -lt $LineCount; $i++ ) { ( $syncHash.txtUsersAddPermission.GetLineText( $i ) ).Split( ";""," ) | ForEach-Object { $lines += ( $_ ).Trim() } }
		CollectUsers -entries ( $lines | Where-Object { $_ -ne "" } ) -PermissionType "Add"
	}
	if ( ( $LineCount = $syncHash.txtUsersRemovePermission.LineCount ) -gt 0 )
	{
		$lines = @()
		for ( $i = 0; $i -lt $LineCount; $i++ ) { ( $syncHash.txtUsersRemovePermission.GetLineText( $i ) ).Split( ";""," ) | ForEach-Object { $lines += ( $_ ).Trim() } }
		CollectUsers -entries ( $lines | Where-Object { $_ -ne "" } ) -PermissionType "Remove"
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
		"Add" { $syncHash.AddUsers = @() }
		"Remove" { $syncHash.RemoveUsers = @() }
	}

	foreach ( $entry in $entries )
	{
		$syncHash.Window.Title = "$( $msgTable.WGettingUser ) $( [Math]::Floor( $loopCounter / $entries.Count * 100 ) )"
		$User = CheckUser -Id $entry
		if ( $User -eq "NotFound" )
		{
			$syncHash.ErrorUsers += @{ "Id" = $entry }
		}
		else
		{
			$object = $null
			$object = @{ "Id" = $entry.ToString().ToUpper(); "AD" = ( Get-ADUser -Identity $entry -Properties otherMailbox ); "PW" = GeneratePassword }
			if ( ( ( $syncHash.AddUsers | Where-Object { $_.Id -eq $object.Id } ).Count + ( $syncHash.RemoveUsers | Where-Object { $_.Id -eq $object.Id } ).Count ) -gt 1 )
			{
				$syncHash.Duplicates += $object.Id
			}
			else
			{
				switch ( $PermissionType )
				{
					"Add"
						{ $syncHash.AddUsers += $object }
					"Remove"
						{ $syncHash.RemoveUsers += $object }
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
	$syncHash.lbGroupsChosen.Items | ForEach-Object { $LogText += "`n$_" }
	if ( $syncHash.AddUsers )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.WNew )"
		$syncHash.AddUsers.AD | ForEach-Object { $LogText += "`n`t$( $_.Name )" }
	}

	if ( $syncHash.RemoveUsers )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.WRemove )"
		$syncHash.RemoveUsers.AD | ForEach-Object { $LogText += "`n`t$( $_.Name )" }
	}

	if ( $syncHash.ErrorUsers )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.WNoAccount ):"
		$syncHash.ErrorUsers.Id | ForEach-Object { $LogText += "`n`t$_" }
	}

	$LogText += "`n------------------------------"
	WriteToLog -Text $LogText
}

##########################################
# Generate message for performed operation
function CreateMessage
{
	$Message = @()
	$Message += "$( $syncHash.Data.msgTable.WMessageIntro ) $( $syncHash.GroupType )"
	$syncHash.lbGroupsChosen.Items | ForEach-Object { $Message += "`t$_" }
	if ( $syncHash.AddUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.WNew ):"
		$syncHash.AddUsers | ForEach-Object { $Message += "`t$( $_.AD.Name )$( if ( $_.AD.otherMailbox -match $syncHash.Data.msgTable.WSpecOrg ) { "( $( $syncHash.Data.msgTable.WNewPassword ): $( $_.PW ) )" } )" }
	}
	if ( $syncHash.RemoveUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.WRemove ):"
		$syncHash.RemoveUsers.AD | ForEach-Object { $Message += "`t$( $_.Name )" }
	}
	if ( $syncHash.ErrorUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.WNoAccount ):"
		$syncHash.ErrorUsers.Id | ForEach-Object { $Message += "`t$_" }
	}
	$Message += $syncHash.Signatur
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
	$p = ScrambleString $p
	return $p
}

##########################################################
# Pick random number up to $length as index in $characters
function Get-RandomCharacters
{
	param ( $length, $characters )
	$random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.Length }
	$private:ofs = ""
	return [string]$characters[$random]
}

########################################
# Randomize order of charaters in string
function ScrambleString
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
	if ( $null -ne $syncHash.lbGroupsChosen.SelectedItem )
	{
		$syncHash.lbAppGroupList.Items.Add( $syncHash.lbGroupsChosen.SelectedItem )
		$syncHash.lbGroupsChosen.Items.Remove( $syncHash.lbGroupsChosen.SelectedItem )
		CheckReady
		UpdateAppGroupListItems
	}
}

#############################################
# A group was doubleclicked
# Remove from grouplist, add to selected list
function GroupSelected
{
	if ( $null -ne $syncHash.lbAppGroupList.SelectedItem )
	{
		$syncHash.lbGroupsChosen.Items.Add( $syncHash.lbAppGroupList.SelectedItem )
		$syncHash.lbAppGroupList.Items.Remove( $syncHash.lbAppGroupList.SelectedItem )
		CheckReady
		UpdateAppGroupListItems
	}
}

#############################
# Start performing operations
function PerformPermissions
{
	CollectEntries

	if ( $syncHash.Duplicates )
	{
		ShowMessageBox -Text "$( $syncHash.Data.msgTable.WDuplicates ):`n$( $syncHash.Duplicates | Select-Object -Unique )" -Title $syncHash.Data.msgTable.WDuplicatesTitle -Icon "Stop"
	}
	else
	{
		$Continue = ShowMessageBox -Text "$( $syncHash.Data.msgTable.QCont1 ) $( $syncHash.lbGroupsChosen.Items.Count ) $( $syncHash.GroupType ) $( $syncHash.Data.msgTable.QCont2 ) $( @( $syncHash.AddUsers ).Count + @( $syncHash.RemoveUsers ).Count ) $( $syncHash.Data.msgTable.QCont3 ) ?$( if ( $syncHash.ErrorUsers ) { "`n$( $syncHash.Data.msgTable.QContErr )." } )" -Title "$( $syncHash.Data.msgTable.QContTitle )?" -Button "OKCancel"
		if ( $Continue -eq "OK" )
		{
			$loopCounter = 0
			foreach ( $Group in $syncHash.lbGroupsChosen.Items )
			{
				$syncHash.Window.Title = "$( $syncHash.Data.msgTable.WProgressTitle ) $( [Math]::Floor( $loopCounter / $syncHash.lbGroupsChosen.Items.Count * 100 ) )%"
				if ( $syncHash.AddUsers )
				{
					Add-ADGroupMember -Identity $Group -Members $syncHash.AddUsers.Id -Confirm:$false
				}

				if ( $syncHash.RemoveUsers )
				{
					Remove-ADGroupMember -Identity $Group -Members $syncHash.RemoveUsers.Id -Confirm:$false
				}
				$loopCounter++
			}
			foreach ( $u in ( $syncHash.AddUsers | Where-Object { $_.AD.otherMailbox -match $syncHash.Data.msgTable.WSpecOrg } ) )
			{
				Set-ADAccountPassword -Identity $u.AD -Reset -NewPassword ( ConvertTo-SecureString -AsPlainText $u.PW -Force )
				Set-ADUser -Identity $u.AD -ChangePasswordAtLogon $false -Confirm:$false
			}
			CreateLogText
			CreateMessage
			WriteToLogFile
			ShowMessageBox -Text "$( $syncHash.lbGroupsChosen.Items.Count * ( @( $syncHash.AddUsers ).Count + @( $syncHash.RemoveUsers ).Count ) ) $( $syncHash.Data.msgTable.WFinishMessage )" -Title "$( $syncHash.Data.msgTable.WFinishMessageTitle )"

			UndoInput
			ResetVariables
			$syncHash.Window.Title = $syncHash.Data.msgTable.WTitle
		}
	}
}

##################
# Resets variables
function ResetVariables
{
	$syncHash.ADGroups = @()
	$syncHash.Duplicates = @()
	$syncHash.ErrorUsers = @()
	$syncHash.AddUsers = @()
	$syncHash.RemoveUsers = @()
}

#################################################
# Depending on user, set its appropriate settings
function SetUserSettings
{
	try
	{
		$a = Get-ADPrincipalGroupMembership $env:USERNAME
		$syncHash.Signatur = "`n$( $syncHash.Data.msgTable.WSigGen )"
		if ( $a.SamAccountName -match $syncHash.Data.msgTable.StrOpGrp )
		{
			$syncHash.LogFilePath = $syncHash.Data.msgTable.StrOpLogPath
			$syncHash.ErrorLogFilePath = "$( $syncHash.Data.msgTable.StrOpLogPath )\Errorlogs\$env:USERNAME-Errorlog.txt"
		}
		elseif ( ( Get-ADGroupMember $syncHash.Data.msgTable.StrSDGrp ).Name -contains ( Get-ADUser $env:USERNAME ).Name )
		{
			$syncHash.Signatur = "`n$( $msgTable.WSigSD )"
		}
		else
		{ throw }
	}
	catch
	{
		WriteErrorLog -LogText "$( $_Exception.Message )`n`t$( $_.InvocationInfo.Line )`n`t$( $_.InvocationInfo.PositionMessage ) "
		ShowMessageBox -Text $syncHash.Data.msgTable.ErrScriptPermissions -Icon "Stop"
		Exit
	}
}

###########################################
# Add names for applications with AD-Groups
function UpdateAppList
{
	$app = [System.Windows.Controls.ComboboxItem]@{	Content = "Citrix Distansanslutning"
		Tag = @{ AppFilter = "(&(Name=Sll_Acc_ADCVPN*_Users)(!(Name=*DNSReg*)))"
			Exclude = @( "DNSReg", "Acceptans" )
			split = "_"
			index = 3 } }
	[void] $syncHash.cbApp.Items.Add( $app )

	$app = [System.Windows.Controls.ComboboxItem]@{ Content ="DS Chefsforum"
		Tag = @{ AppFilter = "(Name=Dan_Mig_webbChef*)"
			Exclude = $null } }
	[void] $syncHash.cbApp.Items.Add( $app )

	$app = [System.Windows.Controls.ComboboxItem]@{ Content = "Kar Tableau"
		Tag = @{ AppFilter = "(Name=Kar_Tableau*)"
			Exclude = @( "Akut", "AoS", "BoK", "DOS", "DS", "Halso", "HK", "ILOV", "Inkop", "Innovation", "ITPortfolj", "KULab", "Neuro", "OpChef", "PoU", "PUppf", "SMB", "SSVP", "ToRM", "UUR" )
			split = "_"
			index = 2 } }
	[void] $syncHash.cbApp.Items.Add( $app )

	$app = [System.Windows.Controls.ComboboxItem]@{ Content = "Logisticaps / Clockworks"
		Tag = @{ AppFilter = "(Name=*_Sys_Logistics_*Remote_Usr)"
			Exclude = $null } }
	[void] $syncHash.cbApp.Items.Add( $app )

	$app = [System.Windows.Controls.ComboboxItem]@{ Content = "QlikView Dan"
		Tag = @{ AppFilter = "(Name=Dan_Acc_Qlik*)"
			Exclude = $null } }
	[void] $syncHash.cbApp.Items.Add( $app )

	$app = [System.Windows.Controls.ComboboxItem]@{ Content = "QlikView Sös"
		Tag = @{ AppFilter = "(|(Name=Sos_Mig_Qlik*)(Name=Sos_Acc_Qlik*))"
			Exclude = $null } }
	[void] $syncHash.cbApp.Items.Add( $app )
}

#########################################################################
# Item in combobox has changed, get that applications group and list them
function UpdateAppGroupList
{
	$syncHash.lbGroupsChosen.Items.Clear()
	$syncHash.lbAppGroupList.Items.Clear()
	$syncHash.Window.Title = $syncHash.Data.msgTable.WGetADGroups
	$syncHash.GroupList = @()
	$item = $syncHash.cbApp.SelectedItem

	switch ( $item.Content )
	{
		"Citrix Distansanslutning"
		{
			$syncHash.GroupType = "Citrix Distans-grupper"
		}
		"DS Chefsforum"
		{
			$syncHash.GroupType = "Chefsforum-grupper"
		}
		"Kar Tableau"
		{
			$syncHash.GroupType = "Tableau-grupper"
		}
		"Logisticaps / Clockworks"
		{
			$syncHash.GroupType = "Logisticaps-grupper"
		}
		"QlikView Dan"
		{
			$syncHash.GroupType = "QlikView-grupper"
		}
		"QlikView Sös"
		{
			$syncHash.GroupType = "QlikView-grupper"
		}
	}
	if ( $null -eq $item.Tag.Exclude )
	{ $syncHash.GroupList = Get-ADGroup -LDAPFilter "$( $item.Tag.AppFilter )" | Select-Object -ExpandProperty Name | Sort-Object }
	else
	{ $syncHash.GroupList = Get-ADGroup -LDAPFilter "$( $item.Tag.AppFilter )" | Where-Object { $item.Tag.Exclude -notcontains $_.Name.Split( $item.Tag.split )[$item.Tag.index] } | Select-Object -ExpandProperty Name }

	UpdateAppGroupListItems
	$syncHash.Window.Title = $syncHash.Data.msgTable.WTitle
}

#########################################################
# Update the list of groups, excluding any selected group
function UpdateAppGroupListItems
{
	$syncHash.lbAppGroupList.Items.Clear()
	foreach ( $item in ( $syncHash.GroupList | Where-Object { $syncHash.lbGroupsChosen.Items -notcontains $_ } ) )
	{
		[void] $syncHash.lbAppGroupList.Items.Add( $item )
	}
}

########################################
# Deletes all userinput and resets lists
function UndoInput
{
	$syncHash.txtUsersAddPermission.Text = ""
	$syncHash.txtUsersRemovePermission.Text = ""
	UpdateAppGroupList
}

###############################
# Write the work to log listbox
function WriteToLog
{
	param (
		$Text
	)

	$syncHash.lbLog.Items.Insert( 0, $Text )
}

######################################
# Write finished operations to logfile
function WriteToLogFile
{
	# One line per group/user
	$LogText = @()

	foreach ( $group in $syncHash.lbGroupsChosen.Items )
	{
		foreach ( $u in $syncHash.AddUsers )
		{
			$t = "$( $u.Id ) > $( $syncHash.Data.msgTable.WNew ) '$group'"
			if ( $_.AD.otherMailbox -match $syncHash.Data.msgTable.WSpecOrg ) { $t += " $( $syncHash.Data.msgTable.WNewPassword ): $( $_.PW )" }
			$LogText += $t
		}
		foreach ( $u in $syncHash.RemoveUsers )
		{
			$LogText += "$( $u.Id ) > $( $syncHash.Data.msgTable.WRemove ) '$group'"
		}
	}

	$LogText | ForEach-Object { WriteLog -LogText $_ | Out-Null }
}

######################### Script start #########################
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force

$controls = New-Object System.Collections.ArrayList
[void] $controls.Add( @{ CName = "lblApp"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblApp }
	) } )
[void] $controls.Add( @{ CName = "lblAppGroupList"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblAppGroupList }
	) } )
[void] $controls.Add( @{ CName = "lblGroupsChosen"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblGroupsChosen }
	) } )
[void] $controls.Add( @{ CName = "lblUsersAddPermission"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblUsersAddPermission }
	) } )
[void] $controls.Add( @{ CName = "lblUsersRemovePermission"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblUsersRemovePermission }
	) } )
[void] $controls.Add( @{ CName = "btnPerform"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentbtnPerform }
	) } )
[void] $controls.Add( @{ CName = "btnUndo"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentbtnUndo }
	) } )
[void] $controls.Add( @{ CName = "lblLog"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblLog }
	) } )
[void] $controls.Add( @{ CName = "cbApp"
	Props = @(
		@{ PropName = "SelectedItem"; PropVal = "" }
	) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.msgTable = $msgTable
SetUserSettings

$syncHash.btnPerform.Add_Click( { PerformPermissions } )
$syncHash.btnUndo.Add_Click( { UndoInput } )
$syncHash.cbApp.Add_DropDownClosed( { if ( $syncHash.DC.cbApp[0] -ne $null ) { UpdateAppGroupList } } )
$syncHash.lbAppGroupList.Add_MouseDoubleClick( { GroupSelected } )
$syncHash.lbGroupsChosen.Add_MouseDoubleClick( { GroupDeselected } )
$syncHash.txtUsersAddPermission.Add_TextChanged( { CheckReady } )
$syncHash.txtUsersRemovePermission.Add_TextChanged( { CheckReady } )
$syncHash.Window.Add_ContentRendered( { $syncHash.Window.Title = $syncHash.Data.msgTable.WPreparing; $syncHash.Window.Top = 20; $syncHash.Window.Activate(); UpdateAppList; $syncHash.Window.Title = $syncHash.Data.msgTable.WTitle ; $syncHash.MainGrid.IsEnabled = $true } )

$syncHash.ErrorLogFilePath = ""
$syncHash.HandledFolders = @()
$syncHash.LogFilePath = ""
ResetVariables

[void] $syncHash.Window.ShowDialog()
