<#
.Synopsis List number of reinstallations
.Description Lists who has performed reinstallations between given dates. Information is gathered from SysMan.
#>

############################
# Show calendar for end date
function BtnEndDate_Click
{
	$syncHash.btnEndDate.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.DatePickerEnd.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.DatePickerEnd.IsDropDownOpen = $true
}

##############################
# Show calendar for start date
function BtnStartDate_Click
{
	$syncHash.btnStartDate.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.DatePickerStart.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.DatePickerStart.IsDropDownOpen = $true
}

#############################################
# Prepares controls and initializes operation
function BtnStart_Click
{
	$syncHash.installations.Clear()
	$syncHash.DC.UserView[0].Clear()
	$syncHash.DC.DescriptionView[0].Clear()
	$syncHash.btnStartDate.IsEnabled = $syncHash.btnEndDate.IsEnabled = $syncHash.btnStart.IsEnabled = $syncHash.btnExport.IsEnabled = $syncHash.DatePickerStart.IsEnabled = $syncHash.DatePickerEnd.IsEnabled = $false
	$syncHash.SelectedStart = $syncHash.DatePickerStart.SelectedDate
	$syncHash.SelectedEnd = $syncHash.DatePickerEnd.SelectedDate
	if ( $syncHash.collect.Runspace.RunspaceStateInfo.State -eq "Opened" ) { $syncHash.collect.Runspace.Close() ; $syncHash.collect.Runspace.Dispose() }

	# Start collecting data from SysMan
	$syncHash.collect = ( [powershell]::Create().AddScript( { param ( $syncHash )
		# Get installation information from SysMan API
		$logs = New-Object System.Collections.ArrayList
		$jobs = New-Object System.Collections.ArrayList
		$processingStart = $syncHash.SelectedStart
		$processingEnd = $processingStart.AddHours( 4 )
		$processingMax = $syncHash.SelectedEnd.AddDays( 1 )

		$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
		$RunspacePool = [runspacefactory]::CreateRunspacePool(
			1, #Min Runspaces
			10 #Max Runspaces
		)
		$RunspacePool.Open()

		$syncHash.Window.Dispatcher.Invoke( [action]{ $syncHash.Window.Title = $syncHash.msgTable.StrOpSetup }, "Normal" )
		do
		{
			$Runspace = [powershell]::Create()
			$Runspace.RunspacePool = $RunspacePool
			[void]$Runspace.AddScript( {
				param ( $processingStart, $processingEnd, $syncHash )
				( Invoke-RestMethod -Uri ( Invoke-Expression $syncHash.msgTable.CodeSysManUrl ) -Method Get -UseDefaultCredentials -ContentType "application/json" ).result | where { $_.LoggedBy -match $syncHash.msgTable.StrAdmPrefix -and $_.eventCode -eq "OSINST" }
			} )
			[void]$Runspace.AddArgument( $processingStart )
			[void]$Runspace.AddArgument( $processingEnd )
			[void]$Runspace.AddArgument( $syncHash )

			[void]$jobs.Add( @{ RS = $Runspace; H = $Runspace.BeginInvoke() } )
			$processingStart = $processingEnd
			$processingEnd = $processingEnd.AddHours( 4 )
		}
		until ( $processingEnd -gt $processingMax )

		# Wait for SysMan-jobs to finish
		$syncHash.Window.Dispatcher.Invoke( [action]{ $syncHash.Window.Title = $syncHash.msgTable.StrOpWaitData }, "Normal" )
		do
		{
			Start-Sleep -Milliseconds 10
			$syncHash.DC.Progress[0] = [double]( ( ( ( $jobs | where { $_.H.IsCompleted } ).Count ) / ( $jobs.Count ) ) * 100 )
		} until ( ( $jobs.H.IsCompleted -eq $false ).Count -eq 0 )

		$ticker = 0
		$syncHash.Window.Dispatcher.Invoke( [action]{ $syncHash.Window.Title = $syncHash.msgTable.StrOpRead }, "Normal" )
		foreach ( $j in $jobs )
		{
			$j.RS.EndInvoke( $j.H ) | foreach { [void]$logs.Add( $_ ) }
			$ticker++
			$syncHash.DC.Progress[0] = [double]( ( $ticker / $jobs.Count ) * 100 )
		}

		$jobs | foreach { $_.RS.Close(); $_.RS.Dispose() }
		$RunspacePool.Close()
		$syncHash.Window.Dispatcher.Invoke( [action]{ $syncHash.Window.Title = $syncHash.msgTable.StrWinTitle }, "Normal" )

		############################################
		# Load list of users, with installationcount

		if ( $logs.Count -eq 0 )
		{
			ShowMessageBox $syncHash.msgTable.StrNoInstallations
			$syncHash.Window.Dispatcher.Invoke( [action]{ $syncHash.Window.Title = $syncHash.msgTable.StrWinTitle }, "Normal" )
		}
		else
		{
			$loopCount = 0
			$syncHash.Window.Dispatcher.Invoke( [action]{ $syncHash.Window.Title = $syncHash.msgTable.StrOpCollect }, "Normal" )
			foreach ( $entry in $logs )
			{
				$entry.LoggedBy = ( Get-ADUser ( ( $entry.loggedBy -split $syncHash.msgTable.StrAdmPrefix )[1] ) ).Name
				$isUserInData = $false
				if ( $syncHash.installations.Count -gt 0 )
				{
					$listIndex = 0
					for ( $i = 0; $i -le $syncHash.installations.Count - 1; $i++ )
					{
						if ( $syncHash.installations[$i].User -eq $entry.loggedBy )
						{
							$isUserInData = $true
							$listIndex = $i
							break
						}
					}
				}

				if ( $isUserInData )
				{
					$computerEntry = New-Object -TypeName PSObject
					$computerEntry | Add-Member -Name "Computer" -MemberType NoteProperty -Value $entry.targetName
					$computerEntry | Add-Member -Name "Date" -MemberType NoteProperty -Value $entry.date
					$computerEntry | Add-Member -Name "Description" -MemberType NoteProperty -Value $entry.text

					$syncHash.installations[$listIndex].log.Add( $computerEntry ) | Out-Null
					$syncHash.installations[$listIndex].installations = [int]( [int]( $syncHash.installations[$listIndex].installations ) + 1 )
				}
				else
				{
					$newUser = New-Object -TypeName PSObject
					$newUser | Add-Member -Name 'User' -MemberType NoteProperty -Value $entry.LoggedBy
					$newUser | Add-Member -Name 'Installations' -MemberType NoteProperty -Value 1
					$newUser | Add-Member -Name 'Log' -MemberType NoteProperty -Value ( New-Object System.Collections.ArrayList )
					$syncHash.installations.Add( $newUser ) | Out-Null

					$computerEntry = New-Object -TypeName PSObject
					$computerEntry | Add-Member -Name "Computer" -MemberType NoteProperty -Value $entry.targetName
					$computerEntry | Add-Member -Name "Date" -MemberType NoteProperty -Value $entry.date
					$computerEntry | Add-Member -Name "Description" -MemberType NoteProperty -Value $entry.text
					$syncHash.installations[$syncHash.installations.Count-1].log.Add( $computerEntry ) | Out-Null
				}

				$loopCount++
				$syncHash.DC.Progress[0] = [double]( ( $loopCount / $logs.Count ) * 100 )
			}
		}

		$syncHash.installations | sort Installations -Descending | foreach `
		{
			$syncHash.DC.UserView[0].Add( [pscustomobject]@{ User = $_.User; Installations = $_.Installations } )
		}
		$syncHash.Window.Dispatcher.Invoke( [action] {
			WriteLog -LogText "$( $syncHash.DatePickerStart.SelectedDate.ToShortDateString() ) - $( $syncHash.DatePickerEnd.SelectedDate.ToShortDateString() ) = $( $logs.Count ) $( $syncHash.msgTable.StrLogEnding )" | Out-Null
			$syncHash.UserView.Items.Refresh()
			$syncHash.btnStartDate.IsEnabled = $syncHash.btnEndDate.IsEnabled = $true
			$syncHash.DC.Progress[0] = 0.0
			$syncHash.Window.Title = $syncHash.msgTable.StrWinTitle
			$syncHash.btnExport.IsEnabled = $syncHash.DC.UserView[0].Count -gt 0
			$syncHash.btnStartDate.Visibility = $syncHash.btnEndDate.Visibility = [System.Windows.Visibility]::Visible
			$syncHash.DatePickerStart.IsEnabled = $syncHash.DatePickerEnd.IsEnabled = $true
			$syncHash.DatePickerStart.BlackoutDates.Clear()
			$syncHash.DatePickerEnd.BlackoutDates.Clear()
			$syncHash.DatePickerStart.Text = ""
			$syncHash.DatePickerEnd.Text = ""
			$syncHash.DatePickerStart.Visibility = $syncHash.DatePickerEnd.Visibility = [System.Windows.Visibility]::Collapsed
		}, "Normal" )
		$logs.Clear()
	} ).AddArgument( $syncHash ) )
	$syncHash.collect.BeginInvoke()
}

############################
# Exports information to CSV
function BtnExport_Click
{
	$output = $syncHash.installations | sort Installations -Descending | foreach { [pscustomobject]@{ User = $_.User; OS_Installations = $_.Installations } } | ConvertTo-Csv -NoTypeInformation -Delimiter ";"
	$outputFile = WriteOutput -Output $output -FileExtension "csv" -Scoreboard
	ShowMessageBox "$( $syncHash.msgTable.StrExportPathMessage )`n$outputFile"
	$syncHash.btnExport.IsEnabled = $false
}

############################################################################################################################
# Calendar has closed, if calendarbutton for enddate is not visible, create blacked out dates previous to selected startdate
function DatePickerStart_CalendarClosed
{
	if ( $syncHash.DatePickerStart.Text -eq "" )
	{
		$syncHash.btnStartDate.Visibility = [System.Windows.Visibility]::Visible
		$syncHash.DatePickerStart.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.btnStart.IsEnabled = $false
	}
	else
	{
		if ( $syncHash.DatePickerEnd.Visibility -eq "Visible" )
		{
			$syncHash.btnStart.IsEnabled = $true
		}
		else
		{
			$syncHash.DatePickerEnd.BlackoutDates.Clear()
			$disabledDates = New-Object System.Windows.Controls.CalendarDateRange
			$disabledDates.Start = $syncHash.DatePickerStart.SelectedDate.AddDays( -31 )
			$disabledDates.End = $syncHash.DatePickerStart.SelectedDate.AddDays( -1 )
			$syncHash.DatePickerEnd.BlackoutDates.Add( $disabledDates )
		}
	}
}

#########################################################################################################################
# Calendar has closed, if calendarbutton for startdate is not visible, create blacked out dates after to selected enddate
function DatePickerEnd_CalendarClosed
{
	if ( $syncHash.DatePickerEnd.Text -eq "" )
	{
			$syncHash.btnEndDate.Visibility = [System.Windows.Visibility]::Visible
			$syncHash.DatePickerEnd.Visibility = [System.Windows.Visibility]::Collapsed
			$syncHash.btnStart.IsEnabled = $false
	}
	else
	{
		if ( $syncHash.DatePickerStart.Visibility -eq "Visible" )
		{
			$syncHash.btnStart.IsEnabled = $true
		}
		else
		{
			$syncHash.DatePickerStart.BlackoutDates.Clear()
			$disabledDates = New-Object System.Windows.Controls.CalendarDateRange
			$disabledDates.Start = $syncHash.DatePickerEnd.SelectedDate.AddDays( 1 )
			$disabledDates.End = $syncHash.DatePickerEnd.SelectedDate.AddDays( 31 )
			$syncHash.DatePickerStart.BlackoutDates.Add( $disabledDates )
		}
	}
}

###################################################################################
# User in userview is selected, get information of installations for selected dates
function UserView_SelectionChanged
{
	$syncHash.SelectedUser = $syncHash.UserView.SelectedItems[0]
	( [powershell]::Create().AddScript( { param ( $syncHash )
		####################################
		# Collect data from info from SysMan
		function GetUserInstallations
		{
			param ( $User )

			$UserLog = @( ( $syncHash.installations.Where( { $_.User -eq $User.User } ) ).log )
			$jobs = New-Object System.Collections.ArrayList
			$i = 1
			$t = ""

			$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
			$RunspacePool = [runspacefactory]::CreateRunspacePool(
				1, #Min Runspaces
				10 #Max Runspaces
			)
			$RunspacePool.Open()

			$syncHash.Window.Dispatcher.Invoke( [action]{ $syncHash.Window.Title = "$( $syncHash.msgTable.StrOpUserStart ) $( $User.User )" }, "Normal" )
			foreach ( $installation in $UserLog )
			{
				$Runspace = [powershell]::Create()
				$Runspace.RunspacePool = $RunspacePool
				$Runspace.AddScript( {
					param ( $in, $syncHash )
					try
					{
						$ofs = "`n"
						$r = Get-ADComputer ( $in.Computer ) -Properties MemberOf -ErrorAction Stop | select -ExpandProperty MemberOf | where { $_ -like "*_Wrk*PR*_PC*" } | foreach { ( ( $_ -split "=" )[1] -split "," )[0] }
						if ( $r.Count -eq 0 )
						{ $t = $syncHash.msgTable.StrOtherCompRole }
						else
						{
							$r | foreach {
								if ( ( $syncHash.msgTable.CodeAllowedCompOrgs -split "," | Foreach-Object -Begin { $ok = $false } -Process { if ( $r -match $_.Trim() ) { $ok = $true } } -End { $ok } ) -and `
								( $syncHash.msgTable.CodeAllowedCompRoles-split "," | Foreach-Object -Begin { $ok = $false } -Process { if ( $r -match $_.Trim() ) { $ok = $true } } -End { $ok } ) )
								{ $wrongType = 0 }
								else { $containsWrongType = $true }
							}
							if ( $containsWrongType ) { $wrongType = 1 }
							$t = [string]$r
						}
					}
					catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
					{
						$t = $syncHash.msgTable.StrComputerNotFound
					}
					catch
					{
						$t = $syncHash.msgTable.StrErrorADLookup
					}
					[pscustomobject]@{ Computer = $in.Computer; Date = ( Get-Date $in.Date ); Type = $t ; Description = $in.Description; WrongType = $wrongType }
				} )
				$Runspace.AddArgument( $installation )
				$Runspace.AddArgument( $syncHash )
				$jobs.Add( @{ Runspace = $Runspace; Handle = $Runspace.BeginInvoke() } )
				$i++
				$syncHash.DC.Progress[0] = [double]( ( $i / $UserLog.Count ) * 100 )
			}
			return @{ Jobs = $jobs; LogCount = $UserLog.Count; RSP = $RunspacePool }
		}

		[void] $syncHash.DC.DescriptionView[0].Clear()

		if ( $syncHash.SelectedUser )
		{
			$data = GetUserInstallations -User ( $syncHash.SelectedUser )

			$syncHash.Window.Dispatcher.Invoke( [action]{ $syncHash.Window.Title = $syncHash.msgTable.StrOpWaitData }, "Normal" )
			do
			{
				Start-Sleep -Milliseconds 500
				$completed = ( $data.Jobs | where { $_.Handle.IsCompleted -eq "Completed" } ).Count
				$syncHash.DC.Progress[0] = [double]( ( $completed / $data.Jobs.Count ) * 100 )
			} until ( $completed -eq $data.Jobs.Count )

			$ticker = 0
			$syncHash.Window.Dispatcher.Invoke( [action]{ $syncHash.Window.Title = $syncHash.msgTable.StrOpUserImporting }, "Normal" )
			foreach ( $j in $data.Jobs )
			{
				$syncHash.DC.DescriptionView[0].Add( $j.Runspace.EndInvoke( $j.Handle ) )
				$j.Runspace.Dispose()
				$ticker++
				$syncHash.DC.Progress[0] = [double]( ( $ticker / $data.Jobs.Count ) * 100 )
			}
			$data.RSP.Close()
		}
		$syncHash.Window.Dispatcher.Invoke( [action]{
			$syncHash.DescriptionView.Items.Refresh()
			$syncHash.Window.Title = $syncHash.msgTable.StrWinTitle
			$syncHash.DC.Progress[0] = 0.0
		}, "Normal" )
	} ).AddArgument( $syncHash ) ).BeginInvoke()
}

###########################################################
# Sort userlist depending on which columnheader was clicked
function SortUserList
{
	param ( $Column )

	if ( $Column -eq "User" )
	{ $items = $syncHash.DC.DescriptionView[0] | sort User, Installations }
	else
	{ $items = $syncHash.DC.DescriptionView[0] | sort Installations, User -Descending }
	$syncHash.DC.DescriptionView[0].Clear()
	$items | foreach { $syncHash.DC.DescriptionView[0].Add( $_ ) }
}

###################### Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "Progress"
	Props = @(
		@{ PropName = "Value"; PropVal = [double] 0 }
	) } )
[void]$controls.Add( @{ CName = "UserView"
	Props = @(
		@{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) }
	) } )
[void]$controls.Add( @{ CName = "DescriptionView"
	Props = @(
		@{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) }
	) } )
[void]$controls.Add( @{ CName = "UserHeader"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentUserCol }
	) } )
[void]$controls.Add( @{ CName = "InstallationsHeader"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentInstCol }
	) } )
[void]$controls.Add( @{ CName = "DescComputer"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentDescCompCol }
	) } )
[void]$controls.Add( @{ CName = "DescDate"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentDescDateCol }
	) } )
[void]$controls.Add( @{ CName = "DescRole"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentDescRoleCol }
	) } )
[void]$controls.Add( @{ CName = "DescDescription"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentDescDescriptionCol }
	) } )
[void]$controls.Add( @{ CName = "DescWT"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentDescWTCol }
	) } )
[void]$controls.Add( @{ CName = "btnStartDate"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentbtnStartDate }
	) } )
[void]$controls.Add( @{ CName = "btnEndDate"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentbtnEndDate }
	) } )
[void]$controls.Add( @{ CName = "btnStart"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentbtnStart }
	) } )
[void]$controls.Add( @{ CName = "btnExport"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentbtnExport }
	) } )
[void]$controls.Add( @{ CName = "Window"
	Props = @(
		@{ PropName = "Title"; PropVal = $msgTable.StrWinTitle }
	) } )

$syncHash = CreateWindowExt $controls

$syncHash.msgTable = $msgTable
$syncHash.installations = New-Object System.Collections.ArrayList

# Set listviewitems style-triggers to localized strings
# Indexes (1 and 2-4) are indexes of style elements in XAML-file
$syncHash.Window.Resources.Item( ( $syncHash.Window.Resources.Keys.Item( 1 ) ) ).triggers[2].value = $syncHash.msgTable.StrComputerNotFound
$syncHash.Window.Resources.Item( ( $syncHash.Window.Resources.Keys.Item( 1 ) ) ).triggers[3].value = $syncHash.msgTable.StrOtherCompRole
$syncHash.Window.Resources.Item( ( $syncHash.Window.Resources.Keys.Item( 1 ) ) ).triggers[4].value = $syncHash.msgTable.StrErrorADLookup

$syncHash.btnEndDate.Add_Click( { BtnEndDate_Click } )
$syncHash.btnStartDate.Add_Click( { BtnStartDate_Click } )
$syncHash.btnStart.Add_Click( { BtnStart_Click } )
$syncHash.btnExport.Add_Click( { BtnExport_Click } )
$syncHash.UserHeader.Add_Click( { SortUserList "User" } )
$syncHash.InstallationsHeader.Add_Click( { SortUserList "Inst" } )
$syncHash.DatePickerStart.Add_CalendarClosed( { DatePickerStart_CalendarClosed } )
$syncHash.DatePickerEnd.Add_CalendarClosed( { DatePickerEnd_CalendarClosed } )
$syncHash.UserView.Add_SelectionChanged( { UserView_SelectionChanged } )
$syncHash.Window.Add_ContentRendered( { $syncHash.Window.Top = 80; $syncHash.Window.Activate() } )
$syncHash.Window.Add_Closed( { Get-EventSubscriber | Unregister-Event } )

[void] $syncHash.Window.ShowDialog()
$syncHash.Window.Close()
$global:syncHash = $syncHash