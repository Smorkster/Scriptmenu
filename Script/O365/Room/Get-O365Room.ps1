<#
.Synopsis Get a room for light administration
.Description Gets a room from Exchange and Azure, and lists its settings and members.
.State Prod
.Author Smorkster (smorkster)
#>

##############################################
# Show messagebox for confirmation to continue
function Confirmations
{
	param ( [string] $Action, [switch] $WithPrefix )

	if ( $WithPrefix ) { $t = "$( $syncHash.Data.msgTable.StrConfirmPrefix ) " }
	$t += "$Action. $( $syncHash.Data.msgTable.StrConfirmSuffix )"

	return ( ShowMessagebox -Text $t -Button "YesNo" -Icon "Warning" )
}

##############################
# Export the roominfo to Excel
function Export
{
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$row = 1
	#region Create Excel
	$excel = New-Object -ComObject excel.application 
	$excel.visible = $false
	$excelWorkbook = $excel.Workbooks.Add()
	$excelWorksheet = $excelWorkbook.ActiveSheet
	$excelWorksheet.Cells.Item( $row, 1 ) = $syncHash.Data.msgTable.ExcelRoomNameTitle
	$excelWorksheet.Cells.Item( $row, 2 ) = $syncHash.Data.Room.DisplayName
	$row += 1
	$excelWorksheet.Cells.Item( $row, 1 ) = $syncHash.Data.msgTable.ExcelRoomMailTitle
	$excelWorksheet.Cells.Item( $row, 2 ) = $syncHash.Data.Room.PrimarySmtpAddress
	$row += 1
	$excelWorksheet.Cells.Item( $row, 1 ) = $syncHash.Data.msgTable.ExcelRoomLocTitle
	$excelWorksheet.Cells.Item( $row, 2 ) = $syncHash.Data.Room.Office
	$row += 1
	$excelWorksheet.Cells.Item( $row, 1 ) = $syncHash.Data.msgTable.ExcelRoomConfirmMess
	if ( $null -eq $syncHash.Data.RoomCalendarProcessing.AdditionalResponse ) { $excelWorksheet.Cells.Item( $row, 2 ) = $syncHash.Data.msgTable.ExcelNoConfirmMess }
	else { $excelWorksheet.Cells.Item( $row, 2 ) = $syncHash.Data.Room.$syncHash.Data.RoomCalendarProcessing.AdditionalResponse }
	$row += 1
	if ( $syncHash.btnFetchRLMembership.Tag )
	{
		$excelWorksheet.Cells.Item( $row, 1 ) = $syncHash.Data.msgTable.ExcelRoomRoomListTitle
		if ( $syncHash.DC.dgListMembership[0].Count -gt 0 )
		{
			foreach ( $list in $syncHash.DC.dgListMembership[0] )
			{
				$excelWorksheet.Cells.Item( $row, 2 ) = $list.DisplayName
				$row += 1
			}
		}
		else
		{
			$excelWorksheet.Cells.Item( $row, 2 ) = $syncHash.Data.msgTable.ExcelNoRoomList
			$row += 1
		}
	}

	if ( $syncHash.btnFetchAdmins.Tag )
	{
		$row += 1
		$tableStart = $row
		$excelWorksheet.Cells.Item( $row, 1 ) = $syncHash.Data.msgTable.ExcelAdmTitle
		$excelWorksheet.Cells.Item( $row, 2 ) = $syncHash.Data.msgTable.ExcelAdmMailTitle
		$row += 1

		if ( $syncHash.Data.AdminsAzure.Count -gt 0 )
		{
			$syncHash.Data.AdminsAzure.DisplayName | Sort-Object | clip
			$excelWorksheet.Cells.Item( $row, 1 ).PasteSpecial() | Out-Null
			( $syncHash.Data.AdminsAzure | Sort-Object DisplayName ).UserPrincipalName | clip
			$excelWorksheet.Cells.Item( $row, 2 ).PasteSpecial() | Out-Null

			$row += $syncHash.Data.AdminsAzure.Count
		}
		else
		{
			$excelWorksheet.Cells.Item( $row, 1 ) = $syncHash.Data.msgTable.ExcelNoAdm
			$excelWorksheet.Cells.Item( $row, 2 ) = $syncHash.Data.msgTable.ExcelNoAdmMail
			$row += 1
		}
		$excelWorksheet.ListObjects.Add( 1, $excelWorksheet.Range( $excelWorksheet.Cells.Item( $tableStart, 1 ), $excelWorksheet.Cells.Item( $tableStart + $syncHash.Data.AdminsAzure.Count, 2 ) ), 0, 1 ) | Out-Null
	}

	if ( $syncHash.btnFetchMembers.Tag )
	{
		$row += 1
		$tableStart = $row
		$excelWorksheet.Cells.Item( $row, 1 ) = $syncHash.Data.msgTable.ExcelUserTitle
		$excelWorksheet.Cells.Item( $row, 2 ) = $syncHash.Data.msgTable.ExcelUserMailTitle
		$row += 1

		if ( $syncHash.Data.UsersAzure.Count -gt 0 )
		{
			$syncHash.Data.UsersAzure.DisplayName | Sort-Object | clip
			$excelWorksheet.Cells.Item( $row, 1 ).PasteSpecial() | Out-Null
			( $syncHash.Data.UsersAzure | Sort-Object DisplayName ).UserPrincipalName | clip
			$excelWorksheet.Cells.Item( $row, 2 ).PasteSpecial() | Out-Null
			$row += $syncHash.Data.UsersAzure.Count
		}
		else
		{
			$excelWorksheet.Cells.Item( $row, 1 ) = $syncHash.Data.msgTable.ExcelNoUser
			$excelWorksheet.Cells.Item( $row, 2 ) = $syncHash.Data.msgTable.ExcelNoUserMail
			$row += 1
		}
		$excelWorksheet.ListObjects.Add( 1, $excelWorksheet.Range( $excelWorksheet.Cells.Item( $tableStart, 1 ), $excelWorksheet.Cells.Item( $tableStart + $syncHash.Data.UsersAzure.Count, 2 ) ), 0, 1 ) | Out-Null

		if ( ( $manualMembers = @( $syncHash.Data.UsersExchange.Where( { $_.Alias -notin $syncHash.Data.UsersAzure.MailNickName } ) ) ).Count -gt 0 )
		{
			$row += 1
			$tableStart = $row
			$excelWorksheet.Cells.Item( $row, 1 ) = $syncHash.Data.msgTable.ExcelManUserTitle
			$excelWorksheet.Cells.Item( $row, 2 ) = $syncHash.Data.msgTable.ExcelManUserMailTitle
			$row += 1

			$manualMembers.Name | Sort-Object | clip
			$excelWorksheet.Cells.Item( $row, 1 ).PasteSpecial() | Out-Null
			( $manualMembers | Sort-Object Name ).PrimarySmtpAddress | clip
			$excelWorksheet.Cells.Item( $row, 2 ).PasteSpecial() | Out-Null
			$excelWorksheet.ListObjects.Add( 1, $excelWorksheet.Range( $excelWorksheet.Cells.Item( $tableStart, 1 ), $excelWorksheet.Cells.Item( $tableStart + $manualMembers.Count, 2 ) ), 0, 1 ) | Out-Null
		}
	}
	#endregion

	$excelRange = $excelWorksheet.UsedRange
	$excelRange.EntireColumn.AutoFit() | Out-Null
	[void]$excelWorksheet.Cells.Item( 1, 2 ).Select()
	$excelWorkbook.SaveAs( $syncHash.Data.FileToSave.FileName )
	$excelWorkbook.Close()
	$excel.Quit()

	[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excelRange ) | Out-Null
	[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excelWorksheet ) | Out-Null
	[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excelWorkbook ) | Out-Null
	[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excel ) | Out-Null
	[System.GC]::Collect()
	[System.GC]::WaitForPendingFinalizers()
	Remove-Variable excel
}

#######################################
# The requested room have been selected
function RoomSelected
{
	if ( $syncHash.tabOps.SelectedIndex -eq 0 )
	{
		$syncHash.Data.RoomAzGroupAdmins = Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.Room.DisplayName )$( $syncHash.Data.msgTable.StrAzureADGrpNameAdmSuffix )"
		$syncHash.Data.RoomAzGroupBook = Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.Room.DisplayName )$( $syncHash.Data.msgTable.StrAzureADGrpNameBookSuffix )"
		$syncHash.DC.btnCheck[1] = $false
		$syncHash.DC.tbCheckRoom[0] = $syncHash.Data.Room.DisplayName
		$syncHash.DC.tbCheckRoom[3] = $false
		$syncHash.Window.Resources['Exists'] = $true
	}
	else
	{
		$syncHash.DC.tbRoomSearch[0] = $syncHash.Data.SourceRoom.DisplayName
		( $syncHash.Data.SourceRoom | Get-CalendarProcessing ).BookInPolicy | ForEach-Object { Get-Mailbox -Identity $_ -ErrorAction SilentlyContinue } | Sort-Object Name | ForEach-Object { $syncHash.DC.dgMembersOtherRoom[0].Add( $_ ) }
	}
	$syncHash.DC.dgSuggestions[0].Clear()
}

##################################
# Search for room by name or email
function SearchRoom
{
	param ( $SearchWord, [switch]$Exclude )

	if ( $SearchWord -match "^\S{1,}@\S{2,}\.\S{2,}$" ) { $t = "PrimarySmtpAddress" }
	else { $t = "DisplayName" }

	if ( $Exclude ) { return ( Get-Mailbox -RecipientTypeDetails "RoomMailbox" -Filter "$t -like '*$SearchWord*'" -ErrorAction Stop | Where-Object { $_.PrimarySmtpAddress -ne $syncHash.Data.Room.PrimarySmtpAddress } ) }
	else { return Get-Mailbox -RecipientTypeDetails "RoomMailbox" -Filter "$t -like '*$SearchWord*'" -ErrorAction Stop }
}

######################################
# Update datagrid with current members
function UpdateDgMembers
{
	$syncHash.DC.dgMembersAzure[0].Clear()
	$syncHash.DC.dgMembersExchange[0].Clear()
	$syncHash.Data.UsersAzure = Get-AzureADGroupMember -ObjectId $syncHash.Data.RoomAzGroupBook.ObjectId -All $true -ErrorAction Stop
	$syncHash.Data.RoomCalendarProcessing = Get-CalendarProcessing -Identity $syncHash.Data.Room.DisplayName
	$syncHash.Data.UsersExchange = $syncHash.Data.RoomCalendarProcessing.BookInPolicy | ForEach-Object { Get-Mailbox -Identity $_ -ErrorAction SilentlyContinue }

	if ( $syncHash.Data.UsersAzure.Count -gt 0 )
	{
		$syncHash.Data.UsersAzure | `
			Sort-Object DisplayName | `
			Select-Object -Property DisplayName, UserPrincipalName, ObjectId, MailNickName,`
				@{ Name = "Synched"; Expression = { $_.ObjectId -in $syncHash.Data.UsersExchange.ExternalDirectoryObjectId } } | `
			ForEach-Object { $syncHash.DC.dgMembersAzure[0].Add( $_ ) }
		$syncHash.DC.btnCopyMembers[1] = $true
	}
	else
	{ $syncHash.DC.dgMembersAzure[0].Add( [pscustomobject]@{ DisplayName = $syncHash.Data.msgTable.StrNoMembersAzure; PrimarySmtpAddress = ""; Synched = $true } ) }

	if ( @( $syncHash.Data.UsersExchange ).Count -gt 0 )
	{
		$syncHash.Data.UsersExchange | `
			Sort-Object Name | `
			Select-Object -Property Name, PrimarySmtpAddress, LegacyExchangeDN, Alias,`
				@{ Name = "Synched"; Expression = { $_.ExternalDirectoryObjectId -in $syncHash.Data.UsersAzure.ObjectId } } | `
			ForEach-Object { $syncHash.DC.dgMembersExchange[0].Add( $_ ) }
		$syncHash.DC.btnCopyMembers[1] = $true
	}
	else { $syncHash.DC.dgMembersExchange[0].Add( $syncHash.Data.msgTable.StrNoMembersExchange ) }

	if ( ( $syncHash.DC.dgMembersExchange[0].Synched.Where( { $_ -match "False" } ) ).Count -gt 0 )
	{ $syncHash.DC.tbMemberInfo[1] = [System.Windows.Visibility]::Visible }

	if ( $syncHash.btnFetchAdmins.Tag ) { $syncHash.DC.btnCopyAll[1] = $true }
}

###########################################################################################
# Update name and address for the room
# Verify first that this was the ment action
# Verify that the values in the textboxes are to be used, if they haven't both been changed
function UpdateNameAddress
{
	param ( $Question )

	if ( ( Confirmations -Action $Question -WithPrefix ) -eq "Yes" )
	{
		$update = $false
		if ( $syncHash.DC.tbRoomAddress[0] -ne $syncHash.Data.Room.PrimarySmtpAddress -and `
			$syncHash.DC.tbRoomName[0] -ne $syncHash.Data.Room.DisplayName )
		{
			$update = $true
		}
		else
		{
			if ( ( ShowMessagebox -Text $syncHash.Data.msgTable.StrNameOrAddrNotUpd -Button "YesNo" -Icon "Warning" ) -eq "Yes" ) { $update = $true }
			else { $update = $false }
		}

		if ( $update )
		{

			try { Set-Mailbox -Identity $syncHash.Data.Room.PrimarySmtpAddress -WindowsEmailAddress $syncHash.DC.tbRoomAddress[0].Trim() -Name $syncHash.DC.tbRoomName[0].Trim() -DisplayName $syncHash.DC.tbRoomName[0].Trim() -EmailAddresses @{Add = "smtp:$( $syncHash.Data.Room.PrimarySmtpAddress )"} -ErrorAction Stop }
			catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewNameAddr ) (Set-Mailbox)`n$_" -UserInput "Name $( $syncHash.DC.tbRoomName[0].Trim() )`nWindowsEmailAddress $( $syncHash.DC.tbRoomAddress[0].Trim() )" -Severity "OtherFail" }

			$azGroups = Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.Room.DisplayName )"
			foreach ( $group in $azGroups )
			{
				try { Set-AzureADGroup -ObjectId $group.ObjectId -DisplayName "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.DC.tbRoomName[0].Trim() )-$( ( $group.DisplayName -split "-" )[-1] )" -Description "Now" -ErrorAction Stop }
				catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewNameAddr ) (Set-AzureGroup)`n$_" -UserInput "$( $syncHash.Data.msgTable.ErrLogNewNameAddrUIGrp ) $( $group.DisplayName ) ($( $group.ObjectId ))`nDisplayName $( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.DC.tbRoomName[0].Trim() )-$( ( $group.DisplayName -split "-" )[-1] )" -Severity "OtherFail" }
			}

			$OFS = "`n"
			WriteLogTest -Text $syncHash.Data.msgTable.StrLogNewNameAddr -UserInput "$( $syncHash.Data.Room.DisplayName ) > $( $syncHash.DC.tbRoomName[0] )`n$( $syncHash.Data.Room.PrimarySmtpAddress ) > $( $syncHash.DC.tbRoomAddress[0] )`n$( [string]( Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.Room.DisplayName )" ).DisplayName )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
			$syncHash.Data.Room = Get-Mailbox -Identity $syncHash.DC.tbRoomName[0].Trim()
			$syncHash.btnRoomName.IsEnabled = $syncHash.btnRoomAddress.IsEnabled = $false
			WriteOpLog $syncHash.Data.msgTable.StrOpNameAddrChangeDone
		}
		else
		{
			ShowMessagebox -Text $syncHash.Data.msgTable.StrNoUpdate
			$syncHash.DC.tbRoomAddress[0] = $syncHash.Data.Room.WindowsEmailAddress
			$syncHash.DC.tbRoomName[0] = $syncHash.Data.Room.DisplayName
		}
	}
}

##################################
# Write text to the log in the GUI
function WriteOpLog
{
	param ( $Text, $Color = "Red" )

	$syncHash.spOpLog.Children.Insert( 0, ( [System.Windows.Controls.TextBlock]@{ Text = $Text; Foreground = $Color; Margin = 5 } ) )
}

###################### Script start
Add-Type -AssemblyName PresentationFramework
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]
$OFS = "`n"

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "btnAddAdmin" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddAdmin } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnAddMember" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddMember } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnAddRoomlist" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddRoomlist } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnBookingInfo" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnBookingInfo } ; @{ PropName = "IsEnabled" ; PropVal = $false } ; @{ PropName = "Tag" ; PropVal = [pscustomobject]@{ Pol = ""; Log = ""; OpLog = "" } } ) } )
[void]$controls.Add( @{ CName = "btnCheck" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCheck } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "btnConfirmMessage" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnConfirmMessage } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnConfirmMessageReset" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnConfirmMessageReset } ) } )
[void]$controls.Add( @{ CName = "btnCopyAdmins" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCopyAdmins } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnCopyAll" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCopyAll } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnCopyMembers" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCopyMembers } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnCopyOtherRoom" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCopyOtherRoom } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnExport" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnExport } ) } )
[void]$controls.Add( @{ CName = "btnFetchAdmins" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnFetchAdmins } ) } )
[void]$controls.Add( @{ CName = "btnFetchMembers" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnFetchMembers } ) } )
[void]$controls.Add( @{ CName = "btnFetchRLMembership" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnFetchRLMembership } ) } )
[void]$controls.Add( @{ CName = "btnLocation" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnLocation } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRemoveMembersAzure" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveMembersAzure } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRemoveMembersExchange" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveMembersExchange } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRemoveRoomlist" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveRoomlist } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRemoveSelectedAdmins" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveSelectedAdmins } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnReset" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnReset } ) } )
[void]$controls.Add( @{ CName = "btnRoomName" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRoomName } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRoomOwner" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRoomOwner } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRoomSearch" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRoomSearch } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnSelectAll" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSelectAll } ) } )
[void]$controls.Add( @{ CName = "btnSyncToExchange" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSyncToExchange } ) } )
[void]$controls.Add( @{ CName = "dgAdmins" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]' ) } ) } )
[void]$controls.Add( @{ CName = "dgListMembership" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]' ) } ) } )
[void]$controls.Add( @{ CName = "dgMembersAzure" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]' ) } ) } )
[void]$controls.Add( @{ CName = "dgMembersExchange" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]' ) } ) } )
[void]$controls.Add( @{ CName = "dgMembersOtherRoom" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]' ) } ) } )
[void]$controls.Add( @{ CName = "dgRoomlists" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]' ) } ) } )
[void]$controls.Add( @{ CName = "dgSuggestions" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]' ) } ) } )
[void]$controls.Add( @{ CName = "expAddMember" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentexpAddMember } ; @{ PropName = "IsExpanded"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "expAddRemAdm" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentexpAddRemAdm } ; @{ PropName = "IsExpanded"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "gAddAdmin" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgAddAdmin } ) } )
[void]$controls.Add( @{ CName = "gAddMember" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgAddMember } ) } )
[void]$controls.Add( @{ CName = "gMembersAzure" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgMembersAzure } ) } )
[void]$controls.Add( @{ CName = "gMembersExchange" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgMembersExchange } ) } )
[void]$controls.Add( @{ CName = "gRemoveSelectedAdmins" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgRemoveSelectedAdmins } ) } )
[void]$controls.Add( @{ CName = "lblAddAdmin" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblAddAdmin } ) } )
[void]$controls.Add( @{ CName = "lblAddMember" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblAddMember } ) } )
[void]$controls.Add( @{ CName = "lblCheckRoomTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblCheckRoomTitle } ) } )
[void]$controls.Add( @{ CName = "lblCopyAll" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblCopyAll } ) } )
[void]$controls.Add( @{ CName = "lblCopyOp" ; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblExport" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblExport } ) } )
[void]$controls.Add( @{ CName = "lblLocation" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLocation } ) } )
[void]$controls.Add( @{ CName = "lblLogTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLogTitle } ) } )
[void]$controls.Add( @{ CName = "lblRemoveSelectedAdmins" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRemoveSelectedAdmins } ) } )
[void]$controls.Add( @{ CName = "lblRoomAddress" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomAddress } ) } )
[void]$controls.Add( @{ CName = "lblRoomName" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomName } ) } )
[void]$controls.Add( @{ CName = "lblRoomOwner" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomOwner } ) } )
[void]$controls.Add( @{ CName = "lblRoomOwnerAddr" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomOwnerAddr } ) } )
[void]$controls.Add( @{ CName = "lblRoomOwnerID" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomOwnerID } ) } )
[void]$controls.Add( @{ CName = "lblRoomSearchTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomSearchTitle } ) } )
[void]$controls.Add( @{ CName = "lblSuggestionsTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSuggestionsTitle } ) } )
[void]$controls.Add( @{ CName = "lblSyncToExchange" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSyncToExchange } ) } )
[void]$controls.Add( @{ CName = "rbBookingInfoNotPublic" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbBookingInfoNotPublic } ; @{ PropName = "IsChecked" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "rbBookingInfoPublic" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbBookingInfoPublic } ; @{ PropName = "IsChecked" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "tbAddAdmin" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbAddMember" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbCheckRoom" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "tbConfirmMessage" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tblBookingInfo" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttblBookingInfo } ) } )
[void]$controls.Add( @{ CName = "tbLocation" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tblOwnerInfo" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbMemberInfo" ; Props = @( @{ PropName = "Text"; PropVal = [string]( $msgTable.ContenttbMemberInfo -split "\. " ) } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "tbRoomAddress" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbRoomName" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbRoomOwnerAddr" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbRoomOwnerID" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbRoomSearch" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tiAdmins" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiAdmins } ) } )
[void]$controls.Add( @{ CName = "tiConfirmMessage" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiConfirmMessage } ) } )
[void]$controls.Add( @{ CName = "tiCopyOtherRoom" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiCopyOtherRoom } ) } )
[void]$controls.Add( @{ CName = "tiInfo" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiInfo } ) } )
[void]$controls.Add( @{ CName = "tiListMembership" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiListMembership } ) } )
[void]$controls.Add( @{ CName = "tiMembers" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiMembers } ) } )
[void]$controls.Add( @{ CName = "ttAddNewMembers" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentttAddNewMembers } ) } )
[void]$controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = "" } ) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.msgTable = $msgTable
$syncHash.Data.BaseDir = $args[0]
$syncHash.ErrorRecord = @()

# Add user as admin in Azure-group
$syncHash.btnAddAdmin.Add_Click( {
	if ( $null -eq ( $newAdmin = Get-AzureADUser -Filter "proxyAddresses/any(y:startswith(y,'smtp:$( $syncHash.DC.tbAddAdmin[0] )'))" ) )
	{
		ShowMessagebox -Text "$( $syncHash.Data.msgTable.StrNoUser ) '$( $syncHash.DC.tbAddAdmin[0] )'" -Icon "Stop"
	}
	else
	{
		$userInput = "$( $syncHash.Data.msgTable.ErrLogAddAdminUIUsr ) $( $newAdmin.UserPrincipalName )`n$( $syncHash.Data.msgTable.ErrLogAddAdminUIGrp ) $( $syncHash.Data.RoomAzGroupAdmins.ObjectId ) $( $syncHash.Data.RoomAzGroupAdmins.DisplayName )"
		try { Add-AzureADGroupMember -ObjectId $syncHash.Data.RoomAzGroupAdmins.ObjectId -RefObjectId $newAdmin.ObjectId -ErrorAction Stop }
		catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogAddAdminAdd ) Add-AzureADGroupMember" -UserInput $userInput -Severity "OtherFail" }

		try { Set-AzureADGroup -ObjectId $syncHash.Data.RoomAzGroupAdmins.ObjectId -Description "Now" -ErrorAction Stop }
		catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogAddAdminSet ) Set-AzureADGroupMember" -UserInput $userInput -Severity "OtherFail" }
		WriteOpLog -Text $syncHash.Data.msgTable.StrOpNewAdmin -Color "Green"
		WriteLogTest -Text $syncHash.Data.msgTable.LogAddAdmin -UserInput $userInput -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
	}
} )

# Add new member
$syncHash.btnAddMember.Add_Click( {
	if ( $null -eq ( $newMember = Get-AzureADUser -Filter "proxyAddresses/any(y:startswith(y,'smtp:$( $syncHash.DC.tbAddAdmin[0] )'))" ) )
	{
		ShowMessagebox -Text "$( $syncHash.Data.msgTable.StrNoUser ) '$( $syncHash.DC.tbAddAdmin[0] )'" -Icon "Stop"
	}
	else
	{
		$roomPolicy = $syncHash.Data.RoomCalendarProcessing.BookInPolicy + ( Get-Mailbox -Identity $newMember.UserPrincipalName ).LegacyExchangeDN | Select-Object -Unique
		try { Set-CalendarProcessing -Identity $syncHash.Data.Room.DisplayName -AllBookInPolicy:$false -BookInPolicy $roomPolicy -ErrorAction Stop }
		catch { $eh += WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogAddMemCalProc -UserInput $newMember.UserPrincipalName -Severity "OtherFail" }

		$syncHash.Jobs.RoomCalendarProcessing = Get-CalendarProcessing -Identity $syncHash.Data.Room.DisplayName -AsJob
		try
		{
			Add-MailboxFolderPermission -Identity $syncHash.Data.ExchangeCalendar -AccessRights LimitedDetails -Confirm:$false -User $newMember.UserPrincipalName -ErrorAction Stop
			WriteOpLog -Text "$( $newMember.DisplayName ) $( $syncHash.Data.msgTable.StrOpNewUser )" -Color "Green"
		}
		catch
		{
			if ( $_.CategoryInfo.Reason -eq "ACLTooBigException" ) { $e = "$( $newMember.DisplayName ) $( $syncHash.Data.msgTable.ErrAclTooBigQuit )" }
			elseif ( $_.CategoryInfo.Reason -eq "InvalidExternalUserIdException" ) { $e = "$( ( $_.Exception -split [char]0x22 )[1] ) $( $syncHash.Data.msgTable.ErrInvalidExternalUserId )" }
			else { $e = "$( $syncHash.Data.msgTable.ErrGen )`n`n$( $_.CategoryInfo.Reason )`n`n$( $_.Exception )" }

			WriteOpLog -Text $e
			$eh += WriteErrorlogTest -LogText $e -UserInput $newMember.UserPrincipalName -Severity "OtherFail"
		}
		WriteLogTest -Text $syncHash.Data.msgTable.LogBookingPerm -UserInput "$( $syncHash.Data.msgTable.LogAddMemUIUser ) $( $newMember.UserPrincipalName )`n$( $syncHash.Data.msgTable.LogAddMemUIRoom ) $( $syncHash.Data.Room.DisplayName )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
		$syncHash.Data.RoomCalendarProcessing = Receive-Job $syncHash.Jobs.RoomCalendarProcessing
		UpdateDgMembers
	}
} )

# Add the current room to a roomlist
$syncHash.btnAddRoomlist.Add_Click( {
	try { Add-DistributionGroupMember -Identity $syncHash.dgRoomlists.SelectedItem.PrimarySmtpAddress -Member $syncHash.Data.Room.PrimarySmtpAddress -ErrorAction Stop }
	catch { $eh = WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogAddToRoomlist )`n$_" -UserInput "$( $syncHash.Data.msgTable.ErrLogAddToRoomlistUIRoom ) $( $syncHash.Data.Room.PrimarySmtpAddress )`n$( $syncHash.Data.msgTable.ErrLogAddToRoomlistUIRoomlist ) $( $syncHash.dgRoomlists.SelectedItem.PrimarySmtpAddress )" }
	$syncHash.DC.dgListMembership[0].Add( $syncHash.dgRoomlists.SelectedItem.PrimarySmtpAddress )
	WriteLogTest -Text $syncHash.Data.msgTable.LogAddRoomList -UserInput "$( $syncHash.Data.msgTable.LogAddRoomListUIRoom ) $( $syncHash.Data.Room.PrimarySmtpAddress )`n$( $syncHash.Data.msgTable.LogAddRoomListUIRoom ) $( $syncHash.dgRoomlists.SelectedItem.PrimarySmtpAddress )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )

# Change policy for accessrights for the romm calendar
$syncHash.btnBookingInfo.Add_Click( {
	try { Set-MailboxFolderPermission -Identity $syncHash.Data.ExchangeCalendar -User Standard -AccessRights $this.Tag.Pol -ErrorAction Stop }
	catch { $eh = WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogAccessRights -UserInput "$( $syncHash.Data.msgTable.ErrLogAccessRightsUIRoom ) $( $syncHash.Data.ExchangeCalendar )`n$( $syncHash.Data.msgTable.ErrLogAccessRightsUIPolicy ) $( $this.Tag.Pol )" -Severity "OtherFail" }
	$this.Tag = [pscustomobject]@{ Pol = ""; Log = ""; OpLog = "" }
	$this.IsEnabled = $false
	WriteOpLog -Text ""
	WriteLogTest -Text $syncHash.Data.msgTable.LogAccessRights -UserInput "$( $syncHash.Data.Room.PrimarySmtpAddress )`n$( $this.Tag.Log ) " -Success ( $null -eq $eh ) -ErrorLogHash | Out-Null
} )

# Try getting the room by searching for the name given by the user
$syncHash.btnCheck.Add_Click( {
	$syncHash.DC.dgSuggestions[0].Clear()
	$search = SearchRoom -SearchWord $syncHash.DC.tbCheckRoom[0]
	if ( $null -eq $search )
	{
		WriteOpLog -Text "$( $syncHash.Data.msgTable.StrOpNoRoom ) '$( $syncHash.DC.tbCheckRoom[0] )'"
		$syncHash.DC.tbCheckRoom[1] = 2
		$eh += WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrRoomNotFound -UserInput $syncHash.DC.tbCheckRoom[0] -Severity "UserInputFail"
	}
	elseif ( @( $search ).Count -gt 1 )
	{
		$search | Sort-Object DisplayName | ForEach-Object { $syncHash.DC.dgSuggestions[0].Add( $_ ) }
	}
	else
	{
		$syncHash.Data.Room = $search
		RoomSelected
	}
	WriteLogTest -Text $syncHash.Data.msgTable.LogRoomSearch -UserInput $syncHash.DC.tbCheckRoom[0] -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )

# Update the confirmation message for booking the room
$syncHash.btnConfirmMessage.Add_Click( {
	try { Set-CalendarProcessing -Identity $syncHash.Data.Room.DisplayName -AdditionalResponse $syncHash.DC.tbConfirmMessage[0] -AddAdditionalResponse ( $syncHash.DC.tbConfirmMessage[0].Length -gt 0 ) -ErrorAction Stop }
	catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogSetConfirmMsg ) Set-CalendarProcessing`n$_" -UserInput "$( $syncHash.Data.Room.DisplayName )`n`n""$syncHash.DC.tbConfirmMessage[0]""" -Severity "OtherFail" }

	try { Set-Mailbox -Identity $syncHash.Data.Room.DisplayName -MailTip $syncHash.DC.tbConfirmMessage[0] -ErrorAction Stop }
	catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogSetConfirmMsg ) Set-Mailbox`n$_" -UserInput "$( $syncHash.Data.Room.DisplayName )`n`n""$syncHash.DC.tbConfirmMessage[0]""" -Severity "OtherFail" }

	WriteLogTest -Text $syncHash.Data.msgTable.LogNewResponseMessage -UserInput "$( $syncHash.Data.Room.DisplayName )`n`n""$syncHash.DC.tbConfirmMessage[0]""" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )

# Reset textbox to contain current confirmation message
$syncHash.btnConfirmMessageReset.Add_Click( {
	$syncHash.DC.tbConfirmMessage[0] = $syncHash.Data.RoomCalendarProcessing.AdditionalResponse
	$syncHash.tbConfirmMessage.Focus()
} )

# Copy the list of admins to clipboard
$syncHash.btnCopyAdmins.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$OFS = "`n"
	"$( $syncHash.Data.Room.DisplayName)`n`n*******************************`n$( $syncHash.Data.msgTable.LogAdmPerm )`n*******************************`n$( $syncHash.Data.AdminsAzure | Sort-Object DisplayName | ForEach-Object { "$( $_.DisplayName ) <$( $_.UserPrincipalName )>" } )" | Clip
	ShowSplash -Text $syncHash.Data.msgTable.StrAdminsCopied
	WriteLogTest -Text $syncHash.Data.msgTable.LogCopyAdmin -Success $true | Out-Null
} )

# Copy the list of users to clipboard
$syncHash.btnCopyMembers.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$OFS = "`n"
	"$( $syncHash.Data.Room.DisplayName)`n`n*******************************`n$( $syncHash.Data.msgTable.LogBookingPerm )`n*******************************`n$( $syncHash.Data.UsersAzure | Sort-Object DisplayName | ForEach-Object { "$( $_.DisplayName ) <$( $_.UserPrincipalName )>" } )" | Clip
	ShowSplash -Text $syncHash.Data.msgTable.StrUsersCopied
	WriteLogTest -Text $syncHash.Data.msgTable.LogCopyMembers -Success $true | Out-Null
} )

# Copy permissions from another room
$syncHash.btnCopyOtherRoom.Add_Click( {
	try { Set-CalendarProcessing -Identity $syncHash.Data.Room.DisplayName -BookInPolicy ( $syncHash.dgMembersOtherRoom.SelectedItems + $syncHash.Data.RoomCalendarProcessing.BookInPolicy ) }
	catch
	{
		$OFS = "`n"
		$eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogCopyOtherRoom ) Set-CalendarProcessing`n$_" -UserInput "$( $syncHash.Data.msgTable.ErrLogCopyPermUIOtherRoom ) $( $syncHash.DC.tbRoomSearch[0] )`n$( $syncHash.Data.msgTable.ErrLogCopyPermUIUsers )`n$( $syncHash.dgMembersOtherRoom.SelectedItems )" -Severity "OtherFail"
	}

	$usersCopied = @()
	foreach ( $user in ( $syncHash.dgMembersOtherRoom.SelectedItems | Where-Object { $_.RecipientTypeDetails -eq "UserMailbox" } ) )
	{
		try
		{
			Add-AzureADGroupMember -ObjectId $syncHash.Data.RoomAzGroupBook.ObjectId -RefObjectId $user.MicrosoftOnlineServicesID -ErrorAction Stop
			$usersCopied += $user
		}
		catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogCopyOtherRoom ) Add-AzureADGroupMember`n$_" -UserInput "$( $syncHash.Data.RoomAzGroupBook.DisplayName )`n$( $user.MicrosoftOnlineServicesID )" -Severity "OtherFail" }
		try { Add-MailboxFolderPermission -Identity $syncHash.Data.ExchangeCalendar -AccessRights LimitedDetails -User $user.MicrosoftOnlineServicesID -Confirm:$false -ErrorAction Stop }
		catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogCopyOtherRoom ) Add-MailboxFolderPermission`n$_" -UserInput "$( $syncHash.Data.ExchangeCalendar )`n$( $user.MicrosoftOnlineServicesID )" -Severity "OtherFail" }
	}
	$syncHash.DC.lblCopyOp[0] += "`n$( $syncHash.Data.msgTable.StrOpCopyOtherRoomDone )"
	WriteLogTest -Text $syncHash.Data.msgTable.LogCopyOtherRoom -UserInput "$( $syncHash.Data.msgTable.LogCopyOtherRoomUIFrom ) $( $syncHash.Data.SourceRoom.PrimarySmtpAddress )`n$( $syncHash.Data.msgTable.LogCopyOtherRoomUIUsers )`n$( $usersCopied.PrimarySmtpAddress )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )

# Export data that have been loaded
$syncHash.btnExport.Add_Click( {
	$fileDialog = [Microsoft.Win32.SaveFileDialog]@{ DefaultExt = ".xlsx"; Filter = "Excel-files | *.xlsx" ; InitialDirectory = "$( $syncHash.Data.BaseDir )\Output\$( $env:USERNAME )" ; FileName = "$( $syncHash.Data.msgTable.StrExportFileName ) - $( $syncHash.Data.Room.DisplayName )" }
	if ( $fileDialog.ShowDialog() )
	{
		$syncHash.Data.FileToSave = $fileDialog
		WriteOpLog -Text $syncHash.Data.msgTable.StrOpExportBegin -Color Blue
		Export
		WriteOpLog -Text "$( $syncHash.Data.msgTable.StrOpExportEnd )`n$( $syncHash.Data.FileToSave.FileName )" -Color Green
		WriteLogTest -Text $syncHash.Data.msgTable.LogExported -OutputPath $syncHash.Data.FileToSave.FileName -Success $true | Out-Null
	}
} )

# Get list of users with admin permissions from Azure
$syncHash.btnFetchAdmins.Add_Click( {
	$this.Tag = $true
	$syncHash.DC.dgAdmins[0].Clear()
	$syncHash.Data.AdminsAzure = Get-AzureADGroupMember -ObjectId $syncHash.Data.RoomAzGroupAdmins.ObjectId | Where-Object { $_.UserType -eq "Member" }

	if ( $syncHash.Data.AdminsAzure.Count -ge 1 )
	{
		$syncHash.Data.AdminsAzure | Sort-Object DisplayName | ForEach-Object { $syncHash.DC.dgAdmins[0].Add( $_ ) }
		$syncHash.DC.btnCopyAdmins[1] = $true
	}
	else { $syncHash.DC.dgAdmins[0].Add( [pscustomobject]@{ DisplayName = $syncHash.Data.msgTable.StrNoAdmins ; UserPrincipalName = "" } ) }

	if ( $syncHash.btnFetchMembers.Tag ) { $syncHash.DC.btnCopyAll[1] = $true }
} )

# Get list of users from Azure and Exchange
# Show info if there users with manually created permissions i Exchange
$syncHash.btnFetchMembers.Add_Click( {
	$this.Tag = $true
	UpdateDgMembers
} )

# Get roomlists currently selected room is part of
$syncHash.btnFetchRLMembership.Add_Click( {
	$this.Tag = $true
	$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrGettingRoomListMembership

	$syncHash.Data.RoomLists = Get-DistributionGroup -Filter { RecipientTypeDetails -eq "RoomList" }
	$syncHash.Data.RoomLists | Sort-Object DisplayName | ForEach-Object { $syncHash.DC.dgRoomlists[0].Add( $_ ) }

	$syncHash.DC.dgListMembership[0] = @( $syncHash.Data.RoomLists | ForEach-Object { if ( ( Get-DistributionGroupMember -Identity $_.PrimarySmtpAddress ).Name -match $syncHash.Data.Room.Name ) { $_ } } )
	$syncHash.DC.Window[0] = ""
} )

# Set a new location
$syncHash.btnLocation.Add_Click( {
	try { Set-Mailbox -Identity $syncHash.Data.Room.PrimarySmtpAddress -Office $syncHash.DC.tbLocation[0] -ErrorAction Stop }
	catch { $eh = WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewLoc )`n$_" -UserInput "$( $syncHash.Data.msgTable.LogNewLocUIRoom ) $( $syncHash.Data.Room.PrimarySmtpAddress )`n$( $syncHash.Data.msgTable.LogNewLocUILoc ) $( $syncHash.DC.tbLocation[0] )" -Severity "OtherFail" }

	$syncHash.Data.Room = Get-Mailbox -Identity $syncHash.Data.Room.PrimarySmtpAddress
	WriteLogTest -Text $syncHash.Data.msgTable.LogNewLoc -UserInput "$( $syncHash.Data.msgTable.LogNewLocUIRoom ) $( $syncHash.Data.Room.PrimarySmtpAddress )`n$( $syncHash.Data.msgTable.LogNewLocUILoc ) $( $syncHash.DC.tbLocation[0] )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )

# Remove a selected user from the rooms Azure-group
$syncHash.btnRemoveMembersAzure.Add_Click( {
	$syncHash.dgMembersAzure.SelectedItems | ForEach-Object {
		try { Remove-AzureADGroupMember -ObjectId $syncHash.Data.RoomAzGroupBook.ObjectId -MemberId $_.ObjectId -ErrorAction Stop }
		catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogRemoveUserAzure )`n$_" -UserInput "$( $syncHash.Data.msgTable.ErrLogRemUsrAzUIRoom ) $( $syncHash.Data.RoomAzGroupBook.DisplayName )`n$( $_.UserPrincipalName )" }
		WriteOpLog -Text "$( $_.DisplayName ) $( $syncHash.Data.msgTable.StrOpRemoveUserAz )" -Color "Green"
	}
	Set-AzureADGroup -ObjectId $syncHash.Data.RoomAzGroupBook.ObjectId -Description "Now"
	$OFS = "`n"
	WriteLogTest -Text $syncHash.Data.msgTable.LogRemUsersAz -UserInput "$( $syncHash.Data.msgTable.LogRemUsersAz ) $( $syncHash.Data.RoomAzGroupBook.DisplayName )`n$( $syncHash.dgMembersAzure.SelectedItems.UserPrincipalName )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
	UpdateDgMembers
} )

# Remove a selected user from the room in Exchange
$syncHash.btnRemoveMembersExchange.Add_Click( {
	$tempBookInPolicy = $syncHash.dgMembersExchange.Items | Where-Object { $_ -notin $syncHash.dgMembersExchange.SelectedItems } | Select-Object LegacyExchangeDN
	try { Set-CalendarProcessing -Identity $syncHash.Data.Room.DisplayName -AllBookInPolicy:$false -BookInPolicy $tempBookInPolicy -ErrorAction Stop }
	catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogRemUsrExcSetCalProc ) (Set-CalendarProcessing)`n$_" -UserInput "$( $syncHash.Data.Room.DisplayName )`n$tempBookInPolicy" -Severity "OtherFail" }

	$syncHash.Jobs.RoomCalendarProcessing = Get-CalendarProcessing -Identity $syncHash.Data.Room.DisplayName -AsJob

	foreach ( $user in $syncHash.dgMembersExchange.SelectedItems )
	{
		try
		{
			Remove-MailboxFolderPermission -Identity $syncHash.Data.ExchangeCalendar -Confirm:$false -User $user.PrimarySmtpAddress -ErrorAction Stop
			$e = "$( $user.DisplayName ) $( $syncHash.Data.msgTable.StrOpRemoveUserExc )"
		}
		catch
		{
			if ( $_.CategoryInfo.Reason -eq "ACLTooBigException" )
			{
				$e = "$( $user.DisplayName ) $( $syncHash.Data.msgTable.ErrAclTooBigQuit )"
				$q = $true
			}
			elseif ( $_.CategoryInfo.Reason -eq "InvalidExternalUserIdException" )
			{ $e = "$( ( $_.Exception -split [char]0x22 )[1] ) $( $syncHash.Data.msgTable.ErrInvalidExternalUserId )" }
			else
			{ $e = "$( $syncHash.Data.msgTable.ErrGen )`n`n$( $_.CategoryInfo.Reason )`n`n$( $_.Exception )" }
		}
		WriteOpLog $e
		$eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogRemUsrExcRemMbPerm ) (Remove-MailboxFolderPermission)`n$_" -UserInput "$( $syncHash.Data.Room.DisplayName )`n$( $user.PrimarySmtpAddress )" -Severity "OtherFail"
		if ( $q ) { return }
	}
	$OFS = "`n"
	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogRemUsersEx )" -UserInput "$( $syncHash.Data.Room.DisplayName )`n$( [string] $syncHash.dgMembersExchange.SelectedItems.PrimarySmtpAddress )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null

	$syncHash.Data.RoomCalendarProcessing = Receive-Job $syncHash.Jobs.RoomCalendarProcessing
	UpdateDgMembers
} )

# Remove the room from the selected roomlist
$syncHash.btnRemoveRoomlist.Add_Click( {
	try { Remove-DistributionGroupMember -Identity $syncHash.dgListMembership.SelectedItem.PrimarySmtpAddress -Member $syncHash.Data.Room.PrimarySmtpAddress -ErrorAction Stop }
	catch { $eh = WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogRemRoomList )`n$_" -UserInput "$( $syncHash.Data.Room.PrimarySmtpAddress )`n$( $syncHash.Data.msgTable.ErrLogRemRoomListUIRoomList ) $( $syncHash.dgListMembership.SelectedItem.PrimarySmtpAddress )" }
	$syncHash.DC.dgListMembership[0] = $syncHash.DC.dgListMembership[0] | Where-Object { $_.PrimarySmtpAddress -ne $syncHash.dgListMembership.SelectedItem.PrimarySmtpAddress }
	WriteLogTest -Text $syncHash.Data.msgTable.ErrLogRemRoomList -UserInput "$( $syncHash.Room.PrimarySmtpAddress )`n$( $syncHash.Data.msgTable.LogRemRoomListUIRoomList) $( $syncHash.dgListMembership.SelectedItem.PrimarySmtpAddress )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )

# Remove the selected admin from the rooms Azure-group
$syncHash.btnRemoveSelectedAdmins.Add_Click( {
	foreach ( $adm in $syncHash.dgAdmins.SelectedItems )
	{
		try { Remove-AzureADGroupMember -ObjectId $syncHash.Data.RoomAzGroupAdmins.ObjectId -MemberId $adm.ObjectId -ErrorAction Stop }
		catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogRemAdmGrp )`n$_" -UserInput "$( $syncHash.Data.RoomAzGroupAdmins.DisplayName )`n$( $adm.UserPrincipalName )" -Severity "OtherFail" }
		WriteOpLog -Text "$( $adm.DisplayName ) $( $syncHash.Data.msgTable.LogMsgOpRemoveAdmAz )" -Color "Green"
	}
	try { Set-AzureADGroup -ObjectId $syncHash.Data.RoomAzGroupAdmins.ObjectId -Description "Now" -ErrorAction Stop }
	catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogRemAdmGrp ) (Set-AzureADGroup)`n$_" -UserInput $syncHash.Data.RoomAzGroupAdmins.DisplayName -Severity "OtherFail" }
	$OFS = "`n"
	WriteLogTest -Text $syncHash.Data.msgTable.LogRemAdmGrp -UserInput "$( $syncHash.Data.Room.DisplayName ) $( $syncHash.Data.RoomAzGroupAdmins )`n$( [string]$syncHash.dgAdmins.SelectedItems.MailNickName )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )

# Reset the GUI
$syncHash.btnReset.Add_Click( {
	$syncHash.Window.Resources['Exists'] = $false
	$syncHash.DC.btnCheck[1] = $true
	$syncHash.DC.tbCheckRoom[0] = ""
	$syncHash.DC.tbCheckRoom[3] = $true
	$syncHash.tbCheckRoom.Focus()
} )

# Texts for name and address was changed, update room
$syncHash.btnRoomName.Add_Click( { UpdateNameAddress -Question $syncHash.Data.msgTable.StrConfirmNewName } )

# Id for owner has changed, update room
$syncHash.btnRoomOwner.Add_Click( {
	if ( ( Confirmations -Action $syncHash.Data.msgTable.StrConfirmNewOwner -WithPrefix ) -eq "Yes" )
	{
		try
		{
			Set-Mailbox -Identity $syncHash.Data.Room.PrimarySmtpAddress -CustomAttribute10 "$( $syncHash.Data.msgTable.StrOwnerAttrPrefix ) $( $syncHash.TempOwner.EmailAddress )" -ErrorAction Stop

			$syncHash.Data.Room = Get-Mailbox -Identity $syncHash.Data.Room.PrimarySmtpAddress -ErrorAction Stop

			$syncHash.Data.RoomOwner = $syncHash.TempOwner
			$syncHash.DC.tbRoomOwnerID[0] = $syncHash.Data.RoomOwner.SamAccountName
			$syncHash.DC.tbRoomOwnerAddr[0] = $syncHash.Data.RoomOwner.EmailAddress
			WriteOpLog -Text $syncHash.Data.msgTable.StrOpNewOwnerDone -Color "Green"
		}
		catch
		{
			$eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewOwner ) ($( $_.CategoryInfo.Activity ))`n$_" -UserInput "$( $syncHash.Data.Room.PrimarySmtpAddress )`n$( $syncHash.TempOwner.EmailAddress )" -Severity "OtherFail"
		}
	}

	WriteLogTest -Text $syncHash.Data.msgTable.LogNewOwner -UserInput "$( $syncHash.Data.Room.DisplayName ) $( $registeredOwner.Alias ) > $( $syncHash.Data.SharedMailboxOwner )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
	$syncHash.TempOwner = $null
} )

# Search for room to copy permissions from
$syncHash.btnRoomSearch.Add_Click( {
	$syncHash.DC.tbRoomSearch[1] = 1
	$syncHash.DC.tbRoomSearch[2] = "LightGray"
	$search = SearchRoom -SearchWord $syncHash.DC.tbRoomSearch[0] -Exclude

	if ( $null -eq $search )
	{
		$syncHash.DC.tbRoomSearch[1] = 2
		$syncHash.DC.tbRoomSearch[2] = "Red"
		$syncHash.DC.lblCopyOp[0] = $syncHash.Data.msgTable.ErrNotFound
	}
	elseif ( @( $search ).Count -gt 1 )
	{
		$search | Sort-Object DisplayName | ForEach-Object { $syncHash.DC.dgSuggestions[0].Add( $_ ) }
	}
	else
	{
		$syncHash.Data.SourceRoom = $search
		RoomSelected
	}
} )

# Select all users in otherroom
$syncHash.btnSelectAll.Add_Click( { $syncHash.dgMembersOtherRoom.SelectAll() } )

# Synchronize members from Azure to Exchange
$syncHash.btnSyncToExchange.Add_Click( {
	$usersAzure = Get-AzureADGroupMember -ObjectId $syncHash.Data.RoomAzGroupBook.ObjectId
	$roomPolicy = $syncHash.Data.RoomCalendarProcessing.BookInPolicy
	$q = $false

	foreach ( $user in $usersAzure )
	{
		$roomPolicy += ( Get-Mailbox -Identity $user.UserPrincipalName ).LegacyExchangeDN
		try
		{
			Add-MailboxFolderPermission -Identity $syncHash.Data.ExchangeCalendar -AccessRights LimitedDetails -Confirm:$false -User $user.UserPrincipalName -ErrorAction Stop
			$e = "$( $user.DisplayName ) $( $syncHash.Data.msgTable.StrOpSynched )"
		}
		catch
		{
			if ( $_.CategoryInfo.Reason -eq "ACLTooBigException" )
			{
				$e = "$( $user.DisplayName ) $( $syncHash.Data.msgTable.ErrAclTooBigQuit )"
				$q = $true
			}
			elseif ( $_.CategoryInfo.Reason -eq "InvalidExternalUserIdException" ) { $e = "$( ( $_.Exception -split [char]0x22 )[1] ) $( $syncHash.Data.msgTable.ErrInvalidExternalUserId )" }
			else { $e = "$( $syncHash.Data.msgTable.ErrGen )`n$( $_.CategoryInfo.Reason )`n`n$( $_.Exception )" }
			$eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogSync )`n$e" -UserInput "$( $syncHash.Data.RoomAzGroupBook.DisplayName )`n$user.PrincipalName" -Severity "OtherFail"
		}
		WriteOpLog $e
		if ( $q ) { return }
	}
	$roomPolicy = $roomPolicy | Select-Object -Unique
	Set-CalendarProcessing -Identity $syncHash.DC.tbRoomName[0] -AllBookInPolicy:$false -BookInPolicy $roomPolicy -ErrorAction SilentlyContinue

	$OFS = "`n"
	WriteLogTest -Text $syncHash.Data.msgTable.LogSync -UserInput "$( $syncHash.Data.Room.DisplayName )`n$( [string]$usersAzure.UserPrincipalName )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
	WriteOpLog -Text $syncHash.Data.msgTable.StrOpSyncDone -Color "Green"
} )

# Enable button if selectioncount is greater than 0
$syncHash.dgAdmins.Add_SelectionChanged( { $syncHash.DC.btnRemoveSelectedAdmins[1] = $this.SelectedItems.Count -gt 0 } )
$syncHash.dgListMembership.Add_SelectionChanged( { $syncHash.DC.btnRemoveRoomlist[1] = $this.SelectedItems.Count -gt 0 } )
$syncHash.dgMembersAzure.Add_SelectionChanged( { $syncHash.DC.btnRemoveMembersAzure[1] = $this.SelectedItems.Count -gt 0 } )
$syncHash.dgMembersExchange.Add_SelectionChanged( { $syncHash.DC.btnRemoveMembersExchange[1] = $this.SelectedItems.Count -gt 0 } )
$syncHash.dgMembersOtherRoom.Add_SelectionChanged( { $syncHash.DC.btnCopyOtherRoom[1] = $this.SelectedItems.Count -gt 0 } )
$syncHash.dgRoomlists.Add_SelectionChanged( { $syncHash.DC.btnAddRoomlist[1] = $this.SelectedItems.Count -gt 0 } )

# A room is selected in the suggestionlist
$syncHash.dgSuggestions.Add_MouseDoubleClick( {
	if ( $syncHash.tabOps.SelectedIndex -eq 0 )
	{ $syncHash.Data.Room = $this.CurrentItem }
	else
	{ $syncHash.Data.SourceRoom = $this.CurrentItem }
	RoomSelected
} )

# Grid is enabled/disabled
$syncHash.gAdmins.Add_IsEnabledChanged( {
	if ( $this.IsEnabled ) {}
	else
	{
		$syncHash.DC.tbAddAdmin[0] = ""
		$syncHash.DC.dgAdmins[0].Clear()
		$syncHash.Data.AdminsAzure.Clear()
	}
} )

# Grid is enabled/disabled
$syncHash.gConfirmMessage.Add_IsEnabledChanged( {
	if ( $this.IsEnabled ) {}
	else
	{
		$syncHash.DC.tbConfirmMessage[0] = ""
	}
} )

# Grid is enabled/disabled
$syncHash.gCopyOtherRoom.Add_IsEnabledChanged( {
	if ( $this.IsEnabled ) {}
	else
	{
		$syncHash.DC.tbRoomSearch[0] = $syncHash.DC.lblCopyOp[0] = ""
		$syncHash.DC.dgMembersOtherRoom[0].Clear()
	}
} )

# Grid is enabled/disabled
$syncHash.gInfo.Add_IsEnabledChanged( {
	if ( $this.IsEnabled )
	{
		# Get Name
		$syncHash.DC.tbRoomName[0] = $syncHash.Data.Room.DisplayName
		# Get Address
		$syncHash.DC.tbRoomAddress[0] = $syncHash.Data.Room.PrimarySmtpAddress
		# Get Owner
		if ( ( $addr = ( $syncHash.Data.Room.CustomAttribute10 -replace $syncHash.Data.msgTable.StrOwnerAttrPrefix ).Trim() ) -eq "" )
		{
			WriteOpLog -Text $syncHash.Data.msgTable.StrNoOwner
		}
		else
		{
			$syncHash.DC.tbRoomOwnerAddr[0] = $addr.Trim()
			try
			{ Get-EXOMailbox -Identity $addr -ErrorAction Stop }
			catch [Microsoft.Exchange.Management.RestApiClient.RestClientException]
			{ WriteOpLog -Text $syncHash.Data.msgTable.ErrMsgNoMailAccountOwner }
			catch
			{ WriteOpLog -Text $_.Exception.Message }

			try
			{
				if ( $null -eq ( $syncHash.Data.RoomOwner = Get-ADUser -LDAPFilter "(proxyaddresses=*smtp:$addr*)" -ErrorAction Stop ) )
				{ WriteOpLog -Text $syncHash.Data.msgTable.ErrMsgNoAdAccountOwner }
				else
				{ $syncHash.DC.tbRoomOwnerID[0] = $syncHash.Data.RoomOwner.SamAccountName.ToUpper() }
			}
			catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
			{ WriteOpLog -Text $syncHash.Data.msgTable.ErrMsgNoAdAccountOwner }
			catch
			{ WriteOpLog -Text $_.Exception.Message }
		}

		$syncHash.Data.FolderStatistics = Get-MailboxFolderStatistics -Identity $syncHash.Data.Room.PrimarySmtpAddress
		$syncHash.Data.ExchangeCalendar = $syncHash.Data.FolderStatistics.Where( { $_.FolderType -eq "Calendar" } ).Identity -replace "\\", ":\"
		$syncHash.Data.FolderPermission = Get-MailboxFolderPermission -Identity $syncHash.Data.ExchangeCalendar

		# Get location
		$syncHash.DC.tbLocation[0] = $syncHash.Data.Room.Office
		# Get Bookinginfo public/nonpublic
		if ( $syncHash.Data.FolderPermission.Where( { $_.User -match "Default" } ).AccessRights -match "LimitedDetails" ) { $syncHash.DC.rbBookingInfoPublic[1] = $true }
		else { $syncHash.DC.rbBookingInfoNotPublic[1] = $true }
	}
	else
	{
		$syncHash.Data.ExchangeCalendar = ""
		"FolderPermission", "Room", "RoomOwner", "RoomCalendarProcessing", "RoomAzGroupBook" | ForEach-Object { $syncHash.Data.$_ = $null }
		$syncHash.DC.tbRoomName[0] = $syncHash.DC.tbRoomAddress[0] = $syncHash.DC.tbRoomOwnerAddr[0] = $syncHash.DC.tbRoomOwnerID[0] = ""
		$syncHash.DC.tbRoomName[1] = $syncHash.DC.tbRoomAddress[1] = $syncHash.DC.tbRoomOwnerAddr[1] = $syncHash.DC.tbRoomOwnerID[1] = 1
		$syncHash.DC.tbRoomName[2] = $syncHash.DC.tbRoomAddress[2] = $syncHash.DC.tbRoomOwnerAddr[2] = $syncHash.DC.tbRoomOwnerID[2] = "LightGray"
		$syncHash.spOpLog.Children.Clear()
	}
	$syncHash.DC.Window[0] = ""
} )

# Grid is enabled/disabled
$syncHash.gListMembership.Add_IsEnabledChanged( {
	if ( $this.IsEnabled ) {}
	else
	{
		$syncHash.DC.dgListMembership[0].Clear()
	}
} )

# Grid is enabled/disabled
$syncHash.gMembers.Add_IsEnabledChanged( {
	if ( $this.IsEnabled ) {}
	else
	{
		$syncHash.DC.tbAddMember[0] = ""
		$syncHash.DC.tbMemberInfo[0] = [System.Windows.Visibility]::Collapsed
		$syncHash.DC.dgMembersAzure[0].Clear()
		$syncHash.DC.dgMembersExchange[0].Clear()
		$syncHash.Data.UsersAzure = $syncHash.Data.UsersExchange = $null
	}
} )

# Radiobutton is checked, prepare for changing bookings visibility policy
$syncHash.rbBookingInfoPublic.Add_Checked( {
	$syncHash.DC.btnBookingInfo[2].Pol = "LimitedDetails"
	$syncHash.DC.btnBookingInfo[2].Log = $syncHash.Data.msgTable.LogBookInfoPub
	$syncHash.DC.btnBookingInfo[2].OpLog = $syncHash.Data.msgTable.StrOpBookInfoPub
	$syncHash.DC.btnBookingInfo[1] = $syncHash.DC.btnBookingInfo[1].Pol -ne $syncHash.Data.FolderPermission.BookInPolicy
} )

# Radiobutton is checked, prepare for changing bookings visibility policy
$syncHash.rbBookingInfoNotPublic.Add_Checked( {
	$syncHash.DC.btnBookingInfo[2].Pol = "AvailabilityOnly"
	$syncHash.DC.btnBookingInfo[2].Log = $syncHash.Data.msgTable.LogBookInfoNonPub
	$syncHash.DC.btnBookingInfo[2].OpLog = $syncHash.Data.msgTable.StrOpBookInfoNonPub
	$syncHash.DC.btnBookingInfo[1] = $syncHash.DC.btnBookingInfo[1].Pol -ne $syncHash.Data.FolderPermission.BookInPolicy
} )

# Text for confirmation message for booking have changed, enable button to save
$syncHash.tbConfirmMessage.Add_TextChanged( {
	$syncHash.DC.btnConfirmMessage[1] = $this.Text -ne $syncHash.Data.RoomCalendarProcessing.AdditionalResponse
} )

# Text for location have changed, enable button to save
$syncHash.tbLocation.Add_TextChanged( { $syncHash.DC.btnLocation[1] = $this.Text -ne $syncHash.Data.Room.Office } )

# Text for address/name have changed, enable button to save
$syncHash.tbRoomAddress.Add_TextChanged( { $syncHash.DC.btnRoomName[1] = $this.Text -ne $syncHash.Data.Room.PrimarySmtpAddress } )
$syncHash.tbRoomName.Add_TextChanged( { $syncHash.DC.btnRoomName[1] = $this.Text -ne $syncHash.Data.Room.DisplayName } )

# Id for new owner is entered, check if it exists, is active and have a mailaddress
$syncHash.tbRoomOwnerID.Add_TextChanged( {
	$syncHash.DC.btnRoomOwner[1] = $false
	if ( $this.Text.Length -eq 4 )
	{
		try
		{
			$tempOwner = Get-ADUser $this.Text -Properties EmailAddress -ErrorAction Stop
			if ( $tempOwner.EmailAddress -eq $null ) { $syncHash.DC.tblOwnerInfo[0] = $syncHash.Data.msgTable.ErrMsgNewOwnerNotAddr ; throw }
			elseif ( -not $tempOwner.Enabled ) { $syncHash.DC.tblOwnerInfo[0] = $syncHash.Data.msgTable.ErrMsgNewOwnerNotActive ; throw }
			elseif ( $this.Text -ne $syncHash.Data.RoomOwner.SamAccountName )
			{
				$syncHash.DC.btnRoomOwner[1] = $true
				$syncHash.TempOwner = $tempOwner
			}
		}
		catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
		{ $syncHash.DC.tblOwnerInfo[0] = $syncHash.Data.msgTable.ErrMsgNewOwnerNotInAd }
	}
} )

# Text for searching for other room, enable button to search
$syncHash.tbRoomSearch.Add_TextChanged( { $syncHash.DC.btnRoomSearch[1] = $this.Text.Length -gt 0 } )

# Window is rendered
$syncHash.Window.Add_ContentRendered( {
	$this.Top = 20
	$syncHash.dgAdmins.Columns[0].Header = $syncHash.Data.msgTable.ContentdgAdminsColName
	$syncHash.dgAdmins.Columns[1].Header = $syncHash.Data.msgTable.ContentdgAdminsColMail
	$syncHash.dgMembersAzure.Columns[0].Header = $syncHash.Data.msgTable.ContentdgMembersAzureColName
	$syncHash.dgMembersAzure.Columns[1].Header = $syncHash.Data.msgTable.ContentdgMembersAzureColMail
	$syncHash.dgMembersAzure.Columns[2].Header = $syncHash.Data.msgTable.ContentdgMembersAzureColSync
	$syncHash.dgMembersExchange.Columns[0].Header = $syncHash.Data.msgTable.ContentdgMembersExchangeColName
	$syncHash.dgMembersExchange.Columns[1].Header = $syncHash.Data.msgTable.ContentdgMembersExchangeColMail
	$syncHash.dgMembersExchange.Columns[2].Header = $syncHash.Data.msgTable.ContentdgMembersExchangeColSync
	$syncHash.dgMembersOtherRoom.Columns[0].Header = $syncHash.Data.msgTable.ContentdgMembersOtherRoomColName
	$syncHash.dgMembersOtherRoom.Columns[1].Header = $syncHash.Data.msgTable.ContentdgMembersOtherRoomColMail
	$syncHash.dgSuggestions.Columns[0].Header = $syncHash.Data.msgTable.ContentdgSuggestionsColName
	$syncHash.dgSuggestions.Columns[1].Header = $syncHash.Data.msgTable.ContentdgSuggestionsColMail
	$syncHash.tbCheckRoom.Focus()
} )

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash
