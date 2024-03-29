<#
.Synopsis Editera en användares autoreply
.Description Ange text för autoreply samt ange start och slutdatum
.Author Smorkster (smorkster)
#>

##################################
# Resets controls to defaul values
function ResetControls
{
	$syncHash.tbAutoReply.Text = ""
	$syncHash.DC.cbActivate[1] = $false
	$syncHash.DC.cbStartHour[0] = 0
	$syncHash.DC.cbStartMinute[0] = 0
	$syncHash.DC.cbEndHour[0] = 0
	$syncHash.DC.cbEndMinute[0] = 0
}

##################################
# Set end date of message validity
function UpdateEnd
{
	$syncHash.Data.End = $syncHash.DC.dpEnd[0].ToShortDateString()
	if ( $syncHash.DC.cbEndHour[0] -lt 10 ) { $syncHash.Data.End += " 0$( $syncHash.DC.cbEndHour[0] ):" }
	else { $syncHash.Data.End += " $( $syncHash.DC.cbEndHour[0] ):" }

	if ( $syncHash.DC.cbEndMinute[0] -lt 10 ) { $syncHash.Data.End += "0$( $syncHash.DC.cbEndMinute[0] )" }
	else { $syncHash.Data.End += $syncHash.DC.cbEndMinute[0] }
}

####################################
# Set start date of message validity
function UpdateStart
{
	$syncHash.Data.Start = $syncHash.DC.dpStart[0].ToShortDateString()
	if ( $syncHash.DC.cbStartHour[0] -lt 10 ) { $syncHash.Data.Start += " 0$( $syncHash.DC.cbStartHour[0] ):" }
	else { $syncHash.Data.Start += " $( $syncHash.DC.cbStartHour[0] ):" }

	if ( $syncHash.DC.cbStartMinute[0] -lt 10 ) { $syncHash.Data.Start += "0$( $syncHash.DC.cbStartMinute[0] )" }
	else { $syncHash.Data.Start += $syncHash.DC.cbStartMinute[0] }
}

########################
# Summarize the settings
function UpdateSummary
{
	param ( $Text )

	UpdateEnd
	UpdateStart
	if ( $Text )
	{
		$syncHash.DC.tbSummary[0] = $Text
	}
	else
	{
		if ( $syncHash.DC.cbActivate[1] )
		{
			$syncHash.DC.tbSummary[0] = $syncHash.Data.msgTable.StrSetAutoReplyStart
			if ( $syncHash.DC.cbScheduled[1] )
			{
				$syncHash.DC.tbSummary[0] += " $( $syncHash.Data.msgTable.StrSetAutoReplyScheduled ) $( $syncHash.Data.Start )"

				if ( $syncHash.DC.rbEndManually[1] )
				{
					$syncHash.DC.tbSummary[0] += ", $( $syncHash.Data.msgTable.StrSetAutoReplyScheduledManEnd )"
				}
				else
				{
					$syncHash.DC.tbSummary[0] += ", $( $syncHash.Data.msgTable.StrSetAutoReplyScheduleEnd ) $( $syncHash.Data.End )"
				}
			}
			else
			{
				$syncHash.DC.tbSummary[0] += " $( $syncHash.Data.msgTable.StrSetAutoReplyNotScheduled )"
			}
		}
		else
		{
			$syncHash.DC.tbSummary[0] = $syncHash.Data.msgTable.StrDisableAutoReply
		}
	}
}

################# Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]
Import-Module ActiveDirectory

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "btnId"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnId } ) } )
[void]$controls.Add( @{ CName = "btnSet"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSet } ) } )
[void]$controls.Add( @{ CName = "cbActivate"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentcbActivate } ; @{ PropName = "IsChecked"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "cbEndHour"; Props = @( @{ PropName = "SelectedIndex"; PropVal = 23 } ) } )
[void]$controls.Add( @{ CName = "cbEndMinute"; Props = @( @{ PropName = "SelectedIndex"; PropVal = 59 } ) } )
[void]$controls.Add( @{ CName = "cbScheduled"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentcbScheduled } ; @{ PropName = "IsChecked"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "cbStartHour"; Props = @( @{ PropName = "SelectedIndex"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "cbStartMinute"; Props = @( @{ PropName = "SelectedIndex"; PropVal = 0 } ) } )
[void]$controls.Add( @{ CName = "dpEnd"; Props = @( @{ PropName = "SelectedDate"; PropVal = [datetime]::Now } ) } )
[void]$controls.Add( @{ CName = "dpStart"; Props = @( @{ PropName = "SelectedDate"; PropVal = [datetime]::Now } ) } )
[void]$controls.Add( @{ CName = "lblAutoReply"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblAutoReply } ) } )
[void]$controls.Add( @{ CName = "lblEnd"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblEnd } ) } )
[void]$controls.Add( @{ CName = "lblId"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblId } ) } )
[void]$controls.Add( @{ CName = "lblNoUser"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblNoUser } ; @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "lblStart"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblStart } ) } )
[void]$controls.Add( @{ CName = "rbEndManually"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbEndManually } ; @{ PropName = "IsChecked" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "rbEndTime"; Props = @( @{ PropName = "Content" ; PropVal = $msgTable.ContentrbEndTime } ; @{ PropName = "IsChecked" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "spAutoReply"; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "spScheduled"; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "spSetEndTime"; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Visible } ) } )
[void]$controls.Add( @{ CName = "spUser"; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ; @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Visible } ) } )
[void]$controls.Add( @{ CName = "tbSummary"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.msgTable = $msgTable
$syncHash.Data.admin = Get-EXOMailbox -Identity ( Get-PSSession -Name "Exchange*" ).Runspace.OriginalConnectionInfo.Credential.UserName

00..23 | Foreach-Object {
	if ( $_ -lt 10 ) { $i = "0$_" } else { $i = $_ }
	[void] $syncHash.cbStartHour.Items.Add( $i )
	[void] $syncHash.cbEndHour.Items.Add( $i )
}
00..59 | Foreach-Object {
	if ( $_ -lt 10 ) { $i = "0$_" } else { $i = $_ }
	[void] $syncHash.cbStartMinute.Items.Add( $i )
	[void] $syncHash.cbEndMinute.Items.Add( $i )
}
$disabledDates = New-Object System.Windows.Controls.CalendarDateRange
$disabledDates.Start = ( Get-Date ).Date.AddDays( -365 )
$disabledDates.End = ( Get-Date ).Date.AddDays( -1 )
$syncHash.dpStart.BlackoutDates.Add( $disabledDates )
$syncHash.dpEnd.BlackoutDates.Add( $disabledDates )

$syncHash.cbActivate.Add_Checked( { $syncHash.DC.spAutoReply[0] = $true ; UpdateSummary } )
$syncHash.cbActivate.Add_Unchecked( { $syncHash.DC.spAutoReply[0] = $false ; UpdateSummary } )
$syncHash.cbScheduled.Add_Checked( { $syncHash.DC.spScheduled[0] = $true ; UpdateSummary } )
$syncHash.cbScheduled.Add_UnChecked( { $syncHash.DC.spScheduled[0] = $false ; UpdateSummary } )
$syncHash.rbEndManually.Add_Checked( { $syncHash.DC.spSetEndTime[0] = [System.Windows.Visibility]::Collapsed ; UpdateSummary } )
$syncHash.rbEndManually.Add_UnChecked( { $syncHash.DC.spSetEndTime[0] = [System.Windows.Visibility]::Visible ; UpdateSummary } )

$syncHash.dpStart.Add_SelectedDateChanged( { UpdateStart ; UpdateSummary } )
$syncHash.dpStart.Add_CalendarClosed( { UpdateStart ; UpdateSummary } )
$syncHash.cbStartHour.Add_SelectionChanged( { UpdateStart ; UpdateSummary } )
$syncHash.cbStartHour.Add_DropDownClosed( { UpdateStart ; UpdateSummary } )
$syncHash.cbStartMinute.Add_DropDownClosed( { UpdateStart ; UpdateSummary } )
$syncHash.cbStartMinute.Add_DropDownClosed( { UpdateStart ; UpdateSummary } )

$syncHash.dpEnd.Add_SelectedDateChanged( { UpdateEnd ; UpdateSummary } )
$syncHash.dpEnd.Add_CalendarClosed( { UpdateEnd ; UpdateSummary } )
$syncHash.cbEndHour.Add_SelectionChanged( { UpdateEnd ; UpdateSummary } )
$syncHash.cbEndHour.Add_DropDownClosed( { UpdateEnd ; UpdateSummary } )
$syncHash.cbEndMinute.Add_DropDownClosed( { UpdateEnd ; UpdateSummary } )
$syncHash.cbEndMinute.Add_DropDownClosed( { UpdateEnd ; UpdateSummary } )

$syncHash.tbId.Add_TextChanged( {
	$syncHash.DC.spUser[1] = [System.Windows.Visibility]::Visible
	$syncHash.DC.spUser[0] = $false
	$syncHash.DC.lblNoUser[1] = [System.Windows.Visibility]::Collapsed
} )
$syncHash.btnId.Add_Click( {
	ResetControls
	try
	{
		$syncHash.Data.user = Get-EXOMailbox -Identity ( ( Get-ADUser -Identity $syncHash.tbId.Text -Properties EmailAddress ).EmailAddress )
		$syncHash.DC.spUser[0] = $true
		$syncHash.Data.userAutoReplyConfig = Get-MailboxAutoReplyConfiguration -Identity $syncHash.Data.user.UserPrincipalName
		if ( $syncHash.Data.userAutoReplyConfig.AutoReplyState -eq "Disabled" )
		{
			$syncHash.DC.cbActivate[1] = $false
		}
		else
		{
			$syncHash.DC.cbActivate[1] = $true
			if ( $syncHash.Data.userAutoReplyConfig.AutoReplyState -eq "Scheduled" )
			{
				$syncHash.DC.cbScheduled[1] = $true
			}
		}

		$syncHash.DC.dpStart[0] = $syncHash.Data.userAutoReplyConfig.StartTime.Date
		$syncHash.DC.dpEnd[0] = $syncHash.Data.userAutoReplyConfig.EndTime.Date
		$syncHash.DC.cbStartHour[0] = $syncHash.Data.userAutoReplyConfig.StartTime.Hour
		$syncHash.DC.cbStartMinute[0] = $syncHash.Data.userAutoReplyConfig.StartTime.Minute
		$syncHash.DC.cbEndHour[0] = $syncHash.Data.userAutoReplyConfig.EndTime.Hour
		$syncHash.DC.cbEndMinute[0] = $syncHash.Data.userAutoReplyConfig.EndTime.Minute
		$b = New-Object -ComObject "htmlfile"
		$b.IHTMLDocument2_write( $syncHash.Data.userAutoReplyConfig.InternalMessage )
		$syncHash.tbAutoReply.Text = $b.body.innerText
	}
	catch
	{
		$syncHash.DC.lblNoUser[1] = [System.Windows.Visibility]::Visible
		$syncHash.DC.spUser[1] = [System.Windows.Visibility]::Collapsed
	}
} )
$syncHash.btnSet.Add_Click( {
	$syncHash.DC.spUser[1] = $false
	UpdateSummary -Text $syncHash.Data.msgTable.StrSetting
	Add-MailboxPermission -Identity $syncHash.Data.user.PrimarySmtpAddress -User $syncHash.Data.admin.PrimarySmtpAddress -AccessRights FullAccess -WarningAction SilentlyContinue | Out-Null

	$confParams = @{}
	$confParams.Identity = $syncHash.Data.user.PrimarySmtpAddress
	if ( $syncHash.DC.cbActivate[1] ) # Activate
	{
		$confParams.InternalMessage = $syncHash.tbAutoReply.Text
		$confParams.ExternalMessage = $syncHash.tbAutoReply.Text
		$confParams.Confirm = $false
		$confParams.ExternalAudience = "All"

		if ( $syncHash.DC.cbScheduled[1] ) # Scheduled
		{
			$confParams.AutoReplyState = "Scheduled"
			$confParams.StartTime = [datetime]::Parse( $syncHash.Data.Start ).ToUniversalTime()
			if ( $syncHash.DC.rbEndTime[1] ) # With an specified end date
			{
				$confParams.EndTime = [datetime]::Parse( $syncHash.Data.End ).ToUniversalTime()
			}
			else # Without an end date
			{
				$confParams.EndTime = [datetime]::Parse( $syncHash.Data.End ).ToUniversalTime().AddYears( 5 )
			}
		}
		else # Not scheduled
		{
			$confParams.AutoReplyState = "Enabled"
			$confParams.StartTime = ( Get-Date ).Date
		}
	}
	else # Disable
	{
		$confParams.AutoReplyState = "Disabled"
	}
	Set-MailboxAutoReplyConfiguration @confParams
	$syncHash.confParams = $confParams

	Remove-MailboxPermission -Identity $syncHash.Data.user.PrimarySmtpAddress -User $syncHash.Data.admin.PrimarySmtpAddress -AccessRights FullAccess -Confirm:$false
	$syncHash.DC.spUser[1] = $true
	if ( $syncHash.DC.cbActivate[1] ) { UpdateSummary -Text $syncHash.Data.msgTable.StrSettingDone }
	else { UpdateSummary -Text $syncHash.Data.msgTable.StrSettingInactiveDone }

	$OFS = "`n"
	WriteLogTest -Text "$( $syncHash.Data.msgTable.LogSummary )`n$( ( $confParams.GetEnumerator() | Sort-Object Key | ForEach-Object { "$( $_.Key ): $( $_.Value )" } ).Trim() )" -UserInput $syncHash.Data.user.PrimarySmtpAddress -Success $true | Out-Null
} )
$syncHash.Window.Add_Activated( {
	$syncHash.tbId.Focus()
	$this.Top = 20
} )

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash
