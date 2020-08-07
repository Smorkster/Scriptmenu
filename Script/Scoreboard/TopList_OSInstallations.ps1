#Description = List number of reinstallations per month per user

############################
# Show calendar for end date
function BtnEndDate_Click
{
	$btnEndDate.Visibility = [System.Windows.Visibility]::Collapsed
	$DatePickerEnd.Visibility = [System.Windows.Visibility]::Visible
	$DatePickerEnd.IsDropDownOpen = $true
}

##############################
# Show calendar for start date
function BtnStartDate_Click
{
	$btnStartDate.Visibility = [System.Windows.Visibility]::Collapsed
	$DatePickerStart.Visibility = [System.Windows.Visibility]::Visible
	$DatePickerStart.IsDropDownOpen = $true
}

#############################################
# Prepares controls and initializes operation
function BtnStart_Click
{
	#TODO
	$UserView.Items.Clear()
	$DescriptionView.items.Clear()
	$btnStart.IsEnabled = $btnExport.IsEnabled = $DatePickerStart.IsEnabled = $DatePickerEnd.IsEnabled = $false

	LoadUserData

	$btnExport.IsEnabled = $UserView.Items.Count -gt 0
	$btnStartDate.Visibility = $btnEndDate.Visibility = [System.Windows.Visibility]::Visible
	$DatePickerStart.BlackoutDates.Clear()
	$DatePickerEnd.BlackoutDates.Clear()
	$DatePickerStart.Text = ""
	$DatePickerEnd.Text = ""
	$DatePickerStart.Visibility = $DatePickerEnd.Visibility = [System.Windows.Visibility]::Collapsed
}

############################
# Exports information to CSV
function BtnExport_Click
{
	$output = $installations | sort Installations -Descending | foreach { [pscustomobject]@{ User=$_.User; OS_Installations=$_.Installations } } | ConvertTo-Csv -NoTypeInformation -Delimiter ";"
	$outputFile = WriteOutput -Output $output -FileExtension "csv" -Scoreboard
	ShowMessageBox "List was exported to:`n$outputFile"
	$btnExport.IsEnabled = $false
}

############################################################################################################################
# Calendar has closed, if calendarbutton for enddate is not visible, create blacked out dates previous to selected startdate
function DatePickerStart_CalendarClosed
{
	if ( $DatePickerStart.Text -eq "" )
	{
		$btnStartDate.Visibility = [System.Windows.Visibility]::Visible
		$DatePickerStart.Visibility = [System.Windows.Visibility]::Collapsed
		$btnStart.IsEnabled = $false
	}
	else
	{
		if ( $DatePickerEnd.Visibility -eq "Visible" )
		{
			$btnStart.IsEnabled = $true
		}
		else
		{
			$DatePickerEnd.BlackoutDates.Clear()
			$disabledDates = New-Object System.Windows.Controls.CalendarDateRange
			$disabledDates.Start = $DatePickerStart.SelectedDate.AddDays( -31 )
			$disabledDates.End = $DatePickerStart.SelectedDate.AddDays( -1 )
			$DatePickerEnd.BlackoutDates.Add( $disabledDates )
		}
	}
}

#########################################################################################################################
# Calendar has closed, if calendarbutton for startdate is not visible, create blacked out dates after to selected enddate
function DatePickerEnd_CalendarClosed
{
	if ( $DatePickerEnd.Text -eq "" )
	{
			$btnEndDate.Visibility = [System.Windows.Visibility]::Visible
			$DatePickerEnd.Visibility = [System.Windows.Visibility]::Collapsed
			$btnStart.IsEnabled = $false
	}
	else
	{
		if ( $DatePickerStart.Visibility -eq "Visible" )
		{
			$btnStart.IsEnabled = $true
		}
		else
		{
			$DatePickerStart.BlackoutDates.Clear()
			$disabledDates = New-Object System.Windows.Controls.CalendarDateRange
			$disabledDates.Start = $DatePickerEnd.SelectedDate.AddDays( 1 )
			$disabledDates.End = $DatePickerEnd.SelectedDate.AddDays( 31 )
			$DatePickerStart.BlackoutDates.Add( $disabledDates )
		}
	}
}

function GetUserInstallations
{
	param ( $User )

	$UserLog = @( ( $installations.Where( { $_.User -eq $User.User } ) ).log )
	$jobs = New-Object System.Collections.ArrayList
	$i = 1
	$t = ""

	$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
	$RunspacePool = [runspacefactory]::CreateRunspacePool(
		1, #Min Runspaces
		10 #Max Runspaces
	)
	$RunspacePool.Open()

	foreach ( $installation in $UserLog )
	{
		$Window.Title = "Start sending for installationdata for $( $User.User ) > $( [Math]::Floor( ( $i / $UserLog.Count ) * 100 ) )%"
		$Runspace = [powershell]::Create()
		$Runspace.RunspacePool = $RunspacePool
		$Runspace.AddScript( {
			param ( $in )
			try
			{
				$ofs = "`n"
				$r = Get-ADComputer ( $in.Computer ) -Properties MemberOf | select -ExpandProperty MemberOf | where { $_ -like "*_Wrk*PR*_PC*" } | foreach { ( ( $_ -split "=" )[1] -split "," )[0] }
				if ( $r.Count -eq 0 )
				{ $t = "Annan datortyp" }
				else
				{
					$r | foreach {
						if ( ( $_ -like "*Role1*" -or $_ -like "*Role2*" -or $_ -like "*Role3*" ) -and ($_ -like "*Org1*" -or $_ -like "*Org2*"-or $_ -like "*Org3*") )
						{ $wrongType = 0 } else { $containsWrongType = $true }
					}
					if ( $containsWrongType ) { $wrongType = 1 }
					$t = [string]$r
				}
			}
			catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] { $t = "Computer can't be found in AD" }
			[pscustomobject]@{ Computer = $in.Computer; Date = ( Get-Date $in.Date ); Type = $t ; Description = $in.Description; WrongType = $wrongType }
		} )
		$Runspace.AddArgument( $installation )
		$jobs.Add( @{ Runspace = $Runspace; Handle = $Runspace.BeginInvoke() } )
		$i++
	}

	return @{ Jobs = $jobs; LogCount = $UserLog.Count; RSP = $RunspacePool }
}

###################################################################################
# User in userview is selected, get information of installations for selected dates
function UserView_SelectionChanged
{
	[void] $DescriptionView.Items.Clear()

	if ( $SelectedUser = $UserView.SelectedItems[0] )
	{
		$data = GetUserInstallations -User ( $SelectedUser )

		do
		{
			Start-Sleep -Milliseconds 500
			$completed = ( $data.Jobs | where { $_.Handle.IsCompleted -eq "Completed" } ).Count
			$Window.Title = "Waiting for data > $( [Math]::Floor( ( $completed / $data.Jobs.Count ) * 100 ) )%"
		} until ( $completed -eq $data.Jobs.Count )

		$ticker = 0
		foreach ( $j in $data.Jobs )
		{
			$Window.Title = "Importing data > $( [Math]::Floor( ( $ticker / $data.Jobs.Count ) * 100 ) )%"
			$DescriptionView.Items.Add( $j.Runspace.EndInvoke( $j.Handle ) )
			$j.Runspace.Dispose()
			$ticker++
		}
		$data.RSP.Close()
	}
	$Window.Title = $WindowTitle
}

############################################
# Load list of users, with installationcount
function LoadUserData
{
	$UserData = Get-SysManLogs

	if ( $UserData.Count -eq 0 )
	{
		ShowMessageBox "No installations found for given days"
		$Window.Title = $WindowTitle
	}
	else
	{
		$loopCount = 0
		foreach ( $entry in $UserData )
		{
			$entry.LoggedBy = ( Get-ADUser ( $entry.loggedBy -split "admin" ) ).Name
			$exists = $false
			if ( $installations.Count -gt 0 )
			{
				$listIndex = 0
				for ( $i = 0; $i -le $installations.Count - 1; $i++ )
				{
					if ( $installations[$i].user -eq $entry.loggedBy )
					{
						$exists = $true
						$listIndex = $i
						break
					}
				}
			}

			if ( $exists )
			{
				$computerEntry = New-Object -TypeName PSObject
				$computerEntry | Add-Member -Name "Computer" -MemberType NoteProperty -Value $entry.targetName
				$computerEntry | Add-Member -Name "Date" -MemberType NoteProperty -Value $entry.date
				$computerEntry | Add-Member -Name "Description" -MemberType NoteProperty -Value $entry.text

				$installations[$listIndex].log.Add( $computerEntry ) | Out-Null
				$installations[$listIndex].installations = [int]( [int]( $installations[$listIndex].installations ) + 1 )
			}
			else
			{
				$newUser = New-Object -TypeName PSObject
				$newUser | Add-Member -Name 'User' -MemberType NoteProperty -Value $entry.loggedBy
				$newUser | Add-Member -Name 'Installations' -MemberType NoteProperty -Value 1
				$newUser | Add-Member -Name 'Log' -MemberType NoteProperty -Value ( New-Object System.Collections.ArrayList )
				$installations.Add( $newUser ) | Out-Null

				$computerEntry = New-Object -TypeName PSObject
				$computerEntry | Add-Member -Name "Computer" -MemberType NoteProperty -Value $entry.targetName
				$computerEntry | Add-Member -Name "Date" -MemberType NoteProperty -Value $entry.date
				$computerEntry | Add-Member -Name "Description" -MemberType NoteProperty -Value $entry.text
				$installations[$installations.Count-1].log.Add( $computerEntry ) | Out-Null
			}

			$loopCount++
			[int]$ProgressValue = ( $loopCount / $UserData.Count ) * 100
			$Window.Title = "Collecting Installation Logs - $( $ProgressValue )%"
		}

		$loopCount = 0
	}

	$installations | sort Installations -Descending | foreach `
	{
		$Row = [pscustomobject]@{ User = $_.User; Installations = $_.Installations }
		[void] $UserView.Items.Add( $row )
	}

	$UserData = $null
	$Window.Title = $WindowTitle
	$DatePickerStart.IsEnabled = $DatePickerEnd.IsEnabled = $true
}

##############################################
# Get installation information from SysMan API
function Get-SysManLogs
{
	$logs = New-Object System.Collections.ArrayList
	$jobs = New-Object System.Collections.ArrayList
	$processingDate = $DatePickerStart.SelectedDate
	$processingMax = ( $DatePickerEnd.SelectedDate - $DatePickerStart.SelectedDate ).Days + 1

	$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
	$RunspacePool = [runspacefactory]::CreateRunspacePool(
		1, #Min Runspaces
		10 #Max Runspaces
	)
	$RunspacePool.Open()

	$Window.Title = "Setting up for SysMan-logs"
	do
	{
		$Runspace = [powershell]::Create()
		$Runspace.RunspacePool = $RunspacePool
		[void]$Runspace.AddScript( {
			param ( $processingDate )
			$processingEnd = $processingDate.AddDays( 1 ).AddSeconds( -1 )
			$entries = ( Invoke-RestMethod -Uri "http://sysman.domain.com/SysMan//api/Log?name=osinst&take=10000&skip=0&startDate=$processingDate&endDate=$processingEnd" -Method Get -UseDefaultCredentials -ContentType "application/json" ).result | where { $_.LoggedBy -like "*admin*" }
			$entries
		} )
		[void]$Runspace.AddArgument( $processingDate )
		
		[void]$jobs.Add( @{ RS = $Runspace; H = $Runspace.BeginInvoke() } )
		$processingDate = $processingDate.AddDays( 1 )
	}
	until ( $processingDate -gt $DatePickerEnd.SelectedDate )

	$ticker = 0
	foreach ( $j in $jobs )
	{
		$j.RS.EndInvoke( $j.H ) | foreach { [void]$logs.Add( $_ ) }
		$CurrentProgress = [math]::Floor( ( $ticker / $jobs.Count ) * 100 )
		$Window.Title = "Getting SysMan Logs - $( $CurrentProgress )%"
		$ticker++
	}

	$jobs | foreach { $_.RS.Dispose() }
	$RunspacePool.Close()
	$Window.Title = $Script:WindowTitle
	return $logs
}

###########################################################
# Sort userlist depending on which columnheader was clicked
function SortUserList
{
	param ( $Column )

	if ( $Column -eq "User" )
	{ $items = $UserView.Items | sort User, Installations }
	else
	{ $items = $UserView.Items | sort Installations, User -Descending }
	$UserView.Items.Clear()
	$items | foreach { $UserView.Items.Add( $_ ) }
}

###################### Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$Window, $vars = CreateWindow
$vars | foreach { Set-Variable -Name $_ -Value $Window.FindName( $_ ) -Scope script }
$Script:WindowTitle = "SysMan - OS Installation Stats"
$Script:installations = New-object System.Collections.ArrayList

$btnEndDate.Add_Click( { BtnEndDate_Click } )
$btnStartDate.Add_Click( { BtnStartDate_Click } )
$btnStart.Add_Click( { BtnStart_Click } )
$btnExport.Add_Click( { BtnExport_Click } )
$UserHeader.Add_Click( { SortUserList "User" } )
$InstallationsHeader.Add_Click( { SortUserList "Inst" } )
$DatePickerStart.Add_CalendarClosed( { DatePickerStart_CalendarClosed } )
$DatePickerEnd.Add_CalendarClosed( { DatePickerEnd_CalendarClosed } )
$UserView.Add_SelectionChanged( { UserView_SelectionChanged } )
$Window.Add_ContentRendered( { $Window.Top = 80; $Window.Activate() } )

[void] $Window.ShowDialog()
$Window.Close()
