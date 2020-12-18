<#
.Synopsis Remove one or more profiles on remote computer
.Description Remove one or more profiles on remote computer.
.Requires Role_Servicedesk_Backoffice
.Author Someone
#>

function Connect
{
	$syncHash.DC.DClvProfileList[0].Clear()
	$syncHash.DC.DClbOutput[0].Clear()

	if ( $syncHash.DC.DCbtnConnect[0] -eq "Connect to computer" )
	{
		if ( VerifyInput )
		{
			( [powershell]::Create().AddScript( { param ( $syncHash, $li )
				$syncHash.DC.DCtxtCName[0] = $false
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.DCProgress[1] = $true } )
				$syncHash.DC.DCbtnLogOutAll[0] = $false
				$syncHash.Window.Dispatcher.Invoke( [action] {
					$li.Content = "Check if $( $syncHash.Data.ComputerName ) is online and reachable"
					$syncHash.DC.DClbOutput[0].Add( $li )
				} )

				try
				{
					Test-WSMan $syncHash.Data.ComputerName -ErrorAction Stop
					$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += "`n`tIs online" } )
					$n = ( quser /server:$( $syncHash.data.ComputerName ) | select -Skip 1 ).Count
					if ( $n -gt 0 )
					{
						$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += "`n`t$( $n ) users have loginsessions.`n`tLog out all before you continue." } )
						$syncHash.DC.DCbtnLogOutAll[1] = "Log out all users"
					}
					else
					{
						$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += "`n`t0 users have loginsessions." } )
						$syncHash.DC.DCbtnLogOutAll[1] = "Get profiles"
					}
					$syncHash.DC.DCbtnLogOutAll[0] = $true
					$syncHash.DC.DCbtnConnect[0] = "Reset"
				}
				catch
				{
					$syncHash.Window.Dispatcher.Invoke( [action] {
						$li.Content += "`n`tIs NOT online"
						$li.Background = "#FFFF0000"
						$li.FontWeight = "Bold"
					} )
					$syncHash.DC.DCtxtCName[0] = $true
				}
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.DCProgress[1] = $false } )
			} ).AddArgument( $syncHash ).AddArgument( [System.Windows.Controls.ListBoxItem]@{ Content = "" } ) ).BeginInvoke()
		}
	}
	else
	{
		$syncHash.DC.DCbtnLogOutAll[0] = $false
		$syncHash.DC.DCbtnMarkAll[0] = $false
		$syncHash.DC.DCbtnRemoveMarked[0] = $false
		$syncHash.DC.DCtxtCName[0] = $true

		$syncHash.DC.DCbtnConnect[0] = "Connect to computer"
	}
}

function DeleteProfiles
{
	$syncHash.DC.DClvProfileList[1] = $true

	$RunspacePool = [runspacefactory]::CreateRunspacePool( 1, 1 )
	$RunspacePool.CleanupInterval = New-TimeSpan -Minutes 1
	$RunspacePool.Open()
	$syncHash.jobs = New-Object System.Collections.ArrayList
	$syncHash.logText = "$( $syncHash.Data.ComputerName ), $( $syncHash.lvProfileList.SelectedItems.Count ) profiles"
	$syncHash.Output = "Removed $( $syncHash.lvProfileList.SelectedItems.Count ) profiles on computer $( $syncHash.Data.ComputerName ):"
	foreach ( $user in ( $syncHash.lvProfileList.SelectedItems ) )
	{
		$li = [System.Windows.Controls.ListBoxItem]@{ Content = $user.Name }
		$ps = [powershell]::Create()
		$ps.RunspacePool = $RunspacePool
		[void] $ps.AddScript( { param ( $syncHash, $li, $user )
			$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.DClbOutput[0].Add( $li ) } )
			# region FileBackup
			$syncHash.Window.Dispatcher.Invoke( [action] {
				$li.Content += "`n`tStarting backup for ($( $user.P ))... "
			} )
			$out = Invoke-Command -ComputerName $syncHash.Data.ComputerName -ScriptBlock `
			{
				param ( $id, $Name )
				try { New-Item -Path "C:\Users" -Name Old -ItemType Directory -ErrorAction Stop } catch {}

				# Directories
				"C:\Users\$id",
				"C:\Users\$id\AppData\Roaming\Microsoft\Office",
				"C:\Users\$id\AppData\Roaming\Microsoft\Signatures",
				"C:\Users\$id\AppData\Roaming\Microsoft\Sticky Notes" | foreach {
					Get-ChildItem $_ -Recurse | Copy-Item -Destination { $_.FullName -replace "$id", "Old\$id" }
				}

				#Files
				"C:\Users\$id\AppData\Local\Google\Chrome\User Data\Default\Bookmarks",
				"C:\Users\$id\AppData\Roaming\Microsoft\OneNote\16.0\Preferences.dat" | foreach {
					New-Item -Path { ( $_ -replace "$id", "Old\$id" -split "\\" | select -SkipLast 1 ) -join "\" } `
							-Name { $_ -split "\\" | select -Last 1 } `
							-ItemType File `
							-Force `
							-Value ( Get-Content -Path $_ )
				}

				$zipDest = "C:\Users\Old\$Name Profilebackup, created $( ( Get-Date ).ToShortDateString() ).zip"
				$earlierBackups = Get-ChildItem -Path "C:\Users\Old" | where { $_.Name -match $id }
				$earlierBackups | where { $_.LastWriteTime -lt ( Get-Date ).AddDays( -30 ) } | Remove-Item

				Compress-Archive -Path C:\Users\Old\$id -DestinationPath $zipDest -CompressionLevel Optimal
				Remove-Item C:\Users\Old\$id -Recurse
				[pscustomobject]@{ ZIP = $zipDest ; Org = "C:\Users\$id" }
			} -ArgumentList $user.ID, $user.Name
			$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += "Done" } )
			# endregion FileBackup

			# region RemoveProfile
			$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += "`n`tDeletes profile and files ($( $user.ID ))... " } )
			Get-CimInstance -ComputerName $syncHash.Data.ComputerName -Class Win32_UserProfile | where { $_.LocalPath.Split( '\' )[-1] -eq $user.ID } | Remove-CimInstance
			$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += "Klar" } )
			# endregion RemoveProfile

			$syncHash.DC.DClvProfileList[0] = $syncHash.DC.DClvProfileList[0] | where { $_.ID -ne $user.ID }
			$syncHash.Output += "`n`n$( $user.Name )`n`tProfile location: $( $out.Org )`n`tZIP-backup: $( $out.ZIP )"

			$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.DCProgress[0] = [double] ( ( ( ( $syncHash.jobs.H.IsCompleted -eq $true ).Count + 1 ) / $syncHash.jobs.Count ) * 100 ) } )
		} ).AddArgument( $syncHash ).AddArgument( $li ).AddArgument( $user )
		[void] $syncHash.jobs.Add( [pscustomobject]@{ P = $ps ; H = $ps.BeginInvoke() } )
	}
}

########################################
# Log off all users from remote computer
function LogoffRemote
{
	if ( $syncHash.DC.DCbtnLogOutAll[1] -eq "Log out all users" )
	{
		$userlogins = quser /server:$( $syncHash.data.ComputerName ) | select -Skip 1 | foreach { 
			[pscustomobject]@{
				UserID = ( $_ -split " +" )[1]
				SessionID = $( if ( ( $_ -split " +" ).Count -eq 8 ) { ( $_ -split " +" )[3] } else { ( $_ -split " +" )[2] } )
			}
		}
		$li = [System.Windows.Controls.ListBoxItem]@{ Content = "" }

		$syncHash.Window.Dispatcher.Invoke( [action] {
			$ofs = "`n`t"
			$li.Content = "$( $userlogins.Count ) users logged out`n`t$( [string]( $userlogins.UserID | Get-ADUser | select -ExpandProperty Name | sort ) )"
			$syncHash.DC.DClbOutput[0].Add( $li )
		} )
	}

	Get-CimInstance -ComputerName $( $syncHash.Data.ComputerName ) -ClassName Win32_UserProfile | where { -not $_.Special -and $_.LocalPath -notmatch "default" -and -not [string]::IsNullOrEmpty( $_.LocalPath ) } | foreach {
		[pscustomobject]@{
			P = $_.LocalPath
			ID = ( $_.LocalPath -split "\\" )[2].ToUpper()
			Name = ( Get-ADUser ( $_.LocalPath -split "\\" )[2] ).Name
			LastUsed = $_.LastUseTime.ToShortDateString()
		}
	} | sort Name | foreach { $syncHash.DC.DClvProfileList[0].Add( $_ ) }
	if ( $syncHash.DC.DClvProfileList[0].Count -gt 0 )
	{
		$syncHash.DC.DCbtnMarkAll[0] = $true
	}

	$syncHash.DC.DCbtnLogOutAll[0] = $false
	$syncHash.DC.DCbtnRemoveMarked[0] = $false
	$syncHash.DC.DClvProfileList[1] = $true
}

function VerifyInput
{
	$c1 = $true
	if ( $syncHash.Data.ComputerName -match "(org1|org2)(d|l)s\d{7}" )
	{
		if ( $role = Get-ADComputer $syncHash.Data.ComputerName -Properties Memberof | select -ExpandProperty MemberOf | where { $_ -match "_Wrk_.+PC," } )
		{
			$role | foreach { if ( $_ -notmatch "(Exp|Admin)" ) { $c1 = $false } }
			if ( -not $c1 )
			{
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.DClbOutput[0].Add( ( [System.Windows.Controls.ListBoxItem]@{ Content = "Computer does not have the correct role. One or more of these roles demands special handling by IT-Service.`nComputer have these roles:`n`t$( $ofs = "`n`t"; $role | foreach { ( ( $_ -split "=" )[1] -split "," )[0] } )"; Background = "#FFFF0000" } ) ) } )
			}
		}
	}
	elseif ( $syncHash.Data.ComputerName -match "^(org3|org5)" )
	{
		$c1 = $false
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.DClbOutput[0].Add( ( [System.Windows.Controls.ListBoxItem]@{ Content = "Deletion of profiles are only done on computers for Org1 and Org2. This computer belongs to other organisation, so their IT-Service can help."; Background = "#FFFF0000" } ) ) } )
	}
	else
	{
		$c1 = $false
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.DClbOutput[0].Add( ( [System.Windows.Controls.ListBoxItem]@{ Content = "Computername is not valid and can't be verified in AD"; Background = "#FFFF0000" } ) ) } )
	}

	return $c1
}

########################### Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$syncHash = [hashtable]::Synchronized( @{} )
$syncHash.Bindings = [hashtable]( @{} )
$syncHash.Data = [hashtable]( @{} )
$syncHash.DC = [hashtable]( @{} )
$syncHash.Output = ""
$syncHash.Vars = @()
$syncHash.Window, $vars = CreateWindow
$vars | foreach {
	$syncHash.$_ = $syncHash.Window.FindName( $_ )
	$syncHash.Vars += $_
	$syncHash.Bindings."Bindings$_" = New-Object System.Collections.ObjectModel.ObservableCollection[object]
	$syncHash.DC."DC$_" = New-Object System.Collections.ObjectModel.ObservableCollection[object]
}

$syncHash.DC.DCProgress.Add( 0.0 ) # 0 Value
$syncHash.DC.DCProgress.Add( $false ) # 1 IsIndeterminate

$syncHash.DC.DCspComputer.Add( $true ) # 0 IsEnabled
$syncHash.DC.DCspComputer.Add( [System.Windows.Visibility]::Visible ) # 1 Visibility

$syncHash.DC.DClbOutput.Add( ( New-Object System.Collections.ObjectModel.ObservableCollection[object] ) ) # 0 ItemsSource

$syncHash.DC.DClvProfileList.Add( ( New-Object System.Collections.ObjectModel.ObservableCollection[object] ) ) # 0 ItemsSource
$syncHash.DC.DClvProfileList.Add( $false ) # 1 IsEnabled

$syncHash.DC.DCtxtCName.Add( $true ) # 0 IsEnabled

$syncHash.DC.DCbtnRemoveMarked.Add( $false ) # 0 IsEnabled

$syncHash.DC.DCbtnMarkAll.Add( $false ) # 0 IsEnabled
$syncHash.DC.DCbtnMarkAll.Add( "Markera alla" ) # 1 Content

$syncHash.DC.DCbtnLogOutAll.Add( $false ) # 0 IsEnabled
$syncHash.DC.DCbtnLogOutAll.Add( "Logga ut alla användare" ) # 1 Content

$syncHash.DC.DCbtnConnect.Add( "Connect to computer" ) # 0 Content

foreach ( $v in $syncHash.Vars )
{
	0..( $syncHash.DC."DC$v".Count - 1 ) | foreach { [void] $syncHash.Bindings."Bindings$v".Add( ( New-Object System.Windows.Data.Binding -ArgumentList "[$_]" ) ) }
	$syncHash.Bindings."Bindings$v" | foreach { $_.Mode = [System.Windows.Data.BindingMode]::TwoWay }
	$syncHash.$v.DataContext = $syncHash.DC."DC$v"
}

[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.Progress, [System.Windows.Controls.ProgressBar]::ValueProperty, $syncHash.Bindings.BindingsProgress[0] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.Progress, [System.Windows.Controls.ProgressBar]::IsIndeterminateProperty, $syncHash.Bindings.BindingsProgress[1] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.spComputer, [System.Windows.Controls.StackPanel]::IsEnabledProperty, $syncHash.Bindings.BindingsspComputer[0] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.spComputer, [System.Windows.Controls.StackPanel]::VisibilityProperty, $syncHash.Bindings.BindingsspComputer[1] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.txtCName, [System.Windows.Controls.TextBox]::IsEnabledProperty, $syncHash.Bindings.BindingstxtCName[0] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.btnConnect, [System.Windows.Controls.Button]::ContentProperty, $syncHash.Bindings.BindingsbtnConnect[0] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.btnLogOutAll, [System.Windows.Controls.Button]::IsEnabledProperty, $syncHash.Bindings.BindingsbtnLogOutAll[0] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.btnLogOutAll, [System.Windows.Controls.Button]::ContentProperty, $syncHash.Bindings.BindingsbtnLogOutAll[1] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.btnMarkAll, [System.Windows.Controls.Button]::IsEnabledProperty, $syncHash.Bindings.BindingsbtnMarkAll[0] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.btnMarkAll, [System.Windows.Controls.Button]::ContentProperty, $syncHash.Bindings.BindingsbtnMarkAll[1] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.btnRemoveMarked, [System.Windows.Controls.Button]::IsEnabledProperty, $syncHash.Bindings.BindingsbtnRemoveMarked[0] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.lvProfileList, [System.Windows.Controls.ListView]::ItemsSourceProperty, $syncHash.Bindings.BindingslvProfileList[0] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.lvProfileList, [System.Windows.Controls.ListView]::IsEnabledProperty, $syncHash.Bindings.BindingslvProfileList[1] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.lbOutput, [System.Windows.Controls.ListBox]::ItemsSourceProperty, $syncHash.Bindings.BindingslbOutput[0] )

$syncHash.btnConnect.Add_Click( { Connect } )

$syncHash.btnMarkAll.Add_Click( {
	if ( $syncHash.DC.DCbtnMarkAll[1] -eq "Select all" )
	{
		$syncHash.lvProfileList.SelectAll()
		$syncHash.DC.DCbtnMarkAll[1] = "Deselect all"
	}
	else
	{
		$syncHash.lvProfileList.UnselectAll()
		$syncHash.DC.DCbtnMarkAll[1] = "Select all"
	}
} )

$syncHash.btnRemoveMarked.Add_Click( { DeleteProfiles } )
$syncHash.btnLogOutAll.Add_Click( { LogoffRemote } )

$syncHash.lvProfileList.Add_SelectionChanged( {
	if ( $syncHash.lvProfileList.SelectedItems.Count -eq 0 )
	{
		$syncHash.DC.DCbtnRemoveMarked[0] = $false
	}
	else
	{
		$syncHash.DC.DCbtnRemoveMarked[0] = $true
	}
} )

$syncHash.Progress.Add_ValueChanged( {
	if ( $this.Value -eq 100 )
	{
		$syncHash.logText += "`n`tSummary: $( WriteOutput -Output $( $syncHash.Output ) )"
		$logFile = WriteLog -LogText $syncHash.logText
		$syncHash.DC.DClvProfileList[1] = $true

		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.DCProgress[0] = [double] ( 0 ) } )
	}
} )

$syncHash.txtCName.Add_TextChanged( {
	$syncHash.Data.ComputerName = $syncHash.txtCName.Text
} )

$syncHash.Window.Add_ContentRendered( {
	$syncHash.Window.Top = 80; $syncHash.Window.Activate()
} )

$syncHash.Data.ComputerName = $syncHash.txtCName.Text = $args[1]

[void] $syncHash.Window.ShowDialog()
$syncHash.Window.Close()
#$global:syncHash = $syncHash