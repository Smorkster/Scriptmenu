<#
.Synopsis Main script
.Description Main script for collecting and accessing script
.Author Smorkster (smorkster)
#>

class ComputerObject
{
	$ComputerName = @{ Name = ""; Value = "" }
	$ReinstallAllowed = @{ Name = ""; Value = "" }
	$FreeSpace = @{ Name = ""; Value = "" }
	$IEVersion = @{ Name = ""; Value = "" }
	$Model = @{ Name = ""; Value = "" }
	$NetAdapters = @{ Name = ""; Value = @() }
	$Operatingsystem = @{ Name = ""; Value = "" }
	$Role = @{ Name = ""; Value = "" }
	$Serialnumber = @{ Name = ""; Value = "" }
	$TimeOfInstallation = @{ Name = ""; Value = "" }
	$TimeOfLastBoot = @{ Name = ""; Value = "" }
	$TimeSinceLastBoot = @{ Name = ""; Value = "" }
	hidden $msgTable = $null

	ComputerObject ( $msgTable )
	{
		$this.ComputerName.Name = $msgTable.CompObjTitleCompName
		$this.ReinstallAllowed.Name = $msgTable.CompObjTitleReinstAllowed
		$this.FreeSpace.Name = $msgTable.CompObjTitleFreeSpace
		$this.IEVersion.Name = $msgTable.CompObjTitleIEVer
		$this.Model.Name = $msgTable.CompObjTitleModel
		$this.NetAdapters.Name = $msgTable.CompObjTitleNetAd
		$this.OperatingSystem.Name = $msgTable.CompObjTitleOS
		$this.Role.Name = $msgTable.CompObjTitleRole
		$this.Serialnumber.Name = $msgTable.CompObjTitleSN
		$this.TimeOfInstallation.Name = $msgTable.CompObjTitleInst
		$this.TimeOfLastBoot.Name = $msgTable.CompObjTitleBoot
		$this.TimeSinceLastBoot.Name = $msgTable.CompObjTitleSinceBoot
		$this.msgTable = $msgTable
	}

	[void] AddDiskInfo ( $Info )
	{
		if ( $Info.FreeSpace -gt 20GB ) { $this.FreeSpace.Name = $this.msgTable.CompObjTitleFreeSpace }
		else { $this.FreeSpace.Name = $this.msgTable.CompObjTitleFreeSpaceLow }

		if ( $Info.FreeSpace -gt 1GB ) { $size = "GB" }
		else { $size = "MB" }
		$this.FreeSpace.Value = "$( [math]::Round( $Info.FreeSpace / "1$( $size )" , 2 ) ) $size"
	}

	[void] AddTimeInfo ( $Info )
	{
		$this.TimeSinceLastBoot.Value = "{0:dd} $( $this.msgTable.StrBaseInfoDays ), {0:hh} $( $this.msgTable.StrBaseInfoHours ), {0:mm} $( $this.msgTable.StrBaseInfoMinutes )" -f ( ( Get-Date ) - $Info.LastBootUpTime )
		$this.TimeOfLastBoot.Value = $Info.LastBootUpTime.GetDateTimeFormats()[22]
		$this.TimeOfInstallation.Value = $Info.InstallDate.GetDateTimeFormats()[22]
	}

	[void] Clear ()
	{
		$this.ComputerName.Value = ""
		$this.ReinstallAllowed.Value = ""
		$this.FreeSpace.Value = ""
		$this.IEVersion.Value = ""
		$this.Model.Value = ""
		$this.NetAdapters.Value.Clear()
		$this.Operatingsystem.Value = ""
		$this.Role.Value = ""
		$this.Serialnumber.Value = ""
		$this.TimeOfInstallation.Value = ""
		$this.TimeOfLastBoot.Value = ""
		$this.TimeSinceLastBoot.Value = ""
	}
}

#######################################################################
# Create controls to hold computerinfo and buttons for computer-scripts
function CreateComputerInfo
{
	if ( $syncHash.Window.Resources["WinRM"] ) { GetPCInfo }
	GetPCRole

	$syncHash.ComputerObj.psobject.Properties.Where( { $_.MemberType -eq "Property" } ) | ForEach-Object {
		$Name = $_.Value.Name
		$Info = $_.Value.Value
		if ( $_.Name -eq "NetAdapters" )
		{
			$_.Value.Value | ForEach-Object { $syncHash.DC.dgBaseInfo[0].Add( [pscustomobject]@{ "Name" = "$( $msgTable.StrBaseInfoNetAd )`n$( $_.NetDesc )"; "Info" = "IP: $( $_.IP )`nMAC: $( $_.MAC )" } )
			}
		}
		else
		{
			$syncHash.DC.dgBaseInfo[0].Add( [pscustomobject]@{ "Name" = $Name; "Info" = $Info } )
		}
	}
	$syncHash.tcComputer_Default.SelectedIndex = 0
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
					$wpScriptControls = [System.Windows.Controls.WrapPanel]@{}
					$wpScriptControls.Name = "wp$( $file.ScriptName -replace "\W" )"
					$button = [System.Windows.Controls.Button]@{ Content = "$( $msgTable.ContentBtnRun ) >"; ToolTip = $file.Path; Tag = $file }
					$name = "btn$( $file.Name -replace "\W" )"
					$button.Name = $name
					$label = [System.Windows.Controls.Label]@{ Content = $file.Synopsis; ToolTip = [string]$file.Description.Replace( ". ", ".`n" ) }
					$label.Name = "lbl$( $file.ScriptName -replace "\W" )"

					if ( $file.Depends -in ( $syncHash.Window.Resources.Keys | Where-Object { $null -eq $_.IsPublic } ) )
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
							# If script is in the computer-folder, add computername to runspace argumentlist
							if ( $this.ToolTip -match "$( $msgTable.ComputerFolder )\\" -and $tbComputerName.Text.Length -gt 0 )
							{ $scriptArguments += $tbComputerName.Text }

							# Checks if there exists a XAML-file for GUI for the script
							if ( Get-ChildItem "$( ( Get-Item $PSCommandPath ).Directory.Parent.FullName )\Gui" | Where-Object { $_.Name -match ( ( Get-Item $this.ToolTip ).Name -split "\." )[0] } )
							# XAML-file exists, PowerShell-window will be hidden
							{ $hidden = "Hidden" }
							# No XAML-file, PowerShell-window will be shown, to handle script input/output
							else { $hidden = "Normal" }

							# Create new runspace for the script to run in
							$ProgramRunspace = [powershell]::Create().AddScript( {
								param( $scriptArguments, $hidden )
								Start-Process powershell -WindowStyle $hidden -ArgumentList $scriptArguments
							} ).AddArgument( $scriptArguments ).AddArgument( $hidden )

							$run = $ProgramRunspace.BeginInvoke() # Run runspace
							if ( $this.Tag.State -eq $msgTable.ScriptContentInTest )
							{
								$syncHash.DC.lblRateTitle[0] = "$( $msgTable.ContentlblRateTitle ):"
								$syncHash.DC.lblRateScript[0] = $this.Tag.Name
								$syncHash.DC.WindowSurvey[1] = [System.Windows.Visibility]::Visible
								$syncHash.DC.WindowSurvey[2].ScriptName = $this.Tag.Name
								$syncHash.DC.WindowSurvey[2].Survey.ScriptVersion = Get-Date ( Get-Item $this.Tag.Path ).LastWriteTime -f "yyyy-MM-dd hh:mm:ss"
							}
						}
					} )

					$syncHash.$name = $button
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

	$g = [System.Windows.Controls.Grid]@{}
	$scroller = [System.Windows.Controls.ScrollViewer]@{}
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
	$syncHash.ComputerObj.Clear()
	$syncHash.DC.dgBaseInfo[0].Clear()
	$syncHash.tcComputer_Default.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.btnComputerConnect[1] = $true
	$syncHash.DC.tbComputerName[0] = $false
	$syncHash.tbComputerName.Text = ""
	$syncHash.DC.btnComputerDisconnect[2] = [System.Windows.Visibility]::Collapsed
}

#####################################
# Get WMI information for given class
function FetchPCInfo
{
	param ( $Class, $Filter = $null )
	return Get-CimInstance -ComputerName $syncHash.ComputerObj.ComputerName.Value -ClassName $Class -Filter $Filter
}

#####################################
# Small tweaks before window launches
function FulHack
{
	# Sort the tabitems that are not generated from folders
	$tiScoreboard.Background = "Gold"
	$temp = $tiScoreboard
	$syncHash.tc.Items.RemoveAt( $syncHash.tc.Items.IndexOf( $tiScoreboard ) )
	$syncHash.tc.Items.Insert( ( $syncHash.tc.Items.Count ), $temp )
	$syncHash.tc.Items.Insert( $syncHash.tc.Items.Count, $syncHash.tiOutputTool )
	$syncHash.tc.Items.Insert( $syncHash.tc.Items.Count, $syncHash.tiReportTool )

	$syncHash.DC.cbScriptList[0] = $syncHash.DC.cbScriptList[0] | Sort-Object CBName
	# Define the nametrigger for computerinfo-datagrid
	$syncHash.Window.Resources[[System.Windows.Controls.DatagridRow]].Triggers[0].Value = $msgTable.CompObjTitleReinstNotAllowed
	$syncHash.Window.Resources[[System.Windows.Controls.DatagridRow]].Triggers[1].Value = $msgTable.CompObjTitleReinstAllowed

	$syncHash.tcComputer_Default = $syncHash."tc$( $msgTable.ComputerFolder )"
	$syncHash.tcComputer_Default.Items.Insert( 0, $syncHash.Window.Resources['tiBaseInfo'] )

	# Set mainwindow Y-position and activate it
	$syncHash.Window.Add_ContentRendered( { $syncHash.Window.Top = 50; $syncHash.Window.Activate() } )
}

#########################################
# Get scriptfiles in the specified folder
function GetFiles
{
	param ( $dirPath )
	$Get = { ( Select-String -InputObject $_ -Pattern "^\.$( $args[0] )" -Encoding UTF8 ).Line.Replace( ".$( $args[0] ) ", "" ) }
	$files = Get-ChildItem -File -Filter "*ps1" -Path $dirPath.FullName | Where-Object { $_.Name -ne ( Get-Item $PSCommandPath ).Name } | `
		Select-Object -Property @{ Name = "Name" ; Expression = { $_.Name } }, `
			@{ Name = "Path"; Expression = { $_.FullName } }, `
			@{ Name = "Group"; Expression = { ( $_.BaseName -split "-" )[0] } }, `
			@{ Name = "Synopsis"; Expression = { & $Get "Synopsis" } }, `
			@{ Name = "Description"; Expression = { & $Get "Description" } }, `
			@{ Name = "Requires"; Expression = { ( & $Get "Requires" ) -split "\W" | Where-Object { $_ } } }, `
			@{ Name = "AllowedUsers"; Expression = { ( & $Get "AllowedUsers" ) -split "\W" | Where-Object { $_ } } }, `
			@{ Name = "State"; Expression = { ( & $Get "State" ) -split "\W" | Where-Object { $_ } } }, `
			@{ Name = "Author"; Expression = { ( ( Select-String $_ -Pattern "^.Author" ).Line -split "\(" )[1].TrimEnd( ")" ) } }, `
			@{ Name = "Depends"; Expression = { ( ( & $Get "Depends" ) ) -split "\W" | Where-Object { $_ } } }, `
			@{ Name = "CBName"; Expression = { "$( & $Get "Synopsis" ) ($( $_.Name ))" } } | `
			Sort-Object Synopsis
	$files | ForEach-Object { $syncHash.DC.cbScriptList[0].Add( $_ ) }
	return $files
}

####################################################
# Search folder for items, operate depending on type
function GetFolderItems
{
	param (
		$dirPath
	)

	$spFolder = [System.Windows.Controls.WrapPanel]@{ Orientation = "Vertical"; Name = "wp$( $dirPath.Name -replace " " )" }
	if ( $dirPath -match $msgTable.O365Folder )
	{
		$spFolder.AddChild( ( $syncHash.Window.Resources['spO365'] ) )
		$syncHash.spO365 = $syncHash.Window.Resources['spO365']
	}
	else
	{
		if ( $wpScriptGroup = CreateScriptGroup $dirPath ) { $spFolder.AddChild( $wpScriptGroup ) }
		if ( $dirPath.Name -eq $msgTable.ComputerFolder ) { $spFolder.AddChild( ( $syncHash.Window.Resources['ComputerSP'] ) ) }
		if ( $dirs = Get-ChildItem -Directory -Path $dirPath.FullName )
		{
			$name = "tc$( $dirPath.Name -replace " " )"
			$syncHash.$name = [System.Windows.Controls.TabControl]@{ Name = $name }

			if ( $dirPath.Name -eq $msgTable.ComputerFolder ) { $syncHash.$name.Visibility = [System.Windows.Visibility]::Collapsed }
			elseif ( $dirPath.Name -eq $msgTable.O365Folder ) { $syncHash.$name.Visibility = [System.Windows.Visibility]::Collapsed }

			if ( $dirPath -eq "" ) { $syncHash.$name.MaxHeight = 700 }

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
				$syncHash.$name.AddChild( $_ )
			}
			$spFolder.AddChild( $syncHash.$name )
		}
	}

	return $spFolder
}

######################################
# Get information from remote computer
function GetPCInfo
{
	FetchPCInfo -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled='True'" | Where-Object { $_ } | ForEach-Object { $syncHash.ComputerObj.NetAdapters.Value += [pscustomobject]@{ MAC = $_.MACAddress; NetDesc = $_.Description; IP = $_.IPAddress[0] } }

	$syncHash.ComputerObj.Model.Value = ( FetchPCInfo -Class win32_computersystem ).Model
	$syncHash.ComputerObj.Serialnumber.Value = ( FetchPCInfo -Class win32_bios ).SerialNumber

	$syncHash.ComputerObj.AddTimeInfo( ( FetchPCInfo -Class win32_operatingsystem ) )

	$syncHash.ComputerObj.IEVersion.Value = ( ( [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey( 'LocalMachine', $syncHash.ComputerObj.ComputerName.Value ) ).OpenSubKey( "SOFTWARE\\Microsoft\\Internet Explorer" ) ).GetValue( 'svcVersion' )

	$syncHash.ComputerObj.AddDiskInfo( ( FetchPCInfo -Class CIM_LogicalDisk -Filter "DeviceID like 'C:'" ) )
}

###############################
# Get PCRole of remote computer
function GetPCRole
{
	$ADPC = Get-ADComputer $syncHash.ComputerObj.ComputerName.Value -Properties Memberof, OperatingSystem
	$syncHash.ComputerObj.Role.Value = $null
	$syncHash.ComputerObj.OperatingSystem.Value = $ADPC.OperatingSystem

	switch -Regex ( $ADPC.MemberOf | Where-Object { $_ -match "_Wrk_" } )
	{
		"Role1" { $r = "PCRole 1" }
		"Role2" { $r = "PCRole 2" }
	}
	if ( $null -eq $r ) { $r = $msgTable.ComputerUnknownRole }
	$syncHash.ComputerObj.Role.Value = $r

	if ( $syncHash.ComputerObj.ComputerName.Value -notmatch "^($( $msgTable.OrgList ))" )
	{
		$syncHash.ComputerObj.ReinstallAllowed.Name = $msgTable.CompObjTitleReinstNotAllowed
		$syncHash.ComputerObj.ReinstallAllowed.Value = "$( $msgTable.ComputerNoReInstall ):`n$( $msgTable.StrOtherOrg )"
	}
	elseif ( $msgTable.CompList -match $syncHash.ComputerObj.ComputerName.Value )
	{
		$syncHash.ComputerObj.ReinstallAllowed.Name = $msgTable.CompObjTitleReinstNotAllowed
		$syncHash.ComputerObj.ReinstallAllowed.Value = "$( $msgTable.ComputerNoReInstall ):`n$( $msgTable.StrSpecComp )"
	}
	elseif ( $msgTable.RoleList -notmatch $syncHash.ComputerObj.Role.Value )
	{
		$syncHash.ComputerObj.ReinstallAllowed.Name = $msgTable.CompObjTitleReinstNotAllowed
		$syncHash.ComputerObj.ReinstallAllowed.Value = "$( $msgTable.ComputerNoReInstall ):`n$( [string]( $PCRoll | Where-Object { $_ -notmatch "($( $msgTable.RoleList ))" } | ForEach-Object { ( ( $_ -split "=" )[1] -split "," )[0] } ) )"
	}
	else
	{
		$syncHash.ComputerObj.ReinstallAllowed.Name = $msgTable.CompObjTitleReinstAllowed
		$syncHash.ComputerObj.ReinstallAllowed.Value = ""
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

	if ( $Add ) { $syncHash.DC.Window[0] += $Text }
	elseif ( $Remove ) { $syncHash.DC.Window[0] = $msgTable.ContentWindow }
	elseif ( $Replace ) { $syncHash.DC.Window[0] = $Text }
}

################################
# Check if computer is reachable
function StartWinRMOnRemoteComputer
{
	SetTitle -Replace -Text $msgTable.ComputerOnline
	$syncHash.tcComputer_Default.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.DC.btnComputerDisconnect[2] = [System.Windows.Visibility]::Visible
	$syncHash.ComputerObj.ComputerName.Value = $syncHash.tbComputerName.Text.Trim()

	try
	{
		Get-CimInstance -ComputerName $syncHash.ComputerObj.ComputerName.Value -ClassName win32_operatingsystem -ErrorAction Stop
		$syncHash.Window.Resources["WinRM"] = $true
	}
	catch
	{
		$syncHash.Window.Resources["WinRM"] = $false
		$eh = WriteErrorlogTest -LogText $_ -UserInput $msgTable.LogConnectingToComp -ComputerName $syncHash.ComputerObj.ComputerName.Value -Severity "OtherFail"
		SetTitle -Add -Text $msgTable.ComputerOffline
		ShowMessageBox -Text $msgTable.ComputerOfflineMessage -Title $tbComputerName.Text | Out-Null
	}
	WriteLogTest -UserInput $msgTable.LogConnectingToComp -ComputerName $syncHash.ComputerObj.ComputerName.Value -Success ( $null -eq $eh ) -ErrorLogHash $eh
	CreateComputerInfo
	$syncHash.DC.btnComputerConnect[1] = $false
	$syncHash.DC.btnComputerDisconnect[1] = $true
	$syncHash.DC.tbComputerName[0] = $true
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

$controls = [System.Collections.ArrayList]::new()
[void] $controls.Add( @{ CName = "btnO365Connect" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnO365Connect } ) } )
[void] $controls.Add( @{ CName = "btnAddScript" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddScript } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void] $controls.Add( @{ CName = "btnComputerConnect" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnComputerConnect } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void] $controls.Add( @{ CName = "btnComputerDisconnect" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnComputerDisconnect } ; @{ PropName = "IsEnabled" ; PropVal = $false } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void] $controls.Add( @{ CName = "btnFeedbackSend" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnFeedbackSend } ; @{ PropName = "Tag" ; PropVal = @{ 
		From = ( ( Get-ADUser ( Get-ADUser $env:USERNAME ).SamAccountName.Replace( $msgTable.StrAdmPrefix, "" ) -Properties EmailAddress ).EmailAddress )
		To = $msgTable.StrMailAddress
		SMTP = $msgTable.StrSMTP
		Body = "`n`n$( $msgTable.StrMailSender ):`n$( ( Get-ADUser $env:USERNAME ).Name )`n$( Get-Date -f "yyyy-MM-dd HH:mm:ss" )"
		Subject = $msgTable.ContentWindow } } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void] $controls.Add( @{ CName = "btnListOutputFiles" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnListOutputFiles } ) } )
[void] $controls.Add( @{ CName = "btnOpenOutputFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenOutputFile } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void] $controls.Add( @{ CName = "btnSurveyCancel" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSurveyCancel } ) } )
[void] $controls.Add( @{ CName = "btnSurveySave" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSurveySave } ) } )
[void] $controls.Add( @{ CName = "cbScriptList" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[object] ) } ) } )
[void] $controls.Add( @{ CName = "dgBaseInfo" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[object] ) } ) } )
[void] $controls.Add( @{ CName = "dgOutputFiles" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[object] ) } ; @{ PropName = "SelectedItem" ; PropVal = $null } ; @{ PropName = "SelectedIndex" ; PropVal = -1 } ) } )
[void] $controls.Add( @{ CName = "lblComputerNameTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblComputerNameTitle } ) } )
[void] $controls.Add( @{ CName = "lblFeedbackType" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblFeedbackType } ) } )
[void] $controls.Add( @{ CName = "lblO65" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblO65 } ) } )
[void] $controls.Add( @{ CName = "lblRateScript" ; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void] $controls.Add( @{ CName = "lblRateTitle" ; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void] $controls.Add( @{ CName = "lblSurvey" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSurvey } ) } )
[void] $controls.Add( @{ CName = "rbReport" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbReport } ; @{ PropName = "IsChecked" ; PropVal = $true } ) } )
[void] $controls.Add( @{ CName = "rbSuggestion" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbSuggestion } ) } )
[void] $controls.Add( @{ CName = "rbSurveyRate1" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbSurveyRate1 } ) } )
[void] $controls.Add( @{ CName = "rbSurveyRate2" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbSurveyRate2 } ) } )
[void] $controls.Add( @{ CName = "rbSurveyRate3" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbSurveyRate3 } ) } )
[void] $controls.Add( @{ CName = "rbSurveyRate4" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbSurveyRate4 } ) } )
[void] $controls.Add( @{ CName = "rbSurveyRate5" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbSurveyRate5 } ) } )
[void] $controls.Add( @{ CName = "tbComputerName" ; Props = @( @{ PropName = "IsReadOnly"; PropVal = $false } ) } )
[void] $controls.Add( @{ CName = "tbFeedback" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void] $controls.Add( @{ CName = "tiBaseInfo" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiBaseInfo } ) } )
[void] $controls.Add( @{ CName = "tiOutputTool" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiOutputTool } ) } )
[void] $controls.Add( @{ CName = "tiReportTool" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiReportTool } ) } )
[void] $controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = $msgTable.ContentWindow } ) } )
[void] $controls.Add( @{ CName = "WindowSurvey" ; Props = @( @{ PropName = "Title"; PropVal = $msgTable.ContentWindowSurvey } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden } ; @{ PropName = "Tag" ; PropVal = [pscustomobject]@{ Survey = ( NewSurvey ) ; ScriptName = "" } } ) } )

$syncHash = CreateWindowExt $controls
if ( Test-Path "C:\Program Files (x86)\Notepad++\notepad++.exe" ) { $syncHash.Editor = "C:\Program Files (x86)\Notepad++\notepad++.exe" }
else { $syncHash.Editor = "notepad" }
$syncHash.ComputerObj = [ComputerObject]::new( $msgTable )
$syncHash.LocalizeCulture = $LocalizeCulture
$syncHash.Error = @()

if ( $PSCommandPath -match "Development" ) { SetTitle -Add " - Developer edition" }

Push-Location ( Get-Item $PSCommandPath ).Directory.FullName
$syncHash.MainContent.AddChild( ( GetFolderItems "" ) )
FulHack

# Open GUI for Office365-script
$syncHash.btnO365Connect.Add_Click( {
	$p = [powershell]::Create().AddScript( {
		param ( $p )
		Start-Process powershell -ArgumentList $p -WindowStyle Hidden
	} )
	$p.AddArgument( @( "$( ( Get-ChildItem $PSCommandPath ).Directory.FullName )\O365\O365GUI.ps1", $LocalizeCulture ) )
	$h = $p.BeginInvoke()
	WriteLogTest -Text $msgTable.LogOpenO365 -Success $true
} )

# Add a script name and its synopsis to the text box
$syncHash.btnAddScript.Add_Click( { $syncHash.DC.tbFeedback[0] += "`n$( $syncHash.cbScriptList.SelectedItem.CBName )`n" } )

# Check if computer is online
$syncHash.btnComputerConnect.Add_Click( { StartWinRMOnRemoteComputer } )

# Clear computer info and reset GUI
$syncHash.btnComputerDisconnect.Add_Click( { DisconnectComputer } )

# Send feedback
$syncHash.btnFeedbackSend.Add_Click( {
	Send-MailMessage -From $this.Tag.From `
		-To $this.Tag.To `
		-Body "$( $syncHash.DC.tbFeedback[0] )$( $this.Tag.Body )" `
		-Encoding bigendianunicode `
		-SmtpServer $this.Tag.SMTP `
		-Subject $this.Tag.Subject
	$syncHash.DC.tbFeedback[0] = ""
	$syncHash.cbScriptList.SelectedIndex = -1
	$syncHash.rbReport.IsChecked = $true
} )

# List output files and sort descending by creation date
$syncHash.btnListOutputFiles.Add_Click( {
	$syncHash.DC.dgOutputFiles[0].Clear()
	Remove-Variable eh -ErrorAction SilentlyContinue
	try
	{
		Get-ChildItem "$BaseDir\Output\$( $env:USERNAME )" -ErrorAction Stop | Select-Object Name, @{ Name = "LastWriteTime"; Expression = { $_.LastWriteTime.GetDateTimeFormats()[22] } } | Sort-Object LastWriteTime -Descending | ForEach-Object { $syncHash.DC.dgOutputFiles[0].Add( $_ ) }
	}
	catch
	{
		$eh = WriteErrorlogTest -LogText $_ -UserInput $msgTable.StrOFListing -Severity "OtherFail"
		$syncHash.DC.dgOutputFiles[0].Add( ( [pscustomobject]@{ "Name" = $msgTable.StrNoOutputfiles ; "LastWriteTime" = ( Get-Date -Format "yyyy-MM-dd hh:mm:ss" ) } ) )
	}

	WriteLogTest -Text $msgTable.StrOFListing -Success ( $null -eq $true ) -ErrorLogHash $eh
} )

# Open the selected file
$syncHash.btnOpenOutputFile.Add_Click( {
	Start-Process -FilePath $syncHash.Editor -ArgumentList """$( $syncHash.DC.dgOutputFiles[1].FullName )"""
	WriteLogTest -Text $msgTable.StrOFOpenFile -UserInput $syncHash.DC.dgOutputFiles[1].FullName -Success $true
} )

# Cancel survey and hide the window
$syncHash.btnSurveyCancel.Add_Click( { $syncHash.DC.WindowSurvey[1] = [System.Windows.Visibility]::Hidden } )

# Save the survey and hide the window
$syncHash.btnSurveySave.Add_Click( {
	WriteSurvey -Survey $syncHash.DC.WindowSurvey[2].Survey -ScriptName $syncHash.DC.WindowSurvey[2].ScriptName
	$syncHash.DC.WindowSurvey[1] = [System.Windows.Visibility]::Hidden
} )

# Selected item changed, enable / disable button for adding script
$syncHash.cbScriptList.Add_SelectionChanged( { $syncHash.DC.btnAddScript[1] = $this.SelectedIndex -ne -1 } )

# Double-click in datagrid, copy value in cell
$syncHash.dgBaseInfo.Add_MouseDoubleClick( {
	"$( $this.CurrentCell.Item."$( $this.CurrentCell.Column.Header )" )" | clip
	ShowSplash -Text "'$( $this.CurrentCell.Column.Header )' $( $msgTable.StrInfoCopied )"
} )

# Selected item changed, enable / disable button to open file
$syncHash.dgOutputFiles.Add_SelectionChanged( { $syncHash.DC.btnOpenOutputFile[1] = $this.SelectedIndex -ne -1 } )

# Radiobutton is checked, set mail subject
$syncHash.rbReport.Add_Checked( { $syncHash.DC.btnFeedbackSend[1].Subject = "$( $msgTable.ContentWindow ) $( $this.Content )" } )

# Radiobutton is checked, set mail subject
$syncHash.rbSuggestion.Add_Checked( { $syncHash.DC.btnFeedbackSend[1].Subject = "$( $msgTable.ContentWindow ) $( $this.Content )" } )

# Radiobutton is checked, set survey rating
$syncHash.rbSurveyRate1.Add_Checked( { $syncHash.DC.WindowSurvey[2].Survey.Rating = 1 } )
$syncHash.rbSurveyRate2.Add_Checked( { $syncHash.DC.WindowSurvey[2].Survey.Rating = 2 } )
$syncHash.rbSurveyRate3.Add_Checked( { $syncHash.DC.WindowSurvey[2].Survey.Rating = 3 } )
$syncHash.rbSurveyRate4.Add_Checked( { $syncHash.DC.WindowSurvey[2].Survey.Rating = 4 } )
$syncHash.rbSurveyRate5.Add_Checked( { $syncHash.DC.WindowSurvey[2].Survey.Rating = 5 } )

# Check if Enter was pressed
$syncHash.tbComputerName.Add_KeyDown( { if ( $args[1].Key -eq "Return" ) { StartWinRMOnRemoteComputer } } )

# Text changed, enable button to connect if computer exists and is enabled in AD
$syncHash.tbComputerName.Add_TextChanged( { $syncHash.DC.btnComputerConnect[1] = try { ( Get-ADComputer $this.Text -ErrorAction Stop ).Enabled } catch { $false } } )

# Text has changed, enable send-button if text exists
$syncHash.tbFeedback.Add_TextChanged( { $syncHash.DC.btnFeedbackSend[2] = ( $syncHash.tbFeedback.Text.Length -gt 0 ) } )

# Survey-comment has changed, update object
$syncHash.tbSurveyComment.Add_TextChanged( { $syncHash.DC.WindowSurvey[2].Survey.Comment = $this.Text } )

# Mainwindow has finished loading, do some finetuning
$syncHash.Window.Add_Loaded( {
	$this.Activate()
	$splash.Close()
	$syncHash.WindowSurvey.Owner = $this
	$syncHash.dgOutputFiles.Columns[0].Header = $msgTable.ContentdgOutputFilesColNames
	$syncHash.dgOutputFiles.Columns[1].Header = $msgTable.ContentdgOutputFilesColDates
} )

# Escape was pressed, hide window
$syncHash.WindowSurvey.Add_KeyDown( {
	if ( $args[1].Key -eq "Escape" )
	{
		$syncHash.tbSurveyComment.Text = ""
		$this.Visibility = [System.Windows.Visibility]::Hidden
	}
} )

# If the survey window isn't visible, active mainwindow
$syncHash.WindowSurvey.Add_IsVisibleChanged( { if ( -not $this.Visible ) { $syncHash.Window.Activate() } } )

[void] $syncHash.Window.ShowDialog()
Pop-Location
$syncHash.Window.Close()
#$global:syncHash = $syncHash
