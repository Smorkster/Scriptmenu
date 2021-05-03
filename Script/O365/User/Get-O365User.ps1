<#
.Synopsis Kontrollera status för Office365 konto
.Description Kontrollerar status för en användares Office365 konto, ifall det synkats samt annan information
#>

############################
# Get last successful logins
function GetLogins
{
	$syncHash.DC.spLogins[0] = $false
	$syncHash.DC.btnGetDelegates[1] = $false
	$syncHash.DC.btnGetDistsMember[1] = $false
	$syncHash.DC.btnGetDistsOwner[1] = $false
	$syncHash.DC.btnGetIcon[1] = $false
	$syncHash.DC.btnGetDelegates[0] += " $( $syncHash.Data.msgTable.StrGettingLogginsDelegates )"
	$syncHash.DC.btnGetDistsMember[0] += " $( $syncHash.Data.msgTable.StrGettingLogginsDelegates )"
	$syncHash.DC.btnGetDistsOwner[0] += " $( $syncHash.Data.msgTable.StrGettingLogginsDelegates )"
	$syncHash.DC.btnGetIcon[0] += " $( $syncHash.Data.msgTable.StrGettingLogginsDelegates )"
	$syncHash.DC.tbLastO365Login[0] = $syncHash.Data.msgTable.StrGettingLoggins

	$syncHash.Data.mailLogin = ( Get-MailboxStatistics $syncHash.DC.tbId[0] ).LastLogonTime
	$syncHash.Data.GetAuditLog = Search-UnifiedAuditLog -StartDate ( ( [DateTime]::Today.AddDays( -10 ) ).ToUniversalTime() ) -EndDate ( ( [DateTime]::Now ).ToUniversalTime() ) -UserIds $syncHash.Data.user.EmailAddress -Operations "FileAccessed" -RecordType "SharePointFileOperation" -AsJob

	( [powershell]::Create().AddScript( { param ( $syncHash )
		Wait-Job $syncHash.Data.GetAuditLog
		$syncHash.Data.GetAuditLog = $syncHash.Data.GetAuditLog | Receive-Job
		if ( $syncHash.Data.GetAuditLog.Count -eq 0 ) { $TeamsLoginText = $syncHash.Data.msgTable.StrNoLogin }
		else
		{
			$syncHash.Data.lastLogin = ( $syncHash.Data.GetAuditLog | Sort-Object CreationDate | Select-Object -Last 1 ).CreationDate
			$TeamsLoginText = "$( $syncHash.Data.lastLogin.ToShortDateString() ) $( $syncHash.Data.lastLogin.ToLongTimeString() )"
		}

		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.tbLastTeamsLogins.Text = $TeamsLoginText
			$syncHash.DC.tbLastO365Login[0] = "$( $syncHash.Data.mailLogin.ToShortDateString() ) $( $syncHash.Data.mailLogin.ToLongTimeString() )"
			$syncHash.DC.btnGetDelegates[0] = $syncHash.Data.msgTable.ContentbtnGetDelegates
			$syncHash.DC.btnGetDistsMember[0] = $syncHash.Data.msgTable.ContentbtnGetDistsMember
			$syncHash.DC.btnGetDistsOwner[0] = $syncHash.Data.msgTable.ContentbtnGetDistsOwner
			$syncHash.DC.btnGetIcon[0] = $syncHash.Data.msgTable.ContentbtnGetIcon
			$syncHash.DC.spLogins[0] = $true
			$syncHash.DC.btnGetDelegates[1] = $true
			$syncHash.DC.btnGetDistsMember[1] = $true
			$syncHash.DC.btnGetDistsOwner[1] = $true
			$syncHash.DC.btnGetIcon[1] = $true
		} )
	} ).AddArgument( $syncHash ) ).BeginInvoke()
	WriteLog -LogText "Logins $( $syncHash.DC.tbId[0] )"
}

#################################
# Get devices registered for user
function GetDevices
{
	if ( ( $devices = Get-AzureADUserRegisteredDevice -ObjectId $syncHash.Data.userAzure.ObjectId ).Count -gt 0 )
	{
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.tbDevices.Text = "" } )
		foreach ( $device in $devices )
		{
			$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.tbDevices.Text += "$( $device.DisplayName )`n" } )
		}
	}

	WriteLog -LogText "Devices $( $syncHash.DC.tbId[0] )"
}

###################
# Get any delegates
function GetDelegates
{
	$syncHash.dgDelegates.Items.Clear()

	$ofs = ","
	$mailDelegates = Get-MailboxFolderPermission -Identity "$( $syncHash.Data.user.EmailAddress ):\$( $syncHash.Data.msgTable.StrInbox )" -ErrorAction Stop | Where-Object { $_.User -notin "Standard","Anonymous","Default" }

	try
	{
		$calendarDelegates = Get-MailboxFolderPermission -Identity "$( $syncHash.Data.user.EmailAddress ):\$( $syncHash.Data.msgTable.StrCalendar )" -ErrorAction Stop | Where-Object { $_.User -notin "Standard","Anonymous","Default" }
	}
	catch
	{
		if ( $_.CategoryInfo -like "*ManagementObjectNotFoundException*" )
		{
			try
			{
				$calendarDelegates = Get-MailboxFolderPermission -Identity "$( $syncHash.Data.user.EmailAddress ):\Calendar" -ErrorAction Stop | Where-Object { $_.User -notin "Standard","Anonymous","Default" }
			}
			catch
			{
				if ( $_.CategoryInfo -like "*ManagementObjectNotFoundException*" )
				{
					$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.tbCheckMessage.Text += "`n$( $syncHash.Data.msgTable.ErrNoCalendar )" } )
				}
			}
		}
	}

	if ( ( $mailDelegates.Count + $calendarDelegates.Count ) -gt 0 )
	{
		$syncHash.dgDelegates.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgDelegatesTitleFolder; Width = 150; Binding = [System.Windows.Data.Binding]@{ Path = "Folder" } } ) )
		$syncHash.dgDelegates.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgDelegatesTitleUser; Width = 150; Binding = [System.Windows.Data.Binding]@{ Path = "User" } } ) )
		$syncHash.dgDelegates.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgDelegatesTitlePerm; Binding = [System.Windows.Data.Binding]@{ Path = "Permission" } } ) )
	}

	if ( $mailDelegates.Count -gt 0 ) { $mailDelegates | ForEach-Object { $syncHash.dgDelegates.AddChild( [pscustomobject]@{ "Folder" = $_.FolderName; "User" = $_.User; "Permission" = [string]$_.AccessRights } ) } }
	else { $syncHash.dgDelegates.AddChild( [pscustomobject]@{ "Folder" = $syncHash.Data.msgTable.StrNoMailDelegates; "User" = ""; "Permission" = "" } ) }

	if ( $calendarDelegates.Count -gt 0 ) { $calendarDelegates | ForEach-Object { $syncHash.dgDelegates.AddChild( [pscustomobject]@{ "Folder" = $_.FolderName; "User" = $_.User; "Permission" = [string]$_.AccessRights } ) } }
	else { $syncHash.dgDelegates.AddChild( [pscustomobject]@{ "Folder" = $syncHash.Data.msgTable.StrNoMailDelegates; "User" = ""; "Permission" = "" } ) }

	WriteLog -LogText "Delegates $( $syncHash.DC.tbId[0] )"
}

##################################################
# Get all distributiongroups the user is member of
function GetDistsMembership
{
	$syncHash.dgDistsMember.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgDistsMemberTitleName; Binding = [System.Windows.Data.Binding]@{ Path = "Name" } } ) )
	$syncHash.dgDistsMember.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgDistsMemberTitleSmtp; Binding = [System.Windows.Data.Binding]@{ Path = "SMTP" } } ) )

	$dists = Get-AzureADUser -SearchString $syncHash.DC.tbId[0] | Get-AzureADUserMembership | Where-Object { $_.DisplayName -match "^DL" }

	if ( @( $dists ).Count -eq 0 ) { $syncHash.dgDistsMember.AddChild( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrNoDistsMember ; SMTP = "" } ) }
	else
	{
		$dists.DisplayName | `
			Foreach-Object { $_ -replace "DL-" -split "-"  | Select-Object -SkipLast 1 } | `
			Select-Object @{ Name = "Name"; Expression = { $_ }}, @{ Name = "SMTP"; Expression = { ( Get-DistributionGroup -Identity $_ ).PrimarySMTPAddress } } | `
			ForEach-Object { $syncHash.dgDistsMember.AddChild( [pscustomobject]@{ Name = $_.Name; SMTP = $_.SMTP } ) }
	}

	WriteLog -LogText "Distribution Groups Owner $( $syncHash.DC.tbId[0] )"
}

########################################################
# Get all distributiongroups the user is set as owner for
function GetDistsOwnership
{
	$syncHash.dgDistsOwner.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgDistsOwnerTitleName; Binding = [System.Windows.Data.Binding]@{ Path = "Name" } } ) )
	$syncHash.dgDistsOwner.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgDistsOwnerTitleSmtp; Binding = [System.Windows.Data.Binding]@{ Path = "SMTP" } } ) )

	$dists = Get-DistributionGroup -Filter "CustomAttribute10 -like '*$( $syncHash.Data.user.EmailAddress )*'"
	if ( @( $dists ).Count -eq 0 ) { $syncHash.dgDistsOwner.AddChild( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrNoDistsOwner ; SMTP = "" } ) }
	else { $dists | ForEach-Object { $syncHash.dgDistsOwner.AddChild( [pscustomobject]@{ Name = $_.Name; SMTP = $_.PrimarySmtpAddress } ) } }

	WriteLog -LogText "Distribution Groups Owner $( $syncHash.DC.tbId[0] )"
}

################################################
# Get all shared mailboxes the user is member of
function GetSharedMembership
{
	$syncHash.dgSharedMember.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgSharedMemberTitleName; Binding = [System.Windows.Data.Binding]@{ Path = "Name" } } ) )
	$syncHash.dgSharedMember.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgSharedMemberTitlePermission; Binding = [System.Windows.Data.Binding]@{ Path = "Permission" } } ) )

	$shared = Get-AzureADUser -SearchString $syncHash.DC.tbId[0] | Get-AzureADUserMembership | Where-Object { $_.DisplayName -match "^MB" }
	if ( @( $shared ).Count -eq 0 ) { $syncHash.dgSharedMember.AddChild( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrNoSharedMember ; Permission = "" } ) }
	else
	{
		$list = New-Object System.Collections.ArrayList
		foreach ( $i in ( $shared.DisplayName | Select-Object @{ Name = "Name"; Expression = { $_ -replace "MB-" -split "-" | Select-Object -SkipLast 1 } }, @{ Name = "Permission"; Expression = { $_ -split "-" | Select-Object -Last 1 } } | Sort-Object Name ) )
		{
			if ( $list.Name -contains $i.Name )
			{
				( $list.Where( { $_.Name -eq $i.Name } ) | Select-Object -First 1 ).Permission += ", $( $i.Permission )"
			}
			else
			{
				[void]$list.Add( [pscustomobject]@{ Name = $i.Name; Permission = $i.Permission } )
			}
		}
		$list | ForEach-Object { $syncHash.dgSharedMember.AddChild( [pscustomobject]@{ Name = $_.Name; Permission = $_.Permission } ) }
	}

	WriteLog -LogText "Shared Mailboxes Membership $( $syncHash.DC.tbId[0] )"
}

#######################################################
# Get all shared mailboxes the user is set as owner for
function GetSharedOwnership
{
	$syncHash.dgSharedOwner.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgSharedOwnerTitleName; Binding = [System.Windows.Data.Binding]@{ Path = "Name" } } ) )
	$syncHash.dgSharedOwner.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgSharedOwnerTitlePermission; Binding = [System.Windows.Data.Binding]@{ Path = "SMTP" } } ) )

	$shared = Get-EXOMailBox -Filter "CustomAttribute10 -like '*$( $syncHash.Data.user.EmailAddress )*'"
	if ( @( $shared ).Count -eq 0 ) { $syncHash.dgSharedOwner.AddChild( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrNoSharedOwner ; SMTP = "" } ) }
	else { $shared | ForEach-Object { $syncHash.dgSharedOwner.AddChild( [pscustomobject]@{ Name = $_.DisplayName; SMTP = $_.PrimarySmtpAddress } ) } }

	WriteLog -LogText "Shared Mailboxes Ownership $( $syncHash.DC.tbId[0] )"
}

########################
# Set ellipse fill-color
function FillEllipse
{
	param ( $c, $co )
	$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.$c.Fill = $co } )
}

###############
# Write message
function ErrorMessage
{
	param( $Text, [switch] $ClearText )

	if ( $ClearText ) { $syncHash.tbCheckMessage.Text = $Text }
	else { $syncHash.tbCheckMessage.Text += "$( $syncHash.tbCheckMessage.Text )`n $( $Text )".Trim() }
	if ( $syncHash.tbCheckMessage.LineCount -lt 5 ) { $syncHash.rdMessage.Height = $syncHash.tbCheckMessage.LineCount * 20 }
}

#####################
# Reset ellipse color
function ClearEllipses
{
	$syncHash.Keys | Where-Object { $_ -like "el*" } | ForEach-Object { $syncHash.$_.Fill = "LightGray" }
}

function Reset
{
	$syncHash.DC.spInfo[0] = [System.Windows.Visibility]::Collapsed
	$syncHash.Data.user = $null
	$syncHash.DC.btnGetLogins[0] = $syncHash.Data.msgTable.ContentbtnGetLogins
	$syncHash.DC.btnGetDelegates[0] = $syncHash.Data.msgTable.ContentbtnGetDelegates
	$syncHash.DC.btnID[1] = $false
	$syncHash.tbLastO365Login.Text = ""
	$syncHash.tbLastTeamsLogins.Text = ""
	$syncHash.tbDevices.Text = ""
	$syncHash.dgDelegates.Items.Clear()
	$syncHash.dgDistsMember.Items.Clear()
	$syncHash.dgDistsOwner.Items.Clear()
	$syncHash.dgSharedMember.Items.Clear()
	$syncHash.dgSharedOwner.Items.Clear()
	$syncHash.imgIcon.Source = $null
	$syncHash.imgIcon.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.btnRemoveIcon[1] = $false
	ClearEllipses
}

################# Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force
Import-Module ActiveDirectory

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "btnGetDelegates"; Props = @(
	@{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetDelegates }
	@{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "btnGetDevices"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetDevices } ) } )
[void]$controls.Add( @{ CName = "btnGetDistsMember"; Props = @(
	@{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetDistsMember }
	@{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "btnGetDistsOwner"; Props = @(
	@{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetDistsOwner }
	@{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "btnGetIcon"; Props = @(
	@{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetIcon }
	@{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "btnGetLogins"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetLogins } ) } )
[void]$controls.Add( @{ CName = "btnGetSharedOwner"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetSharedOwner } ) } )
[void]$controls.Add( @{ CName = "btnGetSharedMember"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetSharedMember } ) } )
[void]$controls.Add( @{ CName = "btnID"; Props = @(
	@{ PropName = "Content"; PropVal = $msgTable.ContentbtnID }
	@{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRemoveIcon"; Props = @(
	@{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveIcon }
	@{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "lblADActiveCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblADActiveCheck } ) } )
[void]$controls.Add( @{ CName = "lblADCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblADCheck } ) } )
[void]$controls.Add( @{ CName = "lblADLockCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblADLockCheck } ) } )
[void]$controls.Add( @{ CName = "lblADMailCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblADMailCheck } ) } )
[void]$controls.Add( @{ CName = "lblADmsECheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblADmsECheck } ) } )
[void]$controls.Add( @{ CName = "lblID"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblID } ) } )
[void]$controls.Add( @{ CName = "lblLastO365Login"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLastO365Login } ) } )
[void]$controls.Add( @{ CName = "lblLastTeamsLogin"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLastTeamsLogin } ) } )
[void]$controls.Add( @{ CName = "lblOAccountCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOAccountCheck } ) } )
[void]$controls.Add( @{ CName = "lblOExchCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOExchCheck } ) } )
[void]$controls.Add( @{ CName = "lblOLicCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOLicCheck } ) } )
[void]$controls.Add( @{ CName = "lblOLoginCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOLoginCheck } ) } )
[void]$controls.Add( @{ CName = "lblOMigCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOMigCheck } ) } )
[void]$controls.Add( @{ CName = "spInfo"; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "spLogins"; Props = @( @{ PropName = "IsEnabled"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "tbCheckMessage"; Props = @( @{ PropName = "IsReadOnly"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "tbId"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbLastO365Login"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tiDelegates"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiDelegates } ) } )
[void]$controls.Add( @{ CName = "tiDevices"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiDevices } ) } )
[void]$controls.Add( @{ CName = "tiDists"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiDists } ) } )
[void]$controls.Add( @{ CName = "tiDistsMember"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiDistsMember } ) } )
[void]$controls.Add( @{ CName = "tiDistsOwner"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiDistsOwner } ) } )
[void]$controls.Add( @{ CName = "tiIcon"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiIcon } ) } )
[void]$controls.Add( @{ CName = "tiLogins"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiLogins } ) } )
[void]$controls.Add( @{ CName = "tiShared"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiShared } ) } )
[void]$controls.Add( @{ CName = "tiSharedMember"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiSharedMember } ) } )
[void]$controls.Add( @{ CName = "tiSharedOwner"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiSharedOwner } ) } )
[void]$controls.Add( @{ CName = "Window"; Props = @( @{ PropName = "Cursor"; PropVal = [System.Windows.Input.Cursors]::Arrow } ) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.msgTable = $msgTable

$syncHash.btnID.Add_Click( {
	try
	{
		$syncHash.Data.userAzure = Get-AzureADUser -Filter "mail eq '$( $syncHash.Data.user.EmailAddress )'" -ErrorAction Stop
		FillEllipse "elOAccountCheck" "LightGreen"

		if ( $syncHash.Data.userAzure.AccountEnabled )
		{
			FillEllipse "elOLoginCheck" "LightGreen"
		} else {
			ErrorMessage $syncHash.Data.msgTable.StrO365LoginDisabled
			FillEllipse "elOLoginCheck" "LightCoral"
		}

		if ( ( $syncHash.Data.userAzure | Get-AzureADUserMembership ).DisplayName -match "O365-MigPilots" )
		{
			FillEllipse "elOMigCheck" "LightGreen"
		}
		else
		{
			ErrorMessage $syncHash.Data.msgTable.StrO365NoMig
			FillEllipse "elOMigCheck" "LightCoral"
		}

		if ( $syncHash.Data.user.DistinguishedName -match $syncHash.Data.msgTable.CodeMsExchIgnoreOrg )
		{
			ErrorMessage $syncHash.Data.msgTable.StrO365IgnoreLicense
			FillEllipse "elOLicCheck" "LightGray"
		}
		else
		{
			if ( $syncHash.Data.userAzure.AssignedLicenses.SkuId -match ( Get-AzureADSubscribedSku | Where-Object { $_.SkuPartNumber -match "EnterprisePack" } ).SkuId )
			{
				FillEllipse "elOLicCheck" "LightGreen"
			}
			else
			{
				ErrorMessage $syncHash.Data.msgTable.StrO365NoLicens
				FillEllipse "elOLicCheck" "LightCoral"
			}
		}

		try
		{
			Get-EXOMailbox -Identity $syncHash.Data.user.EmailAddress -ErrorAction Stop
			FillEllipse "elOExchCheck" "LightGreen"
			$syncHash.DC.spInfo[0] = [System.Windows.Visibility]::Visible
		}
		catch
		{
			ErrorMessage $syncHash.Data.msgTable.StrO365NotFoundExchange
			FillEllipse "elOExchCheck" "LightCoral"
		}
	}
	catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException]
	{
		if ( $_.Exception -match "Connect-AzureAD" ) { ErrorMessage $syncHash.Data.msgTable.StrO365NoAzAdConnection }
	}
	catch
	{
		if ( $_.Exception -match "User Not Found" )
		{
			ErrorMessage $syncHash.Data.msgTable.StrO365NotFound
			FillEllipse "elOAccountCheck" "LightCoral"
		}
		else { ErrorMessage $_ }
	}
	WriteLog -LogText $syncHash.DC.tbId[0]
} )

$syncHash.tbId.Add_TextChanged( {
	Reset

	if ( $this.Text.Length -ge 4 )
	{
		try
		{
			$syncHash.Data.user = Get-ADUser -Identity $this.Text -Properties *
			FillEllipse "elADCheck" "LightGreen"

			if ( $null -eq $syncHash.Data.user.EmailAddress )
			{
				ErrorMessage $syncHash.Data.msgTable.StrErrNoMail
				FillEllipse "elADMailCheck" "LightCoral"
			}
			else { FillEllipse "elADMailCheck" "LightGreen" }

			if ( $syncHash.Data.user.Enabled ) { FillEllipse "elADActiveCheck" "LightGreen" }
			else
			{
				ErrorMessage $syncHash.Data.msgTable.StrErrAdDisabled
				FillEllipse "elADActiveCheck" "LightCoral"
			}

			if ( $syncHash.Data.user.LockedOut )
			{
				ErrorMessage $syncHash.Data.msgTable.StrErrAdLocked
				FillEllipse "elADLockCheck" "LightCoral"
			}
			else { FillEllipse "elADLockCheck" "LightGreen" }

			if ( $syncHash.Data.user.DistinguishedName -match $syncHash.Data.msgTable.CodeMsExchIgnoreOrg )
			{
				ErrorMessage $syncHash.Data.msgTable.StrIgnoreMsExch
				FillEllipse "elADmsECheck" "LightGray"
			}
			else
			{
				if ( $null -ne $syncHash.Data.user.msExchMailboxGuid )
				{
					ErrorMessage $syncHash.Data.msgTable.StrErrMsExch
					FillEllipse "elADmsECheck" "LightCoral"
				}
				else
				{
					FillEllipse "elADmsECheck" "LightGreen"
					$syncHash.DC.btnID[1] = $true
					$syncHash.btnID.Focus()
				}
			}
		}
		catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
		{
			ErrorMessage -Text $syncHash.Data.msgTable.StrErrADNF -ClearText
			FillEllipse "elADCheck" "LightCoral"
		}
		catch [Microsoft.ActiveDirectory.Management.ADServerDownException]
		{
			ErrorMessage $syncHash.Data.msgTable.StrErrAD
			FillEllipse "elADCheck" "LightGray"
		}
	}
} )
$syncHash.btnGetLogins.Add_Click( { GetLogins } )
$syncHash.btnGetDevices.Add_Click( { GetDevices } )
$syncHash.btnGetDelegates.Add_Click( { GetDelegates } )
$syncHash.Window.Add_ContentRendered( { $syncHash.tbId.Focus() } )

$syncHash.btnGetDistsMember.Add_Click( { GetDistsMembership } )
$syncHash.btnGetDistsOwner.Add_Click( { GetDistsOwnership } )
$syncHash.btnGetSharedMember.Add_Click( { GetSharedMembership } )
$syncHash.btnGetSharedOwner.Add_Click( { GetSharedOwnership } )
$syncHash.btnGetIcon.Add_Click( {
	try
	{
		$syncHash.DC.btnGetIcon[1] = $false
		$icon = Get-UserPhoto -Identity $syncHash.Data.user.EmailAddress -ErrorAction Stop
		$syncHash.imgIcon.Visibility = [System.Windows.Visibility]::Visible
		$syncHash.imgIcon.Source = $icon.PictureData
		$syncHash.DC.btnRemoveIcon[1] = $true
	}
	catch
	{
		$syncHash.imgIcon.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.DC.btnRemoveIcon[1] = $false
		$syncHash.btnRemoveIcon.Content = $syncHash.Data.msgTable.StrNoImage
	}
} )
$syncHash.btnRemoveIcon.Add_Click( { Remove-UserPhoto -Identity $syncHash.Data.user.EmailAddress } )

$syncHash.tiLogins.Add_GotFocus( {
	$this.Background = $null
} )

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash