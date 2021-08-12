<#
.Synopsis Main script
.Description Main script for collecting and accessing script
.Author Smorkster (smorkster)
#>

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

#######################################################################
# Create controls to hold computerinfo and buttons for computer-scripts
function CreateComputerInfo
{
	$tI = [System.Windows.Controls.TabItem]@{ Name = "$( $msgTable.ComputerBaseInfo )"; Header = "$( $msgTable.ComputerBaseInfo )" }
	$datagrid = [System.Windows.Controls.DataGrid]@{ AutoGenerateColumns = $true ; IsReadOnly = $true }
	$datagrid.Add_MouseDoubleClick( {
		"$( $this.CurrentCell.Item."$( $this.CurrentCell.Column.Header )" )" | clip
		$splash = [System.Windows.Window]@{ WindowStartupLocation = "CenterScreen" ; WindowStyle = "None"; ResizeMode = "NoResize"; SizeToContent = "WidthAndHeight" }
		$splash.AddChild( [System.Windows.Controls.Label]@{ Content = "'$( $this.CurrentCell.Column.Header )' $( $msgTable.StrInfoCopied )"; BorderBrush = "Green"; BorderThickness = 5 } )
		$splash.Show()
		Start-Sleep -Seconds 1.5
		$splash.Close()
	} )

	$datagrid.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = "Name"; Width = "SizeToCells"; Binding = [System.Windows.Data.Binding]@{ Path = "Name" } } ) )
	$datagrid.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = "Info"; Binding = [System.Windows.Data.Binding]@{ Path = "Info" } } ) )

	if ( $Window.Resources["WinRM"] ) { GetPCInfo }
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
			if ( [double]( ( $ComputerObj.$( $_ ) -split " " )[0] ) -lt 20 )
			{
				$name += " (Low)"
			}
		}

		$datagrid.AddChild( [pscustomobject]@{ "Name" = $name; "Info" = $info } )
	}

	$tI.AddChild( $datagrid )
	$tcComputer_Default.Items.Insert( 0, $tI )
	$tcComputer_Default.SelectedIndex = 0
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

####################################################
# Create controls to connect to O365-online services
function CreateO365Input
{
	$mainSP = [System.Windows.Controls.StackPanel]@{ Orientation = "Horizontal" }
	$l = [System.Windows.Controls.Label]@{ Content = $msgTable.ContentO365Start }
	$b = [System.Windows.Controls.Button]@{
		Content = $msgTable.ContentBtnO365Connect
		Margin = "5,0,0,0"
		Name = "btnO365Connect"
	}
	#$b.Add_Click( { Invoke-Expression "$( ( Get-ChildItem $PSCommandPath ).Directory.FullName )\O365\O365GUI.ps1 '$LocalizeCulture'" } )
	$b.Add_Click( {
		$p = [powershell]::Create().AddScript( {
			param ( $p )
			Start-Process powershell -ArgumentList $p -WindowStyle Hidden
		} )
		$p.AddArgument( @( "$( ( Get-ChildItem $PSCommandPath ).Directory.FullName )\O365\O365GUI.ps1", $LocalizeCulture ) )
		$h = $p.begininvoke()
	} )
	Set-Variable -Name "btnO365Connect" -Value $b -Scope script

	$mainSP.AddChild( $l )
	$mainSP.AddChild( $b )
	return $mainSP
}

####################################################################
# Create a group of buttons and labels for all scriptfiles in folder
function CreateScriptGroup
{
	param (
		$dirPath
	)

	if ( $FilesInFolder = GetFiles $dirPath )
	{
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
					$wpScriptControls.Name = "wp$( $file.Name -replace "\W" )"
					$button = [System.Windows.Controls.Button]@{ Content = "$( $msgTable.ContentBtnRun ) >"; ToolTip = $file.Path }
					$button.Name = "btn$( $file.Name -replace "\W" )"
					$label = [System.Windows.Controls.Label]@{ Content = $file.Synopsis; ToolTip = [string]$file.Description.Replace( ". ", ".`n" ) }
					$label.Name = "lbl$( $file.Name -replace "\W" )"

					if ( $file.Depends -in ( $Window.Resources.Keys | Where-Object { $null -eq $_.IsPublic } ) )
					{ $wpScriptControls.SetResourceReference( [System.Windows.Controls.WrapPanel]::IsEnabledProperty, $file.Depends ) }

					if ( $file.State -match "$( $msgTable.ScriptContentInDev )" )
					{
						$label.Background = "Red"
						if ( $msgTable.AdmList -match $env:USERNAME -or $file.Author -eq $env:USERNAME ) { $button.IsEnabled = $true }
						else { $button.IsEnabled = $false }
					}
					elseif ( $file.State -match "$( $msgTable.ScriptContentInTest )" )
					{
						$label.Background = "LightBlue"
						$label.Content += "`n$( $msgTable.ContentLblInTest )"
					}

					$button.Add_Click( {
						$scriptArguments = @( $this.ToolTip, ( Get-Item $PSScriptRoot ).Parent.FullName, $LocalizeCulture )
						if ( $this.ToolTip -match $msgTable.O365Folder )
						{
							Invoke-Command -ScriptBlock { & $this.ToolTip $scriptArguments[1] }
						}
						else
						{
							$ProgramRunspace = [System.Management.Automation.PowerShell]::Create() # Create new runspace for the script to run in

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
						}
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

#########################################
# Clears content for 'connected' computer
function DisconnectComputer
{
	$Script:ComputerObj.Clear()
	if ( $tcComputer_Default.Items[ 0 ].Header -eq $msgTable.ComputerBaseInfo ) { $tcComputer_Default.Items.RemoveAt( 0 ) }
	$btnConnect.IsEnabled = $true
	$tbComputerName.IsReadOnly = $false
	$tbComputerName.Text = ""
	$tcComputer_Default.Visibility = [System.Windows.Visibility]::Collapsed
	$btnDisconnect.Visibility = [System.Windows.Visibility]::Collapsed
}

#####################################
# Get WMI information for given class
function FetchPCInfo
{
	param ( $Class, $Filter = $null )
	return Get-CimInstance -ComputerName $ComputerObj.Computername -ClassName $Class -Filter $Filter
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
	Set-Variable -Name tcComputer_Default -Value ( Get-Variable "tc$( $msgTable.ComputerFolder )" ).Value -Scope script
}

#########################################
# Get scriptfiles in the specified folder
function GetFiles
{
	param ( $dirPath )
	$Get = { ( Select-String -InputObject $_ -Pattern "^\.$( $args[0] )" -Encoding UTF8 ).Line.Replace( ".$( $args[0] ) ", "" ) }
	Get-ChildItem -File -Filter "*ps1" -Path $dirPath.FullName | Where-Object { $_.Name -ne ( Get-Item $PSCommandPath ).Name } | `
		Select-Object -Property @{ Name = "Name"; Expression = { $_.Name } }, `
			@{ Name = "Path"; Expression = { $_.FullName } }, `
			@{ Name = "Group"; Expression = { ( $_.BaseName -split "-" )[0] } }, `
			@{ Name = "Synopsis"; Expression = { & $Get "Synopsis" } }, `
			@{ Name = "Description"; Expression = { & $Get "Description" } }, `
			@{ Name = "Requires"; Expression = { ( & $Get "Requires" ) -split "\W" | Where-Object { $_ } } }, `
			@{ Name = "AllowedUsers"; Expression = { ( & $Get "AllowedUsers") -split "\W" | Where-Object { $_ } } }, `
			@{ Name = "State"; Expression = { ( & $Get "State") -split "\W" | Where-Object { $_ } } }, `
			@{ Name = "Author"; Expression = { ( ( Select-String $_ -Pattern "^.Author" ).Line -split "\(" )[1].TrimEnd( ")" ) } }, `
			@{ Name = "Depends"; Expression = { ( ( & $Get "Depends" ) ) -split "\W" | Where-Object { $_ } } } | `
			Sort-Object Synopsis
}

####################################################
# Search folder for items, operate depending on type
function GetFolderItems
{
	param (
		$dirPath
	)

	$spFolder = [System.Windows.Controls.WrapPanel]@{ Orientation = "Vertical"; Name = "wp$( $dirPath.Name -replace " " )" }
	Set-Variable -Name  "wp$( $dirPath.Name )" -Value $spFolder -Scope script
	if ( $dirPath -match $msgTable.O365Folder )
	{
		$spFolder.AddChild( ( CreateO365Input ) )
	}
	else
	{
		if ( $wpScriptGroup = CreateScriptGroup $dirPath ) { $spFolder.AddChild( $wpScriptGroup ) }
		if ( $dirPath.Name -eq $msgTable.ComputerFolder ) { $spFolder.AddChild( ( CreateComputerInput ) ) }
		if ( $dirs = Get-ChildItem -Directory -Path $dirPath.FullName )
		{
			$tabControl = [System.Windows.Controls.TabControl]@{ Name = "tc$( $dirPath.Name -replace " " )" }

			if ( $dirPath.Name -eq $msgTable.ComputerFolder ) { $tabControl.Visibility = [System.Windows.Visibility]::Collapsed }
			elseif ( $dirPath.Name -eq $msgTable.O365Folder ) { $tabControl.Visibility = [System.Windows.Visibility]::Collapsed }

			if ( $dirPath -eq "" ) { $tabControl.MaxHeight = 700 }
			Set-Variable -Name ( "tc" + $( $dirPath.Name ) ) -Value $tabControl -Scope script

			$tiList = @()
			foreach ( $dir in $dirs )
			{
				if ( $dir.Name -eq $msgTable.O365Folder ) { if ( $msgTable.StrBORole -notin $userGroups ) { continue } }
				$tiList += ( CreateTabItem $dir )
			}
			$tiList | Sort-Object $_.Header | ForEach-Object {
				if ( $_.Content.Children[0].Content.Children.Count -eq 0 )
				{
					$_.Visibility = [System.Windows.Visibility]::Collapsed
				}
				$tabControl.AddChild( $_ )
			}
			$spFolder.AddChild( $tabControl )
		}
	}

	return $spFolder
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
	$ADPC = Get-ADComputer $ComputerObj.Computername -Properties Memberof, OperatingSystem
	$ComputerObj.Roll = $null
	$ComputerObj.( $msgTable.StrOSParam ) = $ADPC.OperatingSystem

	switch -Regex ( $ADPC.MemberOf | Where-Object { $_ -match "_Wrk_" } )
	{
		"Role1" { $r = "PCRole 1" }
		"Role2" { $r = "PCRole 2" }
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

################################
# Check if computer is reachable
function StartWinRMOnRemoteComputer
{
	SetTitle -Replace -Text $msgTable.ComputerOnline
	$tcComputer_Default.Visibility = [System.Windows.Visibility]::Visible
	$btnDisconnect.Visibility = [System.Windows.Visibility]::Visible
	$ComputerObj.Computername = $tbComputerName.Text.Trim()

	try
	{
		Get-CimInstance -ComputerName $tbComputerName.Text.Trim() -ClassName win32_operatingsystem -ErrorAction Stop

		$Window.Resources["WinRM"] = $true
	}
	catch
	{
		$Window.Resources["WinRM"] = $false
		WriteErrorLog -LogText $_
		SetTitle -Add -Text $msgTable.ComputerOffline
		ShowMessageBox -Text $msgTable.ComputerOfflineMessage -Title $tbComputerName.Text | Out-Null
	}
	CreateComputerInfo
	$btnConnect.IsEnabled = $false
	$tbComputerName.IsReadOnly = $true
}

############################## Script start
Add-Type -AssemblyName PresentationFramework
$culture = "sv-SE"
$BaseDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
if ( ( [System.Globalization.CultureInfo]::GetCultures( "AllCultures" ) ).Name -contains $culture ) { $LocalizeCulture = $culture }
else
{
	[System.Windows.MessageBox]::Show( "'$culture' is not a valid localization language.`nWill use default 'sv-SE'" )
	$LocalizeCulture = "sv-SE"
}
Import-Module "$BaseDir\Modules\FileOps.psm1" -Force -ArgumentList $LocalizeCulture
Import-Module "$BaseDir\Modules\GUIOps.psm1" -Force -ArgumentList $LocalizeCulture

$splash = ShowSplash -Text $msgTable.StrSplash -SelfAdmin
$splash.Show()
$userGroups = ( Get-ADUser $env:USERNAME -Properties memberof ).memberof | ForEach-Object { ( ( $_ -split "=" )[1] -split "," )[0] }
$Script:ComputerObj = @{}
$Window, $vars = CreateWindow
SetTitle -Add -Text $( $msgTable.StrScriptSuite )
if ( $PSCommandPath -match "Development" ) { SetTitle -Add " - Developer edition" }
$vars | ForEach-Object { Set-Variable -Name $_ -Value $Window.FindName( $_ ) }

Push-Location ( Get-Item $PSCommandPath ).Directory.FullName
$MainContent.AddChild( ( GetFolderItems "" ) )
FulHack
AddReportTool
$Window.Add_Loaded( { $Window.Activate(); $splash.Close() } )

[void] $Window.ShowDialog()
Pop-Location
$Window.Close()
#$global:window = $window