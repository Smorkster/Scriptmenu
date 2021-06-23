<#
.Synopsis Main GUI for Office 365 scripts
.Description Main script for collecting and accessing scripts related to Office 365
.Author Smorkster (smorkster)
#>
param ( $culture = "sv-SE" )

#####################################################################
# Check if a connection to the Office 365 online services are present
# If connection is present, set scriptcontrols to visible
function CheckConnection
{
	$a = $e = $false
	try { $syncHash.azureAdAccount = Get-AzureADCurrentSessionInfo -ErrorAction Stop ; $a = $true ; $syncHash.DC.elStatusAzureAD[0] = "LightGreen" } catch { }
	try { Get-PSSession -Name Exchange* -ErrorAction Stop; $e = $true ; $syncHash.DC.elStatusExchange[0] = "LightGreen" } catch { }

	if ( $a -and $e )
	{
		$syncHash.DC.MainContent[0] = [System.Windows.Visibility]::Visible
		$syncHash.DC.btnO365Connect[1] = $false
		$syncHash.DC.spConnect[0] = [System.Windows.Visibility]::Collapsed
		$syncHash.DC.spConnected[0] = [System.Windows.Visibility]::Visible
		$syncHash.DC.lblConnectedAs[0] = $syncHash.azureAdAccount.Account.Id
	}
	else
	{
		$syncHash.DC.MainContent[0] = [System.Windows.Visibility]::Collapsed
		$syncHash.DC.elStatusAzureAD[0] = "LightCoral"
		$syncHash.DC.elStatusExchange[0] = "LightCoral"
	}
}

#################################
# Connect to O365-online services
function ConnectO365
{
	"ExchangeOnlineManagement", "ActiveDirectory" | ForEach-Object { Import-Module $_ }
	try { $syncHash.azureAdAccount = Connect-AzureAD -ErrorAction Stop }
	catch {}

	try { Connect-ExchangeOnline -UserPrincipalName $syncHash.azureAdAccount.Account.Id -ErrorAction Stop }
	catch {}

	CheckConnection
}

####################################################
# Create controls to connect to O365-online services
####################################################################
# Create a group of buttons and labels for all scriptfiles in folder
function CreateScriptGroup
{
	param ( $dirPath )

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
					$wpScriptControls = [System.Windows.Controls.WrapPanel]@{ Name = "wp$( $file.Name -replace "\W" )" }
					$button = [System.Windows.Controls.Button]@{ Content = "$( $syncHash.Data.msgTable.ContentbtnRun ) >"; ToolTip = $file.Path }
					$button.Name = "btn$( $file.Name -replace "\W" )"
					$label = [System.Windows.Controls.Label]@{ Content = $file.Synopsis; ToolTip = [string]$file.Description.Replace( ". ", ".`n" ) }
					$label.Name = "lbl$( $file.Name -replace "\W" )"

					if ( $file.Depends -in ( $syncHash.Window.Resources.Keys | Where-Object { $_.IsPublic -eq $null } ) )
					{ $wpScriptControls.SetResourceReference( [System.Windows.Controls.WrapPanel]::IsEnabledProperty, $file.Depends ) }

					if ( $file.State -match "$( $syncHash.Data.msgTable.ScriptContentInDev )" )
					{
						$label.Background = "Red"
						if ( $syncHash.Data.msgTable.AdmList -match $env:USERNAME -or $file.Author -eq $env:USERNAME ) { $button.IsEnabled = $true }
						else { $button.IsEnabled = $false }
					}
					elseif ( $file.State -match "$( $syncHash.Data.msgTable.ScriptContentInTest )" )
					{
						$label.Background = "LightBlue"
						$label.Content += "`n$( $syncHash.Data.msgTable.ContentLblInTest )"
					}

					$button.Add_Click( { Invoke-Command -ScriptBlock { param ( $lc ) & $this.ToolTip ( ( Get-Item $PSScriptRoot ).Parent.Parent.FullName ) $lc } -ArgumentList "en-US" } )

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
	param ( $dirPath )

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
# Get scriptfiles in the specified folder
function GetFiles
{
	param ( $dirPath )
	$Get = { ( Select-String -InputObject $_ -Pattern "^.$( $args[0] )" -Encoding UTF8 ).Line.Replace( ".$( $args[0] ) ", "" ) }
	Get-ChildItem -File -Filter "*ps1" -Path $dirPath.FullName | Where-Object { $_.Name -ne ( Get-Item $PSCommandPath ).Name } | `
		Select-Object -Property @{ Name = "Name"; Expression = { $_.Name } }, `
			@{ Name = "Path"; Expression = { $_.FullName } }, `
			@{ Name = "Group"; Expression = { ( $_.Name -split "-" )[0] } }, `
			@{ Name = "Synopsis"; Expression = { & $Get "Synopsis" } }, `
			@{ Name = "Description"; Expression = { & $Get "Description" } }, `
			@{ Name = "Requires"; Expression = { ( & $Get "Requires" ) -split "\W" | Where-Object { $_ } } }, `
			@{ Name = "AllowedUsers"; Expression = { ( & $Get "AllowedUsers" ) -split "\W" | Where-Object { $_ } } }, `
			@{ Name = "State"; Expression = { ( & $Get "State" ) | Where-Object { $_ } } }, `
			@{ Name = "Author"; Expression = { ( ( & $Get "Author" ) -split "\(" )[1].TrimEnd( ")" ) } }, `
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

	if ( $wpScriptGroup = CreateScriptGroup $dirPath ) { $spFolder.AddChild( $wpScriptGroup ) }

	if ( $dirs = Get-ChildItem -Directory -Path $dirPath.FullName )
	{
		$tabControl = [System.Windows.Controls.TabControl]@{ Name = "tc$( $dirPath.Name -replace " " )" }

		if ( $dirPath -eq "" ) { $tabControl.MaxHeight = 700 }
		Set-Variable -Name ( "tc" + $( $dirPath.Name ) ) -Value $tabControl -Scope script

		$tiList = @()
		foreach ( $dir in $dirs ) { $tiList += ( CreateTabItem $dir ) }
		$tiList | Sort-Object $_.Header | ForEach-Object {
			if ( $_.Content.Children[0].Content.Children.Count -eq 0 )
			{
				$_.Visibility = [System.Windows.Visibility]::Collapsed
			}
			$tabControl.AddChild( $_ )
		}
		$spFolder.AddChild( $tabControl )
	}
	return $spFolder
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

	if ( $Add ) { $syncHash.Window.Title += $Text }
	elseif ( $Remove ) { $syncHash.Window.Title = $syncHash.Data.msgTable.StrScriptSuite }
	elseif ( $Replace ) { $syncHash.Window.Title = $Text }
}

############################## Script start
$BaseDir = ( ( Get-Item $PSCommandPath ).Directory.Parent.FullName -split "\\" | Select-Object -SkipLast 1 ) -join "\"
if ( ( [System.Globalization.CultureInfo]::GetCultures( "AllCultures" ) ).Name -contains "sv-SE" -contains $culture ) { $LocalizeCulture = $culture }
else
{
	[System.Windows.MessageBox]::Show( "Not a valid localization language. Will default to sv-SE" )
	$LocalizeCulture = "sv-SE"
}
Add-Type -AssemblyName PresentationFramework
Import-Module "$( $BaseDir )\Modules\FileOps.psm1" -Force -ArgumentList $LocalizeCulture
Import-Module "$( $BaseDir )\Modules\GUIOps.psm1" -Force -ArgumentList $LocalizeCulture

if ( ( ( Get-ADUser $env:USERNAME -Properties memberof ).memberof -match $msgTable.StrBORole ).Count -gt 0 )
{
	$controls = New-Object System.Collections.ArrayList
	[void]$controls.Add( @{ CName = "btnAddAdminPermission" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAddAdminPermission } ) } )
	[void]$controls.Add( @{ CName = "btnO365Connect" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnO365Connect } ; @{ PropName = "IsEnabled"; PropVal = $true } ) } )
	[void]$controls.Add( @{ CName = "elStatusAzureAD" ; Props = @( @{ PropName = "Fill"; PropVal = "LightCoral" } ) } )
	[void]$controls.Add( @{ CName = "elStatusExchange" ; Props = @( @{ PropName = "Fill"; PropVal = "LightCoral" } ) } )
	[void]$controls.Add( @{ CName = "lbAdminPermissions" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
	[void]$controls.Add( @{ CName = "lblCheckersTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblCheckersTitle } ) } )
	[void]$controls.Add( @{ CName = "lblConnectedAs" ; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
	[void]$controls.Add( @{ CName = "lblConnectedAsTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblConnectedAsTitle } ) } )
	[void]$controls.Add( @{ CName = "lblConnectTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblConnectTitle } ) } )
	[void]$controls.Add( @{ CName = "lblPermListTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblPermListTitle } ) } )
	[void]$controls.Add( @{ CName = "lblStatusAzureAD" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblStatusAzureAD } ) } )
	[void]$controls.Add( @{ CName = "lblStatusExchange" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblStatusExchange } ) } )
	[void]$controls.Add( @{ CName = "MainContent" ; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
	[void]$controls.Add( @{ CName = "tbAddAdminPermission" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
	[void]$controls.Add( @{ CName = "spConnect" ; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Visible } ) } )
	[void]$controls.Add( @{ CName = "spConnected" ; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
	[void]$controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = $msgTable.StrScriptSuite } ) } )

	$syncHash = CreateWindowExt $controls
	$syncHash.Data.msgTable = $msgTable

	$FileSystemWatcher = New-Object System.IO.FileSystemWatcher
	$FileSystemWatcher.Path  = $env:USERPROFILE
	$FileSystemWatcher.EnableRaisingEvents = $true
	$FileSystemWatcher.Filter = "O365Admin.txt"

	$Action = {
		$event.MessageData.DC.lbAdminPermissions[0].Clear()
		Get-Content "$( $env:USERPROFILE )\O365Admin.txt" | Foreach-Object { $event.MessageData.DC.lbAdminPermissions[0].Add( $_ ) }
	}
	Register-ObjectEvent -InputObject $FileSystemWatcher -EventName Changed -Action $Action -SourceIdentifier MainFSChange -MessageData $syncHash | Out-Null
	Register-ObjectEvent -InputObject $FileSystemWatcher -EventName Created -Action $Action -SourceIdentifier MainFSCreate -MessageData $syncHash | Out-Null
	Register-ObjectEvent -InputObject $FileSystemWatcher -EventName Deleted -Action $Action -SourceIdentifier MainFSDelete -MessageData $syncHash | Out-Null

	if ( $PSCommandPath -match "Development" ) { SetTitle -Add " - Developer edition" }

	Push-Location ( Get-Item $PSCommandPath ).Directory.FullName
	$syncHash.MainContent.AddChild( ( GetFolderItems "" ) )

	$syncHash.btnAddAdminPermission.Add_Click( {
		try
		{
			$a = Get-EXORecipient -Identity $syncHash.DC.tbAddAdminPermission[0] -ErrorAction Stop
			if ( $a.RecipientTypeDetails -in ( "EquipmentMailbox","RoomMailbox","SharedMailbox","UserMailbox" ) )
			{
				Add-MailboxPermission -Identity $a.PrimarySmtpAddress -User $syncHash.azureAdAccount -AccessRights FullAccess
				Add-Content -Value $a.PrimarySmtpAddress -Path "$( $env:USERPROFILE )\O365Admin.txt"
			}
			else { throw }
		}
		catch
		{
			ShowMessageBox -Text $syncHash.Data.msgTable.StrNoRecipientFound
		}
	} )
	$syncHash.btnO365Connect.Add_Click( { ConnectO365 } )
	$syncHash.Window.Add_Closed( {
		$FileSystemWatcher.EnableRaisingEvents = $false
		$FileSystemWatcher.Dispose()
		Unregister-Event MainFSChange
		Unregister-Event MainFSCreate
		Unregister-Event MainFSDelete
		Get-Job | Remove-Job -ErrorAction SilentlyContinue
	} )
	$syncHash.Window.Add_ContentRendered( {
		$syncHash.Window.Top = 100
		$syncHash.Window.Activate()
		CheckConnection
		Get-Content "$( $env:USERPROFILE )\O365Admin.txt" | Foreach-Object { $syncHash.DC.lbAdminPermissions[0].Add( $_ ) }
	} )

	[void] $syncHash.Window.ShowDialog()
	$global:syncHash = $syncHash
	Pop-Location
	$syncHash.Window.Close()
}
else { [void] [System.Windows.MessageBox]::Show( $msgTable.StrNoPermission ) }
