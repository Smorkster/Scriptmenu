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

	if ( $files = Get-ChildItem -File -Filter "*ps1" -Path $dirPath.FullName | where { $_.Name -ne ( Get-Item $PSCommandPath ).Name } | select -Property @{ Name = "Name"; Expression = { $_.Name } }, @{ Name = "Path"; Expression = { $_.FullName } }, @{ Name = "Description"; Expression = { ( Select-String -InputObject $_ -Pattern "#Description" -Encoding Default ).Line.TrimStart( "#Description = " ) } } | sort Description )
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
		if ( $dirPath.FullName -match "(Computer\\)" ) { $tabcontrol.Visibility = [System.Windows.Visibility]::Collapsed }
		$tabcontrol = New-Object System.Windows.Controls.TabControl
		$tabcontrol.Name = "tc"+( $dirPath.Name -replace " ")
		Set-Variable -Name ( "tc" + $( $dirPath.Name ) ) -Value $tabcontrol -Scope script
		foreach ( $dir in $dirs )
		{
			$tI = CreateTabItem $dir
			$tabcontrol.AddChild( $tI )
		}
		$spFolder.AddChild( $tabcontrol )
	}
	return $spFolder
}

function ConnectToComputer
{
	StartWinRMOnRemoteComputer
}

function DisonnectComputer
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
		SetTitle -Replace -Text ( "Verify that '" + $tbComputerName.Text + "' is reachable" )
		Test-WSMan $tbComputerName.Text -ErrorAction Stop

		$btnConnect.IsEnabled = $false
		$tbComputerName.IsReadOnly = $true
		$tcDator.Visibility = [System.Windows.Visibility]::Visible
		$btnDisconnect.Visibility = [System.Windows.Visibility]::Visible
		CreateComputerInfo
	}
	catch
	{
		SetTitle -Add -Text " ... Failed"
		ShowMessageBox "No contact with computer, or name does not exist. Try again."
	}
}

######################################
# Get information from remote computer
function GetPCInfo
{
	Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ComputerObj.ComputerName -Filter "IPEnabled='True'" | select -Property MACAddress, Description, IPAddress | foreach `
	{
		$t = @{
			MAC = $_.MACAddress
			NetDesc = $_.Description
			IP = $_.IPAddress[0]
		}
		$ComputerObj.NetAdapters += $t
	}
	$ComputerObj.Model = ( Get-WmiObject -ComputerName $ComputerObj.ComputerName -Class win32_computersystem ).Model
	$ComputerObj.Serienummer = ( Get-WmiObject -ComputerName $ComputerObj.ComputerName -Class win32_bios ).SerialNumber
	$ComputerObj.LastBoot = ( Get-CimInstance -ComputerName $ComputerObj.ComputerName -ClassName win32_operatingsystem ).LastBootUpTime
	$ComputerObj.InstallDate = ( Get-CimInstance -ComputerName $ComputerObj.ComputerName -ClassName win32_operatingsystem ).InstallDate
}

###############################
# Get PCRole of remote computer
function GetPCRole
{
	$ComputerObj.Roll = $null
	$PCRoll = Get-ADComputer $ComputerObj.ComputerName -Properties Memberof | select -ExpandProperty MemberOf | where { $_ -match "_Wrk_" }
	$types = @( "Role1", "Role2" )

	switch ( ( $types | where { $PCRoll -match $_ } ) )
	{
		"Role1" { $r = "Role1-PC" }
		"Role2" { $r = "Role2-PC" }
	}
	if ( $r -eq $null ) { $r = "Unknown-PC" }
	$ComputerObj.Roll = $r

	if ( ( @( "Role1-PC" ) -contains $ComputerObj.Roll ) -or ( @( "Org1*", "Org2*") -contains $ComputerObj.ComputerName.Substring( 0, 3 ) ) )
	{
		Add-Member -InputObject $ComputerObj -MemberType NoteProperty -Name DontInstall -Value "Do NOT reinstall computer: $r"
	}
	elseif ( ( @( "SpecComputer1", "SpecComputer2" ) | foreach { $_ -like "$( $ComputerObj.ComputerName )*" } ) -eq $true )
	{
		Add-Member -InputObject $ComputerObj -MemberType NoteProperty -Name DontInstall -Value "AAA-dator Do NOT reinstall"
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
	$tI = New-Object System.Windows.Controls.TabItem
	$tI.Header = $tI.Name = "Baseinformation"
	$datagrid = New-Object System.Windows.Controls.DataGrid
	$datagrid.AutoGenerateColumns = $true
	Set-Variable -Name datagrid -Value $datagrid

	$Script:colName = New-Object System.Windows.Controls.DataGridTextColumn
	$colName.Header = "Name"
	$colName.Width = "SizeToCells"
	$colNameBinding = New-Object System.Windows.Data.Binding
	$colNameBinding.Path = "Name"
	$colName.Binding = $colNameBinding

	$Script:colInfo = New-Object System.Windows.Controls.DataGridTextColumn
	$colInfo.Header = "Info"
	$colInfo.Width = "SizeToCells"
	$colInfoBinding = New-Object System.Windows.Data.Binding
	$colInfoBinding.Path = "Info"
	$colInfo.Binding = $colInfoBinding

	CreateComputerObject $tbComputerName.Text
	GetPCInfo
	GetPCRole

	$ComputerObj | Get-Member -MemberType NoteProperty | foreach `
	{
		if ( $_.name -eq "NetAdapters" )
		{
			for ($i = 1; $i -le $ComputerObj.NetAdapters.Count; $i++)
			{
				$ComputerObj.NetAdapters[$i-1].Keys | foreach `
				{
					$datagrid.AddChild( [pscustomobject]@{ "Name" = "$_ $i"; "Info" = $ComputerObj.NetAdapters[$i-1].$_ } )
				}
			}
		}
		else
		{
			$datagrid.AddChild( [pscustomobject]@{ "Name" = $_.Name; "Info" = $_.Definition.Split("=")[1] } )
		}
	}

	$datagrid.Columns.Add($colName)
	$datagrid.Columns.Add($colInfo)
	$tI.AddChild( $datagrid )
	$tcDator.Items.Insert( 0, $tI )
	$tcDator.SelectedIndex = 0
}

#################################################
# A object to hold information of remote computer
function CreateComputerObject
{
	param (
		$Name
	)

	$Script:ComputerObj = [PSCustomObject]@{ "InstallDate" = ""; "LastBoot" = ""; "Serienummer" = ""; "Model" = ""; "NetAdapters" = @(); "Roll" = ""; "ComputerName" = $Name }
}

#########################################################
# Create controls for computername and buttons to connect
function CreateComputerInput
{
	$sp = New-Object System.Windows.Controls.StackPanel
	$sp.Orientation = "Horizontal"
	$sp.Margin = "0,15,0,10"

	$l = New-Object System.Windows.Controls.Label
	$l.Content = "Computername:"

	$tb = New-Object System.Windows.Controls.TextBox
	$tb.Name = "tbComputerName"
	$tb.Add_TextChanged( { if ( $this.Text.Length -gt 5 ) { $btnConnect.IsEnabled = $true } else { $btnConnect.IsEnabled = $false } } )
	$tb.VerticalContentAlignment = "Center"
	$tb.Width = 200
	Set-Variable -Name "tbComputerName" -Value $tb -Scope script

	$b = New-Object System.Windows.Controls.Button
	$b.Add_Click( { ConnectToComputer } )
	$b.Content = "Fetch info"
	$b.Name = "btnConnect"
	$b.IsEnabled = $false
	$b.Width = 75
	$b.Margin = "5,0,0,0"
	Set-Variable -Name "btnConnect" -Value $b -Scope script

	$b2 = New-Object System.Windows.Controls.Button
	$b2.Add_Click( { DisonnectComputer } )
	$b2.Content = "Disconnect"
	$b2.Name = "btnDisconnect"
	$b2.Visibility = [System.Windows.Visibility]::Collapsed
	$b2.Width = 65
	$b2.Margin = "5,0,0,0"
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

	foreach ( $file in $Files )
	{
		$wpScriptControls = New-Object System.Windows.Controls.WrapPanel
		$button = New-Object System.Windows.Controls.Button
		$label = New-Object System.Windows.Controls.Label

		$button.Content = "Run >"
		$button.ToolTip = $file.Path
		$label.Content = $file.Description

		if ( $label.Content -match "under development" )
		{
			$label.Background = "Red"
			if ( $adminList -notcontains $env:USERNAME ) { $button.IsEnabled = $false }
		}
		elseif ( $label.Content -match "under testing" )
		{
			$label.Background = "LightBlue"
			$label.Content += "`nOnly use if told to."
		}

		if ( $label.Content.Contains( "[BO]" ) )
		{
			if ( ( Get-ADUser $env:USERNAME -Properties MemberOf | select -ExpandProperty MemberOf ) -match "Role_Backoffice" )
			{
				$button.IsEnabled = $true
			}
			else
			{
				$button.IsEnabled = $false
				$button.ToolTip = "This script is only to be used by backoffice"
			}
		}

		$button.Add_Click( {
			$ProgramRunspace = [System.Management.Automation.PowerShell]::Create() # Create new runspace
			$args = @( $this.ToolTip, ( Get-Item $PSScriptRoot ).Parent.FullName )
			if ( $this.ToolTip -match "(Computer\\)" )
			{ $args += $tbComputerName.Text }

			if ( Get-ChildItem "$( ( Get-Item $PSCommandPath ).Directory.Parent.FullName )\Gui" | where { $_.Name -match ( ( Get-Item $this.ToolTip ).Name -split "\." )[0] } ) { $hidden = $true }
			else { $hidden = $false }

			[void]$ProgramRunspace.AddScript( {
				param( $arg, $hidden )
				if ( $hidden )
				{ start powershell -WindowStyle Hidden -ArgumentList $arg } # Starts script, using gui, without consolewindow
				else
				{ start powershell -ArgumentList $arg } # Starts script, without gui, in new consolewindow
			} ).AddArgument( $args ).AddArgument( $hidden )

			$run = $ProgramRunspace.BeginInvoke() # Start runspace
			do { Start-Sleep -Milliseconds 50 } until ( $run.IsCompleted )
			$ProgramRunspace.Dispose()
		} )

		[void] $wpScriptControls.AddChild( $button )
		[void] $wpScriptControls.AddChild( $label )
		[void] $wpScriptGroup.AddChild( $wpScriptControls )
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

	$tabitem = New-Object System.Windows.Controls.TabItem
	$tabitem.Header = $dirPath.Name
	$tabitem.Name = "ti" + $( $dirPath.Name )
	Set-Variable -Name ( "ti" + $( $dirPath.Name ) ) -Value $tabitem -Scope Script
	$g = New-Object System.Windows.Controls.Grid
	$scroller = New-Object System.Windows.Controls.ScrollViewer
	$sp = GetFolderItems $dirPath
	$scroller.AddChild( $sp )
	$g.AddChild( $scroller )
	$tabitem.AddChild( $g )
	return $tabitem
}

# Check if logged on user is part of admingroup
function CheckForAdmin
{
	if ( $adminList -contains $env:USERNAME )
	{
		$Admins.Visibility = [System.Windows.Visibility]::Visible
		$btnCheckForUpdates.Add_Click( {
			$ProgramRunspace = [System.Management.Automation.PowerShell]::Create() # Create new runspace
			$args = @( "\\dfs\gem$\Scriptmenu\Development\Update-Scripts.ps1", ( Get-Item $PSScriptRoot ).Parent.FullName )
			[void]$ProgramRunspace.AddScript( { param( $arg ); start powershell -WindowStyle Hidden -ArgumentList $arg } ).AddArgument( $args )
			$run = $ProgramRunspace.BeginInvoke() # Start runspace
			do { Start-Sleep -Milliseconds 50 } until ( $run.IsCompleted )
			$ProgramRunspace.Dispose()
		} )
	}
	if ( $PSCommandPath -match "Development" ) { SetTitle -Add " - Developer edition" }
}

# Add a tabitem to send error report or suggestions
function AddReportTool
{
	$ti = New-Object System.Windows.Controls.TabItem
	$sp = New-Object System.Windows.Controls.StackPanel
	$spScript = New-Object System.Windows.Controls.StackPanel
	$spSubject = New-Object System.Windows.Controls.StackPanel
	$cb = New-Object System.Windows.Controls.ComboBox
	$tbText = New-Object System.Windows.Controls.TextBox
	$btnAdd = New-Object System.Windows.Controls.Button
	$btnSend = New-Object System.Windows.Controls.Button
	$lblSubject = New-Object System.Windows.Controls.Label
	$rbR = New-Object System.Windows.Controls.RadioButton
	$rbS = New-Object System.Windows.Controls.RadioButton

	$ti.Header = "Errorreporting / Suggestions"
	$ti.Background = "#FFFF9C9C"

	$spScript.Orientation = $spSubject.Orientation = "Horizontal"

	$tbText.AcceptsReturn = $true
	$tbText.AcceptsTab = $true
	$tbText.TextWrapping = "WrapWithOverflow"
	$tbText.VerticalScrollBarVisibility = "Auto"
	$tbText.Height = "300"

	$cb.Width = "300"
	$cb.Height = "25"
	( Get-ChildItem $PSCommandPath.Directory -Filter "*ps1" -File -Recurse ).Name | sort | foreach { [void] $cb.Items.Add( $_ ) }

	$btnAdd.Content = "Add name to be reported"
	$btnAdd.Margin = "0,5,10,5"
	$btnSend.Content = "Send report"

	$lblSubject.Content = "Type of message: "
	$rbR.Content = "Error report"
	$rbR.GroupName = "Subject"
	$rbR.IsChecked = $true
	$rbS.Content = "Suggestions"
	$rbS.GroupName = "Subject"

	$btnAdd.Add_Click( {
		$this.Parent.Parent.Children[2].Text = $this.Parent.Children[1].SelectedItem + "`r`n" + $this.Parent.Parent.Children[2].Text
		$this.Parent.Children[1].SelectedIndex = -1
	} )
	$btnSend.Add_Click( {
		if ( $this.Parent.Children[1].Children[1].IsChecked ) { $subject = "Error reporting" }
		elseif ( $this.Parent.Children[1].Children[2].IsChecked ) { $subject = "Suggestions" }
		Send-MailMessage -From ( ( Get-ADUser ( Get-ADUser $env:USERNAME ).SamAccountName.Replace( "admin", "" ) -Properties EmailAddress ).EmailAddress ) `
			-To backoffice@test.com `
			-SmtpServer smtprelay `
			-Subject "$subject Scriptmenu" `
			-Body "$( $this.Parent.Children[2].Text )`n`nFrom:`n$( ( Get-ADUser $env:USERNAME ).Name )" `
			-Encoding Default
		$this.Parent.Children[2].Text = ""
	} )
	$rbR.Add_Checked( { $this.Parent.Parent.Children[1].Children[0].Content = "Add name of script to be reported"
		$this.Parent.Parent.Children[3].Content = "Send report" } )
	$rbS.Add_Checked( { $this.Parent.Parent.Children[1].Children[0].Content = "Add name of script for suggestions"
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

$Window, $vars = CreateWindow
$vars | foreach { Set-Variable -Name $_ -Value $Window.FindName( $_ ) }
$adminList = @( "admin1", "admin2" )

Push-Location ( Get-Item $PSCommandPath ).Directory.FullName
$MainContent.AddChild( ( GetFolderItems "" ) )
FulHack
CheckForAdmin
AddReportTool
$Window.Add_Loaded( { $Window.Activate() } )

[void] $Window.ShowDialog()
Pop-Location
$Window.Close()
