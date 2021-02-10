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

	$spFolder = [System.Windows.Controls.WrapPanel]@{ Orientation = "Vertical"; Name = "wp$( $dirPath.Name -replace " " )" }
	Set-Variable -Name ( "wp" + $( $dirPath.Name ) ) -Value $spFolder -Scope script

	if ( $files = Get-ChildItem -File -Filter "*ps1" -Path $dirPath.FullName | Where-Object { $_.Name -ne ( Get-Item $PSCommandPath ).Name } | `
		Select-Object -Property @{ Name = "Name"; Expression = { $_.Name } }, `
			@{ Name = "Path"; Expression = { $_.FullName } }, `
			@{ Name = "Group"; Expression = { ( $_.Name -split "-" )[0] } }, `
			@{ Name = "Synopsis"; Expression = { ( Select-String -InputObject $_ -Pattern "^.Synopsis" -Encoding UTF8 ).Line.Replace( ".Synopsis ", "" ) } }, `
			@{ Name = "Requires"; Expression = { ( [string]( Select-String -InputObject $_ -Pattern "^.Requires" -Encoding UTF8 ).Line ).Replace( ".Requires ", "" ) -split "\W" | Where-Object { $_ } } }, `
			@{ Name = "AllowedUsers"; Expression = { ( [string]( Select-String -InputObject $_ -Pattern "^.AllowedUsers" -Encoding UTF8 ).Line ).Replace( ".AllowedUsers ", "" ) -split "\W" | Where-Object { $_ } } }, `
			@{ Name = "Description"; Expression = { ( Select-String -InputObject $_ -Pattern "^.Description" -Encoding UTF8 ).Line.TrimStart( ".Description " ) } } | `
			Sort-Object Synopsis )
	{
		$wpScriptGroup = CreateScriptGroup $files
		$spFolder.AddChild( $wpScriptGroup )
	}

	if ( $dirPath.Name -like "*$( $msgTable.ComputerFolder )" )
	{
		$spFolder.AddChild( ( CreateComputerInput ) )
	}

	if ( $dirs = Get-ChildItem -Directory -Path $dirPath.FullName )
	{
		$tabcontrol = [System.Windows.Controls.TabControl]@{ Name = "tc"+( $dirPath.Name -replace " " ) }
		if ( $dirPath.FullName -match "($( $msgTable.ComputerFolder ))" ) { $tabcontrol.Visibility = [System.Windows.Visibility]::Collapsed }
		if ( $dirPath -eq "" ) { $tabcontrol.MaxHeight = 700 }
		Set-Variable -Name ( "tc" + $( $dirPath.Name ) ) -Value $tabcontrol -Scope script

		$tiList = @()
		foreach ( $dir in $dirs )
		{
			$tiList += ( CreateTabItem $dir )
		}
		$tiList | Sort-Object $_.Header | ForEach-Object {
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

#########################################
# Clears content for 'connected' computer
function DisconnectComputer
{
	$Script:ComputerObj.Clear()
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
		SetTitle -Replace -Text $msgTable.ComputerOnline
		Test-WSMan $tbComputerName.Text.Trim() -ErrorAction Stop

		$btnConnect.IsEnabled = $false
		$tbComputerName.IsReadOnly = $true
		$tcDator.Visibility = [System.Windows.Visibility]::Visible
		$btnDisconnect.Visibility = [System.Windows.Visibility]::Visible
		$ComputerObj.Computername = $tbComputerName.Text.Trim()
		CreateComputerInfo
	}
	catch
	{
		WriteErrorLog -LogText $_
		SetTitle -Add -Text $msgTable.ComputerOffline
		ShowMessageBox -Text "$( $msgTable.ComputerOfflineMessage )`n$_ " -Title $tbComputerName.Text
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
	$c | ForEach-Object { $ComputerObj.NetAdapters += [pscustomobject]@{ MAC = $_.MACAddress; NetDesc = $_.Description; IP = $_.IPAddress[0] } }

	$ComputerObj.Model = ( FetchPCInfo -Class win32_computersystem ).Model
	$ComputerObj.Serienummer = ( FetchPCInfo -Class win32_bios ).SerialNumber

	$c = FetchPCInfo -Class win32_operatingsystem
	$ComputerObj.TimeOfLastBoot = $c.LastBootUpTime.GetDateTimeFormats()[22]
	$ComputerObj.TimeOfInstallation = $c.InstallDate.GetDateTimeFormats()[22]
	$duration = ( Get-Date ) - $c.LastBootUpTime
	$ComputerObj.TimeSinceLastBoot = "$( $duration.Days ) dagar $( $duration.Hours ) timmar $( $duration.Minutes ) minuter"

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
	$PCRoll = Get-ADComputer $ComputerObj.Computername -Properties Memberof | Select-Object -ExpandProperty MemberOf | Where-Object { $_ -match "_Wrk_" }

	switch -Regex ( $PCRoll )
	{
		"Role1" { $r = "Role1-PC" }
		"Role2" { $r = "Role2-PC" }
	}
	if ( $null -eq $r ) { $r = $msgTable.ComputerUnknownRole }
	$ComputerObj.Roll = $r

	if ( $ComputerObj.Computername -notmatch "^($( $msgTable.OrgList ))" )
	{
		$ComputerObj.DontInstall = "$( $msgTable.ComputerNoReInstall ): $( $msgTable.StrOtherOrg )"
	}
	elseif ( $msgTable.CompList -match $ComputerObj.Computername )
	{
		$ComputerObj.DontInstall = "$( $msgTable.ComputerNoReInstall ): $( $msgTable.StrSpecComp )"
	}
	else
	{
		$c1 = $true
		$ComputerObj.Roll | ForEach-Object { if ( $_ -notmatch "($( $msgTable.RoleList ))" ) { $c1 = $false } }
		if ( -not $c1 )
		{
			$ComputerObj.DontInstall = "$( $msgTable.ComputerNoReInstall ): `n$( [string]( $PCRoll | Where-Object { $_ -notmatch "($( $msgTable.RoleList ))" } | ForEach-Object { ( ( $_ -split "=" )[1] -split "," )[0] } ) )"
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
		$Window.Title = $msgTable.StrScriptSuite
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
	$tI = [System.Windows.Controls.TabItem]@{ Name = "$( $msgTable.ComputerBaseInfo )"; Header = "$( $msgTable.ComputerBaseInfo )" }
	$datagrid = [System.Windows.Controls.DataGrid]@{ AutoGenerateColumns = $true }
	Set-Variable -Name datagrid -Value $datagrid

	$Script:colName = [System.Windows.Controls.DataGridTextColumn]@{ Header = "Name"; Width = "SizeToCells"; Binding = [System.Windows.Data.Binding]@{ Path = "Name" } }
	$Script:colInfo = [System.Windows.Controls.DataGridTextColumn]@{ Header = "Info"; Binding = [System.Windows.Data.Binding]@{ Path = "Info" } }

	GetPCInfo
	GetPCRole

	$ComputerObj.Keys | Sort-Object | ForEach-Object {
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
	$l = [System.Windows.Controls.Label]@{ Content = $msgTable.InputComputerName }
	$tb = [System.Windows.Controls.TextBox]@{
		Name = "tbComputerName"
		VerticalContentAlignment = "Center"
		Width = 200
	}
	$tb.Add_TextChanged( { if ( $this.Text.Length -gt 5 ) { $btnConnect.IsEnabled = $true } else { $btnConnect.IsEnabled = $false } } )
	$tb.Add_KeyDown( { if ( $args[1].Key -eq "Return" ) { StartWinRMOnRemoteComputer } } )
	Set-Variable -Name "tbComputerName" -Value $tb -Scope script

	$b = [System.Windows.Controls.Button]@{
		Content = $msgTable.ContentBtnGetComputerInfo
		IsEnabled = $false
		Margin = "5,0,0,0"
		Name = "btnConnect"
		Width = 75
	}
	$b.Add_Click( { StartWinRMOnRemoteComputer } )
	Set-Variable -Name "btnConnect" -Value $b -Scope script

	$b2 = [System.Windows.Controls.Button]@{
		Content = $msgTable.ContentBtnDisconnectComputer
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
		$FilesInFolder
	)

	$wpScriptGroup = [System.Windows.Controls.WrapPanel]@{ Orientation = "Vertical" }

	foreach ( $group in ( $FilesInFolder | Group-Object { $_.Group } | Sort-Object Name ) )
	{
		$gb = [System.Windows.Controls.GroupBox]@{ Header = $group.Name }
		$sp = [System.Windows.Controls.WrapPanel]@{ Orientation = "Vertical" }
		foreach ( $file in $group.Group )
		{
			# Check if user is member of a group required to allow running this script
			# or if user is listed as allowed user
			if ( ( ( $null -eq $file.Requires ) -or ( $file.Requires | ForEach-Object { if ( $_ -in $userGroups ) { $true } } ) ) -and `
				( ( $null -eq $file.AllowedUsers ) -or ( $env:USERNAME -in $file.AllowedUsers ) ) )
			{
				$wpScriptControls = New-Object System.Windows.Controls.WrapPanel
				$button = [System.Windows.Controls.Button]@{ Content = "$( $msgTable.ContentBtnRun ) >"; ToolTip = $file.Path }
				$label = [System.Windows.Controls.Label]@{ Content = $file.Synopsis; ToolTip = [string]$file.Description.Replace( ". ", ".`n" ) }

				if ( $file.Synopsis -match "$( $msgTable.ScriptContentInDev )" )
				{
					$label.Background = "Red"
					if ( $msgTable.AdmList -notmatch $env:USERNAME ) { $button.IsEnabled = $false }
				}
				elseif ( $file.Synopsis -match "$( $msgTable.ScriptContentInTest )" )
				{
					$label.Background = "LightBlue"
					$label.Content += "`n$( $msgTable.ContentLblInTest )"
				}

				$button.Add_Click( {
					$ProgramRunspace = [System.Management.Automation.PowerShell]::Create() # Create new runspace for the script to run in
					$scriptArguments = @( $this.ToolTip, ( Get-Item $PSScriptRoot ).Parent.FullName )

					# If script is in the computer-folder, add computername to runspace argumentlist
					if ( $this.ToolTip -match "$( $msgTable.ComputerFolder )\\" -and $tbComputerName.Text.Length -gt 0 )
					{ $scriptArguments += $tbComputerName.Text }

					# Checks if there exists a XAML-file for GUI for the script
					if ( Get-ChildItem "$( ( Get-Item $PSCommandPath ).Directory.Parent.FullName )\Gui" | Where-Object { $_.Name -match ( ( Get-Item $this.ToolTip ).Name -split "\." )[0] } ) { $hidden = $true }
					else { $hidden = $false }

					[void]$ProgramRunspace.AddScript( {
						param( $arg, $hidden )
						if ( $hidden )
						{ Start-Process powershell -WindowStyle Hidden -ArgumentList $arg } # Run script with GUI, without a PowerShell-window
						else
						{ Start-Process powershell -ArgumentList $arg } # Run script without GUI, with a PowerShell-window
					} ).AddArgument( $scriptArguments ).AddArgument( $hidden )

					$run = $ProgramRunspace.BeginInvoke() # Run runspace
					do { Start-Sleep -Milliseconds 50 } until ( $run.IsCompleted )
					$ProgramRunspace.Dispose()
				} )

				[void] $wpScriptControls.AddChild( $button )
				[void] $wpScriptControls.AddChild( $label )
				[void] $sp.AddChild( $wpScriptControls )
			}
		}

		# If there are scripts for this group, add groupbox
		if ( $sp.Children.Count -gt 0 )
		{
			$gb.Content = $sp
			$wpScriptGroup.AddChild( $gb )
		}
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
	( $dirPath.Name ).GetEnumerator() | ForEach-Object { if ( $_ -cmatch "\b[A-Z]") { $tT += " $_" } else { $tT += $_ } }
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
	if ( $msgTable.AdmList -match $env:USERNAME )
	{
		$Admins.Visibility = [System.Windows.Visibility]::Visible
		$btnCheckForUpdates.Add_Click( {
			$ProgramRunspace = [System.Management.Automation.PowerShell]::Create() # Create new runspace
			if ( ( Get-Item $PSScriptRoot ).Parent.Name -eq "Development" )
			{ $script = "Update-Scripts.ps1" }
			else
			{ $script = "Development\Update-Scripts.ps1" }
			$scriptArguments = @( "$( ( Get-Item $PSScriptRoot ).Parent.FullName )\$script", ( Get-Item $PSScriptRoot ).Parent.FullName )
			[void]$ProgramRunspace.AddScript( { param( $arg ); Start-Process powershell -WindowStyle Hidden -ArgumentList $arg } ).AddArgument( $scriptArguments )
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
	$ti = [System.Windows.Controls.TabItem]@{ Header = "$( $msgTable.ContentFeedbackHeader )"; Background = "#FFFF9C9C" }
	$sp = New-Object System.Windows.Controls.StackPanel
	$spScript = [System.Windows.Controls.StackPanel]@{ Orientation = "Horizontal" }
	$spSubject = [System.Windows.Controls.StackPanel]@{ Orientation = "Horizontal" }
	$cb = [System.Windows.Controls.ComboBox]@{ Height = "25"; Width = "300" }
	$tbText = [System.Windows.Controls.TextBox]@{ AcceptsReturn = $true; AcceptsTab = $true; TextWrapping = "WrapWithOverflow"; VerticalScrollBarVisibility = "Auto"; Height = "300" }
	$btnAdd = [System.Windows.Controls.Button]@{ Content = $msgTable.ContentBtnAddScript; IsEnabled = $false; Margin = "0,5,10,5" }
	$btnSend = [System.Windows.Controls.Button]@{ Content = $msgTable.ContentBtnSend; Tag = @{ 
		From = ( ( Get-ADUser ( Get-ADUser $env:USERNAME ).SamAccountName.Replace( $msgTable.StrAdmPrefix, "" ) -Properties EmailAddress ).EmailAddress )
		To = $msgTable.StrMailAddress
		SMTP = $msgTable.StrSMTP
		Body = "`n`n$( $msgTable.StrMailSender ):`n$( ( Get-ADUser $env:USERNAME ).Name )`n$( Get-Date -f "yyyy-MM-dd HH:mm:ss" )"
		Subject = $msgTable.StrScriptSuite } }
	$lblSubject = [System.Windows.Controls.Label]@{ Content = "$( $msgTable.ContentLblMessageType ): " }
	$rbR = [System.Windows.Controls.RadioButton]@{ Content = $msgTable.ContentRBtnErrorReport; GroupName = "Subject"; IsChecked = $true }
	$rbS = [System.Windows.Controls.RadioButton]@{ Content = $msgTable.ContentRBtnSuggestion; GroupName = "Subject" }

	Get-ChildItem $PSCommandPath.Directory -Filter "*ps1" -File -Recurse | Select-Object Name, @{ Name = "Synopsis"; Expression = { ( Select-String -InputObject $_ -Pattern "^.Synopsis" -Encoding Default ).Line.Replace( ".Synopsis ", "" ) } } | Sort-Object Synopsis | ForEach-Object { [void] $cb.Items.Add( "$( $_.Synopsis )`n`t$( $_.Name )" ) }

	$btnAdd.Add_Click( {
		$this.Parent.Parent.Children[2].Text = $this.Parent.Children[1].SelectedItem + "`n" + $this.Parent.Parent.Children[2].Text
		$this.Parent.Children[1].SelectedIndex = -1
		$this.IsEnabled = $false
	} )
	$btnSend.Add_Click( {
		$ofs = "`r`n"
		Send-MailMessage -From $this.Tag.From `
			-To $this.Tag.To `
			-Body "$( $this.Parent.Children[2].Text )$( $this.Tag.Body )" `
			-Encoding UTF8 `
			-SmtpServer $this.Tag.SMTP `
			-Subject $this.Tag.Subject
		$this.Parent.Children[2].Text = ""
	} )
	$cb.Add_DropDownClosed( { if ( $this.Text -eq [string]::Empty ) { $this.Parent.Children[0].IsEnabled = $false } else { $this.Parent.Children[0].IsEnabled = $true } } )

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
Import-Module "$( ( Get-Item $PSCommandPath ).Directory.Parent.FullName )\Modules\GUIOps.psm1" -Force

$userGroups = ( Get-ADUser $env:USERNAME -Properties memberof ).memberof | ForEach-Object { ( ( $_ -split "=" )[1] -split "," )[0] }
$Script:ComputerObj = @{}
$Window, $vars = CreateWindow
SetTitle -Add -Text $( $msgTable.StrScriptSuite )
if ( $PSCommandPath -match "Development" ) { SetTitle -Add " - Developer edition" }
$vars | ForEach-Object { Set-Variable -Name $_ -Value $Window.FindName( $_ ) }

Push-Location ( Get-Item $PSCommandPath ).Directory.FullName
$MainContent.AddChild( ( GetFolderItems "" ) )
FulHack
CheckForAdmin
AddReportTool
$Window.Add_Loaded( { $Window.Activate() } )

[void] $Window.ShowDialog()
Pop-Location
$Window.Close()
