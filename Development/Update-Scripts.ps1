
#############################
# Search for any updated file
function CheckForUpdates
{
	$btnUpdateScripts.IsEnabled = $false
	$dirExclusion = @( "ErrorLogs",
						"Input",
						"Logs",
						"Output",
						"UpdateRollback" )
	$fileExclusion = @( ( Get-Item $PSCommandPath ).Name )
	$updatedFiles.Clear()
	$Window.Dispatcher.Invoke( [action] {
		$spUpdateList.Children.Clear()
		$spOtherUpdates.Children.Clear()
	} )

	$devFiles = Get-ChildItem $devRoot -Directory -Exclude $dirExclusion | Get-ChildItem -File -Recurse -Exclude $fileExclusion
	$devFiles += Get-ChildItem $devRoot -File | Where-Object { $_.Name -notin $fileExclusion }
	$prodFiles = Get-ChildItem $prodRoot -Directory -Exclude $( $dirExclusion += "Development"; $dirExclusion ) | Get-ChildItem -File -Recurse -Exclude $fileExclusion
	$prodFiles += Get-ChildItem $prodRoot -File | Where-Object { $_.Name -notin $fileExclusion }
	$MD5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider

	foreach ( $devFile in $devFiles )
	{
		$prodFile = $prodFiles | Where-Object { $_.Name -eq $devFile.Name }

		if ( $null -eq $prodFile )
		{
			$updatedFiles.Add( @( $devFile, "" ) )
		}
		elseif ( [System.BitConverter]::ToString( $MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $devFile.FullName ) ) ) -ne `
			[System.BitConverter]::ToString( $MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $prodFile.FullName ) ) ) )
		{
			if ( $prodFile.LastWriteTime -gt $devFile.LastWriteTime )
			{
				$filesUpdatedInProd.Add( @( $devFile, $prodFile ) )
			}
			else
			{
				$updatedFiles.Add( @( $devFile, $prodFile ) )
			}
		}
		$prodFile = $null
	}

	if ( $updatedFiles.Count -gt 0 )
	{
		AddControlsForUpdatedFiles
	}
	else
	{
		$btnUpdateScripts.IsEnabled = $false
		$lblUpdateInfo.Content = $IntmsgTable.StrNoUpdates
	}

	if ( $filesUpdatedInProd.Count -gt 0 )
	{
		AddControlsForUpdatedProdFiles
	}
}

################################
# Checks/unchecks all checkboxes
function CheckAll
{
	param( $Mark )

	$spUpdateList.Children | Where-Object { $_.IsEnabled -and ( $null -ne $_.Tag ) } | ForEach-Object { $_.IsChecked = $Mark }
}

######################################
# Add a checkbox for each updated file
function AddControlsForUpdatedFiles
{
	$cbMarkAll = New-Object System.Windows.Controls.CheckBox
	$cbMarkAll.Content = $IntmsgTable.StrSelectAll
	$cbMarkAll.Margin = "0,0,0,10"
	$cbMarkAll.Add_Checked( { CheckAll $true } )
	$cbMarkAll.Add_UnChecked( { CheckAll $false } )
	Set-Variable -Name cbMarkAll -Value $cbMarkAll -Scope script

	$spUpdateList.AddChild( $cbMarkAll )

	foreach ( $update in $updatedFiles )
	{
		$cbUpdate = New-Object System.Windows.Controls.CheckBox
		$cbUpdate.Add_MouseRightButtonDown( { $this.Tag.Split( "`n" ) | ForEach-Object { & 'C:\Program Files (x86)\Notepad++\notepad++.exe' $_ } } )
		$cbUpdate.Name = ( $update[0].Name.Split( "\." ) )[0] -replace "-" -replace " "
		$cbUpdate.Tag = "$( $update[0].FullName )`n$( $update[1].FullName )"
		$devUpdated = Get-Date $update[0].LastWriteTime -Format 'yyyy-MM-dd HH:mm:ss'
		if ( $update[1] -eq "" ) { $prodUpdated = $IntmsgTable.StrNew }
		else { $prodUpdated = Get-Date $update[1].LastWriteTime -Format 'yyyy-MM-dd HH:mm:ss' }
		$cbUpdate.ToolTip = "$( $IntmsgTable.StrUpInDev ):`t$devUpdated`n$( $IntmsgTable.StrUpInProd ):`t$prodUpdated"
		$cbUpdate.Content = "$( ( $( $update[0] ).FullName -split "development" )[1] )"

		if ( ( Get-Content $update[0].FullName | Select-String "^.State " ) -match $IntmsgTable.ScriptContentInDev )
		{
			$cbUpdate.FontWeight = "Bold"
			$cbUpdate.Foreground = "Red"
			$cbUpdate.ToolTip = "$( $IntmsgTable.StrDevTooltip )`n$( $cbUpdate.ToolTip )"
		}
		if ( $update[0].Name.EndsWith( "xaml" ) -or $update[0].Name.EndsWith( "psd1" ) )
		{
			if ( ( Get-ChildItem -Filter "$( $update[0].Name.Replace( "xaml", "ps1" ).Replace( "psd1", "ps1" ) )" -Recurse | Select-String ".State" ) -match $IntmsgTable.ScriptContentInDev )
			{
				$cbUpdate.FontWeight = "Bold"
				$cbUpdate.Foreground = "Red"
				$cbUpdate.ToolTip = "$( $IntmsgTable.StrScriptInDevTooltip )`n$( $cbUpdate.ToolTip )"
			}
		}
		$cbUpdate.VerticalContentAlignment = "Center"
		$cbUpdate.Add_Checked( { $this.Foreground = "Green"; CheckChecked } )
		$cbUpdate.Add_UnChecked( { $this.Foreground = "Black"; CheckChecked } )

		$spUpdateList.AddChild( $cbUpdate )
	}
	$lblUpdateInfo.Content = "$( ( $spUpdateList.Children | Where-Object { $_.IsEnabled -and ( $null -ne $_.Tag ) } ).Count ) $( $IntmsgTable.StrSummaryUp )"
	if ( ( $spUpdateList.Children | Where-Object { -not ( $_.IsEnabled ) -and ( $null -ne $_.Tag ) } ).Count -gt 0 )
	{
		$lblUpdateInfo.Content += "`n$( ( $spUpdateList.Children | Where-Object { -not ( $_.IsEnabled ) -and ( $null -ne $_.Tag ) } ).Count ) $( $IntmsgTable.StrSummaryDev )"
	}
}

############################################################################
# Lists all files that were updated in production but not updating it in dev
function AddControlsForUpdatedProdFiles
{
	$l = New-Object System.Windows.Controls.Label
	$l.Content = $IntmsgTable.StrSummaryUpInProd
	$spOtherUpdates.AddChild( $l )
	foreach ( $file in $filesUpdatedInProd )
	{
		$l = New-Object System.Windows.Controls.Label
		$l.Content = "$( $file[1].Name )`n`t$( $file[1].LastWriteTime.ToString() ) $( $IntmsgTable.StrUpInProd ).`n`t$( $file[0].LastWriteTime.ToString() ) $( $IntmsgTable.StrUpInDev )."
		$l.Tag = $file
		$l.Add_MouseRightButtonDown( { $this.Tag | ForEach-Object { & 'C:\Program Files (x86)\Notepad++\notepad++.exe' $_.FullName } } )
		$spOtherUpdates.AddChild( $l )
	}
}

#####################################################################################
# If one or more checkboxes is checked, enable updatebutton and show informationlabel
# If no checkbox is checked, disable updatebutton and hide informationlabel
function CheckChecked
{
	if ( ( $spUpdateList.Children | Where-Object { $_.IsChecked -and ( $null -ne $_.Tag ) } ).Count -gt 0 )
	{
		$btnUpdateScripts.IsEnabled = $true
		$lblInfo.Content = $IntmsgTable.StrUpdateWarning
	}
	else
	{
		$btnUpdateScripts.IsEnabled = $false
		$lblInfo.Content = ""
	}
}

###########################################
# Update the scripts that have been checked
function UpdateScripts
{
	$loop = 1

	$fileCheckboxes = $spUpdateList.Children | Where-Object { $_.IsChecked -and ( $null -ne $_.Tag ) }
	foreach ( $fileCheckbox in $fileCheckboxes )
	{
		$updatedFile = Get-Item $fileCheckbox.Tag.Split( "`n" )[0]
		if ( $null -eq $fileCheckbox.Tag.Split( "`n" )[1] ) { $updatedFileDestination = $fileCheckbox.Tag.Split( "`n" )[1] }
		else { $updatedFileDestination = $prodRoot + "\" + ( $updatedFile.FullName.Replace( "$devRoot\", "" ) ) }

		$OFS = "`n"
		if ( Test-Path $updatedFileDestination )
		{
			$name = $updatedFileDestination -split "\\" | Select-Object -Last 1
			$updated = Get-Date ( Get-Item $updatedFileDestination ).LastWriteTime -Format "yyyy-MM-dd HH.mm.ss"
			$extension = ( Get-Item $updatedFileDestination ).Extension
			$OFS = "`n"
			$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
			New-Item -Path "$rollbackRoot\$( ( Get-Date ).Year )\$( ( Get-Date ).Month )\" -Name "$name ($( $IntmsgTable.StrRollbackName ) $updated)$extension" -ItemType File -Value ( [string]( Get-Content -Path $updatedFileDestination -Encoding UTF8 ) ) -Force | Out-Null
			#Copy-Item -Path $updatedFileDestination -Destination "$rollbackRoot\$( ( Get-Date ).ToShortDateString() )\$( $updatedFileDestination -split "\\" | select -Last 1 )" -Force
			Copy-Item -Path $updatedFile.FullName -Destination $updatedFileDestination -Force
		}
		else
		{
			New-Item -ItemType File -Path $updatedFileDestination -Force
			Copy-Item -Path $updatedFile.FullName -Destination $updatedFileDestination -Force
		}

		$spUpdateList.Children.Remove( $fileCheckbox )
		$loop++
	}

	$ofs = ", "
	$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
	$LogText = "$( $IntmsgTable.StrLogIntro ) $( [string]( $fileCheckboxes.Content ) )"
	if ( @( $Script.filesUpdatedInProd ).Count -gt 0 )
	{
		$LogText += "`n`t$( $IntmsgTable.StrSummaryUpInProd ): "
		$LogText += [string]( $Script:filesUpdatedInProd | ForEach-Object { ( $_[0].FullName -split "development" )[1] } )
	}
	$LogFilePath = "$( ( Get-Item $PSCommandPath ).Directory.Parent.FullName )\Logs\$( [datetime]::Now.Year )\$( [datetime]::Now.Month )\Update-Scripts - log.txt"
	if ( -not ( Test-Path $LogFilePath ) ) { New-Item -Path $LogFilePath -ItemType File -Force | Out-Null } # If logfile does not exist, create it
	Add-Content -Path $LogFilePath -Value ( $nudate + " " + $env:USERNAME + " [" + $env:USERDOMAIN + "] => " + $LogText )

	$lblUpdateInfo.Content = "$( $spUpdateList.Children.Count ) $( $IntmsgTable.StrSummaryUp )"
	CheckChecked
	if ( $spUpdateList.Children.Count -eq 1 )
	{ $spUpdateList.Children.Clear() }
	else
	{ $cbMarkAll.IsChecked = $false }
	$lblUpdateInfo.Content = ""
	$spOtherUpdates.Children.Clear()
	$Script:filesUpdatedInProd.Clear()
	$Script:updatedFiles.Clear()
	$Window.Title = ""
}

######################### Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]
$culture = "sv-SE"
Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "..\Localization"

$Window, $vars = CreateWindow
$vars | ForEach-Object { Set-Variable -Name $_ -Value $Window.FindName( $_ ) }

$Script:devRoot = ( Get-Item $PSCommandPath ).Directory.FullName
$Script:prodRoot = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
$Script:rollbackRoot = "$( ( Get-Item $PSCommandPath ).Directory.Parent.FullName )\UpdateRollback"
$Script:updatedFiles = New-Object System.Collections.ArrayList
$Script:filesUpdatedInProd = New-Object System.Collections.ArrayList
$btnCheckForUpdates.Add_Click( { CheckForUpdates } )
$btnUpdateScripts.Add_Click( { UpdateScripts } )
$Window.Add_ContentRendered( { $Window.Top = 80; $Window.Activate() } )

[void] $Window.ShowDialog()
$Window.Close()
