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

	if ( $WithPrefix ) { $t = $syncHash.Data.msgTable.StrConfirmPrefix }
	$t += "$Action. $( $syncHash.Data.msgTable.StrConfirmSuffix )"

	return ( ShowMessagebox -Text $t -Button "YesNo" -Icon "Warning" )
}

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
		if ( $syncHash.DC.lbListMembership[0].Count -gt 0 )
		{
			foreach ( $list in $syncHash.DC.lbListMembership[0] )
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

function SearchRoom
{
	param ( $searchWord )

	if ( $searchWord -match "^\S{1,}@\S{2,}\.\S{2,}$" ) { $t = "PrimarySmtpAddress" }
	else { $t = "DisplayName" }
	return Get-Mailbox -RecipientTypeDetails "RoomMailbox" -Filter "$t -eq '$searchWord'" -ErrorAction Stop
}

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
			Foreach-Object { $syncHash.DC.dgMembersAzure[0].Add( $_ ) }
		$syncHash.DC.btnCopyMembers[1] = $true
	}
	else
	{
		$syncHash.DC.dgMembersAzure[0].Add( $syncHash.Data.msgTable.StrNoMembersAzure )
	}

	if ( $syncHash.Data.UsersExchange.Count -gt 0 )
	{
		$syncHash.Data.UsersExchange | `
			Sort-Object Name | `
			Select-Object -Property Name, PrimarySmtpAddress, LegacyExchangeDN, Alias,`
				@{ Name = "Synched"; Expression = { $_.ExternalDirectoryObjectId -in $syncHash.Data.UsersAzure.ObjectId } } | `
			Foreach-Object { $syncHash.DC.dgMembersExchange[0].Add( $_ ) }
		$syncHash.DC.btnCopyMembers[1] = $true
	}
	else { $syncHash.DC.dgMembersExchange[0].Add( $syncHash.Data.msgTable.StrNoMembersExchange ) }

	if ( ( $syncHash.DC.dgMembersExchange[0].Synched -match "False" ).Count -gt 0 )
	{ $syncHash.DC.lblMemberInfo[0] = $syncHash.Data.msgTable.StrExchangeMembersNotSynched }

	if ( $syncHash.btnFetchAdmins.Tag ) { $syncHash.DC.btnCopyAll[1] = $true }
}

######################################
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

			Set-Mailbox -Identity $syncHash.Data.Room.PrimarySmtpAddress -WindowsEmailAddress $syncHash.DC.tbRoomAddress[0].Trim() -Name $syncHash.DC.tbRoomName[0].Trim() -DisplayName $syncHash.DC.tbRoomName[0].Trim() -EmailAddresses @{add="smtp:$( $syncHash.Data.Room.PrimarySmtpAddress )"}

			$azGroups = Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.Room.DisplayName )"
			foreach ( $group in $azGroups )
			{
				Set-AzureADGroup -ObjectId $group.ObjectId -DisplayName ( $group.DisplayName -replace $group.DisplayName , $syncHash.DC.tbRoomName[0].Trim() ) -Description "Now"
			}

			WriteLog -Text "$( $syncHash.Data.Room.DisplayName ) $( $syncHash.Data.msgTable.StrLogNewNameAddr ) > $( $syncHash.DC.tbRoomName[0] ) ($( $syncHash.DC.tbRoomAddress[0] ))"
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

function WriteOpLog
{
	param ( $Text, $Color = "Red" )

	$syncHash.spOpLog.Children.Insert( 0, ( [System.Windows.Controls.TextBlock]@{ Text = $Text; Foreground = $Color; Margin = 5 } ) )
}

###################### Script start
Add-Type -AssemblyName PresentationFramework
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -Argumentlist $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -Argumentlist $args[1]

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "btnAddAdmin" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddAdmin } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnAddMember" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddMember } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnAddRoomlist" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddRoomlist } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnBookingInfo" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnBookingInfo } ; @{ PropName = "IsEnabled" ; PropVal = $false } ; @{ PropName = "Tag" ; PropVal = [pscustomobject]@{ Pol = ""; Log = ""; OpLog = "" } } ) } )
[void]$controls.Add( @{ CName = "btnCheck" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCheck } ) } )
[void]$controls.Add( @{ CName = "btnConfirmMessage" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnConfirmMessage } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnConfirmMessageReset" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnConfirmMessageReset } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
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
[void]$controls.Add( @{ CName = "btnRoomAddress" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRoomAddress } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRoomName" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRoomName } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRoomOwner" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRoomOwner } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRoomSearch" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRoomSearch } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnSelectAll" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSelectAll } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnSyncToExchange" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSyncToExchange } ) } )
[void]$controls.Add( @{ CName = "dgAdmins" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]' ) } ) } )
[void]$controls.Add( @{ CName = "dgMembersAzure" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]' ) } ) } )
[void]$controls.Add( @{ CName = "dgMembersExchange" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]' ) } ) } )
[void]$controls.Add( @{ CName = "gAddAdmin" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgAddAdmin } ) } )
[void]$controls.Add( @{ CName = "gAddMembers" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgAddMembers } ) } )
[void]$controls.Add( @{ CName = "gMembersAzure" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgMembersAzure } ) } )
[void]$controls.Add( @{ CName = "gMembersExchange" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgMembersExchange } ) } )
[void]$controls.Add( @{ CName = "gRemoveSelectedAdmins" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgRemoveSelectedAdmins } ) } )
[void]$controls.Add( @{ CName = "lblAddAdmin" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblAddAdmin } ) } )
[void]$controls.Add( @{ CName = "lblAddMember" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblAddMember } ) } )
[void]$controls.Add( @{ CName = "lblCopyAll" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblCopyAll } ) } )
[void]$controls.Add( @{ CName = "lblCopyOp" ; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblCheckRoomTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblCheckRoomTitle } ) } )
[void]$controls.Add( @{ CName = "lblExport" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblExport } ) } )
[void]$controls.Add( @{ CName = "lbListMembership" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]' ) } ) } )
[void]$controls.Add( @{ CName = "lblLocation" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLocation } ) } )
[void]$controls.Add( @{ CName = "lblLogTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLogTitle } ) } )
[void]$controls.Add( @{ CName = "lblMemberInfo" ; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lbMembersOtherRoom" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]' ) } ) } )
[void]$controls.Add( @{ CName = "lblRemoveSelectedAdmins" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRemoveSelectedAdmins } ) } )
[void]$controls.Add( @{ CName = "lblRoomAddress" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomAddress } ) } )
[void]$controls.Add( @{ CName = "lblRoomOwner" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomOwner } ) } )
[void]$controls.Add( @{ CName = "lblRoomOwnerAddr" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomOwnerAddr } ) } )
[void]$controls.Add( @{ CName = "lblRoomOwnerID" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomOwnerID } ) } )
[void]$controls.Add( @{ CName = "lblRoomName" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomName } ) } )
[void]$controls.Add( @{ CName = "lblRoomSearchTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRoomSearchTitle } ) } )
[void]$controls.Add( @{ CName = "lblSyncToExchange" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSyncToExchange } ) } )
[void]$controls.Add( @{ CName = "lbRoomlists" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object 'System.Collections.ObjectModel.ObservableCollection[System.Object]' ) } ) } )
[void]$controls.Add( @{ CName = "rbBookingInfoNotPublic" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbBookingInfoNotPublic } ; @{ PropName = "IsChecked" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "rbBookingInfoPublic" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbBookingInfoPublic } ; @{ PropName = "IsChecked" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "tbAddAdmin" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbAddMember" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbCheckRoom" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbLocation" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbRoomAddress" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tblBookingInfo" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttblBookingInfo } ) } )
[void]$controls.Add( @{ CName = "tbConfirmMessage" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbRoomName" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbRoomOwnerAddr" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbRoomOwnerID" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tbRoomSearch" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "BorderThickness" ; PropVal = 1 } ; @{ PropName = "BorderBrush" ; PropVal = "LightGray" } ) } )
[void]$controls.Add( @{ CName = "tiAdmins" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiAdmins } ) } )
[void]$controls.Add( @{ CName = "tiConfirmMessage" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiConfirmMessage } ) } )
[void]$controls.Add( @{ CName = "tiInfo" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiInfo } ) } )
[void]$controls.Add( @{ CName = "tiListMembership" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiListMembership } ) } )
[void]$controls.Add( @{ CName = "tiCopyOtherRoom" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiCopyOtherRoom } ) } )
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
		Add-AzureADGroupMember -ObjectId $syncHash.Data.RoomAzGroupAdmins.ObjectId -RefObjectId $newAdmin.ObjectId
		Set-AzureADGroup -ObjectId $syncHash.Data.RoomAzGroupAdmins.ObjectId -Description "Now"
		WriteOpLog -Text $syncHash.Data.msgTable.StrOpNewAdmin -Color "Green"
		WriteLog -LogText "$( $syncHash.Data.Room.DisplayName ) $( $syncHash.Data.msgTable.LogAdmPerm ) $( $newAdmin.MailNickName )"
	}
} )
$syncHash.btnAddMember.Add_Click( {
	if ( $null -eq ( $newMember = Get-AzureADUser -Filter "proxyAddresses/any(y:startswith(y,'smtp:$( $syncHash.DC.tbAddAdmin[0] )'))" ) )
	{
		ShowMessagebox -Text "$( $syncHash.Data.msgTable.StrNoUser ) '$( $syncHash.DC.tbAddAdmin[0] )'" -Icon "Stop"
	}
	else
	{
		$roomPolicy = $syncHash.Data.RoomCalendarProcessing.BookInPolicy + ( Get-Mailbox -Identity $newMember.UserPrincipalName ).LegacyExchangeDN | Select-Object -Unique
		Set-CalendarProcessing -Identity $syncHash.Data.Room.DisplayName -AllBookInPolicy:$false -BookInPolicy $roomPolicy -ErrorAction SilentlyContinue
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

			$syncHash.ErrorRecord += @{ E = $e; P = ( WriteErrorlog -LogText $e ) }
			WriteOpLog -Text $e
		}
		$t = "$( $syncHash.Data.Room.DisplayName ) $( $syncHash.Data.msgTable.LogBookingPerm )"
		if ( $syncHash.ErrorRecord.Count -gt 0 )
		{
			$t += "`n`t$( $syncHash.ErrorRecord.P )"
		}
		WriteLog -LogText $t | Out-Null
		$syncHash.ErrorRecord.Clear()
		$syncHash.Data.RoomCalendarProcessing = Receive-Job $syncHash.Jobs.RoomCalendarProcessing
		UpdateDgMembers
	}
} )
$syncHash.btnAddRoomlist.Add_Click( {
	Add-DistributionGroupMember -Identity $syncHash.lbRoomlists.SelectedItem.PrimarySmtpAddress -Member $syncHash.Data.Room.PrimarySmtpAddress
	$syncHash.DC.lbListMembership[0].Add( $syncHash.lbRoomlists.SelectedItem.PrimarySmtpAddress )
	WriteLog -LogText "$( $syncHash.Data.Room.PrimarySmtpAddress ) > $( $syncHash.Data.msgTable.LogAddRoomList ) $( $syncHash.lbRoomlists.SelectedItem.PrimarySmtpAddress )"
} )
$syncHash.btnBookingInfo.Add_Click( {
	Set-MailboxFolderPermission -Identity $syncHash.Data.ExchangeCalendar -User Standard -AccessRights $this.Tag.Pol
	$this.Tag = ""
	$this.IsEnabled = $false
	WriteOpLog -Text ""
	WriteLog -LogText "$( $syncHash.Data.Room.PrimarySmtpAddress ) $( $this.Tag.Log ) "
} )
# Try getting the room by searching for the name given by the user
$syncHash.btnCheck.Add_Click( {
	try
	{
		$syncHash.Data.Room = SearchRoom -searchWord $syncHash.DC.tbCheckRoom[0]
		if ( $null -eq $syncHash.Data.Room )
		{
			WriteOpLog -Text "$( $syncHash.Data.msgTable.StrOpNoRoom ) '$( $syncHash.DC.tbCheckRoom[0] )'"
			throw $syncHash.Data.msgTable.ErrNotFound
		}
		else
		{
			$syncHash.Data.ExchangeCalendar = "$( $syncHash.Data.Room.DisplayName )`:\$( $syncHash.Data.msgTable.StrCalendarSuffix )"
			$syncHash.Jobs.FolderPermission = Get-MailboxFolderPermission -Identity $syncHash.Data.ExchangeCalendar -User Default -AsJob
			$syncHash.Data.RoomAzGroupAdmins = Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.Room.DisplayName )$( $syncHash.Data.msgTable.StrAzureADGrpNameAdmSuffix )"
			$syncHash.Data.RoomAzGroupBook = Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.Room.DisplayName )$( $syncHash.Data.msgTable.StrAzureADGrpNameBookSuffix )"
			$syncHash.Window.Resources['Exists'] = $true
		}
	}
	catch
	{
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.tbCheckRoom[1] = 2 } )
		$syncHash.ErrorRecord = $_
	}
} )
$syncHash.btnConfirmMessage.Add_Click( {
	Set-CalendarProcessing -Identity $syncHash.Data.Room.DisplayName -AdditionalResponse $syncHash.DC.tbConfirmMessage[0] -AddAdditionalResponse ( $syncHash.DC.tbConfirmMessage[0].Length -gt 0 )
	Set-Mailbox -Identity $syncHash.Data.Room.DisplayName -MailTip $syncHash.DC.tbConfirmMessage[0]
	WriteLog -LogText "$( $syncHash.Data.Room.PrimarySmtpAddress ) $( $syncHash.Data.msgTable.LogNewResponceMessage )`n`t$( $syncHash.DC.tbConfirmMessage[0] )"
} )
$syncHash.btnConfirmMessageReset.Add_Click( {
	$syncHash.DC.tbConfirmMessage[0] = $syncHash.Data.RoomCalendarProcessing.AdditionalResponse
	$syncHash.tbConfirmMessage.Focus()
} )
# Copy the list of admins to clipboard
$syncHash.btnCopyAdmins.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$OFS = "`n"
	"$( $syncHash.Data.Room.DisplayName)`n`n*******************************`n$( $syncHash.Data.msgTable.LogAdmPerm )`n*******************************`n$( $syncHash.Data.AdminsAzure | Sort-Object DisplayName | Foreach-Object { "$( $_.DisplayName ) <$( $_.UserPrincipalName )>" } )" | Clip
	ShowSplash -Text $syncHash.Data.msgTable.StrAdminsCopied
} )
# Copy the list of users to clipboard
$syncHash.btnCopyMembers.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$OFS = "`n"
	"$( $syncHash.Data.Room.DisplayName)`n`n*******************************`n$( $syncHash.Data.msgTable.LogBookingPerm )`n*******************************`n$( $syncHash.Data.UsersAzure | Sort-Object DisplayName | Foreach-Object { "$( $_.DisplayName ) <$( $_.UserPrincipalName )>" } )" | Clip
	ShowSplash -Text $syncHash.Data.msgTable.StrUsersCopied

} )
# Copy permissions from anoter room to the currently selected room
$syncHash.btnCopyOtherRoom.Add_Click( {
	Set-CalendarProcessing -Identity $syncHash.Data.Room.DisplayName -BookInPolicy ( $syncHash.lbMembersOtherRoom.SelectedItems + $syncHash.Data.RoomCalendarProcessing.BookInPolicy )

	foreach ( $user in ( $syncHash.lbMembersOtherRoom.SelectedItems | Where-Object { $_.RecipientTypeDetails -eq "UserMailbox" } ) )
	{
		Add-AzureADGroupMember -ObjectId $syncHash.Data.RoomAzGroupBook -RefObjectId $_.MicrosoftOnlineServicesID
		Add-MailboxFolderPermission -Identity $syncHash.Data.ExchangeCalendar -AccessRights LimitedDetails -User $_.MicrosoftOnlineServicesID -Confirm:$false
	}
	$syncHash.DC.lblCopyOp[0] += "`n$( $syncHash.Data.msgTable.StrOpCopyOtherRoomDone )"
	WriteLog -LogText "$( $syncHash.Data.Room.PrimarySmtpAddress ) $( $syncHash.Data.msgTable.LogCopyOtherRoom ) $( $syncHash.DC.tbRoomSearch[0] )"
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
	}
} )
# Get list of users with admin permissions from Azure
$syncHash.btnFetchAdmins.Add_Click( {
	$this.Tag = $true
	$syncHash.DC.dgAdmins[0].Clear()
	$syncHash.Data.AdminsAzure = Get-AzureADGroupMember -ObjectId $syncHash.Data.RoomAzGroupAdmins.ObjectId | Where-Object { $_.UserType -eq "Member" }

	if ( $syncHash.Data.AdminsAzure.Count -gt 0 )
	{
		$syncHash.DC.dgAdmins[0] = $syncHash.Data.AdminsAzure | Sort-Object DisplayName
		$syncHash.DC.btnCopyAdmins[1] = $true
	}
	else { $syncHash.DC.dgAdmins[0].Add( $syncHash.Data.msgTable.StrNoAdmins ) }

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
	if ( $syncHash.Data.RoomList.Count -eq 0 )
	{
		$syncHash.Data.RoomLists = Get-DistributionGroup -Filter { RecipientTypeDetails -eq "RoomList" }
		$syncHash.DC.lbRoomlists[0] = $syncHash.Data.RoomLists | Sort-Object DisplayName
	}

	$syncHash.DC.lbListMembership[0] = @( $syncHash.Data.RoomLists | Foreach-Object { if ( ( Get-DistributionGroupMember -Identity $_.PrimarySmtpAddress ).Name -match $syncHash.Data.Room.Name ) { $_ } } )
	$syncHash.DC.Window[0] = ""
} )
# Set a new location
$syncHash.btnLocation.Add_Click( {
	Set-Mailbox -Identity $syncHash.Data.Room.PrimarySmtpAddress -Office $syncHash.DC.tbLocation[0]
	$syncHash.Data.Room = Get-Mailbox -Identity $syncHash.Data.Room.PrimarySmtpAddress
	WriteLog -LogText "$( $syncHash.Data.Room.PrimarySmtpAddress ) $( $syncHash.Data.msgTable.LogNewLoc ) $( $syncHash.DC.tbLocation[0] )"
} )
# Remove a selected user from the rooms Azure-group
$syncHash.btnRemoveMembersAzure.Add_Click( {
	$syncHash.DC.dgMembersAzure.SelectedItems | Foreach-Object {
		Remove-AzureADGroupMember -ObjectId $syncHash.Data.RoomAzGroupBook.ObjectId -MemberId $_.ObjectId
		WriteOpLog -Text "$( $_.DisplayName ) $( $syncHash.Data.msgTable.StrOpRemoveUserAz )" -Color "Green"
	}
	Set-AzureADGroup -ObjectId $syncHash.Data.RoomAzGroupBook.ObjectId -Description "Now"
	$ofs=", "
	WriteLog -LogText "$( $syncHash.Data.Room.DisplayName ) $( $syncHash.Data.msgTable.LogRemUsersAz ) > $( [string]$syncHash.dgMembersAzure.SelectedItems.MailNickName )"
	UpdateDgMembers
} )
# Remove a selected user from the room in Exchange
$syncHash.btnRemoveMembersExchange.Add_Click( {
	$tempBookInPolicy = $syncHash.dgMembersExchange.Items | Where-Object { $_ -notin $syncHash.dgMembersExchange.SelectedItems } | Select-Object LegacyExchangeDN
	Set-CalendarProcessing -Identity $syncHash.Data.Room.DisplayName -AllBookInPolicy:$false -BookInPolicy $tempBookInPolicy -ErrorAction SilentlyContinue
	$syncHash.Jobs.RoomCalendarProcessing = Get-CalendarProcessing -Identity $syncHash.Data.Room.DisplayName -AsJob
	foreach ( $user in $syncHash.dgMembersExchange.SelectedItems )
	{
		try
		{
			Remove-MailboxFolderPermission -Identity $syncHash.Data.ExchangeCalendar -Confirm:$false -User $user.PrimarySmtpAddress -ErrorAction Stop
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
			else { $e = "$( $syncHash.Data.msgTable.ErrGen )`n`n$( $_.CategoryInfo.Reason )`n`n$( $_.Exception )" }

			$syncHash.ErrorRecord += @{ E = $e; P = ( WriteErrorlog -LogText $e ) }
		}
		WriteOpLog $e
		if ( $q ) { return }
	}
	$OFS = ", "
	$t = "$( $syncHash.Data.Room.DisplayName ) $( $syncHash.Data.msgTable.LogRemUsersEx ) $( [string] $syncHash.dgMembersExchange.SelectedItems.Alias )"
	if ( $syncHash.ErrorRecord.Count -gt 0 )
	{
		$OFS = "`n`t"
		$t += "`n`t$( $syncHash.ErrorRecord.P )"
	}
	WriteLog -LogText $t | Out-Null
	$syncHash.Data.RoomCalendarProcessing = Receive-Job $syncHash.Jobs.RoomCalendarProcessing
	$syncHash.ErrorRecord.Clear()
	UpdateDgMembers
} )
# Remove the room from the selected roomlist
$syncHash.btnRemoveRoomlist.Add_Click( {
	Remove-DistributionGroupMember -Identity $syncHash.lbListMembership.SelectedItem.PrimarySmtpAddress -Member $syncHash.Data.Room.PrimarySmtpAddress
	$syncHash.DC.lbListMembership[0] = $syncHash.DC.lbListMembership[0] | Where-Object { $_.PrimarySmtpAddress -ne $syncHash.lbListMembership.SelectedItem.PrimarySmtpAddress }
	WriteLog -LogText "$( $syncHash.Room.PrimarySmtpAddress ) $( $syncHash.Data.msgTable.LogRemRoomList ) $( $syncHash.lbListMembership.SelectedItem.PrimarySmtpAddress )"
} )
# Remove the selected admin from the rooms Azure-group
$syncHash.btnRemoveSelectedAdmins.Add_Click( {
	$syncHash.DC.dgAdmins.SelectedItems | Foreach-Object {
		Remove-AzureADGroupMember -ObjectId $syncHash.Data.RoomAzGroupAdmins.ObjectId -MemberId $_.ObjectId
		WriteOpLog -Text "$( $_.DisplayName ) $( $syncHash.Data.msgTable.StrOpRemoveAdmAz )" -Color "Green"
	}
	Set-AzureADGroup -ObjectId $syncHash.Data.RoomAzGroupAdmins.ObjectId -Description "Now"
	$ofs=", "
	WriteLog -LogText "$( $syncHash.Data.Room.DisplayName ) $( $syncHash.Data.msgTable.LogRemUsersAz ) > $( [string]$syncHash.dgAdmins.SelectedItems.MailNickName )"
} )
# Reset the GUI
$syncHash.btnReset.Add_Click( {
	$syncHash.Window.Resources['Exists'] = $false
	$syncHash.DC.tbCheckRoom[0] = ""
	$syncHash.tbCheckRoom.Focus()
} )
$syncHash.btnRoomAddress.Add_Click( { UpdateNameAddress -Question $syncHash.Data.msgTable.StrConfirmNewMail } )
$syncHash.btnRoomName.Add_Click( { UpdateNameAddress -Question $syncHash.Data.msgTable.StrConfirmNewName } )
$syncHash.btnRoomOwner.Add_Click( {
	try
	{
		$tempNewOwner = Get-ADUser -Identity $syncHash.DC.tbRoomOwnerID[0] -Properties EmailAddress -ErrorAction Stop
		if ( ( Confirmations -Action $syncHash.Data.msgTable.StrConfirmNewOwner -WithPrefix ) -eq "Yes" )
		{
			Set-Mailbox -Identity $syncHash.Data.Room.ExchangeObjectId -CustomAttribute10 "$( $syncHash.Data.msgTable.StrOwnerAttrPrefix ) $( $tempNewOwner.EmailAddress )"
			$syncHash.Data.Room = Get-Mailbox -Identity $syncHash.DC.tbRoomAddress[0] -ErrorAction Stop
			$registeredOwner = Get-EXOMailbox ( $syncHash.Data.Room.CustomAttribute10 -replace $syncHash.Data.msgTable.StrOwnerAttrPrefix ).Trim()
			$syncHash.Data.RoomOwner = Get-ADUser -Identity $registeredOwner.Alias -Properties EmailAddress -ErrorAction Stop
			$syncHash.DC.tbSMOwnerAddr[0] = $syncHash.Data.SharedMailboxOwner
			WriteLog -Text "$( $syncHash.Data.SharedMailbox.DisplayName ) $( $syncHash.Data.msgTable.StrLogNewOwner ) $( $registeredOwner.Alias ) > $( $syncHash.Data.SharedMailboxOwner )"
			WriteOpLog -Text $syncHash.Data.msgTable.StrOpNewOwnerDone -Color "Green"
		}
	}
	catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
	{
		WriteOpLog -Text $syncHash.Data.msgTable.StrNoAdAccountId
		$syncHash.DC.tbRoomOwnerID[1] = 2
	}
} )
$syncHash.btnRoomSearch.Add_Click( {
	$syncHash.DC.tbRoomSearch[1] = 1
	$syncHash.DC.tbRoomSearch[2] = "LightGray"
	if ( $null -eq ( $syncHash.Data.SourceRoom = SearchRoom -searchWord $syncHash.DC.tbRoomSearch[0] ) )
	{
		$syncHash.DC.tbRoomSearch[1] = 2
		$syncHash.DC.tbRoomSearch[2] = "Red"
		$syncHash.DC.lblCopyOp[0] = $syncHash.Data.msgTable.ErrNotFound
	}
	else
	{
		$syncHash.DC.lbMembersOtherRoom[0] = ( $syncHash.Data.SourceRoom | Get-CalendarProcessing ).BookInPolicy | Get-Mailbox | Sort-Object Name
	}
} )
$syncHash.btnSelectAll.Add_Click( { $syncHash.lbMembersOtherRoom.SelectAll() } )
$syncHash.btnSyncToExchange.Add_Click( {
	$usersAzure = Get-AzureADGroupMember -ObjectId $syncHash.Data.RoomAzGroupBook.ObjectId
	$roomPolicy = $syncHash.Data.RoomCalendarProcessing.BookInPolicy
	$q = $false

	foreach ( $user in $usersAzure )
	{
		$roomPolicy += ( Get-Mailbox -Identity $user.UserPrincipalName ).LegacyExchangeDN
	}
	$roomPolicy = $roomPolicy | Select-Object -Unique
	Set-CalendarProcessing -Identity $syncHash.DC.tbRoomName[0] -AllBookInPolicy:$false -BookInPolicy $roomPolicy -ErrorAction SilentlyContinue

	foreach ( $user in $usersAzure )
	{
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
			else { $e = "$( $syncHash.Data.msgTable.ErrGen )`n`n$( $_.CategoryInfo.Reason )`n`n$( $_.Exception )" }

			$syncHash.ErrorRecord += @{ E = $e; P = ( WriteErrorlog -LogText $e ) }
		}
		WriteOpLog $e
		if ( $q ) { return }
	}

	$t = "$( $syncHash.Data.Room.DisplayName ) $( $syncHash.Data.msgTable.StrLogSync )"
	if ( $syncHash.ErrorRecord.Count -gt 0 )
	{
		$OFS = "`n`t"
		$t += "`n`t$( $syncHash.ErrorRecord.P )"
	}
	WriteLog -LogText $t | Out-Null
	$syncHash.ErrorRecord.Clear()
	WriteOpLog -Text $syncHash.Data.msgTable.StrOpSyncDone -Color "Green"
} )
$syncHash.dgAdmins.Add_SelectionChanged( { $syncHash.DC.btnRemoveSelectedAdmins[1] = $this.SelectedItems.Count -gt 0 } )
$syncHash.dgMembersAzure.Add_SelectionChanged( { $syncHash.DC.btnRemoveMembersAzure[1] = $this.SelectedItems.Count -gt 0 } )
$syncHash.dgMembersExchange.Add_SelectionChanged( { $syncHash.DC.btnRemoveMembersExchange[1] = $this.SelectedItems.Count -gt 0 } )
$syncHash.gAdmins.Add_IsEnabledChanged( {
	if ( $this.IsEnabled ) {}
	else
	{
		$syncHash.DC.tbAddAdmin[0] = ""
		$syncHash.DC.btnCopyAdmins[1] = $syncHash.DC.btnAddAdmin[1] = $syncHash.DC.btnRemoveSelectedAdmins[1] = $false
		$syncHash.DC.dgAdmins[0].Clear()
		$syncHash.Data.AdminsAzure.Clear()
	}
} )
$syncHash.gConfirmMessage.Add_IsEnabledChanged( {
	if ( $this.IsEnabled ) {}
	else
	{
		$syncHash.DC.btnConfirmMessage[1] = $syncHash.DC.btnConfirmMessageReset[1] = $false
		$syncHash.DC.tbConfirmMessage[0] = ""
	}
} )
$syncHash.gCopyOtherRoom.Add_IsEnabledChanged( {
	# TODO
	if ( $this.IsEnabled ) {}
	else
	{
		$syncHash.DC.tbRoomSearch[0] = $syncHash.DC.lblCopyOp[0] = ""
		$syncHash.DC.btnRoomSearch[1] = $syncHash.DC.btnCopyOtherRoom[1] = $false
		$syncHash.DC.lbMembersOtherRoom[0].Clear()
	}
} )
$syncHash.gInfo.Add_IsEnabledChanged( {
	if ( $this.IsEnabled )
	{
		# Get Name
		$syncHash.DC.tbRoomName[0] = $syncHash.Data.Room.DisplayName
		# Get Address
		$syncHash.DC.tbRoomAddress[0] = $syncHash.Data.Room.PrimarySmtpAddress
		# Get Owner
		$addr = ( $syncHash.Data.Room.CustomAttribute10 -replace $syncHash.Data.msgTable.StrOwnerAttrPrefix ).Trim()
		if ( $addr -eq "" )
		{
			WriteOpLog -Text $syncHash.Data.msgTable.StrNoOwner
		}
		else
		{
			$syncHash.DC.tbRoomOwnerAddr[0] = $addr.Trim()
			try
			{
				Get-EXOMailbox -Identity $addr -ErrorAction Stop
			}
			catch [Microsoft.Exchange.Management.RestApiClient.RestClientException]
			{
				WriteOpLog -Text $syncHash.Data.msgTable.StrNoMailAccountOwner
			}

			try
			{
				if ( ( $syncHash.Data.RoomOwner = Get-ADUser -LDAPFilter "(proxyaddresses=*smtp:$addr*)" -ErrorAction Stop ) -ne $null )
				{ $syncHash.DC.tbRoomOwnerID[0] = $syncHash.Data.RoomOwner.SamAccountName.ToUpper() }
				else
				{
					WriteOpLog -Text $syncHash.Data.msgTable.StrNoAdAccountOwner
				}
			}
			catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
			{
				WriteOpLog -Text $syncHash.Data.msgTable.StrNoAdAccountOwner
			}
		}
		Wait-Job $syncHash.Jobs.FolderPermission
		$syncHash.Data.FolderPermission = Receive-Job $syncHash.Jobs.FolderPermission
		# Get location
		$syncHash.DC.tbLocation[0] = $syncHash.Data.Room.Office
		# Get Bookinginfo public/nonpublic
		if ( $syncHash.Data.FolderPermission.AccessRights -match "LimitedDetails" ) { $syncHash.DC.rbBookingInfoPublic[1] = $true }
		else { $syncHash.DC.rbBookingInfoNotPublic[1] = $true }

		Remove-Job $syncHash.Jobs.FolderPermission
	}
	else
	{
		$syncHash.Data.ExchangeCalendar = ""
		$syncHash.Data.FolderPermission = $syncHash.Data.Room = $syncHash.Data.RoomOwner = $null
		$syncHash.DC.tbRoomName[0] = $syncHash.DC.tbRoomAddress[0] = $syncHash.DC.tbRoomOwnerAddr[0] = $syncHash.DC.tbRoomOwnerID[0] = ""
		$syncHash.DC.tbRoomName[1] = $syncHash.DC.tbRoomAddress[1] = $syncHash.DC.tbRoomOwnerAddr[1] = $syncHash.DC.tbRoomOwnerID[1] = 1
		$syncHash.DC.tbRoomName[2] = $syncHash.DC.tbRoomAddress[2] = $syncHash.DC.tbRoomOwnerAddr[2] = $syncHash.DC.tbRoomOwnerID[2] = "LightGray"
		$syncHash.DC.btnRoomName[1] = $syncHash.DC.btnRoomAddress[1] = $syncHash.DC.btnRoomOwner[1] = $syncHash.DC.btnRoomName[1] = $syncHash.DC.btnCopyAll[1] = $false
		$syncHash.spOpLog.Children.Clear()
	}
	$syncHash.DC.Window[0] = ""
} )
$syncHash.gListMembership.Add_IsEnabledChanged( {
	if ( $this.IsEnabled ) {}
	else
	{
		$syncHash.DC.btnRemoveRoomlist[1] = $syncHash.DC.btnAddRoomlist[1] = $false
		$syncHash.DC.lbListMembership[0].Clear()
	}
} )
$syncHash.gMembers.Add_IsEnabledChanged( {
	if ( $this.IsEnabled ) {}
	else
	{
		$syncHash.DC.btnCopyMembers[1] = $syncHash.DC.btnAddMember[1] = $syncHash.DC.btnRemoveMembersAzure[1] = $syncHash.DC.btnRemoveMembersExchange[1] = $false
		$syncHash.DC.tbAddMember[0] = $syncHash.DC.lblMemberInfo[0] = ""
		$syncHash.DC.dgMembersAzure[0].Clear()
		$syncHash.DC.dgMembersExchange[0].Clear()
		$syncHash.Data.UsersAzure = $syncHash.Data.UsersExchange = $null
	}
} )
$syncHash.lbListMembership.Add_SelectionChanged( { $syncHash.DC.btnRemoveRoomlist[1] = $this.SelectedItems.Count -gt 0 } )
$syncHash.lbMembersOtherRoom.Add_SelectionChanged( { $syncHash.DC.btnCopyOtherRoom[1] = $this.SelectedItems.Count -gt 0 } )
$syncHash.lbRoomlists.Add_SelectionChanged( { $syncHash.DC.btnAddRoomlist[1] = $this.SelectedItems.Count -gt 0 } )
$syncHash.rbBookingInfoPublic.Add_Checked( {
	$syncHash.DC.btnBookingInfo[2].Pol = "LimitedDetails"
	$syncHash.DC.btnBookingInfo[2].Log = $syncHash.Data.msgTable.LogBookInfoPub
	$syncHash.DC.btnBookingInfo[2].OpLog = $syncHash.Data.msgTable.StrOpBookInfoPub
	$syncHash.DC.btnBookingInfo[1] = $syncHash.DC.btnBookingInfo[1].Pol -ne $syncHash.Data.FolderPermission.BookInPolicy
} )
$syncHash.rbBookingInfoNotPublic.Add_Checked( {
	$syncHash.DC.btnBookingInfo[2].Pol = "AvailabilityOnly"
	$syncHash.DC.btnBookingInfo[2].Log = $syncHash.Data.msgTable.LogBookInfoNonPub
	$syncHash.DC.btnBookingInfo[2].OpLog = $syncHash.Data.msgTable.StrOpBookInfoNonPub
	$syncHash.DC.btnBookingInfo[1] = $syncHash.DC.btnBookingInfo[1].Pol -ne $syncHash.Data.FolderPermission.BookInPolicy
} )
$syncHash.tbConfirmMessage.Add_TextChanged( { $syncHash.DC.btnConfirmMessage[1] = $syncHash.DC.btnConfirmMessageReset[1] = $this.Text -ne $syncHash.Data.RoomCalendarProcessing.AdditionalResponse } )
$syncHash.tbLocation.Add_TextChanged( { $syncHash.DC.btnLocation[1] = $this.Text -ne $syncHash.Data.Room.Office } )
$syncHash.tbRoomAddress.Add_TextChanged( { $syncHash.DC.btnRoomAddress[1] = $this.Text -ne $syncHash.Data.Room.PrimarySmtpAddress } )
$syncHash.tbRoomName.Add_TextChanged( { $syncHash.DC.btnRoomName[1] = $this.Text -ne $syncHash.Data.Room.DisplayName } )
$syncHash.tbRoomOwnerID.Add_TextChanged( { $syncHash.DC.btnRoomOwner[1] = ( $this.Text.Length -eq 4 ) -and ( $this.Text -ne $syncHash.Data.RoomOwner.SamAccountName ) } )
$syncHash.tbRoomSearch.Add_TextChanged( { $syncHash.DC.btnRoomSearch[1] = $this.Text.Length -gt 0 } )
$syncHash.Window.Add_ContentRendered( {
	$this.Top = 20
	$syncHash.dgMembersAzure.Columns[0].Header = $syncHash.Data.msgTable.ContentdgAzColName
	$syncHash.dgMembersAzure.Columns[1].Header = $syncHash.Data.msgTable.ContentdgAzColMail
	$syncHash.dgMembersAzure.Columns[2].Header = $syncHash.Data.msgTable.ContentdgAzColSync
	$syncHash.dgMembersExchange.Columns[0].Header = $syncHash.Data.msgTable.ContentdgExColName
	$syncHash.dgMembersExchange.Columns[1].Header = $syncHash.Data.msgTable.ContentdgExColMail
	$syncHash.dgMembersExchange.Columns[2].Header = $syncHash.Data.msgTable.ContentdgExColSync
	$syncHash.dgAdmins.Columns[0].Header = $syncHash.Data.msgTable.ContentdgAdmColName
	$syncHash.dgAdmins.Columns[1].Header = $syncHash.Data.msgTable.ContentdgAdmColMail
	$syncHash.tbCheckRoom.Focus()
} )

[void] $syncHash.Window.ShowDialog()
$global:syncHash = $syncHash
