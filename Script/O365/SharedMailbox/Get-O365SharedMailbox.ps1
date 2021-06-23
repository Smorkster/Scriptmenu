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
# Get the admins for the shared mailbox
function UpdateDGAdmins
{
	$syncHash.Data.Admins = Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.SharedMailbox.DisplayName )$( $syncHash.Data.msgTable.StrAzureADGrpNameAdmSuffix )" | Get-AzureADGroupMember -All $true | Where-Object { $_.UserType -eq "Member" }
	if ( $syncHash.Data.Admins.Count -eq 0 ) { $syncHash.dgAdmins.AddChild( [pscustomobject]@{ "Name" = $syncHash.Data.msgTable.StrNoAdmins ; "Mail" = "" } ) }
	else { $syncHash.Data.Admins | Sort-Object DisplayName | Foreach-Object { $syncHash.dgAdmins.AddChild( [pscustomobject]@{ "Name" = $_.DisplayName; "Mail" = $_.UserPrincipalName } ) } }
}

#############################################
# Get the members/users of the shared mailbox
function UpdateDGMembers
{
	param ( [switch] $Azure, [switch] $Exchange )

	$OFS = ", "
	if ( $Exchange )
	{
		$syncHash.dgMembersExchange.Items.Clear()
		$syncHash.Data.ExchangeMembers = Get-EXOMailboxPermission -Identity $syncHash.Data.SharedMailbox.PrimarySmtpAddress -ErrorAction Stop | Where-Object { $_.User -match $syncHash.Data.msgTable.CodeRegExDomain } | `
			Foreach-Object -Process { 
				$Perm = &{ if ( $_.AccessRights -match "Full" ) { $syncHash.Data.msgTable.StrPermFull } elseif ( $_.AccessRights -eq "ReadPermission" ) { $syncHash.Data.msgTable.StrPermRead } }
				[pscustomobject]@{
					Name = ( Get-Mailbox -Identity $_.User ).DisplayName
					Mail = $_.User
					Permission = $Perm } }

		$syncHash.Data.SendOnBehalfMembers = $syncHash.Data.SharedMailbox.GrantSendOnBehalfTo | `
			Foreach-Object -Process { [pscustomobject]@{
					Name = ( Get-Mailbox $_ ).DisplayName
					Mail = ( Get-Mailbox $_ ).PrimarySmtpAddress
					Permission = $syncHash.Data.msgTable.StrPermSendOnBehalf } }

		$syncHash.Data.ExchangeMembers + $syncHash.Data.SendOnBehalfMembers | Sort-Object Name | Foreach-Object { $syncHash.dgMembersExchange.AddChild( $_ ) }
	}

	if ( $Azure )
	{
		$syncHash.dgMembersAzure.Items.Clear()
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

		$syncHash.Data.AzureFullMembers + $syncHash.Data.AzureReadMembers | Sort-Object Name | Foreach-Object { $syncHash.dgMembersAzure.AddChild( $_ ) }
	}
}

################################################
# Update name and address for the shared mailbox
# Verify first that this was the ment action
# Verify that the values in the textboxes are to be used, if they haven't both been changed
function UpdateNameAddress
{
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

			Set-Mailbox -Identity $syncHash.Data.SharedMailbox.PrimarySmtpAddress -WindowsEmailAddress $syncHash.DC.tbSMAddress[0].Trim() -Name $syncHash.DC.tbSMName[0].Trim() -DisplayName $syncHash.DC.tbSMName[0].Trim() -EmailAddresses @{add="smtp:$( $syncHash.Data.SharedMailbox.PrimarySmtpAddress )"}

			$azGroups = Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.SharedMailbox.DisplayName )"
			foreach ( $group in $azGroups )
			{
				Set-AzureADGroup -ObjectId $group.ObjectId -DisplayName ( $group.DisplayName -replace $group.DisplayName , $syncHash.DC.tbSMName[0].Trim() ) -Description "Now"
			}

			WriteLog -Text "$( $syncHash.Data.msgTable.StrLogNewNameAddr ) $( $syncHash.Data.SharedMailbox.DisplayName ) > $( $syncHash.DC.tbSMName[0] ) ($( $syncHash.DC.tbSMAddress[0] ))"
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
}

####################################################
# Check if necessary values are entered for new user
function VerifyNewMemberInfo
{
	$Ok = $true
	try
	{
		if ( $syncHash.DC.tbAddMember[0].Length -eq 4 )
		{ $filterString = "UserPrincipalName eq '$( $syncHash.DC.tbAddMember[0].Trim() )" }
		elseif ( $syncHash.DC.tbAddMember[0] -match $syncHash.Data.MailRegEx )
		{ $filterString = "ImmutableId eq '$( $syncHash.Data.msgTable.StrImmutableIdPrefix )$( $syncHash.DC.tbAddMember[0].ToUpper().Trim() )'" }
		$syncHash.Data.TempUserAz = Get-AzureADUser -Searchstring $filterString -ErrorAction Stop
	}
	catch { $syncHash.DC.bordAddMemberId[1] = 2 ; $Ok = $false }

	if ( $syncHash.DC.cbAddMemberLoc[0] -eq -1 )
	{ $syncHash.DC.bordAddMemberLoc[1] = 2 ; $Ok = $false }

	if ( $syncHash.DC.cbAddMemberPerm[0] -eq -1 )
	{ $syncHash.DC.bordAddMemberPerm[1] = 2 ; $Ok = $false }

	return $Ok
}

##################### Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -Argumentlist $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -Argumentlist $args[1]
Import-Module ActiveDirectory

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "bordAddMemberId" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordAddMemberLoc" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordAddMemberPerm" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordSM" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordSMName" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordSMOwnerAddr" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "bordSMOwnerID" ; Props = @( @{ PropName = "BorderBrush"; PropVal = "Red" } ; @{ PropName = "BorderThickness"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "btnAddAdmin" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddAdmin } ) } )
[void]$controls.Add( @{ CName = "btnAddMember" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddMember } ) } )
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
[void]$controls.Add( @{ CName = "cbAddMemberLoc" ; Props = @( @{ PropName = "SelectedIndex" ; PropVal = -1 } ) } )
[void]$controls.Add( @{ CName = "cbAddMemberPerm" ; Props = @( @{ PropName = "SelectedIndex" ; PropVal = -1 } ) } )
[void]$controls.Add( @{ CName = "gAddAdmin" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgAddAdmin } ) } )
[void]$controls.Add( @{ CName = "gAddMembers" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgAddMembers } ) } )
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
[void]$controls.Add( @{ CName = "lblSMOwnerNoAcc" ; Props = @( @{ PropName = "Content"; PropVal = "" } ; @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "lblSyncToExchange" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSyncToExchange } ) } )
[void]$controls.Add( @{ CName = "tbAddAdmin" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbAddMember" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbSM" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbSMAddress" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbSMName" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbSMOwnerAddr" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
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

$syncHash.btnAddMember.Add_Click( {
	if ( VerifyNewMemberInfo )
	{
		switch ( $syncHash.DC.cbAddMemberPerm[0] )
		{
			0 { $AzAccess = $syncHash.Data.msgTable.StrAzureADGrpNameReadSuffix ; $ExAccess = "ReadPermission" }
			1 { $AzAccess = $syncHash.Data.msgTable.StrAzureADGrpNameFullSuffix; $ExAccess = "FullAccess, ReadPermission" }
		}
		if ( $syncHash.DC.cbAddMemberLoc[0] -in @( 0, 2 ) )
		{
			Add-AzureADGroupMember -ObjectId $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match "$( $AzAccess )$" } ).ObjectId -RefObjectId $syncHash.Data.TempUserAz.ObjectId
			Set-AzureADGroup -ObjectId ( $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match "$AzAccess$" } ) ).ObjectId -MemberId
		}
		if ( $syncHash.DC.cbAddMemberLoc[0] -in @( 1, 2 ) )
		{
			Add-MailboxPermission -Identity $syncHash.Data.SharedMailbox -User $syncHash.DC.tbAddMember[0].Trim() -AccessRights $ExAccess -AutoMapping:$true -Confirm:$false
		}
	}
} )
$syncHash.btnCheck.Add_Click( {
	try
	{
		$syncHash.Data.SharedMailbox = Get-Mailbox -Identity ( $syncHash.DC.tbSM[0] -replace "\*" ) -ErrorAction Stop
		$syncHash.Data.SharedMailboxAzGroups += Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.SharedMailbox.DisplayName )$( $syncHash.Data.msgTable.StrAzureADGrpNameAdmSuffix )"
		$syncHash.Data.SharedMailboxAzGroups += Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.SharedMailbox.DisplayName )$( $syncHash.Data.msgTable.StrAzureADGrpNameFullSuffix )"
		$syncHash.Data.SharedMailboxAzGroups += Get-AzureADGroup -SearchString "$( $syncHash.Data.msgTable.StrAzureADGrpNamePrefix )$( $syncHash.Data.SharedMailbox.DisplayName )$( $syncHash.Data.msgTable.StrAzureADGrpNameReadSuffix )"
		$syncHash.Window.Resources["Exists"] = $true
		$syncHash.tbSM.IsEnabled = $false
	}
	catch
	{
		$syncHash.DC.bordSM[1] = 2
		$syncHash.tbSM.Focus()
		$syncHash.ErrorRecord += $_
	}
} )
$syncHash.btnCopyUsers.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$OFS = "`n"
	"$( $syncHash.Data.SharedMailbox.DisplayName)`n`n*******************************`n$( $syncHash.Data.msgTable.StrPermFull )*******************************`n$( $syncHash.Data.ExchangeMembers.Where( { $_.Permission -match "Full" } ) | Foreach-Object { "$( $_.Name ) <$( $_.Mail )>" } )`n`n*******************************`n$( $syncHash.Data.msgTable.StrPermSend )*******************************`n$( $syncHash.Data.SharedMailbox.GrantSendOnBehalfTo )`n`n*******************************`n$( $syncHash.Data.msgTable.StrPermRead )*******************************`n$( $syncHash.Data.ExchangeMembers.Where( { $_.Permission -eq "ReadPermission" } ) | Foreach-Object { "$( $_.Name ) <$( $_.Mail )>" } )" | Clip
	ShowSplash -Text $syncHash.Data.msgTable.StrUsersCopied
} )
$syncHash.btnFetchAdmins.Add_Click( { UpdateDGAdmins } )
$syncHash.btnFetchMembers.Add_Click( { UpdateDGMembers -Azure -Exchange } )
$syncHash.btnRemoveMembersAzure.Add_Click( {
	if ( ( Confirmations -Action "$( $syncHash.dgMembersAzure.SelectedItems.Count ) $( $syncHash.Data.msgTable.StrConfirmRemoveMembers ) Azure" ) -eq "Yes" )
	{
		foreach ( $user in $syncHash.dgMembersAzure.SelectedItems )
		{
			if ( $user.Permission -eq $syncHash.Data.msgTable.StrPermRead ) { $suffix = $syncHash.Data.msgTable.StrAzureADGrpNameReadSuffix }
			elseif ( $user.Permission -eq $syncHash.Data.msgTable.StrPermFull ) { $suffix = $syncHash.Data.msgTable.StrAzureADGrpNameFullSuffix }
			Remove-AzureADGroupMember -ObjectId ( $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match "$suffix$" } ) ).ObjectId -MemberId $syncHash.Data.TempUserAz.ObjectId
		}
		UpdateDGMembers -Azure
		Set-AzureADGroup -ObjectId ( $syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -match "$suffix$" } ) ).ObjectId -Description "Now"
	}
} )
$syncHash.btnRemoveMembersExchange.Add_Click( {
	if ( ( Confirmations -Action "$( $syncHash.dgMembersAzure.SelectedItems.Count ) $( $syncHash.Data.msgTable.StrConfirmRemoveMembers ) Exchange" ) -eq "Yes" )
	{
		foreach ( $user in $syncHash.dgMembersExchange.SelectedItems )
		{
			if ( $user.Permission -eq $syncHash.Data.msgTable.StrPermRead ) { $access = "ReadPermission" }
			else { $access = "FullAccess,DeleteItem" }
			Remove-MailboxPermission -Identity $syncHash.Data.SharedMailbox.ExchangeObjectId -User $user.Mail -AccessRights $access -ClearAutoMapping -Confirm:$false -InheritanceType All
		}
		UpdateDGMembers -Exchange
	}
} )
$syncHash.btnReset.Add_Click( {
	# Clear strings
	$syncHash.Data.SharedMailboxOwner = ""
	# Clear collections
	"SharedMailboxAzGroups","ExchangeMembers","AzureReadMembers","AzureFullMembers","SendOnBehalfMembers" | Foreach-Object { $syncHash.Data.$_.Clear() }
	# Delete object for sharedmailbox
	$syncHash.Data.SharedMailbox = $null
	#Disable maingrids
	$syncHash.Window.Resources["Exists"] = $false
	$syncHash.tbSM.IsEnabled = $true
} )
$syncHash.btnSMAddress.Add_Click( { UpdateNameAddress } )
$syncHash.btnSMName.Add_Click( { UpdateNameAddress } )
$syncHash.btnSMOwner.Add_Click( {
	if ( ( Confirmations -Action $syncHash.Data.msgTable.StrConfirmNewOwner -WithPrefix ) -eq "Yes" )
	{
		if ( $tempNewOwner = Get-ADUser -Identity $syncHash.DC.tbSMOwnerID[0] -Properties EmailAddress )
		{
			Set-Mailbox -Identity $syncHash.Data.SharedMailbox.ExchangeObjectId -CustomAttribute10 "$( $syncHash.Data.msgTable.StrOwnerAttrPrefix ) $( $tempNewOwner.EmailAddress )"
			$syncHash.Data.SharedMailbox = Get-Mailbox -Identity $syncHash.DC.tbSMAddress[0] -ErrorAction Stop
			$registeredOwner = Get-ExoMailbox ( $syncHash.Data.SharedMailbox.CustomAttribute10 -replace $syncHash.Data.msgTable.StrOwnerAttrPrefix ).Trim()
			$syncHash.Data.SharedMailboxOwner = Get-ADUser -Identity $registeredOwner.Alias -Properties EmailAddress -ErrorAction Stop
			$syncHash.DC.tbSMOwnerAddr[0] = $syncHash.Data.SharedMailboxOwner.EmailAddress
			WriteLog -Text "$( $syncHash.Data.SharedMailbox.DisplayName ) $( $syncHash.Data.msgTable.StrLogNewOwner ) $( $registeredOwner.Alias ) > $( $syncHash.Data.SharedMailboxOwner )"
		}
	}
} )
$syncHash.btnSyncToExchange.Add_Click( {
	$syncHash.Data.SharedMailboxAzGroups.Where( { $_.DisplayName -notmatch $syncHash.Data.msgTable.StrAzureADGrpNameAdmSuffix } ) | Foreach-Object {
		if ( $syncHash.Data.msgTable.StrAzureADGrpNameReadSuffix -match ( $_.DisplayName -split "-" | Select -Last 1 ) )
		{
			Get-AzureADGroupMember -ObjectId $_.ObjectId | Foreach-Object {
				try { Add-MailboxPermission -Identity $syncHash.Data.SharedMailbox.PrimarySmtpAddress -User $_ -AccessRights "ReadPermission" -AutoMapping $true -Confirm:$false -ErrorAction SilentlyContinue } catch {}
			}
		}
		else
		{
			$FullMembers = Get-AzureADGroupMember -ObjectId $_.ObjectId
			$FullMembers | Foreach-Object {
				try { Add-MailboxPermission -Identity $syncHash.Data.SharedMailbox.PrimarySmtpAddress -User $_ -AccessRights "FullAccess,DeleteItem" -AutoMapping $true -Confirm:$false -ErrorAction SilentlyContinue } catch {}
			}
			Set-Mailbox -Identity $syncHash.Data.SharedMailbox.PrimarySmtpAddress -GrantSendOnBehalfTo $null
			Set-Mailbox -Identity $syncHash.Data.SharedMailbox.PrimarySmtpAddress -GrantSendOnBehalfTo $FullMembers.UserPrincipalName
		}
	}
} )
$syncHash.cbAddMemberLoc.Add_SelectionChanged( { $syncHash.DC.bordAddMemberLoc[1] = 0 } )
$syncHash.cbAddMemberPerm.Add_SelectionChanged( { $syncHash.DC.bordAddMemberPerm[1] = 0 } )
$syncHash.gAdmins.Add_IsEnabledChanged( {
	if ( $this.IsEnabled ) {}
	else
	{
		$syncHash.DC.tbAddAdmin[0] = ""
		$syncHash.dgAdmins.Items.Clear()
	}
} )
$syncHash.gInfo.Add_IsEnabledChanged( {
	if ( $this.IsEnabled )
	{
		$syncHash.DC.tbSMName[0] = $syncHash.Data.SharedMailbox.DisplayName
		$syncHash.DC.tbSMAddress[0] = $syncHash.Data.SharedMailbox.PrimarySmtpAddress
		# Check if a mailboxuser exists
		try
		{
			$registeredOwner = ( $syncHash.Data.SharedMailbox.CustomAttribute10 -replace $syncHash.Data.msgTable.StrOwnerAttrPrefix ).Trim()
			$syncHash.DC.tbSMOwnerAddr[0] = $registeredOwner
			Get-ExoMailbox -Identity $registeredOwner -ErrorAction Stop | Out-Null
		}
		catch [Microsoft.Exchange.Management.RestApiClient.RestClientException]
		{
			$syncHash.Window.Dispatcher.Invoke( [action] {
				$syncHash.DC.lblSMOwnerNoAcc[0] = $syncHash.Data.msgTable.StrNoMailAccount
				$syncHash.DC.lblSMOwnerNoAcc[1] = [System.Windows.Visibility]::Visible
			} )
		}

		# Check if AD user exists
		$syncHash.Data.SharedMailboxOwner = Get-ADUser -LDAPFilter "(proxyaddresses=*smtp:$registeredOwner*)" -ErrorAction Stop
		if ( $null -eq $syncHash.Data.SharedMailboxOwner )
		{
			$syncHash.Window.Dispatcher.Invoke( [action] {
				$syncHash.DC.tbSMOwnerID[0] = ""
				$syncHash.DC.lblSMOwnerNoAcc[0] += "$( if ( $syncHash.DC.lblSMOwnerNoAcc[0].Length -gt 0 ) { "`n" } )$( $syncHash.Data.msgTable.StrNoAdAccount )"
				$syncHash.DC.lblSMOwnerNoAcc[1] = [System.Windows.Visibility]::Visible
			} )
		}
		else { $syncHash.DC.tbSMOwnerID[0] = $syncHash.Data.SharedMailboxOwner.SamAccountName.ToUpper() }
		$syncHash.DC.btnSMOwner[1] = $false
	}
	else
	{
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.DC.tbSM[0] = $syncHash.DC.tbSMName[0] = $syncHash.DC.tbSMAddress[0] = $syncHash.DC.tbSMOwner[0] = ""
			$syncHash.DC.lblSMOwnerNoAcc[0] = ""
			$syncHash.DC.lblSMOwnerNoAcc[1] = [System.Windows.Visibility]::Collapsed
		} )
	}
} )
$syncHash.gMembers.Add_IsEnabledChanged( {
	if ( $this.IsEnabled )
	{}
	else
	{
		$syncHash.dgMembersAzure.Items.Clear()
		$syncHash.dgMembersExchange.Items.Clear()
		$syncHash.DC.tbAddMember[0] = ""
	}
} )
$syncHash.tbAddMember.Add_TextChanged( { $syncHash.DC.bordAddMemberId[1] = 0 } )
$syncHash.tbSMOwnerID.Add_TextChanged( {
	$syncHash.Window.Dispatcher.Invoke( [action] {
		$syncHash.DC.lblSMOwnerNoAcc[0] = ""
		$syncHash.DC.lblSMOwnerNoAcc[1] = [System.Windows.Visibility]::Collapsed
		$syncHash.DC.btnSMOwner[1] = $false
	} )
	if ( $this.Text.Length -eq 4 )
	{
		if ( ( Get-ADUser -Identity $this.Text -Properties EmailAddress -ErrorAction Stop ).EmailAddress -ne $syncHash.SharedMailboxOwner )
		{ $syncHash.DC.btnSMOwner[1] = $true }
	}
} )
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
	$msgTable.ContentcbAddMemberLoc -split ", " | Foreach-Object { $syncHash.cbAddMemberLoc.AddChild( $_ ) }
	$msgTable.ContentcbAddMemberPerm -split ", " | Foreach-Object { $syncHash.cbAddMemberPerm.AddChild( $_ ) }
} )

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash
