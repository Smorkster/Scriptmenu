<#
.Synopsis Fetch and administrate roomlists
.Description Lists all roomlists, their owners and rooms that is members of the list
.State Prod
.Author Smorkster (smorkster)
#>

###############################
# Get all rooms in the roomlist
function UpdateRoomsInList
{
	$syncHash.DC.dgRoomsInList[0].Clear()
	$rooms = Get-DistributionGroupMember -Identity $syncHash.dgRoomLists.SelectedItem.PrimarySmtpAddress
	if ( $rooms.Count -gt 0 ) { $rooms | Sort-Object Name | Foreach-Object { $syncHash.DC.dgRoomsInList[0].Add( $_ ) } }
	else { $syncHash.DC.dgRoomsInList[0].Add( [pscustomobject]@{ DisplayName = $syncHash.Data.msgTable.ErrMsgNoRoomsInList } ) }
	$syncHash.DC.tbOwner[0] = $syncHash.dgRoomLists.SelectedItem.ManagedBy
	$syncHash.DC.lblNewOwnerInfo[0] = ""
}

###################
# Get all roomlists
function UpdateRoomListsList
{
	$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrGettingLists
	$syncHash.Data.RoomLists = Get-DistributionGroup -Filter { RecipientTypeDetails -eq "RoomList" }
	$syncHash.Data.RoomLists | Sort-Object Name | Foreach-Object { $syncHash.DC.dgRoomLists[0].Add( $_ ) }
	$syncHash.DC.Window[0] = ""
}

#################################################
# Verify that the input for new roomlist is valid
# Check that the name and emailaddress are not used
# Check that text is entered in the textboxes
function VerifyInputCreateRoomList
{
	if ( $syncHash.DC.bordCreateRoomListMail[1] -eq 0 -and $syncHash.tbCreateRoomListMail.Text.Length -gt 0 -and
		$syncHash.DC.bordCreateRoomListName[1] -eq 0 -and $syncHash.tbCreateRoomListName.Text.Length -gt 0 ) { $syncHash.WindowNewRoomList.Dispatcher.Invoke( [action] { $syncHash.DC.btnCreateRoomListOk[1] = $true } ) }
	else { $syncHash.WindowNewRoomList.Dispatcher.Invoke( [action] { $syncHash.DC.btnCreateRoomListOk[1] = $false } ) }
}

##################### Script start
Add-Type -AssemblyName PresentationFramework
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "bordCreateRoomListMail" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordCreateRoomListName" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "btnAddRoom" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddRoom } ) } )
[void]$controls.Add( @{ CName = "btnAddRoomCancel" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddRoomCancel } ) } )
[void]$controls.Add( @{ CName = "btnAddRoomOk" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddRoomOk } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnChangeOwner" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnChangeOwner } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnCreateRoomList" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCreateRoomList } ) } )
[void]$controls.Add( @{ CName = "btnCreateRoomListCancel" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCreateRoomListCancel } ) } )
[void]$controls.Add( @{ CName = "btnCreateRoomListOk" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCreateRoomListOk } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRemoveRoom" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveRoom } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "lblAddRoomTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblAddRoomTitle } ) } )
[void]$controls.Add( @{ CName = "lblCreateRoomListTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblCreateRoomListTitle } ) } )
[void]$controls.Add( @{ CName = "lblOwnerTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOwnerTitle } ) } )
[void]$controls.Add( @{ CName = "lblListRoomsTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblListRoomsTitle } ) } )
[void]$controls.Add( @{ CName = "lblNewOwnerInfo" ; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblOwnerChangeInfo" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOwnerChangeInfo } ) } )
[void]$controls.Add( @{ CName = "lblRoomListsList" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomListsList } ) } )
[void]$controls.Add( @{ CName = "dgRoomLists" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void]$controls.Add( @{ CName = "dgRoomsInList" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void]$controls.Add( @{ CName = "tbAddRoomName" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbCreateRoomListMail" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbCreateRoomListName" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbOwner" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "WindowAddRoom" ; Props = @( @{ PropName = "Title"; PropVal = "" }; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden } ) } )
[void]$controls.Add( @{ CName = "WindowNewRoomList" ; Props = @( @{ PropName = "Title"; PropVal = "" }; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden } ) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.msgTable = $msgTable

# Show the window to add room to roomlist
$syncHash.btnAddRoom.Add_Click( { $syncHash.WindowAddRoom.Visibility = [System.Windows.Visibility]::Visible } )

# Cancel adding room to roomlist
$syncHash.btnAddRoomCancel.Add_Click( { $syncHash.WindowAddRoom.Tag = $false; $syncHash.WindowAddRoom.Visibility = [System.Windows.Visibility]::Hidden } )

# Continue adding room to the selected roomlist
$syncHash.btnAddRoomOk.Add_Click( {
	$syncHash.WindowAddRoom.Tag = $true
	$syncHash.WindowAddRoom.Visibility = [System.Windows.Visibility]::Hidden
} )

# Save the new owner
$syncHash.btnChangeOwner.Add_Click( {
	try { Set-DistributionGroup -Identity $syncHash.dgRoomLists.SelectedItem.PrimarySmtpAddress -ManagedBy ( $syncHash.DC.tbOwner[0] ) -ErrorAction Stop }
	catch { $eh = WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogNewOwner -UserInput "Identity $( $syncHash.dgRoomLists.SelectedItem.PrimarySmtpAddress )`n ManagedBy $( $syncHash.DC.tbOwner[0] )" }
	WriteLogTest -Text $syncHash.Data.msgTable.LogNewOwner -UserInput "Identity $( $syncHash.dgRoomLists.SelectedItem.PrimarySmtpAddress )`nManagedBy $( $syncHash.DC.tbOwner[0] )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )

# Show window to create new roomlist
$syncHash.btnCreateRoomList.Add_Click( { $syncHash.WindowNewRoomList.Visibility = [System.Windows.Visibility]::Visible } )

# Cancel creating room list
$syncHash.btnCreateRoomListCancel.Add_Click( { $syncHash.WindowNewRoomList.Tag = $false; $syncHash.WindowNewRoomList.Visibility = [System.Windows.Visibility]::Hidden } )

# Continue with creating room list
$syncHash.btnCreateRoomListOk.Add_Click( { $syncHash.WindowNewRoomList.Tag = $true; $syncHash.WindowNewRoomList.Visibility = [System.Windows.Visibility]::Hidden } )

# Remove a room from the selected roomlist
$syncHash.btnRemoveRoom.Add_Click( {
	try { Remove-DistributionGroupMember -Identity $syncHash.dgRoomLists.SelectedItem -Member $syncHash.dgRoomsInList.SelectedItem -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop }
	catch { $eh = WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogRemRoom -UserInput "Identity $( $syncHash.dgRoomLists.SelectedItem )`nMember $( $syncHash.dgRoomsInList.SelectedItem )" -Severity "OtherFail" }
	WriteLogTest -Text $syncHash.Data.msgTable.LogRemoveRoom -UserInput "$( $syncHash.Data.msgTable.LogRemoveRoomUIRL ) $( $syncHash.dgRoomLists.SelectedItem )`n$( $syncHash.Data.msgTable.LogRemoveRoomUIRoom ) $( $syncHash.dgRoomsInList.SelectedItem )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )

# A roomlist is selected, get the rooms connected to it
$syncHash.dgRoomLists.Add_SelectionChanged( {
	$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrGettingsRoomsInList
	UpdateRoomsInList
	$syncHash.DC.Window[0] = ""
} )

# Selection changed, check for rooms or message of no rooms
$syncHash.dgRoomsInList.Add_SelectionChanged( {
	if ( -not ( $syncHash.dgRoomsInList.SelectedItems -match $syncHash.Data.msgTable.ErrMsgNoRoomsInList ) -and ( $syncHash.DC.dgRoomsInList[0].Count -gt 0 ) )
	{ $syncHash.DC.btnRemoveRoom[1] = $true }
	else
	{ $syncHash.DC.btnRemoveRoom[1] = $false }
} )

#Enabled OK-button if text was entered
$syncHash.tbAddRoomName.Add_TextChanged( { $syncHash.DC.btnAddRoomOk[1] = $this.Text.Length -gt 4 } )

# Input for emailaddress for new roomlist have changed, check if address is used
$syncHash.tbCreateRoomListMail.Add_TextChanged( {
	if ( $syncHash.Data.RoomLists.PrimarySmtpAddress.Where( { $_ -eq $this.Text } ).Count -eq 0 ) { $syncHash.DC.bordCreateRoomListMail[1] = 0 }
	else { $syncHash.DC.bordCreateRoomListMail[1] = 2 }
	VerifyInputCreateRoomList
} )

# Input for name for new roomlist have changed, check if name is used
$syncHash.tbCreateRoomListName.Add_TextChanged( {
	if ( $syncHash.Data.RoomLists.DisplayName.Where( { $_ -eq $this.Text } ).Count -eq 0 ) { $syncHash.DC.bordCreateRoomListName[1] = 0 }
	else { $syncHash.DC.bordCreateRoomListName[1] = 2 }
	VerifyInputCreateRoomList
} )

# Textbox lost focus, hide info
$syncHash.tbOwner.Add_LostFocus( {
	if ( $this.Text -eq $syncHash.dgRoomLists.SelectedItem.ManagedBy ) { $syncHash.DC.lblNewOwnerInfo[0] = "" }
} )

# Text changed, verify input
$syncHash.tbOwner.Add_TextChanged( {
	if ( $this.Text.Length -ge 4 )
	{
		if ( $tempNewOwner = Get-Mailbox -Identity $this.Text )
		{ $name = $tempNewOwner.Name }
		else
		{
			$tempNewOwner = Get-AzureADUser -Filter "MailNickName eq '$( $this.Text )'"
			$name = $tempNewOwner.MailNickName
		}

		if ( $name -eq $syncHash.dgRoomLists.SelectedItem.ManagedBy )
		{ $syncHash.DC.lblNewOwnerInfo[0] = $syncHash.Data.msgTable.ErrMsgSame }
		elseif ( $null -eq $name )
		{
			$syncHash.DC.lblNewOwnerInfo[0] = $syncHash.Data.msgTable.ErrMsgNoUsr
		}
		else
		{
			$syncHash.DC.btnChangeOwner[1] = $true
		}
	}
	else
	{
		$syncHash.DC.btnChangeOwner[1] = $false
	}
} )

# Window to add room has opened, set focus to textbox
$syncHash.WindowAddRoom.Add_ContentRendered( { $syncHash.tbAddRoomName.Focus() } )

# Visibility for window to add room to roomlist, has changed
# If it was made hidden, and the OK-button was pressed, add room to roomlist and get the new list of the roomlists members
$syncHash.WindowAddRoom.Add_IsVisibleChanged( {
	if ( -not $this.IsVisible -and $syncHash.WindowAddRoom.Tag )
	{
		try
		{
			$b = Get-EXOMailbox -RecipientTypeDetails "RoomMailbox" -Identity $syncHash.DC.tbAddRoomName[0] -ErrorAction Stop
			try { Add-DistributionGroupMember -Identity $syncHash.dgRoomLists.SelectedItem -Member $b -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop }
			catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogAddRoom ) (Add-DistributionGroupMember)`n$_" -UserInput "Identity $( $syncHash.dgRoomLists.SelectedItem )`nMember $b" -Severity "OtherFail" }

			UpdateRoomsInList
		}
		catch
		{
			[System.Windows.MessageBox]::Show( $syncHash.Data.msgTable.ErrMsgNoRoom )
			$eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogAddRoom ) (Get-EXOMailbox)`n$_" -UserInput $syncHash.DC.tbAddRoomName[0] -Severity "OtherFail"
		}
		WriteLogTest -Text $syncHash.Data.msgTable.LogAddRoom -UserInput "$( $syncHash.Data.msgTable.LogAddRoomUIRL ) $( $syncHash.dgRoomLists.SelectedItem.DisplayName )`n$( $syncHash.Data.msgTable.LogAddRoomUIRoom ) $( $syncHash.DC.tbAddRoomName[0] ) " -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
	}
	$syncHash.DC.tbAddRoomName[0] = ""
} )

# Window to create roomlist has opened, set focus to textbox for name
$syncHash.WindowNewRoomList.Add_ContentRendered( { $syncHash.tbCreateRoomListName.Focus() } )

# Visibility for window to create roomlist, has changed
# If it was made hidden, and the OK-button was pressed, create roomlist and reload the list of roomlists
$syncHash.WindowNewRoomList.Add_IsVisibleChanged( {
	if ( -not $this.IsVisible -and $syncHash.WindowNewRoomList.Tag )
	{
		try
		{ New-DistributionGroup -Name $syncHash.DC.tbCreateRoomListName[0] -Roomlist -ErrorAction Stop }
		catch
		{ $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewList ) (New-DistributionGroup)`n$_" -UserInput $syncHash.DC.tbCreateRoomListName[0] -Severity "OtherFail"}

		try
		{ Set-DistributionGroup -Identity $syncHash.DC.tbCreateRoomListName[0] -PrimarySMTPAddress $syncHash.DC.tbCreateRoomListMail[0] -ErrorAction Stop }
		catch
		{ $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewList ) (Set-DistributionGroup)`n$_" -UserInput "PrimarySMTPAddress $( $syncHash.DC.tbCreateRoomListMail[0] )" -Severity "OtherFail"}

		try
		{ Set-DistributionGroup -Identity $syncHash.DC.tbCreateRoomListName[0] -EmailAddresses @{Add="smtp:$( $syncHash.DC.tbCreateRoomListMail[0] )"} -ErrorAction Stop }
		catch
		{ $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewList ) (Set-DistributionGroup)`n$_" -UserInput "EmailAddresses $( $syncHash.DC.tbCreateRoomListMail[0] )" -Severity "OtherFail"}

		try
		{ Set-DistributionGroup -Identity $syncHash.DC.tbCreateRoomListName[0] -Description "Now" -ErrorAction Stop }
		catch
		{ $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewList ) (Set-DistributionGroup)`n$_" -UserInput "Description ""Now""" -Severity "OtherFail"}

		UpdateRoomListsList
		WriteLogTest -Text $syncHash.Data.msgTable.LogNewList -UserInput "$( $syncHash.Data.msgTable.LogNewListUIRLName ) $( $syncHash.DC.tbCreateRoomListName[0] )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
	}
	$syncHash.DC.tbCreateRoomListMail[0] = ""
	$syncHash.DC.tbCreateRoomListName[0] = ""
} )

# Main window has opened, set position and get the roomlists
$syncHash.Window.Add_ContentRendered( {
	$syncHash.Window.Top = 10
	$syncHash.dgRoomLists.Columns[0].Header = $msgTable.ContentdgRoomListsColListName
	$syncHash.dgRoomsInList.Columns[0].Header = $msgTable.ContentdgRoomsInListColRoomName

	UpdateRoomListsList
} )

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash
