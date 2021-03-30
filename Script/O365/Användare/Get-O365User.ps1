<#
.Synopsis Kontrollera status för Office365 konto
.Description Kontrollerar status för en användares Office365 konto, ifall det synkats samt annan information
#>

function findlastlogon
{
	param ( $logons )

	$lastlogon = ( $logons[0].AuditData | ConvertFrom-Json ).CreationTime

	foreach ( $logon in $logons )
	{
		if ( ( $logon.AuditData | ConvertFrom-Json ).CreationTime -gt $lastlogon )
		{
			$lastlogon = ( $logon.AuditData | ConvertFrom-Json ).CreationTime
		}
	}

	$lastlogon = [datetime]::Parse( $lastlogon ).ToUniversalTime()
	if ( $lastlogon.Date -eq [datetime]::Today.AddDays( -1 ) )
	{
		if ( ( $lastlogon.Hour + 1 ) -lt 10 )
		{
			$hour = "0" + ( $lastlogon.Hour + 1 )
		}
		else
		{
			$hour = $lastlogon.Hour
		}
		if ( $lastlogon.Minute -lt 10 )
		{
			$minute = "0" + ( $lastlogon + 1 )
		}
		else
		{
			$minute = $lastlogon.Minute
		}
		$logontime = "$( $syncHash.Data.msgTable.StrYesterday ) $( $hour ):$( $minute )"
	}
	elseif ( $lastlogon.Date -eq [datetime]::Today )
	{
		if ( ( $lastlogon.Hour + 1 ) -lt 10 )
		{
			$hour = "0" + ( $lastlogon.Hour + 1 )
		}
		else
		{
			$hour = $lastlogon.Hour
		}
		if ( $lastlogon.Minute -lt 10 )
		{
			$minute = "0" + ( $lastlogon.Minute + 1 )
		}
		else
		{
			$minute = $lastlogon.Minute
		}
		$logontime = "$( $syncHash.Data.msgTable.StrToday ) $( $hour ):$( $minute )"
	}
	else
	{
		$logontime = $lastlogon.DateTime
	}
	return $logontime
}

############################
# Get last successful logins
function GetLogins
{
	$syncHash.DC.Window[0] = [System.Windows.Input.Cursors]::Wait
	$auditLog = Search-UnifiedAuditLog -StartDate ( [DateTime]::Today.AddDays( -10 ) ) -EndDate ( [DateTime]::Now ) -UserIds $syncHash.Data.user.EmailAddress
	$successfullAzureLoggins = $auditLog | Where-Object { $_.Operations -eq "UserLoggedIn" }
	$successfullTeamsLoggins = $auditLog | Where-Object { $_.Operations -eq "FileAccessed" -and $_.RecordType -eq "SharePointFileOperation" }

	$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.tbLogins.Text = "$( $syncHash.Data.msgTable.StrLastLogin ) " } )
	if ( $null -eq $successfullAzureLoggins ) { $syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.tbLogins.Text += $syncHash.Data.msgTable.StrNoLogin } ) }
	else { $syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.tbLogins.Text += ( findlastlogon -logons $successfullAzureLoggins ) } ) }

	$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.tbLogins.Text += "`n$( $syncHash.Data.msgTable.StrLastTeamsLogin ) " } )
	if ( $null -eq $successfullTeamsLoggins ) { $syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.tbLogins.Text += $syncHash.Data.msgTable.StrNoLogin } ) }
	else { $syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.tbLogins.Text += ( findlastlogon -logons $successfullTeamsLoggins ) } ) }
	$syncHash.DC.Window[0] = $null

	WriteLog -LogText "Logins $( $syncHash.tbId.Text )"
}

#################################
# Get devices registered for user
function GetDevices
{
	if ( ( $devices = Get-AzureADUserRegisteredDevice -ObjectId $syncHash.Data.userAzure.ObjectId ).Count -gt 0 )
	{
		foreach ( $device in $devices )
		{
			$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.tbDevices.Text += "`t $( $device.DisplayName )`n" } )
		}
	}

	WriteLog -LogText "Devices $( $syncHash.tbId.Text )"
}

###################
# Get any delegates
function GetDelegates
{
	$ofs = ","
	$d = Get-MailboxFolderPermission -Identity "$( $syncHash.Data.user.EmailAddress ):\$( $syncHash.Data.msgTable.StrInbox )" -ErrorAction Stop | Where-Object { $_.User -notmatch "Standard" -and $_.User -notmatch "Anonymous" }

	try
	{
		$d += Get-MailboxFolderPermission -Identity "$( $syncHash.Data.user.EmailAddress ):\$( $syncHash.Data.msgTable.StrCalendar )" -ErrorAction Stop | Where-Object { $_.User -notmatch "Standard" -and $_.User -notmatch "Anonymous" }
	}
	catch
	{
		if ( $_.CategoryInfo -like "*ManagementObjectNotFoundException*" )
		{
			try
			{
				$d += Get-MailboxFolderPermission -Identity "$( $syncHash.Data.user.EmailAddress ):\Calendar" -ErrorAction Stop | Where-Object { $_.User -notmatch "Standard" -and $_.User -notmatch "Anonymous" }
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

	$syncHash.dgDelegates.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgDelegatesTitleFolder; Width = 150; Binding = [System.Windows.Data.Binding]@{ Path = "Folder" } } ) )
	$syncHash.dgDelegates.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgDelegatesTitleUser; Width = 150; Binding = [System.Windows.Data.Binding]@{ Path = "User" } } ) )
	$syncHash.dgDelegates.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgDelegatesTitlePerm; Binding = [System.Windows.Data.Binding]@{ Path = "Permission" } } ) )
	$d | ForEach-Object { $syncHash.dgDelegates.AddChild( [pscustomobject]@{ "Folder" = $_.FolderName; "User" = $_.User; "Permission" = [string]$_.AccessRights } ) }

	WriteLog -LogText "Delegates $( $syncHash.tbId.Text )"
}

#########################################################
# Get all distributiongroups the user is set as owner for
function GetDists
{
	$syncHash.dgDists.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgDistsTitleName; Binding = [System.Windows.Data.Binding]@{ Path = "Name" } } ) )
	$syncHash.dgDists.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgDistsTitleSmtp; Binding = [System.Windows.Data.Binding]@{ Path = "SMTP" } } ) )

	$dists = Get-DistributionGroup -Filter "CustomAttribute10 -like '*$( $syncHash.Data.user.EmailAddress )*'"
	if ( @( $dists ).Count -eq 0 ) { $syncHash.dgDists.AddChild( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrNoDists ; SMTP = "" } ) }
	else { $dists | ForEach-Object { $syncHash.dgDists.AddChild( [pscustomobject]@{ Name = $_.Name; SMTP = $_.PrimarySmtpAddress } ) } }

	WriteLog -LogText "Distribution Groups $( $syncHash.tbId.Text )"
}

#########################################################
# Get all distributiongroups the user is set as owner for
function GetSharedMailboxes
{
	$syncHash.dgShared.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgSharedTitleName; Binding = [System.Windows.Data.Binding]@{ Path = "Name" } } ) )
	$syncHash.dgShared.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $syncHash.Data.msgTable.StrDgSharedTitleSmtp; Binding = [System.Windows.Data.Binding]@{ Path = "SMTP" } } ) )

	$shared = Get-EXOMailBox -Filter "CustomAttribute10 -like '*$( $syncHash.Data.user.EmailAddress )*'"
	if ( @( $shared ).Count -eq 0 ) { $syncHash.dgShared.AddChild( [pscustomobject]@{ Name = $syncHash.Data.msgTable.StrNoShared ; SMTP = "" } ) }
	else { $shared | ForEach-Object { $syncHash.dgShared.AddChild( [pscustomobject]@{ Name = $_.DisplayName; SMTP = $_.PrimarySmtpAddress } ) } }

	WriteLog -LogText "Shared Mailboxes $( $syncHash.tbId.Text )"
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

function ClearEllipses
{
	$syncHash.Keys | Where-Object { $_ -like "el*" } | ForEach-Object { $syncHash.$_.Fill = $null }
}

################# Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force
Import-Module ActiveDirectory

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "Window"; Props = @( @{ PropName = "Cursor"; PropVal = [System.Windows.Input.Cursors]::Arrow } ) } )
[void]$controls.Add( @{ CName = "lblID"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblID } ) } )
[void]$controls.Add( @{ CName = "btnID"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnID } ) } )
[void]$controls.Add( @{ CName = "lblADCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblADCheck } ) } )
[void]$controls.Add( @{ CName = "lblADMailCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblADMailCheck } ) } )
[void]$controls.Add( @{ CName = "lblADActiveCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblADActiveCheck } ) } )
[void]$controls.Add( @{ CName = "lblADLockCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblADLockCheck } ) } )
[void]$controls.Add( @{ CName = "lblADmsECheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblADmsECheck } ) } )
[void]$controls.Add( @{ CName = "lblOAccountCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOAccountCheck } ) } )
[void]$controls.Add( @{ CName = "lblOLoginCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOLoginCheck } ) } )
[void]$controls.Add( @{ CName = "lblOMigCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOMigCheck } ) } )
[void]$controls.Add( @{ CName = "lblOLicCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOLicCheck } ) } )
[void]$controls.Add( @{ CName = "lblOExchCheck"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOExchCheck } ) } )
[void]$controls.Add( @{ CName = "spInfo"; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "tiLogins"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiLogins } ) } )
[void]$controls.Add( @{ CName = "tiDevices"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiDevices } ) } )
[void]$controls.Add( @{ CName = "tiDelegates"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiDelegates } ) } )
[void]$controls.Add( @{ CName = "tiDists"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiDists } ) } )
[void]$controls.Add( @{ CName = "tiShared"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiShared } ) } )
[void]$controls.Add( @{ CName = "tiIcon"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiIcon } ) } )
[void]$controls.Add( @{ CName = "btnGetLogins"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetLogins } ) } )
[void]$controls.Add( @{ CName = "btnGetDevices"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetDevices } ) } )
[void]$controls.Add( @{ CName = "btnGetDelegates"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetDelegates } ) } )
[void]$controls.Add( @{ CName = "btnGetDists"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetDists } ) } )
[void]$controls.Add( @{ CName = "btnGetShared"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetShared } ) } )
[void]$controls.Add( @{ CName = "btnRemoveIcon"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRemoveIcon }; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnGetIcon"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetIcon } ) } )

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
	WriteLog -LogText $syncHash.tbId.Text
} )

$syncHash.tbId.Add_TextChanged( {
	$syncHash.tbLogins.Text = ""
	$syncHash.tbDevices.Text = ""
	$syncHash.dgDelegates.Items.Clear()
	$syncHash.dgDists.Items.Clear()
	$syncHash.dgShared.Items.Clear()
	$syncHash.imgIcon.Source = $null
	$syncHash.imgIcon.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.btnRemoveIcon[1] = $false
	ClearEllipses

	if ( $syncHash.tbId.Text.Length -ge 4 )
	{
		try
		{
			$syncHash.Data.user = Get-ADUser -Identity $syncHash.tbId.Text -Properties *
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
				else { FillEllipse "elADmsECheck" "LightGreen" }
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
$syncHash.btnGetDists.Add_Click( { GetDists } )
$syncHash.btnGetShared.Add_Click( { GetSharedMailboxes } )
$syncHash.btnGetIcon.Add_Click( {
	try
	{
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

[void] $syncHash.Window.ShowDialog()
