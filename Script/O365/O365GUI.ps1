<#
.Synopsis Main GUI for Office 365 scripts
.Description Main script for collecting and accessing scripts related to Office 365
.Author Smorkster (smorkster)
#>

#####################################################################
# Check if a connection to the Office 365 online services are present
# If connection is present, set scriptcontrols to visible
function CheckConnection
{
	$a = $e = $false
	try { Get-AzureADCurrentSessionInfo -ErrorAction Stop ; $a = $true ; $statusAzureAD.Fill = "LightGreen" } catch { }
	try { Get-PSSession -Name Exchange* -ErrorAction Stop; $e = $true ; $statusExchange.Fill = "LightGreen" } catch { }

	if ( $a -and $e )
	{
		$MainContent.Visibility = [System.Windows.Visibility]::Visible
		$btnO365Connect.IsEnabled = $false
	}
	else
	{
		$MainContent.Visibility = [System.Windows.Visibility]::Collapsed
		$statusAzureAD.Fill = "LightCoral"
		$statusExchange.Fill = "LightCoral"
	}
}

#################################
# Connect to O365-online services
function ConnectO365
{
	"ExchangeOnlineManagement", "ActiveDirectory" | ForEach-Object { Import-Module $_ }
	try { $azureAdAccount = Connect-AzureAD -ErrorAction Stop }
	catch {}

	try { Connect-ExchangeOnline -UserPrincipalName $azureAdAccount.Account.Id -ErrorAction Stop }
	catch {}

	CheckConnection
}

####################################################
# Create controls to connect to O365-online services
function CreateO365Input
{
	$mainSP = [System.Windows.Controls.StackPanel]@{
		Orientation = "Vertical"
	}
	$controlsSP = [System.Windows.Controls.StackPanel]@{
		Margin = "5"
		Orientation = "Horizontal"
	}
	$l = [System.Windows.Controls.Label]@{ Content = $msgTable.ContentO365Start }

	$b = [System.Windows.Controls.Button]@{
		Content = $msgTable.ContentBtnO365Connect
		Margin = "5,0,0,0"
		Name = "btnO365Connect"
	}
	$b.Add_Click( { ConnectO365 } )
	Set-Variable -Name "btnO365Connect" -Value $b -Scope script

	$controlsSP.AddChild( $l )
	$controlsSP.AddChild( $b )

	$checkersSP = [System.Windows.Controls.StackPanel]@{
		Margin = "5"
		Orientation = "Horizontal"
	}
	$lpad = "5,0,5,0"
	$l = [System.Windows.Controls.Label]@{ Content = $msgTable.ContentLblO365Connected; Margin = "0,0,10,0" }
	$bo = [System.Windows.Controls.StackPanel]@{ Orientation = "Horizontal" }
	$e1 = [System.Windows.Shapes.Ellipse]@{ Fill = "LightCoral"; Height = 15; Width = 15; Stroke = "Black" }
	$cb1 = [System.Windows.Controls.Label]@{ Content = "ExchangeOnline"; VerticalContentAlignment = "Center"; Padding = $lpad }
	$bo.AddChild( $e1 )
	$bo.AddChild( $cb1 )
	Set-Variable -Name "statusExchange" -Value $e1 -Scope script
	$bo2 = [System.Windows.Controls.StackPanel]@{ Orientation = "Horizontal" }
	$e2 = [System.Windows.Shapes.Ellipse]@{ Fill = "LightCoral"; Height = 15; Width = 15; Stroke = "Black" }
	$cb2 = [System.Windows.Controls.Label]@{ Content = "AzureAD"; VerticalContentAlignment = "Center"; Padding = $lpad }
	$bo2.AddChild( $e2 )
	$bo2.AddChild( $cb2 )
	Set-Variable -Name "statusAzureAD" -Value $e2 -Scope script
	$checkersSP.AddChild( $l )
	$checkersSP.AddChild( $bo )
	$checkersSP.AddChild( $bo2 )

	$mainSP.AddChild( $controlsSP )
	$mainSP.AddChild( $checkersSP )
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
					$wpScriptControls = [System.Windows.Controls.WrapPanel]@{ Name = "wp$( $file.Name -replace "\W" )" }
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

					$button.Add_Click( { Invoke-Command -ScriptBlock { & $this.ToolTip ( ( Get-Item $PSScriptRoot ).Parent.Parent.FullName ) } } )

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

	if ( $Add ) { $Window.Title += $Text }
	elseif ( $Remove ) { $Window.Title = $msgTable.StrScriptSuite }
	elseif ( $Replace ) { $Window.Title = $Text }
}

############################## Script start
$BaseDir = ( ( Get-Item $PSCommandPath ).Directory.Parent.FullName -split "\\" | Select-Object -SkipLast 1 ) -join "\"
Import-Module "$( $BaseDir )\Modules\FileOps.psm1" -Force
Import-Module "$( $BaseDir )\Modules\GUIOps.psm1" -Force

if ( ( ( Get-ADUser $env:USERNAME -Properties memberof ).memberof -match $msgTable.StrBORole ).Count -gt 0 )
{
	$Window, $vars = CreateWindow
	$Window.Title = $msgTable.StrScriptSuite

	if ( $PSCommandPath -match "Development" ) { SetTitle -Add " - Developer edition" }
	$vars | ForEach-Object { Set-Variable -Name $_ -Value $Window.FindName( $_ ) }

	Push-Location ( Get-Item $PSCommandPath ).Directory.FullName
	$spConnect.AddChild( ( CreateO365Input ) )
	$MainContent.AddChild( ( GetFolderItems "" ) )
	$Window.Add_ContentRendered( { $Window.Top = 100; $Window.Activate() ; CheckConnection } )

	[void] $Window.ShowDialog()
	Pop-Location
	$Window.Close()
}
else { [void] [System.Windows.MessageBox]::Show( $msgTable.StrNoPermission ) }
#$global:window = $window