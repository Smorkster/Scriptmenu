<#
.Synopsis Check status of Office365-account
.Description Check status of a users Office365-account, can do some administration
.State Prod
.Author Smorkster (smorkster)
#>

#####################
# Reset ellipse color
function ClearEllipses
{
	$syncHash.Keys | Where-Object { $_ -like "el*" } | ForEach-Object { $syncHash.$_.Fill = "LightGray" }
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

########################
# Set ellipse fill-color
function FillEllipse
{
	param ( $c, $co )
	$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.$c.Fill = $co } )
}

###################
# Get any delegates
function GetDelegates
{
	$syncHash.dgDelegates.Items.Clear()

	$OFS = ","
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
					$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.tbCheckMessage.Text += "`n$( $syncHash.Data.msgTable.ErrMsgNoCalendar )" } )
					$eh = WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogNoCal -UserInput $syncHash.Data.user.EmailAddress -Severity "OtherFail"
				}
			}
		}
	}

	$logDelegates = ""
	if ( @( $mailDelegates ).Count -gt 0 )
	{
		$logDelegates = "$( $syncHash.Data.msgTable.LogMailDelegatesTitle ) $( @( $mailDelegates ).Count )`n"
		$mailDelegates | ForEach-Object {
			$syncHash.dgDelegates.AddChild( [pscustomobject]@{ "Folder" = $_.FolderName; "User" = $_.User; "Permission" = [string]$_.AccessRights } )
			
		}
	}
	else { $syncHash.dgDelegates.AddChild( [pscustomobject]@{ "Folder" = $syncHash.Data.msgTable.StrNoMailDelegates; "User" = ""; "Permission" = "" } ) }

	if ( @( $calendarDelegates ).Count -gt 0 )
	{
		$logDelegates += "$( $syncHash.Data.msgTable.LogCalendarDelegatesTitle ) $( @( $calendarDelegates ).Count )"
		$calendarDelegates | ForEach-Object { $syncHash.dgDelegates.AddChild( [pscustomobject]@{ "Folder" = $_.FolderName; "User" = $_.User; "Permission" = [string]$_.AccessRights } ) }
	}
	else { $syncHash.dgDelegates.AddChild( [pscustomobject]@{ "Folder" = $syncHash.Data.msgTable.StrNoMailDelegates; "User" = ""; "Permission" = "" } ) }

	if ( $logDelegates -eq "" ) { $logText = $syncHash.Data.msgTable.LogNoDelegates }
	else { $logText = $logDelegates.Trim() }

	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogGetDelegates )`n$logText" -UserInput $syncHash.Data.user.EmailAddress -Success ( $null -eq $eh ) | Out-Null
}

#################################
# Get devices registered for user
function GetDevices
{
	$syncHash.dgDevices.Items.Clear()
	if ( ( $devices = Get-AzureADUserRegisteredDevice -ObjectId $syncHash.Data.userAzure.ObjectId ).Count -gt 0 )
	{
		$OFS = "`n"
		$devices | ForEach-Object { $syncHash.dgDevices.AddChild( $_ ) }
		$logText = [string]( $devices.DisplayName | Sort-Object )
	}
	else
	{
		$syncHash.dgDevices.AddChild( [pscustomobject]@{ DisplayName = $syncHash.Data.msgTable.StrNoDevices; ApproximateLastLogonTimeStamp = 0 } )
		$logText = $syncHash.Data.msgTable.LogNoDevices
	}

	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogGetDevices )`n$logText" -UserInput $syncHash.Data.user.EmailAddress -Success $true | Out-Null
}

##################################################
# Get all distributiongroups the user is member of
function GetDistsMembership
{
	$syncHash.dgDistsMember.Items.Clear()
	$dists = Get-AzureADUser -SearchString $syncHash.DC.tbId[0] | Get-AzureADUserMembership | Where-Object { $_.DisplayName -match "^DL" }

	if ( @( $dists ).Count -eq 0 )
	{
		$syncHash.dgDistsMember.AddChild( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrNoDistsMember ; SMTP = "" } )
		$logText = $syncHash.Data.msgTable.LogNoDistsMember
	}
	else
	{
		$OFS = "`n"
		$dists.DisplayName | `
			ForEach-Object { $_ -replace "DL-" -split "-"  | Select-Object -SkipLast 1 } | `
			Select-Object @{ Name = "Name"; Expression = { $_ }}, @{ Name = "SMTP"; Expression = { ( Get-DistributionGroup -Identity $_ ).PrimarySMTPAddress } } | `
			ForEach-Object { $syncHash.dgDistsMember.AddChild( [pscustomobject]@{ Name = $_.Name; SMTP = $_.SMTP } ) }
		$logText = [string]( $dists.DisplayName )
	}

	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogGetDistMemberships )`n$logText"-UserInput $syncHash.Data.user.EmailAddress -Success $true | Out-Null
}

#########################################################
# Get all distributiongroups the user is set as owner for
function GetDistsOwnership
{
	$syncHash.dgDistsOwner.Items.Clear()
	$dists = Get-DistributionGroup -Filter "CustomAttribute10 -like '*$( $syncHash.Data.user.EmailAddress )*'"
	if ( @( $dists ).Count -eq 0 )
	{
		$syncHash.dgDistsOwner.AddChild( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrNoDistsOwner ; SMTP = "" } )
		$logText = $syncHash.Data.msgTable.LogNoDistsOwner
	}
	else
	{
		$OFS = "`n"
		$dists | ForEach-Object { $syncHash.dgDistsOwner.AddChild( [pscustomobject]@{ Name = $_.Name; SMTP = $_.PrimarySmtpAddress } ) }
		$logText = [string]( $dists.Name )
	}

	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogGetDistOwnerships )`n$logText" -UserInput $syncHash.Data.user.EmailAddress -Success $true | Out-Null
}

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
			$syncHash.DC.tbLastTeamsLogins[0] = $TeamsLoginText
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
}

################################################
# Get all shared mailboxes the user is member of
function GetSharedMembership
{
	$syncHash.dgSharedMember.Items.Clear()
	$shared = Get-AzureADUser -SearchString $syncHash.DC.tbId[0] | Get-AzureADUserMembership | Where-Object { $_.DisplayName -match "^MB" }
	if ( @( $shared ).Count -eq 0 )
	{
		$syncHash.dgSharedMember.AddChild( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrNoSharedMember ; Permission = "" } )
		$logText = $syncHash.Data.msgTable.LogNoSharedMember
	}
	else
	{
		$list = [System.Collections.ArrayList]::new()
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
		$OFS = "`n"
		$logText = [string]( $shared.DisplayName | Sort-Object )
	}

	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogGetSharedMemberships )`n$logText" -UserInput $syncHash.DC.tbId[0] -Success $true | Out-Null
}

#######################################################
# Get all shared mailboxes the user is set as owner for
function GetSharedOwnership
{
	$syncHash.dgSharedOwner.Items.Clear()
	$shared = Get-EXOMailBox -Filter "CustomAttribute10 -like '*$( $syncHash.Data.user.EmailAddress )*'"
	if ( @( $shared ).Count -eq 0 )
	{
		$syncHash.dgSharedOwner.AddChild( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrNoSharedOwner ; SMTP = "" } )
		$logText = $syncHash.Data.msgTable.LogNoSharedOwner
	}
	else
	{
		$OFS = "`n"
		$shared | ForEach-Object { $syncHash.dgSharedOwner.AddChild( [pscustomobject]@{ Name = $_.DisplayName; SMTP = $_.PrimarySmtpAddress } ) }
		$logText = [string]( $shared.DisplayName )
	}

	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogGetOwnershipShared )`n$logText"-UserInput $syncHash.Data.user.EmailAddress -Success $true | Out-Null
}

function Reset
{
	$syncHash.DC.spInfo[0] = [System.Windows.Visibility]::Collapsed
	$syncHash.Data.user = $null
	$syncHash.DC.btnGetLogins[0] = $syncHash.Data.msgTable.ContentbtnGetLogins
	$syncHash.DC.btnGetDelegates[0] = $syncHash.Data.msgTable.ContentbtnGetDelegates
	$syncHash.DC.btnID[1] = $false
	$syncHash.DC.tbLastO365Login[0] = ""
	$syncHash.DC.tbLastTeamsLogins[0] = ""
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
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]
Import-Module ActiveDirectory

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "btnActiveLogin"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnActiveLogin } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnGetDelegates"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetDelegates } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "btnGetDevices"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetDevices } ) } )
[void]$controls.Add( @{ CName = "btnGetDistsMember"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetDistsMember } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "btnGetDistsOwner"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetDistsOwner } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "btnGetIcon"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetIcon } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "btnGetLogins"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetLogins } ) } )
[void]$controls.Add( @{ CName = "btnGetSharedOwner"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetSharedOwner } ) } )
[void]$controls.Add( @{ CName = "btnGetSharedMember"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetSharedMember } ) } )
[void]$controls.Add( @{ CName = "btnID"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnID } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnRemoveIcon"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveIcon } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "cbActiveLogin"; Props = @( @{ PropName = "IsChecked"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "gbAD"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgbAD } ) } )
[void]$controls.Add( @{ CName = "gbO365"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgbO365 } ) } )
[void]$controls.Add( @{ CName = "lblActiveLogin"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblActiveLogin } ) } )
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
[void]$controls.Add( @{ CName = "tbLastTeamsLogins"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
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

$syncHash.btnActiveLogin.Add_Click( {
	Set-AzureADUser -ObjectId $syncHash.Data.userAzure.ObjectId -AccountEnabled $syncHash.DC.cbActiveLogin[0]
	WriteLogTest -Text $syncHash.Data.msgTable.LogSetActive -UserInput $syncHash.Data.userAzure.ObjectId -Success $true | Out-Null
} )
$syncHash.btnGetDelegates.Add_Click( { GetDelegates } )
$syncHash.btnGetDevices.Add_Click( { GetDevices } )
$syncHash.btnGetDistsMember.Add_Click( { GetDistsMembership } )
$syncHash.btnGetDistsOwner.Add_Click( { GetDistsOwnership } )
# Retrieve and display the users accont icon
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
		$eh = WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogGetPhoto -UserInput $syncHash.Data.user.EmailAddress -Severity "OtherFail" | Out-Null
	}
	WriteLogTest -Text $syncHash.Data.msgTable.LogGetUserPhoto -UserInput $syncHash.Data.user.EmailAddress -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )
$syncHash.btnGetLogins.Add_Click( { GetLogins } )
$syncHash.btnGetSharedMember.Add_Click( { GetSharedMembership } )
$syncHash.btnGetSharedOwner.Add_Click( { GetSharedOwnership } )
# Check status for the users AzureAD-account
$syncHash.btnID.Add_Click( {
	try
	{
		$syncHash.Data.userAzure = Get-AzureADUser -Filter "mail eq '$( $syncHash.Data.user.EmailAddress )'" -ErrorAction Stop
		FillEllipse "elOAccountCheck" "LightGreen"

		# Is the account enabled?
		if ( $syncHash.Data.userAzure.AccountEnabled )
		{
			FillEllipse "elOLoginCheck" "LightGreen"
			$syncHash.DC.cbActiveLogin[0] = $true
		}
		else
		{
			ErrorMessage $syncHash.Data.msgTable.StrO365LoginDisabled
			FillEllipse "elOLoginCheck" "LightCoral"
			$syncHash.DC.cbActiveLogin[0] = $false
		}

		# Is the account member of O365-MigPilots?
		if ( ( $syncHash.Data.userAzure | Get-AzureADUserMembership ).DisplayName -match "O365-MigPilots" )
		{
			FillEllipse "elOMigCheck" "LightGreen"
		}
		else
		{
			ErrorMessage $syncHash.Data.msgTable.StrO365NoMig
			FillEllipse "elOMigCheck" "LightCoral"
		}

		# Check org
		if ( $syncHash.Data.user.DistinguishedName -match $syncHash.Data.msgTable.CodeMsExchIgnoreOrg )
		{
			ErrorMessage $syncHash.Data.msgTable.StrO365IgnoreLicense
			FillEllipse "elOLicCheck" "LightGray"
		}
		else
		{
			# Do the account have the correct licens?
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

		# Check if account is synched to Exchange
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
			$eh += WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogNotInExc -UserInput $syncHash.Data.user.EmailAddress -Severity "OtherFail"
		}
	}
	# No open connection to Azure-online services
	catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException]
	{
		if ( $_.Exception -match "Connect-AzureAD" )
		{
			ErrorMessage $syncHash.Data.msgTable.ErrMsgO365NoAzAdConnection
			$eh += WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogNotConn -UserInput $syncHash.Data.msgTable.StrErrGetUsr -Severity "OtherFail"
		}
	}
	# User was not found
	catch
	{
		if ( $_.Exception -match "User Not Found" )
		{
			ErrorMessage $syncHash.Data.msgTable.StrO365NotFound
			FillEllipse "elOAccountCheck" "LightCoral"
			$eh += WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogNotFoundAzAd -UserInput $syncHash.Data.user.EmailAddress -Severity "OtherFail"
		}
		else
		{
			ErrorMessage $_
			$eh += WriteErrorlogTest -LogText $_ -UserInput "$( $syncHash.Data.msgTable.ErrLogSomeError )`n$( $syncHash.Data.user.EmailAddress )" -Severity "OtherFail"
		}
	}
	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogGetUserAzAd )" -UserInput $syncHash.DC.tbId[0] -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
} )
# Remove the user ikon
$syncHash.btnRemoveIcon.Add_Click( {
	Remove-UserPhoto -Identity $syncHash.Data.user.EmailAddress
	WriteLogTest -Text $syncHash.Data.msgTable.LogRemovePhoto -UserInput $syncHash.Data.user.EmailAddress -Success $true | Out-Null
} )
# Change checked depending on the status of enabled for account
$syncHash.cbActiveLogin.Add_Checked( { $syncHash.DC.btnActiveLogin[1] = $this.IsChecked -ne $syncHash.Data.userAzure.AccountEnabled } )
$syncHash.cbActiveLogin.Add_Unchecked( { $syncHash.DC.btnActiveLogin[1] = $this.IsChecked -ne $syncHash.Data.userAzure.AccountEnabled } )
# If Stackpanel get enabled, info for last login is retrieved
$syncHash.spLogins.Add_IsEnabledChanged( {
	if ( $this.IsEnabled )
	{ WriteLogTest -Text "$( $syncHash.Data.msgTable.LogGetLastLogin )`n$( $syncHash.Data.msgTable.LogLastLoginO365 ) $( $syncHash.DC.tbLastO365Login[0] )`n$( $syncHash.Data.msgTable.LogLastLoginTeams ) $( $syncHash.DC.tbLastTeamsLogins[0] )" -UserInput $syncHash.Data.user.EmailAddress -Success $true | Out-Null }
} )
$syncHash.tbId.Add_TextChanged( {
	Reset

	if ( $this.Text.Length -ge 4 )
	{
		try
		{
			$syncHash.Data.user = Get-ADUser -Identity $this.Text -Properties *
			FillEllipse "elADCheck" "LightGreen"

			# Do the AD-user have an emailaddress?
			if ( $null -eq $syncHash.Data.user.EmailAddress )
			{
				ErrorMessage $syncHash.Data.msgTable.StrErrNoMail
				FillEllipse "elADMailCheck" "LightCoral"
			}
			else { FillEllipse "elADMailCheck" "LightGreen" }

			# Is the AD-User active?
			if ( $syncHash.Data.user.Enabled ) { FillEllipse "elADActiveCheck" "LightGreen" }
			else
			{
				ErrorMessage $syncHash.Data.msgTable.StrErrAdDisabled
				FillEllipse "elADActiveCheck" "LightCoral"
			}

			# Is the AD-user locked
			if ( $syncHash.Data.user.LockedOut )
			{
				ErrorMessage $syncHash.Data.msgTable.StrErrAdLocked
				FillEllipse "elADLockCheck" "LightCoral"
			}
			else { FillEllipse "elADLockCheck" "LightGreen" }

			# Check org for user
			if ( $syncHash.Data.user.DistinguishedName -match $syncHash.Data.msgTable.CodeMsExchIgnoreOrg )
			{
				ErrorMessage $syncHash.Data.msgTable.StrIgnoreMsExch
				FillEllipse "elADmsECheck" "LightGray"
			}
			else
			{
				# Verify if msExchMailboxGuid is empty
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
		# User was not found in AD
		catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
		{
			ErrorMessage -Text $syncHash.Data.msgTable.StrErrADNF -ClearText
			FillEllipse "elADCheck" "LightCoral"
			$eh += WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogNotFoundAd -UserInput $this.Text -Severity "UserInputFail"
		}
		# Couldn't connect to AD
		catch [Microsoft.ActiveDirectory.Management.ADServerDownException]
		{
			ErrorMessage $syncHash.Data.msgTable.StrErrAD
			FillEllipse "elADCheck" "LightGray"
			$eh += WriteErrorlogTest -LogText $syncHash.Data.msgTable.ErrLogConnFailAd -UserInput $this.Text -Severity "ConnectionFail"
		}
		WriteLogTest -Text $syncHash.Data.msgTable.LogGetUserAd -UserInput $this.Text -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
	}
} )
$syncHash.tiLogins.Add_GotFocus( { $this.Background = $null } )
$syncHash.Window.Add_ContentRendered( {
	$syncHash.dgDelegates.Columns[0].Header = $syncHash.Data.msgTable.ContentdgDelegatesColFolder
	$syncHash.dgDelegates.Columns[1].Header = $syncHash.Data.msgTable.ContentdgDelegatesColUser
	$syncHash.dgDelegates.Columns[2].Header = $syncHash.Data.msgTable.ContentdgDelegatesColPerm
	$syncHash.dgSharedMember.Columns[0].Header = $syncHash.Data.msgTable.ContentdgSharedMemberColName
	$syncHash.dgSharedMember.Columns[1].Header = $syncHash.Data.msgTable.ContentdgSharedMemberColPermission
	$syncHash.dgSharedOwner.Columns[0].Header = $syncHash.Data.msgTable.ContentdgSharedOwnerColName
	$syncHash.dgSharedOwner.Columns[1].Header = $syncHash.Data.msgTable.ContentdgSharedOwnerColSmtp
	$syncHash.dgDistsMember.Columns[0].Header = $syncHash.Data.msgTable.ContentdgDistsMemberColName
	$syncHash.dgDistsMember.Columns[1].Header = $syncHash.Data.msgTable.ContentdgDistsMemberColSmtp
	$syncHash.dgDistsOwner.Columns[0].Header = $syncHash.Data.msgTable.ContentdgDistsOwnerColName
	$syncHash.dgDistsOwner.Columns[1].Header = $syncHash.Data.msgTable.ContentdgDistsOwnerColSmtp
	$syncHash.dgDevices.Columns[0].Header = $syncHash.Data.msgTable.ContentdgDevicesColDisplayName
	$syncHash.dgDevices.Columns[1].Header = $syncHash.Data.msgTable.ContentdgDevicesColLastLogin

	$this.Top = 20
	$syncHash.tbId.Focus()
} )

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash
