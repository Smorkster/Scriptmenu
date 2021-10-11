<#
.Synopsis Gets distribitiongroup from Exchange
.Description Get a distributiongroup from Exchange. In the GUI are functions for administering the group. Change name and owner. Enabled/disable external senders to use the group. Add/remove members.
.State Prod
.Author Smorkster (smorkster)
#>

######################################################################
# A distributiongroup was selected, enter its info and get its members
# Or the group is no longer needed, clear info and reset controls
function CurrentDistUpdated
{
	param ( [switch]$Clear )

	if ( $Clear )
	{
		$syncHash.DC.tbDistName[0] = ""
		$syncHash.DC.tbDistOwner[0] = ""
		$syncHash.DC.tbDistAddress[0] = ""
		$syncHash.DC.rbDistOpenForExternalNo[1] = $false
		$syncHash.DC.rbDistOpenForExternalYes[1] = $false
		$syncHash.DC.dgMembers[0].Clear()
	}
	else
	{
		$syncHash.DC.bordDist[1] = 0
		$syncHash.Window.Resources['Exists'] = $true

		$syncHash.DC.tbDistName[0] = $syncHash.Data.DistGroup.DisplayName
		$syncHash.DC.tbDistOwner[0] = $syncHash.Data.DistGroup.ManagedBy
		$syncHash.DC.tbDistAddress[0] = $syncHash.Data.DistGroup.PrimarySmtpAddress
		if ( $syncHash.Data.DistGroup.RequireSenderAuthenticationEnabled ) { $syncHash.DC.rbDistOpenForExternalNo[1] = $true }
		else { $syncHash.DC.rbDistOpenForExternalYes[1] = $true }
		UpdateDataGrid
	}
}

########################################################
# Retrieve the distributiongroup and update the datagrid
function UpdateDataGrid
{
	$syncHash.Data.Members = Get-DistributionGroupMember -Identity $syncHash.Data.DistGroup.PrimarySmtpAddress
	$syncHash.dgMembers.Items.Clear()
	if ( $syncHash.Data.Members.Count -gt 0 )
	{
		$syncHash.Data.Members | Sort-Object Name | Foreach-Object { $syncHash.dgMembers.AddChild( [pscustomobject]@{ "Name" = $_.Name ; "Mail" = $_.PrimarySmtpAddress } ) }
		$syncHash.btnCopyMembers.IsEnabled = $true
	}
	else { $syncHash.btnCopyMembers.IsEnabled = $false }
}

#######################################################
# Update the name and address for the distributiongroup
function UpdateNameAddress
{
	$update = $false
	if ( $syncHash.tbDistAddress.Text -ne $syncHash.Data.DistGroup.WindowsEmailAddress -and `
		$syncHash.tbDistName.Text -ne $syncHash.Data.DistGroup.DisplayName )
	{
		$update = $true
	}
	else
	{
		if ( [System.Windows.MessageBox]::Show( $syncHash.Data.msgTable.StrNameOrAddrNotUpd, "", [System.Windows.MessageBoxButton]::YesNo ) -eq "Yes" ) { $update = $true }
		else { $update = $false }
	}

	if ( $update )
	{
		$logText = "$( $syncHash.Data.msgTable.LogNewNameAddress )`nPrimarySmtpAddress: $( $syncHash.Data.DistGroup.PrimarySmtpAddress )`nWindowsEmailAddress: $( $syncHash.DC.tbDistAddress[0].Trim() )`nDisplayName: $( $syncHash.DC.tbDistName[0].Trim() )"
		$userInput = $syncHash.Data.DistGroup.PrimarySmtpAddress
		try { Set-DistributionGroup -Identity $syncHash.Data.DistGroup.PrimarySmtpAddress -WindowsEmailAddress $syncHash.DC.tbDistAddress[0].Trim() -DisplayName $syncHash.DC.tbDistName[0].Trim() -ErrorAction Stop }
		catch { $eh = WriteErrorlogTest -LogText $_ -UserInput $userInput -Severity "OtherFail" }

		$Groups = Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureGroupPrefix )$( $syncHash.Data.DistGroup.DisplayName )"
		$logText += "`n`n$( $syncHash.Data.msgTable.LogNewNameAddressAzGrps )`n"
		foreach ( $group in $Groups )
		{
			$NewGroup = $group.DisplayName -replace $OldName, $NewName
			try { Set-AzureADGroup -ObjectId $group.ObjectId -DisplayName $NewGroup -Description "Now" }
			catch { $eh += WriteErrorlogTest -LogText $_ -UserInput $group.DisplayName -Severity "OtherFail" }
			$logText += "$( $group.DisplayName ): $NewGroup"
		}

		WriteLogTest -Text $logText -UserInput $userInput -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
		$syncHash.Data.DistGroup = Get-DistributionGroup -Identity $syncHash.DC.tbDistName[0].Trim()
		$syncHash.DC.btnDistName[1] = $syncHash.DC.btnDistAddress[1] = $false
	}
	else
	{
		[System.Windows.MessageBox]::Show( $syncHash.Data.msgTable.StrNoUpdate )
		$syncHash.tbDistAddress.Text = $syncHash.Data.DistGroup.WindowsEmailAddress
		$syncHash.tbDistName.Text = $syncHash.Data.DistGroup.DisplayName
	}
}

##################### Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "bordDist" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordDistName" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordDistOwner" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "btnAddNewMembers" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddNewMembers } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnCopyMembers" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCopyMembers } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnCheck" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCheck } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnCopyOutput" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCopyOutput } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnDistAddress" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnDistAddress } ; @{ Propname = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnDistName" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnDistName } ; @{ PropName = "IsEnabled"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "btnDistOpenForExternal" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnDistOpenForExternal } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnDistOwner" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnDistOwner } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnImport" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnImport } ) } )
[void]$controls.Add( @{ CName = "btnRemoveMembers" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveMembers } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnReset" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnReset } ) } )
[void]$controls.Add( @{ CName = "btnStartReplace" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnStartReplace } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "dgSuggestions" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "lblAddNewMembers" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblAddNewMembers } ) } )
[void]$controls.Add( @{ CName = "lblDist" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblDist } ) } )
[void]$controls.Add( @{ CName = "lblDistAddress" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblDistAddress } ) } )
[void]$controls.Add( @{ CName = "lblDistName" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblDistName } ) } )
[void]$controls.Add( @{ CName = "lblDistOwner" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblDistOwner } ) } )
[void]$controls.Add( @{ CName = "lblImport" ; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblSuggestionsTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSuggestionsTitle } ) } )
[void]$controls.Add( @{ CName = "rbDistOpenForExternalNo" ; Props = @( @{ PropName = "Content" ; PropVal = $msgTable.ContentrbDistOpenForExternalNo } ; @{ PropName = "IsChecked"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "rbDistOpenForExternalYes" ; Props = @( @{ PropName = "Content" ; PropVal = $msgTable.ContentrbDistOpenForExternalYes } ; @{ PropName = "IsChecked"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "tbDist" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbDistAddress" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbDistName" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbDistOpenForExternal" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttbDistOpenForExternal } ) } )
[void]$controls.Add( @{ CName = "tbDistOwner" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbOutput" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tiInfo" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiInfo } ) } )
[void]$controls.Add( @{ CName = "tiMembers" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiMembers } ) } )
[void]$controls.Add( @{ CName = "tiReplaceAll" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiReplaceAll } ) } )
[void]$controls.Add( @{ CName = "ttAddNewMembers" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentttAddNewMembers } ) } )
[void]$controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = "" } ) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.msgTable = $msgTable

$syncHash.Found = [System.Collections.ArrayList]::new()
$syncHash.FoundOtherOrg = [System.Collections.ArrayList]::new()
$syncHash.NotFound = [System.Collections.ArrayList]::new()
$syncHash.MailList = [System.Collections.ArrayList]::new()
$syncHash.NotMailAddress = [System.Collections.ArrayList]::new()
$syncHash.Data.MailRegEx = "^\S{1,}@\S{2,}\.\S{2,}$"

# Add new member to the distributiongroup
$syncHash.btnAddNewMembers.Add_Click( {
	$syncHash.tbAddNewMembers.Text -split ";" | Where-Object { $_ -match $syncHash.Data.MailRegEx } | Foreach-Object {
		try
		{
			$address = $_
			Add-DistributionGroupMember -Identity $syncHash.Data.DistGroup.PrimarySmtpAddress -Member $address -Confirm:$false -ErrorAction Stop
		}
		catch { $eh += WriteErrorlogTest -LogText $_ -UserInput $address -Severity "OtherFail" }
	}
	$OFS = "`n"
	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogAddNewMembers )" -UserInput "$( [string]( $syncHash.tbAddNewMembers.Text -split ";" ) )" -Success ( $null -eq $eh ) | Out-Null
	UpdateDataGrid
} )

# Verify that the distributiongroup exists in Exchange
$syncHash.btnCheck.Add_Click( {
	[array]$search = Get-DistributionGroup -Identity "$( $syncHash.DC.tbDist[0].Trim() )*" -ErrorAction SilentlyContinue
	$search += Get-DistributionGroup -Filter "DisplayName -like '*$( $syncHash.DC.tbDist[0].Trim() )*'" -ErrorAction SilentlyContinue

	if ( @( $search ).Count -eq 0 )
	{
		$syncHash.DC.bordDist[1] = 2
		$syncHash.tbDist.Focus()
	}
	elseif ( @( $search ).Count -eq 1 )
	{
		$syncHash.Data.DistGroup = $search
		CurrentDistUpdated
	}
	else { $search | Sort-Object DisplayName | Foreach-Object { $syncHash.DC.dgSuggestions[0].Add( $_ ) } }
} )

# Copy members to clipboard
$syncHash.btnCopyMembers.Add_Click( {
	"$( $syncHash.Data.msgTable.StrMembersCopiedTitle ) <$( $syncHash.Data.DistGroup.DisplayName )>`n`n$( $syncHash.dgMembers.Items.ForEach( { "$( $_.Name ) $( $_.Mail )" } ) )" | Clip
	ShowSplash -Text $syncHash.Data.msgTable.StrCopiedMembers
	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogMembersCopied )" -Success $true | Out-Null
} )

# Copy the output of replacing all members
$syncHash.btnCopyOutput.Add_Click( {
	Set-Clipboard "`"$( $syncHash.Data.DistGroup.DisplayName )`" $( $syncHash.Data.msgTable.StrSummary )`n`n$( $syncHash.DC.tbOutput[0] )"
	ShowSplash -Text $syncHash.Data.msgTable.StrCopiedOutput
	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogOutputCopied )" -Success $true | Out-Null
} )

# Change the WindowsEmailAddress for the distributiongroup
$syncHash.btnDistAddress.Add_Click( { UpdateNameAddress } )

# Change the DisplayName of the distributiongroup
$syncHash.btnDistName.Add_Click( { UpdateNameAddress } )

# Set if the distributiongroup can be used by anyone outside the organisation or not
$syncHash.btnDistOpenForExternal.Add_Click( {
	Set-DistributionGroup -Identity $syncHash.Data.DistGroup.Identity -RequireSenderAuthenticationEnabled $syncHash.rbDistOpenForExternalNo.IsChecked
	$this.IsEnabled = $false
	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogSetForExternalUse ) $( $syncHash.rbDistOpenForExternalNo.IsChecked )" -UserInput $syncHash.Data.DistGroup.PrimarySmtpAddress -Success $true | Out-Null
} )

# Change the owner of the distributiongroup
$syncHash.btnDistOwner.Add_Click( {
	try
	{
		if ( ( $newOwner = Get-ADUser -Filter "DisplayName -eq '$( $syncHash.DC.tbDistOwner[0] )'" -Properties EmailAddress -ErrorAction Stop ) -ne $null )
		{
			Get-EXOMailbox $newOwner.EmailAddress -ErrorAction Stop
			Set-DistributionGroup -Identity $syncHash.Data.DistGroup.PrimarySmtpAddress -ManagedBy $newOwner.EmailAddress
		}
		else
		{
			[System.Windows.MessageBox]::Show( $syncHash.Data.msgTable.ErrNotFoundInAd )
			$syncHash.DC.tbDistOwner[0] = $syncHash.Data.DistGroup.ManagedBy
			$eh = WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewOwner )$( $newOwner.EmailAddress )`n$_" -UserInput "$( $syncHash.Data.DistGroup.PrimarySmtpAddress )" -Severity "UserInputFail"
		}
	}
	catch
	{
		[System.Windows.MessageBox]::Show( $_.Exception.Message )
		$syncHash.DC.tbDistOwner[0] = $syncHash.Data.DistGroup.ManagedBy
		$eh = WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewOwner )$( $newOwner.EmailAddress )`n$_" -UserInput "$( $syncHash.Data.DistGroup.PrimarySmtpAddress )" -Severity "UserInputFail"
	}
	$this.IsEnabled = $false
	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogNewOwner )`n$( $newOwner.EmailAddress )" -UserInput $syncHash.Data.DistGroup.PrimarySmtpAddress -Success ( $null -eq $eh) | Out-Null
} )

# Get a list of addresses from clipboard, verify if they exist in Exchange
# For any address outside the organisation, create a Contact-object
$syncHash.btnImport.Add_Click( {
	$syncHash.MailList.Clear()
	$syncHash.Found.Clear()
	$syncHash.FoundOtherOrg.Clear()
	$syncHash.NotFound.Clear()
	$syncHash.NotMailAddress.Clear()

	$syncHash.MailList.Add( ( Get-Clipboard | Where-Object { $_ -and $_ -match "@" } ) )
	$syncHash.NotMailAddress.Add( ( Get-Clipboard | Where-Object { $_ -and $_ -notmatch $syncHash.Data.MailRegEx } ) )

	if ( $syncHash.MailList[0].Count -gt 0 )
	{
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrCheckingAddress
		for ( $i = 0 ; $i -lt $syncHash.MailList[0].Count ; $i++ )
		{
			$address = $syncHash.MailList[0][$i]
			try
			{
				Get-EXORecipient -Identity $address -ErrorAction Stop | Out-Null
				$syncHash.Found.Add( $address )
			}
			catch
			{
				if ( $address -match $syncHash.Data.msgTable.StrOrgDomain )
				{
					$syncHash.NotFound.Add( $syncHash.MailList[0][$i] )
					$eh += WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogImportNotFound -UserInput $syncHash.MailList[0][$i] -Severity "UserInputFail"
				}
				else
				{
					New-MailContact -Name $address -ExternalEmailAddress $address -ErrorAction Stop | Out-Null
					Set-MailContact -Identity $address -HiddenFromAddressListsEnabled $true -ErrorAction Stop
					$syncHash.FoundOtherOrg.Add( $address )
					$syncHash.Found.Add( $address )
				}
			}
			$syncHash.DC.Window[0] = "$( $syncHash.Data.msgTable.StrCheckingAddress ) $( [math]::Floor( ( $i / $syncHash.MailList[0].Count ) * 100 ) ) %"
		}
		$syncHash.DC.btnStartReplace[1] = $true
	}
	else { $syncHash.DC.btnStartReplace[1] = $false }

	$syncHash.DC.lblImport[0] = "$( $syncHash.Found.Count ) $( $syncHash.Data.msgTable.StrImported )"
	$syncHash.DC.Window[0] = ""

	$OFS = "`n"
	$logText = $syncHash.Data.msgTable.LogImported
	if ( @( $syncHash.Found ).Count -gt 0 )
	{
		$logText += "`n$( @( $syncHash.Found ).Count ) $( $syncHash.Data.msgTable.LogImportedAddresses )"
		$Success = $true
	}
	else { $Success = $false }
	if ( @( $syncHash.NotFound ).Count -gt 0 ) { $logText += "`n$( @( $syncHash.NotFound ).Count ) $( $syncHash.Data.msgTable.LogImportedNotfound )" }
	if ( @( $syncHash.FoundOtherOrg ).Count -gt 0 ) { $logText += "`n$( @( $syncHash.FoundOtherOrg ).Count ) $( $syncHash.Data.msgTable.LogImportedOtherOrg )" }
	if ( @( $syncHash.NotMailAddress ).Count -gt 0 ) { $logText += "`n$( @( $syncHash.NotMailAddress ).Count ) $( $syncHash.Data.msgTable.LogImportedNotMailAddress )" }
	WriteLogTest -Text $logText -UserInput "$( [string]$syncHash.MailList )`n$( $syncHash.NotMailAddress )" -Success $Success | Out-Null
} )

# Remove selected member/-s of the distributiongroup
$syncHash.btnRemoveMembers.Add_Click( {
	try { Update-DistributionGroupMember -Identity $syncHash.Data.DistGroup.PrimarySmtpAddress -Members ( $syncHash.Data.Members | Where-Object { $_.PrimarySmtpAddress -notin $syncHash.dgMembers.SelectedItems.Mail } ).PrimarySmtpAddress -ErrorAction Stop }
	catch { $eh = WriteErrorlogTest -LogText $_ -UserInput "$( $syncHash.Data.msgTable.ErrLogRemove )`n$( ( $syncHash.Data.Members | Where-Object { $_.PrimarySmtpAddress -notin $syncHash.dgMembers.SelectedItems.Mail } ).PrimarySmtpAddress )" -Severity "OtherFail" }
	UpdateDataGrid
	WriteLogTest -Text $syncHash.Data.msgTable.LogRemove -UserInput ( $syncHash.Data.Members | Where-Object { $_.PrimarySmtpAddress -notin $syncHash.dgMembers.SelectedItems.Mail } ).PrimarySmtpAddress -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )

# Replace all current members of the distributiongroup, with the list retrieved from clipboard
$syncHash.btnStartReplace.Add_Click( {
	$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrRemovingMembers

	$OFS = "`n"
	try
	{
		Update-DistributionGroupMember -Identity $syncHash.data.DistGroup.DisplayName -Members $syncHash.Found -ErrorAction Stop

		$syncHash.DC.tbOutput[0] = "$( $syncHash.Found.Count ) $( $syncHash.Data.msgTable.StrFound )"
		if ( $syncHash.FoundOtherOrg.Count -gt 0 )
		{
			$syncHash.DC.tbOutput[0] += "`n`n$( $syncHash.FoundOtherOrg.Count ) $( $syncHash.Data.msgTable.StrOtherOrg ):`n"
			$syncHash.DC.tbOutput[0] += "$( $ofs = "`n"; $syncHash.FoundOtherOrg )"
		}
		if ( $syncHash.NotFound.Count -gt 0 )
		{
			$syncHash.DC.tbOutput[0] += "`n`n$( $syncHash.NotFound.Count ) $( $syncHash.Data.msgTable.StrNotFound ):`n"
			$syncHash.DC.tbOutput[0] += "$( $ofs = "`n"; $syncHash.NotFound )"
		}
		if ( $syncHash.NotMailAddress[0].Count -gt 0 )
		{
			$syncHash.DC.tbOutput[0] += "`n`n$( $syncHash.Data.msgTable.StrNotMail ):`n"
			$syncHash.DC.tbOutput[0] += "$( $ofs = "`n"; $syncHash.NotMailAddress[0] | Where-Object { $_ -notin ( Invoke-Expression $syncHash.Data.msgTable.StrTitleMatch ) } )"
		}
	}
	catch
	{
		$eh = WriteErrorlogTest -LogText $_ -UserInput $syncHash.Found.PrimarySmtpAddress -Severity "OtherFail"
	}
	WriteLogTest -Text $syncHash.Data.msgTable.LogReplaceAll -UserInput "$( $syncHash.Data.msgTable.LogReplaceAllUIDist ) $( $syncHash.Data.DistGroup.PrimarySmtpAddress )`n`n$( $syncHash.Data.msgTable.LogReplaceAllUIMemb )`n$( [string]$syncHash.Found.PrimarySmtpAddress )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null

	$syncHash.DC.Window[0] = ""
	$syncHash.DC.btnCopyOutput[1] = $true
} )

# Selection has changed in the datagrid, enabled the button to remove members
$syncHash.dgMembers.Add_SelectionChanged( { $syncHash.btnRemoveMembers.IsEnabled = $this.SelectedItems.Count -gt 0 } )
$syncHash.dgSuggestions.Add_MouseDoubleClick( {
	$syncHash.Data.DistGroup = $this.CurrentItem
	CurrentDistUpdated
	$this.ItemsSource.Clear()
} )

# Grid is enabled/disabled, meaning a distributiongroup is found or GUI is reset
# Get the info and show this in the controls
$syncHash.gInfo.Add_IsEnabledChanged( {
	if ( $this.IsEnabled ) { CurrentDistUpdated }
	else { CurrentDistUpdated -Clear }
} )

# Grid is enabled/disabled, meaning a distributiongroup is found or GUI is reset
# Call function to list/remove members in the datagrid
$syncHash.gMembers.Add_IsEnabledChanged( {
	if ( $this.IsEnabled )
	{ UpdateDataGrid }
	else
	{ $syncHash.dgMembers.Items.Clear() }
} )

# The radiobutton is checked/unchecked, enable/disable the button to save setting
$syncHash.rbDistOpenForExternalNo.Add_Checked( { $syncHash.btnDistOpenForExternal.IsEnabled = ( $this.IsChecked -ne $syncHash.Data.DistGroup.RequireSenderAuthenticationEnabled ) } )

# The radiobutton is checked/unchecked, enable/disable the button to save setting
$syncHash.rbDistOpenForExternalYes.Add_Checked( { $syncHash.btnDistOpenForExternal.IsEnabled = ( $this.IsChecked -eq $syncHash.Data.DistGroup.RequireSenderAuthenticationEnabled ) } )

# Focus moved to other control, close the tooltip
$syncHash.tbAddNewMembers.Add_LostFocus( { $this.ToolTip.IsOpen = $false } )

# Textbox got focus, show tooltip
$syncHash.tbAddNewMembers.Add_GotFocus( { $this.ToolTip.PlacementTarget = $this; $this.ToolTip.IsOpen = $true } )

# Text is entered, enable/disable button to add member/-s
$syncHash.tbAddNewMembers.Add_TextChanged( { $syncHash.btnAddNewMembers.IsEnabled = ( $this.Text -split ";" | Where-Object { $_ -match $syncHash.Data.MailRegEx } ).Count -gt 0 } )

# Text is entered, enable/disable button to verify distributiongroup
$syncHash.tbDist.Add_TextChanged( { $syncHash.DC.btnCheck[1] = ( $this.Text.Length -gt 0 ) } )

# Text is entered, enable/disable button to save addresschange
$syncHash.tbDistAddress.Add_TextChanged( { $syncHash.btnDistAddress.IsEnabled = ( $this.Text -ne $syncHash.Data.DistGroup.PrimarySmtpAddress ) } )

# Text is entered, enable/disable button to save namechange
$syncHash.tbDistName.Add_TextChanged( { $syncHash.btnDistName.IsEnabled = ( $this.Text -ne $syncHash.Data.DistGroup.DisplayName ) } )

# Text is entered, enable/disable button to change owner
$syncHash.tbDistOwner.Add_TextChanged( { $syncHash.btnDistOwner.IsEnabled = ( $this.Text -ne $syncHash.Data.DistGroup.ManagedBy ) } )

# Window is rendered, to minor tweaks
$syncHash.Window.Add_ContentRendered( {
	$syncHash.Window.Top = 20
	$syncHash.tbDist.Focus()
	$syncHash.dgMembers.Columns[0].Header = $syncHash.Data.msgTable.ContentdgMembersNameTitle
	$syncHash.dgMembers.Columns[1].Header = $syncHash.Data.msgTable.ContentdgMembersMailTitle
	$syncHash.dgSuggestions.Columns[0].Header = $syncHash.Data.msgTable.ContentdgSuggestionsColDispName
} )

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash
