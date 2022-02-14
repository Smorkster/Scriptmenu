<#
.Synopsis Edit AD-Groups for applications
.Requires Role_Backoffice
.Description Add/remove permissions for applications. These applications are governed by AD-groups. When the permissions are set, a message with summary is copied to the clipboard.
.Author Smorkster (smorkster)
#>

function CheckReady
{
	<#
	.Synopsis
		Verify if operations is ready to perform
	#>

	if ( ( $syncHash.DC.lbGroupsChosen[1].Count -gt 0 ) -and ( ( $syncHash.txtUsersAddPermission.Text.Length -ge 4 ) -or ( $syncHash.txtUsersRemovePermission.Text.Length -ge 4 ) ) )
	{
		$syncHash.btnPerform.IsEnabled = $true
	}
	else
	{
		$syncHash.btnPerform.IsEnabled = $false
	}
}

function CheckUser
{
	<#
	.Synopsis
		Check if user exists in AD
	.Parameter Id
		Id to verify as userId
	.Outputs
		String if the user exists, or value is not a valid Id
	#>

	param ( [string] $Id )

	if ( dsquery User -samid $Id )
	{
		return "User"
	}
	else
	{
		$syncHash.ErrorUsers += $Id
		$syncHash.Data.ErrorHashes += WriteErrorLogTest -LogText "$( $syncHash.Data.msgTable.ErrMessageGetUser )" -UserInput $Id -Severity "UserInputFail"
		return "NotFound"
	}
}

function CollectEntries
{
	<#
	.Synopsis
		Collect input from textboxes
	#>

	if ( ( $LineCount = $syncHash.txtUsersAddPermission.LineCount ) -gt 0 )
	{
		$lines = @()
		for ( $i = 0; $i -lt $LineCount; $i++ ) { ( $syncHash.txtUsersAddPermission.GetLineText( $i ) ).Split( ";""," ) | ForEach-Object { $lines += ( $_ ).Trim() } }
		CollectUsers -Entries ( $lines | Where-Object { $_ -ne "" } ) -PermissionType "Add"
	}
	if ( ( $LineCount = $syncHash.txtUsersRemovePermission.LineCount ) -gt 0 )
	{
		$lines = @()
		for ( $i = 0; $i -lt $LineCount; $i++ ) { ( $syncHash.txtUsersRemovePermission.GetLineText( $i ) ).Split( ";""," ) | ForEach-Object { $lines += ( $_ ).Trim() } }
		CollectUsers -Entries ( $lines | Where-Object { $_ -ne "" } ) -PermissionType "Remove"
	}
}

function CollectUsers
{
	<#
	.Synopsis
		Get users in the textbox corresponding to operation
	.Parameter Entries
		Array of values in the textboxes
	.Parameter PermissionType
		What type of permission should be applied for the users in Entries
	#>

	param (
		[array] $Entries,
		[string] $PermissionType
	)

	$loopCounter = 0

	switch ( $PermissionType )
	{
		"Add" { $syncHash.AddUsers = @() }
		"Remove" { $syncHash.RemoveUsers = @() }
	}

	foreach ( $entry in $entries )
	{
		$syncHash.Window.Title = "$( $msgTable.StrGettingUser ) $( [Math]::Floor( $loopCounter / $entries.Count * 100 ) )"
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

function CreateLogText
{
	<#
	.Synopsis
		Create text for the log in the GUI
	#>

	$LogText = ""
	$LogText += "$( Get-Date -Format "yyyy-MM-dd HH:mm:ss" )"
	$syncHash.DC.lbGroupsChosen[1].Name | ForEach-Object { $LogText += "`n$_" }
	if ( $syncHash.AddUsers )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.LogNew )"
		$syncHash.AddUsers.AD | ForEach-Object { $LogText += "`n`t$( $_.Name )" }
	}

	if ( $syncHash.RemoveUsers )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.LogRemove )"
		$syncHash.RemoveUsers.AD | ForEach-Object { $LogText += "`n`t$( $_.Name )" }
	}

	if ( $syncHash.ErrorUsers )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.LogNoAccount ):"
		$syncHash.ErrorUsers.Id | ForEach-Object { $LogText += "`n`t$_" }
	}

	$LogText += "`n------------------------------"
	$syncHash.lbLog.Items.Insert( 0, $LogText )
}

function CreateMessage
{
	<#
	.Synopsis
		Generate message for performed operation
	#>

	$Message = @()
	$Message += "$( $syncHash.Data.msgTable.MsgMessageIntro ) $( $syncHash.GroupType )"
	$syncHash.DC.lbGroupsChosen[1].Name | ForEach-Object { $Message += "`t$_" }
	if ( $syncHash.AddUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.MsgNew ):"
		$syncHash.AddUsers | ForEach-Object { $Message += "`t$( $_.AD.Name )$( if ( $_.AD.otherMailbox -match $syncHash.Data.msgTable.StrSpecOrg ) { "( $( $syncHash.Data.msgTable.MsgNewPassword ): $( $_.PW ) )" } )" }
	}
	if ( $syncHash.RemoveUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.MsgRemove ):"
		$syncHash.RemoveUsers.AD | ForEach-Object { $Message += "`t$( $_.Name )" }
	}
	if ( $syncHash.ErrorUsers )
	{
		$Message += "`n$( $syncHash.Data.msgTable.MsgNoAccount ):"
		$syncHash.ErrorUsers.Id | ForEach-Object { $Message += "`t$_" }
	}
	$Message += $syncHash.Signatur
	$OutputEncoding = [System.Text.UnicodeEncoding]::new( $False, $False ).psobject.BaseObject
	$Message | clip
}

function GeneratePassword
{
	<#
	.Synopsis
		Call generator for each of the strings
	.Outputs
		A randomly generated string
	#>

	$p = Get-RandomCharacters -length 1 -characters 'abcdefghikmnprstuvwxyz'
	$p += Get-RandomCharacters -length 1 -characters 'ABCDEFGHKLMNPRSTUVWXYZ'
	$p += Get-RandomCharacters -length 1 -characters '123456789'
	$p += Get-RandomCharacters -length 5 -characters 'abcdefghikmnprstuvwxyzABCDEFGHKLMNPRSTUVWXYZ123456789'
	$p = ScrambleString $p
	return $p
}

function Get-RandomCharacters
{
	<#
	.Synopsis
		Pick random number up to $Length as index in $Characters
	.Parameter Length
		Length of string to return
	.Parameter Characters
		Characters to get a random string from
	.Outputs
		A string of random characters
	#>

	param ( $Length, $Characters )

	$random = 1..$Length | ForEach-Object { Get-Random -Maximum $Characters.Length }
	$private:OFS = ""
	return [string]$Characters[$random]
}

function GroupDeselected
{
	<#
	.Synopsis
		Remove a group from selected groups
	.Description
		A group in the list of selected groups was doubleclicked. Remove it from selected list, add to grouplist.
	#>

	if ( $null -ne $syncHash.DC.lbGroupsChosen[0] )
	{
		$syncHash.DC.lbAppGroupList[1].Add( $syncHash.DC.lbGroupsChosen[0] )
		$syncHash.DC.lbGroupsChosen[1].Remove( $syncHash.DC.lbGroupsChosen[0] )
		CheckReady
		UpdateAppGroupListItems
	}
}

function GroupSelected
{
	<#
	.Synopsis
		Add a group to list of selected groups
	.Description
		A group was selected. Add it to list of selected groups.
	#>

	if ( $null -ne $syncHash.lbAppGroupList.SelectedItem )
	{
		$syncHash.DC.lbGroupsChosen[1].Add( $syncHash.lbAppGroupList.SelectedItem )
		$syncHash.DC.lbAppGroupList[1].Remove( $syncHash.lbAppGroupList.SelectedItem )
		CheckReady
		UpdateAppGroupListItems
	}
}

function PerformPermissions
{
	<#
	.Synopsis
		Start operations to apply permissions
	#>

	CollectEntries

	if ( $syncHash.Duplicates )
	{
		ShowMessageBox -Text "$( $syncHash.Data.msgTable.StrDuplicates ):`n$( $syncHash.Duplicates | Select-Object -Unique )" -Title $syncHash.Data.msgTable.StrDuplicatesTitle -Icon "Stop"
	}
	else
	{
		$Continue = ShowMessageBox -Text "$( $syncHash.Data.msgTable.QCont1 ) $( $syncHash.DC.lbGroupsChosen[1].Count ) $( $syncHash.GroupType ) $( $syncHash.Data.msgTable.QCont2 ) $( @( $syncHash.AddUsers ).Count + @( $syncHash.RemoveUsers ).Count ) $( $syncHash.Data.msgTable.QCont3 ) ?$( if ( $syncHash.ErrorUsers ) { "`n$( $syncHash.Data.msgTable.QContErr )." } )" -Title "$( $syncHash.Data.msgTable.QContTitle )?" -Button "OKCancel"
		if ( $Continue -eq "OK" )
		{
			$loopCounter = 0
			foreach ( $Group in $syncHash.DC.lbGroupsChosen[1] )
			{
				$syncHash.Window.Title = "$( $syncHash.Data.msgTable.StrProgressTitle ) $( [Math]::Floor( $loopCounter / $syncHash.DC.lbGroupsChosen[1].Count * 100 ) )%"
				if ( $syncHash.AddUsers )
				{
					try { Add-ADGroupMember -Identity $Group -Members $syncHash.AddUsers.Id -Confirm:$false }
					catch { $syncHash.Data.ErrorHashes += WriteErrorLogTest -LogText $_ -UserInput "$( $Group.Name )`n$( $OFS = ", "; $syncHash.AddUsers.Id )" -Severity "UserInputFail" }
				}

				if ( $syncHash.RemoveUsers )
				{
					try { Remove-ADGroupMember -Identity $Group -Members $syncHash.RemoveUsers.Id -Confirm:$false }
					catch { $syncHash.Data.ErrorHashes += WriteErrorLogTest -LogText $_ -UserInput "$( $Group.Name )`n$( $OFS = ", "; $syncHash.AddUsers.Id )" -Severity "UserInputFail" }
				}
				$loopCounter++
			}
			foreach ( $u in ( $syncHash.AddUsers | Where-Object { $_.AD.otherMailbox -match $syncHash.Data.msgTable.StrSpecOrg } ) )
			{
				try
				{
					Set-ADAccountPassword -Identity $u.AD -Reset -NewPassword ( ConvertTo-SecureString -AsPlainText $u.PW -Force )
					Set-ADUser -Identity $u.AD -ChangePasswordAtLogon $false -Confirm:$false
				}
				catch
				{
					$syncHash.Data.ErrorHashes += WriteErrorLogTest -LogText "$( $syncHash.Data.msgTable.ErrMessageSetPassword )`n$_" -UserInput $u.AD.SamAccountName -Severity "UserInputFail"
				}
			}
			CreateLogText
			CreateMessage
			WriteToLogFile
			ShowMessageBox -Text "$( $syncHash.DC.lbGroupsChosen[1].Count * ( @( $syncHash.AddUsers ).Count + @( $syncHash.RemoveUsers ).Count ) ) $( $syncHash.Data.msgTable.StrFinishMessage )" -Title "$( $syncHash.Data.msgTable.StrFinishMessageTitle )"

			UndoInput
			ResetVariables
			$syncHash.Window.Title = $syncHash.Data.msgTable.ContentWindowTitle
		}
	}
}

function ResetVariables
{
	<#
	.Synopsis
		Resets variables
	#>

	$syncHash.AddUsers = @()
	$syncHash.ADGroups = @()
	$syncHash.Duplicates = @()
	$syncHash.ErrorUsers = @()
	$syncHash.Data.ErrorHashes = @()
	$syncHash.RemoveUsers = @()
}

function ScrambleString
{
	<#
	.Synopsis
		Randomize order of charaters in string
	.Parameter InputString
		String to scramble its characters
	.Outputs
		String of scrambled characters
	#>

	param ( [string] $InputString )

	$characterArray = $inputString.ToCharArray()
	$scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length
	return -join $scrambledStringArray
}

function SetUserSettings
{
	<#
	.Synopsis
		Adjust settings to the operators groupmemberships
	#>

	try
	{
		$a = Get-ADPrincipalGroupMembership $env:USERNAME
		$syncHash.Signatur = "`n$( $syncHash.Data.msgTable.StrSigGen )"
		if ( $a.SamAccountName -match $syncHash.Data.msgTable.StrOpGrp )
		{
			$syncHash.LogFilePath = $syncHash.Data.msgTable.StrOpLogPath
			$syncHash.ErrorLogFilePath = "$( $syncHash.Data.msgTable.StrOpLogPath )\Errorlogs\$env:USERNAME-Errorlog.txt"
		}
		elseif ( ( Get-ADGroupMember $syncHash.Data.msgTable.StrBORoleGrp ).Name -contains ( Get-ADUser $env:USERNAME ).Name )
		{
			$syncHash.Signatur = "`n$( $msgTable.StrSigSD )"
		}
		else
		{ throw }
	}
	catch
	{
		WriteErrorLogTest -LogText $_ -UserInput $syncHash.Data.msgTable.ErrMessageSetSettings -Severity "PermissionFail"
		ShowMessageBox -Text $syncHash.Data.msgTable.ErrScriptPermissions -Icon "Stop"
		Exit
	}
}

function UpdateAppList
{
	<#
	.Synopsis
		Add names for applications with AD-Groups
	#>

	$apps = @()
	if ( $msgTable.StrBORoleGrp -in ( ( ( Get-ADUser $env:USERNAME -Properties MemberOf ).MemberOf | Get-ADGroup ).Name ) )
	{
		$apps += [pscustomobject]@{ Text = "App 1"
			Tag = @{ AppFilter = "(|(Name=App_1*)(Name=App1*))"
				Exclude = $null
				GroupType = "App1-groups" } }
	}

	$apps += [pscustomobject]@{ Text = "App 2"
		Tag = @{ AppFilter = "(Name=App2*)"
			Exclude = @( "Null", "Closed" )
			GroupType = "App2-groups" }
			split = "_"
			index = 2 }

	$apps | Where-Object { $_ } |  Sort-Object Text | ForEach-Object { $syncHash.DC.cbApp[1].Add( $_ ) }
}

function UpdateAppGroupList
{
	<#
	.Synopsis
		Item in combobox has changed, get that applications groups and list them
	#>

	$syncHash.DC.lbGroupsChosen[1].Clear()
	$syncHash.DC.lbAppGroupList[1].Clear()
	$syncHash.Window.Title = $syncHash.Data.msgTable.StrGetADGroups
	$syncHash.GroupList = @()
	$item = $syncHash.DC.cbApp[0]

	$syncHash.GroupType = $item.Tag.GroupType
	try
	{
		if ( $null -eq $item.Tag.Exclude )
		{ $syncHash.GroupList = Get-ADGroup -LDAPFilter "$( $item.Tag.AppFilter )" | Sort-Object Name }
		else
		{ $syncHash.GroupList = Get-ADGroup -LDAPFilter "$( $item.Tag.AppFilter )" | Where-Object { $item.Tag.Exclude -notcontains $_.Name.Split( $item.Tag.split )[$item.Tag.index] } }
	}
	catch
	{
		$syncHash.Data.ErrorHashes += WriteErrorLogTest -LogText $_ -UserInput $syncHash.Data.msgTable.ErrMessageGetAppGroups -Severity "ConnectionFail"
	}

	UpdateAppGroupListItems
	$syncHash.Window.Title = $syncHash.Data.msgTable.ContentWindowTitle
}

function UpdateAppGroupListItems
{
	<#
	.Synopsis
		Update the list of groups, excluding any selected group
	#>

	$syncHash.DC.lbAppGroupList[1].Clear()
	$syncHash.GroupList | Where-Object { $syncHash.DC.lbGroupsChosen[1] -notcontains $_ } | ForEach-Object { [void] $syncHash.DC.lbAppGroupList[1].Add( $_ ) }
}

function UndoInput
{
	<#
	.Synopsis
		Deletes all userinput and resets lists
	#>

	$syncHash.txtUsersAddPermission.Text = ""
	$syncHash.txtUsersRemovePermission.Text = ""
	UpdateAppGroupList
}

function WriteToLogFile
{
	<#
	.Synopsis
		Write finished operations to logfile
	#>

	$OFS = ", "

	$LogText = "$( $syncHash.Data.msgTable.StrLogMessage ): $( $syncHash.cbApp.Text )`n"
	if ( $syncHash.AddUsers.Count -gt 0 ) { $LogText += "$( $syncHash.Data.msgTable.LogMessageAdd ) $( $syncHash.AddUsers.Id )" }
	if ( $syncHash.RemoveUsers.Count -gt 0 ) { $LogText += "$( $syncHash.Data.msgTable.LogMessageRemove ) $( $syncHash.RemoveUsers.Id )" }

	$UserInput = ""
	if ( $syncHash.txtUsersAddPermission.Text.Length -gt 0 ) { $UserInput += "$( $syncHash.Data.msgTable.LogInputAdd ) $( $syncHash.txtUsersAddPermission.Text -split "\W" )`n" }
	if ( $syncHash.txtUsersRemovePermission.Text.Length -gt 0 ) { $UserInput += "$( $syncHash.Data.msgTable.LogInputRemove ) $( $syncHash.txtUsersRemovePermission.Text -split "\W" )`n" }
	$UserInput += $syncHash.DC.lbGroupsChosen[1]

	WriteLogTest -Text $LogText -UserInput $UserInput -Success ( $syncHash.Data.ErrorHashes.Count -lt 1 ) -ErrorLogHash $syncHash.Data.ErrorHashes
}

######################### Script start #########################
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]

$controls = [System.Collections.ArrayList]::new()
[void] $controls.Add( @{ CName = "btnPerform" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnPerform } ) } )
[void] $controls.Add( @{ CName = "btnUndo" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUndo } ) } )
[void] $controls.Add( @{ CName = "cbApp" ; Props = @( @{ PropName = "SelectedItem"; PropVal = "" } ; @{ PropName = "ItemsSource" ; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void] $controls.Add( @{ CName = "lbAppGroupList" ; Props = @( @{ PropName = "SelectedItem"; PropVal = "" } ; @{ PropName = "ItemsSource" ; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void] $controls.Add( @{ CName = "lbGroupsChosen" ; Props = @( @{ PropName = "SelectedItem"; PropVal = "" } ; @{ PropName = "ItemsSource" ; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void] $controls.Add( @{ CName = "lblApp" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblApp } ) } )
[void] $controls.Add( @{ CName = "lblAppGroupList" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblAppGroupList } ) } )
[void] $controls.Add( @{ CName = "lblGroupsChosen" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblGroupsChosen } ) } )
[void] $controls.Add( @{ CName = "lblLog" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLog } ) } )
[void] $controls.Add( @{ CName = "lblUsersAddPermission" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblUsersAddPermission } ) } )
[void] $controls.Add( @{ CName = "lblUsersRemovePermission" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblUsersRemovePermission } ) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.msgTable = $msgTable
$syncHash.Data.ErrorHashes = @()
SetUserSettings

$syncHash.btnPerform.Add_Click( { PerformPermissions } )
$syncHash.btnUndo.Add_Click( { UndoInput } )
$syncHash.cbApp.Add_DropDownClosed( { if ( $syncHash.DC.cbApp[0] -ne $null ) { UpdateAppGroupList } } )
$syncHash.lbAppGroupList.Add_MouseDoubleClick( { GroupSelected } )
$syncHash.lbGroupsChosen.Add_MouseDoubleClick( { GroupDeselected } )
$syncHash.txtUsersAddPermission.Add_TextChanged( { CheckReady } )
$syncHash.txtUsersRemovePermission.Add_TextChanged( { CheckReady } )
$syncHash.Window.Add_ContentRendered( {
	$syncHash.Window.Title = $syncHash.Data.msgTable.StrPreparing
	$syncHash.Window.Top = 20
	$syncHash.Window.Activate()
	UpdateAppList
	if ( $syncHash.DC.cbApp[1].Count -eq 1 ) { UpdateAppGroupList }
	$syncHash.Window.Title = $syncHash.Data.msgTable.ContentWindowTitle
} )

$syncHash.ErrorLogFilePath = ""
$syncHash.HandledFolders = @()
$syncHash.LogFilePath = ""
ResetVariables

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash
