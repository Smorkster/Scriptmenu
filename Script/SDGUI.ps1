<#
.Synopsis Main script
.Description Main script for collecting and accessing script
.Author Someone
#>
####################################################
# Search folder for items, operate depending on type
function GetFolderItems
{
	param (
		$dirPath
	)

	$spFolder = New-Object System.Windows.Controls.WrapPanel
	$spFolder.Orientation = "Vertical"
	$spFolder.Name = "wp$( $dirPath.Name -replace " " )"

	Set-Variable -Name ( "wp" + $( $dirPath.Name ) ) -Value $spFolder -Scope script

	if ( $files = Get-ChildItem -File -Filter "*ps1" -Path $dirPath.FullName | Where-Object { $_.Name -ne ( Get-Item $PSCommandPath ).Name } | `
		Select-Object -Property @{ Name = "Name"; Expression = { $_.Name } }, `
			@{ Name = "Path"; Expression = { $_.FullName } }, `
			@{ Name = "Group"; Expression = { ( $_.Name -split "-" )[0] } }, `
			@{ Name = "Synopsis"; Expression = { ( Select-String -InputObject $_ -Pattern "^.Synopsis" -Encoding Default ).Line.Replace( ".Synopsis ", "" ) } }, `
			@{ Name = "Requires"; Expression = { ( [string]( Select-String -InputObject $_ -Pattern "^.Requires" -Encoding default ).Line ).Replace( ".Requires ", "" ) -split "\W" | where { $_ } } }, `
			@{ Name = "Description"; Expression = { ( Select-String -InputObject $_ -Pattern "^.Description" -Encoding Default ).Line.TrimStart( ".Description " ) } } | `
			sort Synopsis )
	{
		if ( $dirPath.FullName -match "(Computer\\)" ) { $wpScriptGroup = CreateScriptGroup $files }
		else { $wpScriptGroup = CreateScriptGroup $files }
		$spFolder.AddChild( $wpScriptGroup )
	}

	if ( $dirPath.Name -like "*Computer" )
	{
		$spFolder.AddChild( ( CreateComputerInput ) )
	}

	if ( $dirs = Get-ChildItem -Directory -Path $dirPath.FullName )
	{
		$tabcontrol = New-Object System.Windows.Controls.TabControl
		if ( $dirPath.FullName -match "(Computer)" ) { $tabcontrol.Visibility = [System.Windows.Visibility]::Collapsed }
		if ( $dirPath -eq "" ) { $tabcontrol.MaxHeight = 700 }
		$tabcontrol.Name = "tc"+( $dirPath.Name -replace " " )
		Set-Variable -Name ( "tc" + $( $dirPath.Name ) ) -Value $tabcontrol -Scope script
		$tiList = @()
		foreach ( $dir in $dirs )
		{
			$tiList += ( CreateTabItem $dir )
		}
		$tiList | sort $_.Header | foreach {
			if ( $_.Content.Children[0].Content.Children.Count -eq 0 )
			{
				$_.Visibility = [System.Windows.Visibility]::Collapsed
			}
			$tabcontrol.AddChild( $_ )
		}
		$spFolder.AddChild( $tabcontrol )
	}
	return $spFolder
}

function DisconnectComputer
{
	$Script:ComputerObj = $null
	$tcDator.Items.RemoveAt( 0 )
	$btnConnect.IsEnabled = $true
	$tbComputerName.IsReadOnly = $false
	$tbComputerName.Text = ""
	$tcDator.Visibility = [System.Windows.Visibility]::Collapsed
	$btnDisconnect.Visibility = [System.Windows.Visibility]::Collapsed
}

################################
# Check if computer is reachable
function StartWinRMOnRemoteComputer
{
	try
	{
		SetTitle -Replace -Text ( "Verifies that '" + $tbComputerName.Text + "' is reachable" )
		Test-WSMan $tbComputerName.Text -ErrorAction Stop

		$btnConnect.IsEnabled = $false
		$tbComputerName.IsReadOnly = $true
		$tcDator.Visibility = [System.Windows.Visibility]::Visible
		$btnDisconnect.Visibility = [System.Windows.Visibility]::Visible
		CreateComputerInfo
	}
	catch
	{
		SetTitle -Add -Text " ... failed"
		ShowMessageBox "No contact to computer, or name does not exist. Try again."
		$tbComputerName.Focus()
	}
}

#####################################
# Get WMI information for given class
function FetchPCInfo
{
	param ( $Class, $Filter = $null )
	return Get-CimInstance -ComputerName $ComputerObj.Computername -ClassName $Class -Filter $Filter
}

######################################
# Get information from remote computer
function GetPCInfo
{
	$ComputerObj.NetAdapters = @()
	$c = FetchPCInfo -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled='True'"
	$c | foreach { $ComputerObj.NetAdapters += [pscustomobject]@{ MAC = $_.MACAddress; NetDesc = $_.Description; IP = $_.IPAddress[0] } }

	$ComputerObj.Model = ( FetchPCInfo -Class win32_computersystem ).Model
	$ComputerObj.Serienummer = ( FetchPCInfo -Class win32_bios ).SerialNumber

	$c = FetchPCInfo -Class win32_operatingsystem
	$ComputerObj.TimeOfLastBoot = $c.LastBootUpTime.GetDateTimeFormats()[22]
	$ComputerObj.TimeOfInstallation = $c.InstallDate.GetDateTimeFormats()[22]
	$duration = ( Get-Date ) - $c.LastBootUpTime
	$ComputerObj.TimeSinceLastBoot = "$( $duration.Days ) days $( $duration.Hours ) hours $( $duration.Minutes ) minutes"

	$ComputerObj.IEVersion = ( ( [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey( 'LocalMachine', $ComputerObj.Computername ) ).OpenSubKey( "SOFTWARE\\Microsoft\\Internet Explorer" ) ).GetValue( 'svcVersion' )

	$c = FetchPCInfo -Class CIM_LogicalDisk -Filter "DeviceID like 'C:'"
	if ( $c.FreeSpace -gt 1GB ) { $free = "$( [math]::Round( $c.FreeSpace / 1GB , 2 ) ) GB" }
	else { $free = "$( [math]::Round( $c.FreeSpace / 1MB , 2 ) ) MB" }
	$ComputerObj.FreeSpace = "$free / $( [math]::Round( $c.Size / 1GB , 2) ) GB"
}

###############################
# Get PCRole of remote computer
function GetPCRole
{
	$ComputerObj.Roll = $null
	$PCRoll = Get-ADComputer $ComputerObj.Computername -Properties Memberof | select -ExpandProperty MemberOf | where { $_ -match "_Wrk_" }
	$types = @( "Role1", "Role2" )

	switch ( ( $types | where { $PCRole -match $_ } ) )
	{
		"Role1" { $r = "Role1-PC" }
		"Role2" { $r = "Role2-PC" }
	}
	if ( $r -eq $null ) { $r = "Unknown-PC" }
	$ComputerObj.Role = $r

	if ( $ComputerObj.Computername -notmatch "^(Org1|Org2)" )
	{
		$ComputerObj.DontInstall = "Do not reinstall this computer: Other organisation"
	}
	elseif ( ( @( "Comp1", "CompSpec1" ) | foreach { $_ -like "$( $ComputerObj.Computername )*" } ) -eq $true )
	{
		$ComputerObj.DontInstall = "Special computer. Do not reinstall this computer"
	}
	else
	{
		$c1 = $true
		$ComputerObj.Role | foreach { if ( $_ -notmatch "(Exp|Admin)" ) { $c1 = $false } }
		if ( -not $c1 )
		{
			$ComputerObj.DontInstall = "Do not reinstall this computer: `n$( [string]( $PCRoll | where { $_ -notmatch "(Exp|Admin)" } | foreach { ( ( $_ -split "=" )[1] -split "," )[0] } ) )"
		}
	}
}

##########################
# Sets title of the window
function SetTitle
{
	param (
		[switch] $Add,
		[switch] $Remove,
		[switch] $Replace,
		[string] $Text
	)

	if ( $Add )
	{
		$Window.Title += $Text
	}
	elseif ( $Remove )
	{
		$Window.Title = "SDGUI"
	}
	elseif ( $Replace )
	{
		$Window.Title = $Text
	}
}

#######################################################################
# Create controls to hold computerinfo and buttons for computer-scripts
function CreateComputerInfo
{
	$tI = [System.Windows.Controls.TabItem]@{ Name = "Baseinformation"; Header = "Baseinformation" }
	$datagrid = [System.Windows.Controls.DataGrid]@{ AutoGenerateColumns = $true }
	Set-Variable -Name datagrid -Value $datagrid

	$Script:colName = [System.Windows.Controls.DataGridTextColumn]@{ Header = "Name"; Width = "SizeToCells"; Binding = [System.Windows.Data.Binding]@{ Path = "Name" } }
	$Script:colInfo = [System.Windows.Controls.DataGridTextColumn]@{ Header = "Info"; Width = "SizeToCells"; Binding = [System.Windows.Data.Binding]@{ Path = "Info" } }
	$Script:ComputerObj.Computername = $tbComputerName.Text

	GetPCInfo
	GetPCRole

	$ComputerObj.Keys | sort | foreach {
		$name = $_ -csplit '(?=[A-Z])' -ne '' -join ' '
		$info = $ComputerObj.$( $_ )
		if ( $_ -eq "NetAdapters" )
		{
			for ( $i = 0; $i -lt $ComputerObj.NetAdapters.Count; $i++ )
			{
				$name = "$( $ComputerObj.NetAdapters[$i-1].NetDesc )"
				$info = "$( $ComputerObj.NetAdapters[$i-1].IP )`n$( $ComputerObj.NetAdapters[$i-1].MAC )"
			}
		}
		elseif ( $_ -eq "FreeSpace" )
		{
			if ( ( $ComputerObj.$( $_ ) -split " " )[0] -lt 20 )
			{
				$name += " (Low)"
			}
		}

		$datagrid.AddChild( [pscustomobject]@{ "Name" = $name; "Info" = $info } )
	}

	$datagrid.Columns.Add( $colName )
	$datagrid.Columns.Add( $colInfo )
	$tI.AddChild( $datagrid )
	$tcDator.Items.Insert( 0, $tI )
	$tcDator.SelectedIndex = 0
}

#########################################################
# Create controls for computername and buttons to connect
function CreateComputerInput
{
	$sp = [System.Windows.Controls.StackPanel]@{
		Margin = "0,15,0,10"
		Orientation = "Horizontal"
	}
	$l = [System.Windows.Controls.Label]@{ Content = "Computername" }
	$tb = [System.Windows.Controls.TextBox]@{
		Name = "tbComputerName"
		VerticalContentAlignment = "Center"
		Width = 200
	}
	$tb.Add_TextChanged( { if ( $this.Text.Length -gt 5 ) { $btnConnect.IsEnabled = $true } else { $btnConnect.IsEnabled = $false } } )
	$tb.Add_KeyDown( { if ( $args[1].Key -eq "Return" ) { StartWinRMOnRemoteComputer } } )
	Set-Variable -Name "tbComputerName" -Value $tb -Scope script

	$b = [System.Windows.Controls.Button]@{
		Content = "Get info"
		IsEnabled = $false
		Margin = "5,0,0,0"
		Name = "btnConnect"
		Width = 75
	}
	$b.Add_Click( { StartWinRMOnRemoteComputer } )
	Set-Variable -Name "btnConnect" -Value $b -Scope script

	$b2 = [System.Windows.Controls.Button]@{
		Content = "Disconnect"
		Margin = "5,0,0,0"
		Name = "btnDisconnect"
		Visibility = [System.Windows.Visibility]::Collapsed
		Width = 65
	}
	$b2.Add_Click( { DisconnectComputer } )
	Set-Variable -Name "btnDisconnect" -Value $b2 -Scope script

	$sp.AddChild( $l )
	$sp.AddChild( $tb )
	$sp.AddChild( $b )
	$sp.AddChild( $b2 )
	return $sp
}

####################################################################
# Create a group of buttons and labels for all scriptfiles in folder
function CreateScriptGroup
{
	param (
		$Files
	)

	$wpScriptGroup = New-Object System.Windows.Controls.WrapPanel
	$wpScriptGroup.Orientation = "Vertical"

	foreach ( $group in ( $files | Group { $_.Group } | sort Name ) )
	{
		$gb = [System.Windows.Controls.GroupBox]@{ Header = $group.Name }
		$sp = [System.Windows.Controls.WrapPanel]@{ Orientation = "Vertical" }
		foreach ( $file in $group.Group )
		{
			if ( $file.Requires -eq "" -or
			( $userGroups -match $file.Requires ) )
			{
				$wpScriptControls = New-Object System.Windows.Controls.WrapPanel
				$button = New-Object System.Windows.Controls.Button
				$label = New-Object System.Windows.Controls.Label

				$button.Content = "Run >"
				$button.ToolTip = $file.Path
				$label.Content = $file.Synopsis
				$label.ToolTip = [string]$file.Description.Replace( ". ", ".`n" )

				if ( $file.Synopsis -match "under development" )
				{
					$label.Background = "Red"
					if ( $adminList -notcontains $env:USERNAME ) { $button.IsEnabled = $false }
				}
				elseif ( $file.Synopsis -match "under testing" )
				{
					$label.Background = "LightBlue"
					$label.Content += "`nOnly use if you're told to."
				}

				$button.Add_Click( {
					$ProgramRunspace = [System.Management.Automation.PowerShell]::Create() # Create new runspace
					$args = @( $this.ToolTip, ( Get-Item $PSScriptRoot ).Parent.FullName )
					if ( $this.ToolTip -match "(Dator\\)" )
					{ $args += $tbComputerName.Text }

					if ( Get-ChildItem "$( ( Get-Item $PSCommandPath ).Directory.Parent.FullName )\Gui" | where { $_.Name -match ( ( Get-Item $this.ToolTip ).Name -split "\." )[0] } ) { $hidden = $true }
					else { $hidden = $false }

					[void]$ProgramRunspace.AddScript( {
						param( $arg, $hidden )
						if ( $hidden )
						{ start powershell -WindowStyle Hidden -ArgumentList $arg } # Starts script with gui, without a powershell-window
						else
						{ start powershell -ArgumentList $arg } # Starts script without gui, with new powershell-window
					} ).AddArgument( $args ).AddArgument( $hidden )

					$run = $ProgramRunspace.BeginInvoke() # Run runspace
					do { Start-Sleep -Milliseconds 50 } until ( $run.IsCompleted )
					$ProgramRunspace.Dispose()
				} )

				[void] $wpScriptControls.AddChild( $button )
				[void] $wpScriptControls.AddChild( $label )
				[void] $sp.AddChild( $wpScriptControls )
			}
		}

		$gb.Content = $sp
		$wpScriptGroup.AddChild( $gb )
	}
	return $wpScriptGroup
}

#################################################
# Create a tabcontrol tabitem for given directory
function CreateTabItem
{
	param (
		$dirPath
	)

	$tT = ""
	( $dirPath.Name ).GetEnumerator() | foreach { if ( $_ -cmatch "\b[A-Z]") { $tT += " $_" } else { $tT += $_ } }
	$tabitem = [System.Windows.Controls.TabItem]@{ Header = $tT.Trim(); Name = "ti" + $( $dirPath.Name ) }
	Set-Variable -Name ( "ti" + $( $dirPath.Name ) ) -Value $tabitem -Scope Script

	$g = New-Object System.Windows.Controls.Grid
	$scroller = New-Object System.Windows.Controls.ScrollViewer
	$sp = GetFolderItems $dirPath
	$scroller.AddChild( $sp )
	$g.AddChild( $scroller )
	$tabitem.AddChild( $g )
	return $tabitem
}

####################################################
# Check if user is part of admingroup for Scriptmenu
function CheckForAdmin
{
	if ( $adminList -contains $env:USERNAME )
	{
		$Admins.Visibility = [System.Windows.Visibility]::Visible
		$btnCheckForUpdates.Add_Click( {
			$ProgramRunspace = [System.Management.Automation.PowerShell]::Create() # Create new runspace
			if ( ( Get-Item $PSScriptRoot ).Parent.Name -eq "Development" )
			{ $script = "Update-Scripts.ps1" }
			else
			{ $script = "Development\Update-Scripts.ps1" }
			$args = @( "$( ( Get-Item $PSScriptRoot ).Parent.FullName )\$script", ( Get-Item $PSScriptRoot ).Parent.FullName )
			[void]$ProgramRunspace.AddScript( { param( $arg ); start powershell -WindowStyle Hidden -ArgumentList $arg } ).AddArgument( $args )
			$run = $ProgramRunspace.BeginInvoke() # Run runspace
			do { Start-Sleep -Milliseconds 50 } until ( $run.IsCompleted )
			$ProgramRunspace.Dispose()
		} )
	}
}

################################################
# Add controls to send report or suggestion mail
function AddReportTool
{
	$ti = [System.Windows.Controls.TabItem]@{ Header = "Error report / Suggestions"; Background = "#FFFF9C9C" }
	$sp = New-Object System.Windows.Controls.StackPanel
	$spScript = [System.Windows.Controls.StackPanel]@{ Orientation = "Horizontal" }
	$spSubject = [System.Windows.Controls.StackPanel]@{ Orientation = "Horizontal" }
	$cb = [System.Windows.Controls.ComboBox]@{ Height = "25"; Width = "300" }
	$tbText = [System.Windows.Controls.TextBox]@{ AcceptsReturn = $true; AcceptsTab = $true; TextWrapping = "WrapWithOverflow"; VerticalScrollBarVisibility = "Auto"; Height = "300" }
	$btnAdd = [System.Windows.Controls.Button]@{ Content = "Add name of script to be reported"; IsEnabled = $false; Margin = "0,5,10,5" }
	$btnSend = [System.Windows.Controls.Button]@{ Content = "Send report" }
	$lblSubject = [System.Windows.Controls.Label]@{ Content = "Type of message: " }
	$rbR = [System.Windows.Controls.RadioButton]@{ Content = "Error report"; GroupName = "Subject"; IsChecked = $true }
	$rbS = [System.Windows.Controls.RadioButton]@{ Content = "Suggestion"; GroupName = "Subject" }

	Get-ChildItem $PSCommandPath.Directory -Filter "*ps1" -File -Recurse | select Name, @{ Name = "Synopsis"; Expression = { ( Select-String -InputObject $_ -Pattern "^.Synopsis" -Encoding Default ).Line.Replace( ".Synopsis ", "" ) } } | sort Synopsis | foreach { [void] $cb.Items.Add( "$( $_.Synopsis )`n`t$( $_.Name )" ) }

	$btnAdd.Add_Click( {
		$this.Parent.Parent.Children[2].Text = $this.Parent.Children[1].SelectedItem + "`r`n" + $this.Parent.Parent.Children[2].Text
		$this.Parent.Children[1].SelectedIndex = -1
	} )
	$btnSend.Add_Click( {
		if ( $this.Parent.Children[1].Children[1].IsChecked ) { $subject = "Error report" }
		elseif ( $this.Parent.Children[1].Children[2].IsChecked ) { $subject = "Suggestion" }
		Send-MailMessage -From ( ( Get-ADUser ( Get-ADUser $env:USERNAME ).SamAccountName.Replace( "admin", "" ) -Properties EmailAddress ).EmailAddress ) `
			-To backoffice@test.com `
			-Body "$( $this.Parent.Children[2].Text )`n`nFrån:`n$( ( Get-ADUser $env:USERNAME ).Name )" `
			-BodyAsHTML
			-Encoding Default
			-SmtpServer smtprelay.test.com `
			-Subject "$subject Scriptmenu" `
		$this.Parent.Children[2].Text = ""
	} )
	$cb.Add_DropDownClosed( { if ( $this.Text -eq [string]::Empty ) { $this.Parent.Children[0].IsEnabled = $false } else { $this.Parent.Children[0].IsEnabled = $true } } )
	$rbR.Add_Checked( { $this.Parent.Parent.Children[1].Children[0].Content = "Add scriptname to be reported"
		$this.Parent.Parent.Children[3].Content = "Send report" } )
	$rbS.Add_Checked( { $this.Parent.Parent.Children[1].Children[0].Content = "Add scriptname to suggestion"
		$this.Parent.Parent.Children[3].Content = "Send suggestion" } )

	[void] $spSubject.AddChild( $lblSubject )
	[void] $spSubject.AddChild( $rbR )
	[void] $spSubject.AddChild( $rbS )
	[void] $spScript.AddChild( $btnAdd )
	[void] $spScript.AddChild( $cb )
	[void] $sp.AddChild( $spSubject )
	[void] $sp.AddChild( $spScript )
	[void] $sp.AddChild( $tbText )
	[void] $sp.AddChild( $btnSend )
	[void] $ti.AddChild( $sp )
	[void] $tc.AddChild( $ti )
}

#####################################
# Small tweaks before window launches
function FulHack
{
	$tItem = $tiScoreboard
	$tItem.Background = "Gold"
	$tc.Items.RemoveAt( $tc.Items.IndexOf( $tiScoreboard ) )
	$tc.Items.Insert( ( $tc.Items.Count ), $tItem )
	$Window.Add_ContentRendered( { $Window.Top = 50; $Window.Activate() } )
	$tiDator.Add_LostFocus( { SetTitle -Remove } )
}

############################## Script start
Import-Module "$( ( Get-Item $PSCommandPath ).Directory.Parent.FullName )\Modules\FileOps.psm1" -Force

$userGroups = ( Get-ADUser $env:USERNAME -Properties memberof ).memberof | foreach { ( ( $_ -split "=" )[1] -split "," )[0] }
$Script:ComputerObj = @{}
$Window, $vars = CreateWindow
if ( $PSCommandPath -match "Development" ) { SetTitle -Add " - Developer edition" }
$vars | foreach { Set-Variable -Name $_ -Value $Window.FindName( $_ ) }
$adminList = @( "admin1", "admin2", "admin3" )

Push-Location ( Get-Item $PSCommandPath ).Directory.FullName
$MainContent.AddChild( ( GetFolderItems "" ) )
FulHack
CheckForAdmin
AddReportTool
$Window.Add_Loaded( { $Window.Activate() } )

[void] $Window.ShowDialog()
Pop-Location
$Window.Close()
