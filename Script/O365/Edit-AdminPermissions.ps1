<#
.Synopsis Search for, and handle, accounts you have Full-permission for
.Description Handle the accounts that you have been given Full-permission for in Exchange. The script can also search through all the objects to find any account that is not listed
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "btnAddAdminPermission" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddAdminPermission } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRemoveAdminPermission" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveAdminPermission } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnSearchAdminPermission" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSearchAdminPermission } ) } )
[void]$controls.Add( @{ CName = "lbAdminPermissions" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void]$controls.Add( @{ CName = "tbAddAdminPermission" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = "" } ) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.msgTable = $msgTable

$FileSystemWatcher = New-Object System.IO.FileSystemWatcher
$FileSystemWatcher.Path  = $env:USERPROFILE
$FileSystemWatcher.EnableRaisingEvents = $true
$FileSystemWatcher.Filter = "O365Admin.txt"

$Action = {
	$event.MessageData.Window.Dispatcher.Invoke( [action] {
		$event.MessageData.DC.lbAdminPermissions[0].Clear()
		$event.MessageData.PermissionList | Foreach-Object { $event.MessageData.DC.lbAdminPermissions[0].Add( $_ ) }
		$event.MessageData.lbAdminPermissions.Items.Refresh()
		$event.MessageData.lbAdminPermissions.UpdateLayout()
	} )
}
Register-ObjectEvent -InputObject $FileSystemWatcher -EventName Changed -Action $Action -SourceIdentifier FSChange -MessageData $syncHash | Out-Null
Register-ObjectEvent -InputObject $FileSystemWatcher -EventName Created -Action $Action -SourceIdentifier FSCreate -MessageData $syncHash | Out-Null
Register-ObjectEvent -InputObject $FileSystemWatcher -EventName Deleted -Action $Action -SourceIdentifier FSDelete -MessageData $syncHash | Out-Null

$syncHash.AdmAccount = ( Get-AzureADCurrentSessionInfo ).account.id

$syncHash.btnAddAdminPermission.Add_Click( {
	try
	{
		$a = Get-EXORecipient -Identity $syncHash.DC.tbAddAdminPermission[0] -ErrorAction Stop
		if ( $a.RecipientTypeDetails -in ( "EquipmentMailbox","RoomMailbox","SharedMailbox","UserMailbox" ) )
		{
			try
			{
				Add-MailboxPermission -Identity $a.PrimarySmtpAddress -User $syncHash.AdmAccount -AccessRights FullAccess
				Add-Content -Value $a.PrimarySmtpAddress -Path "$( $env:USERPROFILE )\O365Admin.txt"
				$syncHash.PermissionList.Add( $a.PrimarySmtpAddress )
			}
			catch { $eh = WriteErrorlogTest -LogText $error[0].Exception.Message -UserInput $syncHash.DC.tbAddAdminPermission[0] -Severity "OtherFail" }
		}
		else { throw }
	}
	catch
	{
		ShowMessageBox -Text $syncHash.Data.msgTable.StrNoRecipientFound
		$eh = WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogNotMailbox -UserInput $syncHash.DC.tbAddAdminPermission[0] -Severity "OtherFail"
	}
	WriteLogTest -Text $syncHash.Data.msgTable.LogNewAdmPerm -UserInput $syncHash.DC.tbAddAdminPermission[0] -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )
$syncHash.btnRemoveAdminPermission.Add_Click( {
	if ( ( ShowMessageBox -Text $syncHash.Data.msgTable.StrRemoveContinueQuestion -Button "YesNo" -Icon "Warning" ) -eq "Yes" )
	{
		for ( $i = 0; $i -lt $syncHash.lbAdminPermissions.SelectedItems.Count; $i++ )
		{
			$syncHash.DC.Window[0] = "$( $syncHash.Data.msgTable.StrRemovingPerm ) $( $i + 1 )/$( $syncHash.lbAdminPermissions.SelectedItems.Count ) ($( $syncHash.lbAdminPermissions.SelectedItems[$i] ))"
			try
			{
				Remove-MailboxPermission -Identity $syncHash.lbAdminPermissions.SelectedItems[$i] -User $syncHash.AdmAccount -AccessRights FullAccess -Confirm:$false -ErrorAction Stop
				$syncHash.PermissionList.Remove( $syncHash.lbAdminPermissions.SelectedItems[$i] )
			}
			catch
			{
				$eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogRemovePerm )`n$_" -UserInput $syncHash.lbAdminPermissions.SelectedItems[$i] -Severity "OtherFail"
			}
		}
		$syncHash.DC.Window[0] = ""
		Set-Content -Value $syncHash.PermissionList -Path "$( $env:UserProfile )\O365Admin.txt" -Force
		WriteLogTest -Text $syncHash.Data.msgTable.LogRemovePerm -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
	}
} )
$syncHash.btnSearchAdminPermission.Add_Click( {
	if ( ( ShowMessageBox -Text $syncHash.Data.msgTable.StrSearchContinueQuestion -Icon "Warning" -Button "YesNo" ) -eq "Yes" )
	{
		$tot = New-Object System.Collections.ArrayList
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrWaitCollecting
		$allmailboxes = Get-EXORecipient -ResultSize Unlimited -RecipientTypeDetails EquipmentMailbox
		for ( $i = 0; $i -lt $allmailboxes.Count; $i++ )
		{
			if ( ( Get-MailboxPermission -Identity $allmailboxes[$i].PrimarySmtpAddress ).User -match $syncHash.AdmAccount )
			{
				$tot.Add( $allmailboxes[$i].PrimarySmtpAddress )
			}
			$syncHash.DC.Window[0] = "$( $syncHash.Data.msgTable.StrSearching ) $( [Math]::Round( ( $i / $allmailboxes.Count ) * 100 , 2 ) ) %"
		}

		$syncHash.PermissionList = $tot
		Set-Content -Value $syncHash.PermissionList -Path "$( $env:UserProfile )\O365Admin.txt" -Force
		TextToSpeech -Text $syncHash.Data.msgTable.StrSearchFinished
		WriteLogTest -Text $syncHash.Data.msgTable.LogSearchedAdmin -Success $true | Out-Null
		$syncHash.DC.Window[0] = ""
	}
} )
$syncHash.lbAdminPermissions.Add_SelectionChanged( {
	if ( $syncHash.DC.lbAdminPermissions[1].Count -gt 0 ) { $syncHash.DC.btnRemoveAdminPermission[1] = $true }
	else { $syncHash.DC.btnRemoveAdminPermission[1] = $true }
} )
$syncHash.tbAddAdminPermission.Add_TextChanged( {
	if ( $this.Text.Length -gt 0 ) { $syncHash.DC.btnAddAdminPermission[1] = $true }
	else { $syncHash.DC.btnAddAdminPermission[1] = $false }
} )
$syncHash.Window.Add_Closed( {
	$FileSystemWatcher.EnableRaisingEvents = $false
	$FileSystemWatcher.Dispose()
	Unregister-Event FSChange
	Unregister-Event FSCreate
	Unregister-Event FSDelete
	Get-Job | Remove-Job -ErrorAction SilentlyContinue
} )
$syncHash.Window.Add_ContentRendered( { $this.Activate() ; $this.Top = 20 } )
$syncHash.Window.Add_Loaded( {
	[System.Collections.ArrayList] $syncHash.PermissionList = Get-Content "$( $env:UserProfile )\O365Admin.txt"
	$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.PermissionList | Foreach-Object { $syncHash.DC.lbAdminPermissions[0].Add( $_ ) } } )
} )

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash
