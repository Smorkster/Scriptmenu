<#
.Synopsis Fetch and administrate roomlists
.Description Lists all roomlists, their owners and rooms that is members of the list
.State Prod
.Author Smorkster (smorkster)
#>

##########################################################
# Get all rooms in the roomlist and display in the listbox
function UpdateRoomsInList
{
	$syncHash.DC.lbRoomsInList[0].Clear()
	$rooms = Get-DistributionGroupMember -Identity $syncHash.lbRoomLists.SelectedItem.PrimarySmtpAddress
	if ( $rooms.Count -gt 0 ) { $rooms | Sort-Object Name | Foreach-Object { $syncHash.DC.lbRoomsInList[0].Add( $_ ) } }
	$syncHash.DC.lblOwner[0] = $syncHash.Data.RoomLists.Where( { $_.DisplayName -eq $syncHash.lbRoomLists.SelectedItem } ).ManagedBy
}

###################
# Get all roomlists
function UpdateRoomListsList
{
	$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrGettingLists
	$syncHash.Data.RoomLists = Get-DistributionGroup -Filter { RecipientTypeDetails -eq "RoomList" }
	$syncHash.Data.RoomLists | Sort-Object Name | Foreach-Object { $syncHash.DC.lbRoomLists[0].Add( $_ ) }
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
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "bordCreateRoomListMail" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordCreateRoomListName" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "btnAddRoom" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddRoom } ) } )
[void]$controls.Add( @{ CName = "btnAddRoomCancel" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddRoomCancel } ) } )
[void]$controls.Add( @{ CName = "btnAddRoomOk" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddRoomOk } ) } )
[void]$controls.Add( @{ CName = "btnCreateRoomList" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCreateRoomList } ) } )
[void]$controls.Add( @{ CName = "btnCreateRoomListCancel" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCreateRoomListCancel } ) } )
[void]$controls.Add( @{ CName = "btnCreateRoomListOk" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCreateRoomListOk } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRemoveRoom" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveRoom } ) } )
[void]$controls.Add( @{ CName = "lblAddRoomTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblAddRoomTitle } ) } )
[void]$controls.Add( @{ CName = "lblCreateRoomListTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblCreateRoomListTitle } ) } )
[void]$controls.Add( @{ CName = "lblOwnerTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOwnerTitle } ) } )
[void]$controls.Add( @{ CName = "lbRoomsInList" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void]$controls.Add( @{ CName = "lblListRoomsTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblListRoomsTitle } ) } )
[void]$controls.Add( @{ CName = "lblRoomListsList" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomListsList } ) } )
[void]$controls.Add( @{ CName = "lblOwner" ; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lbRoomLists" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void]$controls.Add( @{ CName = "tbAddRoomName" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbCreateRoomListMail" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbCreateRoomListName" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "WindowAddRoom" ; Props = @( @{ PropName = "Title"; PropVal = "" }; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden } ) } )
[void]$controls.Add( @{ CName = "WindowNewRoomList" ; Props = @( @{ PropName = "Title"; PropVal = "" }; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden } ) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.msgTable = $msgTable
$syncHash.ErrorRecord = @()

# Show the window to add room to roomlist
$syncHash.btnAddRoom.Add_Click( { $syncHash.WindowAddRoom.Visibility = [System.Windows.Visibility]::Visible } )
# Cancel adding room to roomlist
$syncHash.btnAddRoomCancel.Add_Click( { $syncHash.WindowAddRoom.Tag = $false; $syncHash.WindowAddRoom.Visibility = [System.Windows.Visibility]::Hidden } )
# Continue adding room to the selected roomlist
$syncHash.btnAddRoomOk.Add_Click( { $syncHash.WindowAddRoom.Tag = $true; $syncHash.WindowAddRoom.Visibility = [System.Windows.Visibility]::Hidden } )
# Show window to create new roomlist
$syncHash.btnCreateRoomList.Add_Click( { $syncHash.WindowNewRoomList.Visibility = [System.Windows.Visibility]::Visible } )
# Cancel creating room list
$syncHash.btnCreateRoomListCancel.Add_Click( { $syncHash.WindowNewRoomList.Tag = $false; $syncHash.WindowNewRoomList.Visibility = [System.Windows.Visibility]::Hidden } )
# Continue with creating room list
$syncHash.btnCreateRoomListOk.Add_Click( { $syncHash.WindowNewRoomList.Tag = $true; $syncHash.WindowNewRoomList.Visibility = [System.Windows.Visibility]::Hidden } )
# Remove a room from the selected roomlist
$syncHash.btnRemoveRoom.Add_Click( {
	Remove-DistributionGroupMember -Identity $syncHash.lbRoomLists.SelectedItem -Member $syncHash.lbRoomsInList.SelectedItem -BypassSecurityGroupManagerCheck -Confirm:$false
	WriteLog -Text "$( $syncHash.lbRoomsInList.SelectedItem ) $( $syncHash.Data.msgTable.StrRemoveRoom ) $( $syncHash.lbRoomLists.SelectedItem )"
} )
# A roomlist is selected, get the rooms connected to it
$syncHash.lbRoomLists.Add_SelectionChanged( {
	$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrGettingsRoomsInList
	UpdateRoomsInList
	$syncHash.DC.Window[0] = ""
} )
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
			Add-DistributionGroupMember -Identity $syncHash.lbRoomLists.SelectedItem -Member $b -BypassSecurityGroupManagerCheck -Confirm:$false
			UpdateRoomsInList
			WriteLog -Text "$( $syncHash.lbRoomsInList.SelectedItem ) $( $syncHash.Data.msgTable.StrAddRoom ) $( $syncHash.lbRoomLists.SelectedItem )"
		}
		catch { [System.Windows.MessageBox]::Show( $syncHash.Data.msgTable.StrNoRoom ) }
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
		New-DistributionGroup -Name $syncHash.DC.tbCreateRoomListName[0] -Roomlist
		Set-DistributionGroup -Identity $syncHash.DC.tbCreateRoomListName[0] -PrimarySMTPAddress $syncHash.DC.tbCreateRoomListMail[0]
		Set-DistributionGroup -Identity $syncHash.DC.tbCreateRoomListName[0] -EmailAddresses @{Add="smtp:$( $syncHash.DC.tbCreateRoomListMail[0] )"}
		Set-DistributionGroup -Identity $syncHash.DC.tbCreateRoomListName[0] -Description "Now"
		UpdateRoomListsList
		WriteLog -Text "$( $syncHash.Data.msgTable.StrNewList ) $( $syncHash.DC.tbCreateRoomListName[0] )"
	}
	$syncHash.DC.tbCreateRoomListMail[0] = ""
	$syncHash.DC.tbCreateRoomListName[0] = ""
} )
# Main window has opened, set position and get the roomlists
$syncHash.Window.Add_ContentRendered( {
	$syncHash.Window.Top = 10
	UpdateRoomListsList
} )

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash
