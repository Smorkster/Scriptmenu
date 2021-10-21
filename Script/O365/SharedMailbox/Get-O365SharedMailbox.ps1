<#
.Synopsis Get a SharedMailbox from Exchange
.Description Fetches a sharedmailbox from Exchange. Do some light administration. Change name/owner. Add/remove members.
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

#######################################
# The desired mailbox has been selected
function SelectedMailboxChanged
{
	$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrGettingMailbox
	$syncHash.DC.bordSM[1] = 0
	$syncHash.DC.tbSM[0] = $syncHash.Data.SharedMailbox.DisplayName
	$syncHash.DC.tbSM[1] = $false
	"StrAzureADGrpNameAdmSuffix", "StrAzureADGrpNameFullSuffix", "StrAzureADGrpNameReadSuffix" | `
		ForEach-Object { Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.SharedMailbox.DisplayName )$( $syncHash.Data.msgTable.$_ )" } | `
		ForEach-Object { $syncHash.Data.SharedMailboxAzGroups += $_ }

	$syncHash.Window.Resources["Exists"] = $true
	$syncHash.DC.Window[0] = ""
}


#######################################
# Get the admins for the shared mailbox
function UpdateDGAdmins
{
	$syncHash.DC.Window[0] = " $( $syncHash.Data.msgTable.StrGettingAdmins )"
	$syncHash.DC.dgAdmins[0].Clear()
	$syncHash.Data.Admins = Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.SharedMailbox.DisplayName )$( $syncHash.Data.msgTable.StrAzureADGrpNameAdmSuffix )" | Get-AzureADGroupMember -All $true | Where-Object { $_.UserType -eq "Member" }

	if ( $syncHash.Data.Admins.Count -eq 0 ) { $syncHash.DC.dgAdmins[0].AddChild( [pscustomobject]@{ "Name" = $syncHash.Data.msgTable.StrNoAdmins ; "Mail" = "" } ) }
	else { $syncHash.Data.Admins | Sort-Object DisplayName | Foreach-Object { $syncHash.DC.dgAdmins[0].Add( [pscustomobject]@{ "Name" = $_.DisplayName; "Mail" = $_.UserPrincipalName ; ObjectId = $_.ObjectId } ) } }
	$syncHash.DC.Window[0] = ""
}

#############################################
# Get the members/users of the shared mailbox
function UpdateDGMembers
{
	param ( [switch] $Azure, [switch] $Exchange )

	$syncHash.DC.Window[0] = " $( $syncHash.Data.msgTable.StrGettingMembers )"
	$OFS = ", "
	if ( $Exchange )
	{
		$syncHash.DC.dgMembersExchange[0].Clear()
		$syncHash.Data.ExchangeMembers = Get-EXOMailboxPermission -Identity $syncHash.Data.SharedMailbox.PrimarySmtpAddress -ErrorAction Stop | `
			Where-Object { $_.User -match $syncHash.Data.msgTable.CodeRegExDomain } | `
			Foreach-Object -Process {
				if ( $_.AccessRights -match "Full" )
				{ $Perm = $syncHash.Data.msgTable.StrPermFull }
				elseif ( $_.AccessRights -eq "ReadPermission" )
				{ $Perm = $syncHash.Data.msgTable.StrPermRead }
				[pscustomobject]@{
					Name = ( Get-Mailbox -Identity $_.User ).DisplayName
					Mail = $_.User
					Permission = $Perm }
			}

		$syncHash.Data.SendOnBehalfMembers = $syncHash.Data.SharedMailbox.GrantSendOnBehalfTo | `
			Foreach-Object -Process {
				$user = Get-Mailbox $_
				[pscustomobject]@{
					Name = $user.DisplayName
					Mail = $user.PrimarySmtpAddress
					Permission = $syncHash.Data.msgTable.StrPermSendOnBehalf } }

		$syncHash.Data.ExchangeMembers + $syncHash.Data.SendOnBehalfMembers | Sort-Object Name | Foreach-Object { $syncHash.DC.dgMembersExchange[0].Add( $_ ) }
	}

	if ( $Azure )
	{
		$syncHash.DC.dgMembersAzure[0].Clear()
		$syncHash.Data.AzureFullMembers = Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.SharedMailbox.DisplayName )$( $syncHash.Data.msgTable.StrAzureADGrpNameFullSuffix )" | Get-AzureADGroupMember -All $true | `
			Foreach-Object -Process { [pscustomobject]@{
					Name = $_.DisplayName
					Mail = $_.UserPrincipalName
					Permission = $syncHash.Data.msgTable.StrPermFull
					ObjectId = $_.ObjectId } }

		$syncHash.Data.AzureReadMembers = Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.SharedMailbox.DisplayName )$( $syncHash.Data.msgTable.StrAzureADGrpNameReadSuffix )" | Get-AzureADGroupMember -All $true | `
			Foreach-Object -Process { [pscustomobject]@{
					Name = $_.DisplayName
					Mail =  $_.UserPrincipalName
					Permission = $syncHash.Data.msgTable.StrPermRead
					ObjectId = $_.ObjectId } }

		$syncHash.Data.AzureFullMembers + $syncHash.Data.AzureReadMembers | Sort-Object Name | Foreach-Object { $syncHash.DC.dgMembersAzure[0].Add( $_ ) }
	}
	$syncHash.DC.Window[0] = ""
}

################################################
# Update name and address for the shared mailbox
# Verify first that this was the ment action
# Verify that the values in the textboxes are to be used, if they haven't both been changed
function UpdateNameAddress
{
	$UserInput = "$( $syncHash.Data.msgTable.LogNewNameAddrUIName ) $( $syncHash.DC.tbSMName[0].Trim() )`n$( $syncHash.Data.msgTable.LogNewNameAddrUIAddr )$( $syncHash.DC.tbSMAddress[0].Trim() )"

	if ( ( Confirmations -Action $syncHash.Data.msgTable.StrConfirmRename -WithPrefix ) -eq "Yes" )
	{
		$update = $false
		if ( $syncHash.DC.tbSMAddress[0] -ne $syncHash.Data.SharedMailbox.WindowsEmailAddress -and `
			$syncHash.DC.tbSMName[0] -ne $syncHash.Data.SharedMailbox.DisplayName )
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
			try
			{ Set-Mailbox -Identity $syncHash.Data.SharedMailbox.PrimarySmtpAddress -WindowsEmailAddress $syncHash.DC.tbSMAddress[0].Trim() -Name $syncHash.DC.tbSMName[0].Trim() -DisplayName $syncHash.DC.tbSMName[0].Trim() -EmailAddresses @{add="smtp:$( $syncHash.Data.SharedMailbox.PrimarySmtpAddress )"} }
			catch
			{ $eh = WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewNameAddrSetMailbox )`n$_" -UserInput $UserInput -Severity "OtherFail" }

			try
			{ $azGroups = Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.SharedMailbox.DisplayName )" }
			catch
			{ $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewNameAddrGetGrps )`n$_" -UserInput $UserInput -Severity "OtherFail" }

			try
			{
				foreach ( $group in $azGroups )
				{
					Set-AzureADGroup -ObjectId $group.ObjectId -DisplayName ( $group.DisplayName -replace $group.DisplayName , $syncHash.DC.tbSMName[0].Trim() ) -Description "Now"
				}
			}
			catch
			{ $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewNameAddrSetAzGrps )`n$_" -UserInput $UserInput -Severity "OtherFail" }

			$syncHash.Data.SharedMailbox = Get-Mailbox -Identity $syncHash.DC.tbSMName[0].Trim()
			$syncHash.btnSMName.IsEnabled = $syncHash.btnSMAddress.IsEnabled = $false
		}
		else
		{
			ShowMessagebox -Text $syncHash.Data.msgTable.StrNoUpdate
			$syncHash.DC.tbSMAddress[0] = $syncHash.Data.SharedMailbox.WindowsEmailAddress
			$syncHash.DC.tbSMName[0] = $syncHash.Data.SharedMailbox.DisplayName
		}
	}
	else
	{ $eh = WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogNewNameAddrSetMailbox -UserInput $UserInput -Severity "ScriptAborted" }

	WriteLogTest -Text $syncHash.Data.msgTable.LogNewNameAddr -UserInput $UserInput -Successs ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
}

####################################################
# Check if necessary values are entered for new user
function TestInput
{
	param ( $Text )
	if ( -not ( $user = Get-AzureADUser -SearchString $Text ) )
	{ $user = Get-AzureAdUser -Filter "UserPrincipalName eq '$( $Text )'" }

	if ( $user )
	{
		$syncHash.Data.TempUserAz = $user
		return $true
	}
	else
	{ return $false }
}

##################### Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]
Import-Module ActiveDirectory

# Some default values for comboboxes
$cbLocDefault = 2
$cbPermDefault = 0
$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "bordAddAdmin" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordAddMember" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordSM" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordSMName" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordSMOwnerAddr" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordSMOwnerID" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "btnAddAdmin" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddAdmin } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnAddMember" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddMember } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnCheck" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCheck } ) } )
[void]$controls.Add( @{ CName = "btnCopyUsers" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCopyUsers } ) } )
[void]$controls.Add( @{ CName = "btnFetchAdmins" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnFetchAdmins } ) } )
[void]$controls.Add( @{ CName = "btnFetchMembers" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnFetchMembers } ) } )
[void]$controls.Add( @{ CName = "btnRemoveMembersAzure" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveMembersAzure } ) } )
[void]$controls.Add( @{ CName = "btnRemoveMembersExchange" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveMembersExchange } ) } )
[void]$controls.Add( @{ CName = "btnRemoveSelectedAdmins" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveSelectedAdmins } ) } )
[void]$controls.Add( @{ CName = "btnReset" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnReset } ) } )
[void]$controls.Add( @{ CName = "btnSMAddress" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSMAddress } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnSMName" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSMName } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnSMOwner" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSMOwner } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnSyncToExchange" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSyncToExchange } ) } )
[void]$controls.Add( @{ CName = "cbAddMemberLoc" ; Props = @( @{ PropName = "SelectedIndex" ; PropVal = $cbLocDefault } ; @{ PropName = "SelectedValue"; PropVal = ( $msgTable.ContentcbAddMemberLoc -split ", " )[$cbLocDefault] } ) } )
[void]$controls.Add( @{ CName = "cbAddMemberPerm" ; Props = @( @{ PropName = "SelectedIndex" ; PropVal = 0 } ; @{ PropName = "SelectedValue"; PropVal = ( $msgTable.ContentcbAddMemberPerm -split ", " )[$cbPermDefault] } ) } )
[void]$controls.Add( @{ CName = "dgAdmins" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[object]]::new() } ) } )
[void]$controls.Add( @{ CName = "dgMembersAzure" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[object]]::new() } ) } )
[void]$controls.Add( @{ CName = "dgMembersExchange" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[object]]::new() } ) } )
[void]$controls.Add( @{ CName = "dgSuggestions" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[object]]::new() } ) } )
[void]$controls.Add( @{ CName = "expAddAdmin" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentexpAddAdmin } ; @{ PropName = "IsExpanded" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "expAddMembers" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentexpAddMembers } ; @{ PropName = "IsExpanded" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "gAddAdmin" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgAddAdmin } ) } )
[void]$controls.Add( @{ CName = "gMembersAzure" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgMembersAzure } ) } )
[void]$controls.Add( @{ CName = "gMembersExchange" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgMembersExchange } ) } )
[void]$controls.Add( @{ CName = "gRemoveSelectedAdmins" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgRemoveSelectedAdmins } ) } )
[void]$controls.Add( @{ CName = "lblAddAdmin" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblAddAdmin } ) } )
[void]$controls.Add( @{ CName = "lblAddMember" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblAddMember } ) } )
[void]$controls.Add( @{ CName = "lblAddMemberLoc" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblAddMemberLoc } ) } )
[void]$controls.Add( @{ CName = "lblAddMemberPerm" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblAddMemberPerm } ) } )
[void]$controls.Add( @{ CName = "lblCopyUsers" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblCopyUsers } ) } )
[void]$controls.Add( @{ CName = "lblRemoveSelectedAdmins" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRemoveSelectedAdmins } ) } )
[void]$controls.Add( @{ CName = "lblSM" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSM } ) } )
[void]$controls.Add( @{ CName = "lblSMAddress" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSMAddress } ) } )
[void]$controls.Add( @{ CName = "lblSMName" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSMName } ) } )
[void]$controls.Add( @{ CName = "lblSMOwner" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSMOwner } ) } )
[void]$controls.Add( @{ CName = "lblSMOwnerAddr" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSMOwnerAddr } ) } )
[void]$controls.Add( @{ CName = "lblSMOwnerID" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSMOwnerId } ) } )
[void]$controls.Add( @{ CName = "lblSMOwnerNoAcc" ; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblSuggestionsTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSuggestionsTitle } ) } )
[void]$controls.Add( @{ CName = "lblSyncToExchange" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSyncToExchange } ) } )
[void]$controls.Add( @{ CName = "tbAddAdmin" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbAddMember" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbSM" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "IsEnabled"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "tbSMAddress" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbSMName" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbSMOwnerAddr" ; Props = @( @{ PropName = "Text"; PropVal = "" } ; @{ PropName = "ToolTip"; PropVal = ( [System.Windows.Controls.ToolTip]@{Content = $msgTable.ContentOwnerAddrTT } ) } ) } )
[void]$controls.Add( @{ CName = "tbSMOwnerID" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tiAdmins" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiAdmins } ) } )
[void]$controls.Add( @{ CName = "tiInfo" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiInfo } ) } )
[void]$controls.Add( @{ CName = "tiMembers" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiMembers } ) } )
[void]$controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = "" } ) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.msgTable = $msgTable
$syncHash.ErrorRecord = @()
$syncHash.Data.SharedMailboxAzGroups = @()

$syncHash.Data.MailRegEx = "^\S{1,}@\S{2,}\.\S{2,}$"

# Add a new admin to the admingroup in AzureAD
$syncHash.btnAddAdmin.Add_Click( {
	if ( ( TestInput -Text $syncHash.DC.tbAddAdmin[0] ) )
	{
		try
		{ Add-AzureADGroupMember -ObjectId $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match $syncHash.Data.msgTable.StrAzureADGrpNameAdmSuffix } ).ObjectId -RefObjectId $syncHash.Data.TempUserAz.ObjectId }
		catch
		{ $eh = WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewAdm )`n$_" -UserInput $syncHash.tbAddAdmin.Text -Severity "OtherFail" }
		WriteLogTest -Text $syncHash.Data.msgTable.LogNewAdm -UserInput $syncHash.Data.TempUserAz.PrimarySmtpAddress -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
		UpdateDGAdmins
	}
	else
	{ $syncHash.DC.bordAddAdmin[1] = 2 }
} )

# Add a member to the shared mailbox, either in Azure, Exchange or both
$syncHash.btnAddMember.Add_Click( {
	if ( TestInput -Text $syncHash.DC.tbAddMember[0] )
	{
		switch ( $syncHash.DC.cbAddMemberPerm[0] )
		{
			0 { $AzAccess = $syncHash.Data.msgTable.StrAzureADGrpNameReadSuffix ; $ExAccess = "ReadPermission" }
			1 { $AzAccess = $syncHash.Data.msgTable.StrAzureADGrpNameFullSuffix; $ExAccess = "FullAccess, ReadPermission" }
		}
		if ( $syncHash.DC.cbAddMemberLoc[0] -in @( 0, 2 ) )
		{
			try
			{ Add-AzureADGroupMember -ObjectId $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match "$( $AzAccess )$" } ).ObjectId -RefObjectId $syncHash.Data.TempUserAz.ObjectId -ErrorAction Stop }
			catch
			{ $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewMem ) Add-AzureADGroupMember" -UserInput $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match "$( $AzAccess )$" } ).ObjectId -Severity "OtherFail" }

			try
			{ Set-AzureADGroup -ObjectId ( $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match "$AzAccess$" } ) ).ObjectId -Description "Now" -ErrorAction Stop }
			catch
			{ $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewMem ) Add-AzureADGroupMember" -UserInput $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match "$( $AzAccess )$" } ).ObjectId -Severity "OtherFail" }

		}
		if ( $syncHash.DC.cbAddMemberLoc[0] -in @( 1, 2 ) )
		{
			try
			{ Add-MailboxPermission -Identity $syncHash.Data.SharedMailbox.Identity -User $syncHash.DC.tbAddMember[0].Trim() -AccessRights $ExAccess -AutoMapping:$true -Confirm:$false -ErrorAction Stop }
			catch
			{ $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewMem ) Add-AzureADGroupMember" -UserInput $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match "$( $AzAccess )$" } ).ObjectId -Severity "OtherFail" }

			try
			{ Set-Mailbox -Identity $syncHash.Data.SharedMailbox.Identity -GrantSendOnBehalfTo @{ Add = $syncHash.DC.tbAddMember[0].Trim() } }
			catch
			{ $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewMem ) Add-AzureADGroupMember" -UserInput $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match "$( $AzAccess )$" } ).ObjectId -Severity "OtherFail" }
		}
		UpdateDGMembers -Azure -Exchange
		WriteLogTest -Text $syncHash.Data.msgTable.LogNewMember -UserInput "$( $syncHash.Data.msgTable.LogNewMemberUIUser ) $( $syncHash.Data.TempUserAz.UserPrincipalName )`n$( $syncHash.Data.msgTable.LogNewMemberUIPerm ) $( $syncHash.cbAddMemberPerm )`n$( $syncHash.Data.msgTable.LogNewMemberUILoc ) $( $syncHash.DC.cbAddMemberLoc[1] )" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
	}
	else
	{ $syncHash.DC.bordAddMember[1] = 2 }
} )

# Search for shared mailbox. If available, retrieve information and enable controls
$syncHash.btnCheck.Add_Click( {
	try
	{
		$syncHash.DC.dgSuggestions[0].Clear()
		$search = Get-Mailbox -Filter "DisplayName -like '*$( $syncHash.DC.tbSM[0] )*' -and RecipientTypeDetails -eq 'SharedMailbox'"

		if ( @( $search ).Count -eq 0 )
		{
			$syncHash.DC.bordSM[1] = 2
			$syncHash.tbSM.Focus()
		}
		elseif ( @( $search ).Count -eq 1 )
		{
			$syncHash.Data.SharedMailbox = $search
			SelectedMailboxChanged
		}
		else
		{ $search | Sort-Object DisplayName | Foreach-Object { $syncHash.DC.dgSuggestions[0].Add( $_ ) } }
	}
	catch
	{
		$eh = WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogSearchMailbox )`n$_" -UserInput $syncHash.DC.tbSM[0] -Severity "OtherFail"
	}
	WriteLogTest -Text $syncHash.Data.msgTable.LogSearchMailbox -UserInput $syncHash.DC.tbSM[0] -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )

# Copy list of members
$syncHash.btnCopyUsers.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$OFS = "`n"
	"$( $syncHash.Data.SharedMailbox.DisplayName )`n`n*******************************`n$( $syncHash.Data.msgTable.StrPermFull )`n*******************************`n$( $syncHash.Data.ExchangeMembers.Where( { $_.Permission -match "Full" } ) | Sort-Object Name | Foreach-Object { "$( $_.Name ) <$( $_.Mail )>" } )`n`n*******************************`n$( $syncHash.Data.msgTable.StrPermSend )`n*******************************`n$( $syncHash.Data.SharedMailbox.GrantSendOnBehalfTo | Sort-Object )`n`n*******************************`n$( $syncHash.Data.msgTable.StrPermRead )`n*******************************`n$( $syncHash.Data.ExchangeMembers.Where( { $_.Permission -eq "ReadPermission" } ) | Sort-Object Name | Foreach-Object { "$( $_.Name ) <$( $_.Mail )>" } )" | Clip
	ShowSplash -Text $syncHash.Data.msgTable.StrUsersCopied
} )

# Retrieve list of administrators
$syncHash.btnFetchAdmins.Add_Click( { UpdateDGAdmins } )

# Retrieve list of members
$syncHash.btnFetchMembers.Add_Click( { UpdateDGMembers -Azure -Exchange } )

# Remove members selected in the datagrid from Azure-groups
$syncHash.btnRemoveMembersAzure.Add_Click( {
	if ( ( Confirmations -Action "$( $syncHash.dgMembersAzure.SelectedItems.Count ) $( $syncHash.Data.msgTable.StrConfirmRemoveMembers ) Azure" ) -eq "Yes" )
	{
		$OFS = "`n"
		foreach ( $user in $syncHash.dgMembersAzure.SelectedItems )
		{
			if ( $user.Permission -eq $syncHash.Data.msgTable.StrPermRead )
			{ $group = $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match "$( $syncHash.Data.msgTable.StrAzureADGrpNameReadSuffix )$" } ) }
			elseif ( $user.Permission -eq $syncHash.Data.msgTable.StrPermFull )
			{ $group = $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match "$( $syncHash.Data.msgTable.StrAzureADGrpNameFullSuffix )$" } ) }

			try { Remove-AzureADGroupMember -ObjectId $group.ObjectId -MemberId $user.ObjectId -ErrorAction Stop }
			catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogRemoveMemAzGrp )`n$_" -UserInput "$( $user.ObjectId ) ($( $user.Name ))" -Severity "OtherFail" }
		}
		WriteLogTest -Text $syncHash.Data.msgTable.LogRemoveMemAz -UserInput $syncHash.dgMembersAzure.SelectedItems.Mail -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
		Set-AzureADGroup -ObjectId $group.ObjectId -Description "Now"
		UpdateDGMembers -Azure
	}
} )

# Remove members selected in the datagrid from Exchange
$syncHash.btnRemoveMembersExchange.Add_Click( {
	if ( ( Confirmations -Action "$( $syncHash.dgMembersExchange.SelectedItems.Count ) $( $syncHash.Data.msgTable.StrConfirmRemoveMembers ) Exchange" ) -eq "Yes" )
	{
		$OFS = "`n"
		foreach ( $user in $syncHash.dgMembersExchange.SelectedItems )
		{
			if ( $user.Permission -eq $syncHash.Data.msgTable.StrPermSendOnBehalf )
			{
				try { Set-Mailbox -Identity $syncHash.Data.SharedMailbox.Identity -GrantSendOnBehalfTo @{ Remove = $user.Name } -ErrorAction Stop }
				catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogRemoveMemGSOBT )`n$_" -UserInput $user.Name -Severity "OtherFail" }
			}
			else
			{
				if ( $user.Permission -eq $syncHash.Data.msgTable.StrPermRead ) { $access = "ReadPermission" }
				else { $access = "FullAccess,DeleteItem" }
				try { Remove-MailboxPermission -Identity $syncHash.Data.SharedMailbox.Identity -User $user.Mail -AccessRights $access -Confirm:$false -InheritanceType All -ErrorAction Stop }
				catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogRemoveMemPermExc )`n$_" -UserInput $user.Mail -Severity "OtherFail" }
			}
		}
		WriteLogTest -Text $syncHash.Data.msgTable.LogRemoveMemExc -UserInput $syncHash.dgMembersExchange.SelectedItems.Mail -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
		UpdateDGMembers -Exchange
	}
} )

# Remove the admins selected in datagrid
$syncHash.btnRemoveSelectedAdmins.Add_Click( {
	$syncHash.dgAdmins.SelectedItems | Foreach-Object {
		$u = $_
		try
		{ Remove-AzureADGroupMember -ObjectId ( $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match $syncHash.Data.msgTable.StrAzureADGrpNameAdmSuffix } ) ).ObjectId -MemberId $u.ObjectId }
		catch { $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogRemoveAdm )`n$_" -UserInput $u.PrimarySmtpAddress -Severity "OtherFail" }
	}
	WriteLogTest -Text $syncHash.Data.msgTable.LogRemoveAdm -UserInput $syncHash.dgAdmins.SelectedItems.PrimarySmtpAddress -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
	UpdateDGAdmins
} )

# Remove the information and reset controls
$syncHash.btnReset.Add_Click( {
	# Clear strings
	$syncHash.Data.SharedMailboxOwner = ""
	# Clear collections
	"SharedMailboxAzGroups","ExchangeMembers","AzureReadMembers","AzureFullMembers","SendOnBehalfMembers" | Foreach-Object { try { $syncHash.Data.$_.Clear() } catch {} }
	# Delete object for sharedmailbox
	$syncHash.Data.SharedMailbox = $null
	#Disable maingrids
	$syncHash.Window.Resources["Exists"] = $false
	$syncHash.DC.tbSM[1] = $true
	$syncHash.tabOps.SelectedIndex = 0
	$syncHash.tbSM.Focus()
} )

# Update name and address accoring to newly entered strings
$syncHash.btnSMAddress.Add_Click( { UpdateNameAddress } )

# Update name and address accoring to newly entered strings
$syncHash.btnSMName.Add_Click( { UpdateNameAddress } )

# Change listed owner for the shared mailbox
$syncHash.btnSMOwner.Add_Click( {
	if ( ( Confirmations -Action $syncHash.Data.msgTable.StrConfirmNewOwner -WithPrefix ) -eq "Yes" )
	{
		try
		{
			$tempNewOwner = Get-ADUser -Identity $syncHash.DC.tbSMOwnerID[0] -Properties EmailAddress

			Set-Mailbox -Identity $syncHash.Data.SharedMailbox.ExchangeObjectId -CustomAttribute10 "$( $syncHash.Data.msgTable.StrOwnerAttrPrefix ) $( $tempNewOwner.EmailAddress )"
			$syncHash.Data.SharedMailbox = Get-Mailbox -Identity $syncHash.DC.tbSMAddress[0] -ErrorAction Stop
			$syncHash.Data.SharedMailboxOwner = $tempNewOwner
			$syncHash.DC.tbSMOwnerAddr[0] = $syncHash.Data.SharedMailboxOwner.EmailAddress
		}
		catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
		{
			$eh = WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewOwner )`n$_" -UserInput $syncHash.DC.tbSMOwnerID[0] -Severity "UserInputFail"
		}
		catch
		{
			$eh = WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogNewOwner )`n$_" -UserInput $syncHash.DC.tbSMOwnerID[0] -Severity "OtherFail"
		}
	}
	WriteLogTest -Text $syncHash.Data.msgTable.LogNewOwner -UserInput $registeredOwner.Alias -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )

# Manually synchronize members from Azure-groups to Exchange
$syncHash.btnSyncToExchange.Add_Click( {
	$syncHash.Data.SharedMailboxAzGroups | Foreach-Object {
		if ( $_.DisplayName -match "$( $syncHash.Data.msgTable.StrAzureADGrpNameReadSuffix )$" )
		{
			foreach ( $user in ( Get-AzureADGroupMember -ObjectId $_.ObjectId ) )
			{
				try
				{ Add-MailboxPermission -Identity $syncHash.Data.SharedMailbox.PrimarySmtpAddress -User $user -AccessRights "ReadPermission" -AutoMapping $true -Confirm:$false -ErrorAction SilentlyContinue }
				catch
				{ $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogSyncRead )`n$_" -UserInput $user -Severity "OtherFail" }
			}
		}
		elseif ( $_.DisplayName -match "$( $syncHash.Data.msgTable.StrAzureADGrpNameFullSuffix )$" )
		{
			foreach ( $user in ( Get-AzureADGroupMember -ObjectId $_.ObjectId ) )
			{
				try
				{ Add-MailboxPermission -Identity $syncHash.Data.SharedMailbox.PrimarySmtpAddress -User $_ -AccessRights "FullAccess,DeleteItem" -AutoMapping $true -Confirm:$false -ErrorAction SilentlyContinue }
				catch
				{ $eh += WriteErrorlogTest -LogText "$( $syncHash.Data.msgTable.ErrLogSyncFull )`n$_" -UserInput $syncHash.DC.tbSMOwnerID[0] -Severity "OtherFail" }
				Set-Mailbox -Identity $syncHash.Data.SharedMailbox.PrimarySmtpAddress -GrantSendOnBehalfTo @{ Add = $user.UserPrincipalName }
			}
		}
	}
	WriteLogTest -Text $syncHash.Data.msgTable.LogSync -UserInput $registeredOwner.Alias -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
	UpdateDGMembers -Azure -Exchange
	UpdateDGAdmins
} )

# A doubleclick occured in the datagrid to select a shared mailbox
# Set the item as selected
$syncHash.dgSuggestions.Add_MouseDoubleClick( {
	$syncHash.Data.SharedMailbox = $this.CurrentItem
	SelectedMailboxChanged
	$this.ItemsSource.Clear()
} )

# gAdmins is disabled, clear content
$syncHash.gAdmins.Add_IsEnabledChanged( {
	if ( $this.IsEnabled )
	{ UpdateDGAdmins }
	else
	{
		$syncHash.DC.tbAddAdmin[0] = ""
		$syncHash.DC.dgAdmins.Items.Clear()
	}
} )

# Enabled changed for gInfo get or remove info
$syncHash.gInfo.Add_IsEnabledChanged( {
	if ( $this.IsEnabled )
	{
		$syncHash.DC.tbSMName[0] = $syncHash.Data.SharedMailbox.DisplayName
		$syncHash.DC.tbSMAddress[0] = $syncHash.Data.SharedMailbox.PrimarySmtpAddress
		# Check if a mailbox/AD-account exists for registered owner
		try
		{
			if ( $syncHash.Data.SharedMailbox.CustomAttribute10 -eq $null )
			{ throw }
			else
			{
				$registeredOwner = ( $syncHash.Data.SharedMailbox.CustomAttribute10 -replace $syncHash.Data.msgTable.StrOwnerAttrPrefix ).Trim()
				$syncHash.DC.tbSMOwnerAddr[0] = $registeredOwner
				$syncHash.Data.SharedMailboxOwner = Get-ExoMailbox -Identity $registeredOwner -ErrorAction Stop
				$syncHash.DC.tbSMOwnerID[0] = $syncHash.Data.SharedMailboxOwner.Alias.ToUpper()
				try
				{
					if ( -not ( Get-ADUser -Identity $syncHash.Data.SharedMailboxOwner.Alias ).Enabled )
					{ $syncHash.DC.lblSMOwnerNoAcc[0] = $syncHash.Data.msgTable.ErrMsgAdAccNotActive }
					else
					{ $syncHash.DC.lblSMOwnerNoAcc[0] = "" }
				}
				catch
				{ $syncHash.DC.lblSMOwnerNoAcc[0] = $syncHash.Data.msgTable.ErrMsgNoAdAccount }
			}
		}
		catch [Microsoft.Exchange.Management.RestApiClient.RestClientException]
		{ $syncHash.DC.lblSMOwnerNoAcc[0] = $syncHash.Data.msgTable.ErrMsgNoMailAccount }
		catch
		{ $syncHash.DC.lblSMOwnerNoAcc[0] = $syncHash.Data.msgTable.ErrMsgNoOwner }
	}
	else
	{
		$syncHash.DC.tbSM[0] = ""
		$syncHash.DC.tbSMName[0] = ""
		$syncHash.DC.tbSMAddress[0] = ""
		$syncHash.DC.tbSMOwnerAddr[0] = ""
		$syncHash.DC.tbSMOwnerID[0] = ""
		$syncHash.DC.lblSMOwnerNoAcc[0] = ""
	}
} )

# gMembers is disabled remove info
$syncHash.gMembers.Add_IsEnabledChanged( {
	if ( $this.IsEnabled )
	{ UpdateDGMembers -Azure -Exchange }
	else
	{
		$syncHash.DC.dgMembersAzure[0].Clear()
		$syncHash.DC.dgMembersExchange[0].Clear()
		$syncHash.DC.tbAddMember[0] = ""
	}
} )

# Text entered for new admin, if AzureAD-account exists, enabled button to add
$syncHash.tbAddAdmin.Add_TextChanged( {
	$syncHash.DC.bordAddAdmin[1] = 0
	if ( $this.Text.Length -ge 4 )
	{
		if ( ( TestInput -Text $this.Text ) )
		{ $syncHash.DC.btnAddAdmin[1] = $true }
		else
		{
			$syncHash.DC.btnAddAdmin[1] = $false
			$syncHash.DC.bordAddAdmin[1] = 2
		}
	}
} )

# Text changed for new member
$syncHash.tbAddMember.Add_TextChanged( {
	$syncHash.DC.bordAddMember[1] = 0
	if ( $this.Text.Length -ge 4 )
	{
		if ( ( TestInput -Text $this.Text ) )
		{ $syncHash.DC.btnAddMember[1] = $true }
		else
		{
			$syncHash.DC.btnAddMember[1] = $false
			$syncHash.DC.bordAddMember[1] = 2
		}
	}
} )

# Input was sent to textbox, show tooltip that it is readonly
$syncHash.tbSMOwnerAddr.Add_KeyDown( { $this.ToolTip.IsOpen = $true } )

# Textbox lost focus, close tooltip
$syncHash.tbSMOwnerAddr.Add_LostFocus( { $this.ToolTip.IsOpen = $false } )

# Id for new owner changed, check if user exists in AD and Exchange
# If it exists, enable button to do the change
$syncHash.tbSMOwnerID.Add_TextChanged( {
	$syncHash.Window.Dispatcher.Invoke( [action] {
		$syncHash.DC.lblSMOwnerNoAcc[0] = ""
		$syncHash.DC.btnSMOwner[1] = $false
		$syncHash.DC.bordSMOwnerID[1] = 0
	} )
	if ( $this.Text.Length -eq 4 )
	{
		try
		{
			$search = Get-ADUser $this.Text -Properties ProxyAddresses
			if ( $search.Enabled )
			{
				$syncHash.DC.btnSMOwner[1] = -not ( "smtp:$( ( $syncHash.Data.SharedMailbox.CustomAttribute10 -replace $syncHash.Data.msgTable.StrOwnerAttrPrefix ).Trim() )" -in ( $search ).ProxyAddresses )
			}
			else
			{
				$syncHash.DC.bordSMOwnerID[1] = 2
				$syncHash.DC.lblSMOwnerNoAcc[0] = $syncHash.Data.msgTable.ErrMsgOwnerAdDisabled
			}
		}
		catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
		{
			$syncHash.DC.bordSMOwnerID[1] = 2
			$syncHash.DC.lblSMOwnerNoAcc[0] = $syncHash.Data.msgTable.ErrMsgOwnerAdNotFound
		}
		catch
		{
			$syncHash.DC.bordSMOwnerID[1] = 2
			$syncHash.DC.lblSMOwnerNoAcc[0] = $syncHash.Data.msgTable.ErrMsgOwnerAdError
		}
	}
} )

# Some minor tweaking
$syncHash.Window.Add_ContentRendered( {
	$syncHash.Window.Top = 10
	$syncHash.tbSM.Focus()
	$syncHash.dgMembersAzure.Columns[0].Header = $syncHash.Data.msgTable.ContentdgMembersNameTitle
	$syncHash.dgMembersAzure.Columns[1].Header = $syncHash.Data.msgTable.ContentdgMembersMailTitle
	$syncHash.dgMembersAzure.Columns[2].Header = $syncHash.Data.msgTable.ContentdgMembersPermissionTitle
	$syncHash.dgMembersExchange.Columns[0].Header = $syncHash.Data.msgTable.ContentdgMembersNameTitle
	$syncHash.dgMembersExchange.Columns[1].Header = $syncHash.Data.msgTable.ContentdgMembersMailTitle
	$syncHash.dgMembersExchange.Columns[2].Header = $syncHash.Data.msgTable.ContentdgMembersPermissionTitle
	$syncHash.dgAdmins.Columns[0].Header = $syncHash.Data.msgTable.ContentdgAdminsNameTitle
	$syncHash.dgAdmins.Columns[1].Header = $syncHash.Data.msgTable.ContentdgAdminsMailTitle
	$syncHash.dgSuggestions.Columns[0].Header = $syncHash.Data.msgTable.ContentdgSuggestionsColDispName
	$syncHash.dgSuggestions.Columns[1].Header = $syncHash.Data.msgTable.ContentdgSuggestionsColPrimSmtp
	$msgTable.ContentcbAddMemberLoc -split ", " | Foreach-Object { $syncHash.cbAddMemberLoc.AddChild( $_ ) }
	$msgTable.ContentcbAddMemberPerm -split ", " | Foreach-Object { $syncHash.cbAddMemberPerm.AddChild( $_ ) }
} )

# Window closes, make sure tooltip is closed
$syncHash.Window.Add_Closing( { $syncHash.DC.tbSMOwnerAddr[1].IsOpen = $false } )

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash
