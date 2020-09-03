
#############################
# Search for any updated file
function CheckForUpdates
{
	$btnUpdateScripts.IsEnabled = $false
	$dirExclusion = @( "ErrorLogs",
	
						"Input",
						"Logs",
						"Output" )
	$fileExclusion = @( ( Get-Item $PSCommandPath ).Name )
	
	
	
	
	$updatedFiles.Clear()
	$spUpdateList.Children.Clear()

	$devFiles = Get-ChildItem $devRoot -Directory -Exclude $dirExclusion | Get-ChildItem -File -Recurse -Exclude $fileExclusion
	$prodFiles = Get-ChildItem $prodRoot -Directory -Exclude $( $dirExclusion += "Development"; $dirExclusion ) | Get-ChildItem -File -Recurse
	$prodFiles += Get-ChildItem $prodRoot -File
	$MD5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider

	foreach ( $devFile in $devFiles )
	{
		$prodFile = $prodFiles | where { $_.Name -eq $devFile.Name }
		if ( $prodFile -eq $null )
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
		$lblUpdateInfo.Content = "No updated files"
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

	$spUpdateList.Children | where { $_.IsEnabled -and ( $_.Tag -ne $null ) } | foreach { $_.IsChecked = $Mark }
}

######################################
# Add a checkbox for each updated file
function AddControlsForUpdatedFiles
{
	$cbMarkAll = New-Object System.Windows.Controls.CheckBox
	$cbMarkAll.Content = "Mark all"
	$cbMarkAll.Margin = "0,0,0,10"
	$cbMarkAll.Add_Checked( { CheckAll $true } )
	$cbMarkAll.Add_UnChecked( { CheckAll $false } )
	Set-Variable -Name cbMarkAll -Value $cbMarkAll -Scope script

	$spUpdateList.AddChild( $cbMarkAll )

	foreach ( $update in $updatedFiles )
	{
		$cbUpdate = New-Object System.Windows.Controls.CheckBox
		$cbUpdate.Add_MouseRightButtonDown( { $this.Tag.Split( "`n" ) | foreach { & 'C:\Program Files (x86)\Notepad++\notepad++.exe' $_ } } )
		$cbUpdate.Name = ( $update[0].Name.Split( "\." ) )[0] -replace "-" -replace " "
		$cbUpdate.Tag = "$( $update[0].FullName )`n$( $update[1].FullName )"
		$devUpdated = Get-Date $update[0].LastWriteTime -Format 'yyyy-MM-dd HH:mm:ss'
		if ( $update[1] -eq "" ) { $prodUpdated = "New script" }
		else { $prodUpdated = Get-Date $update[1].LastWriteTime -Format 'yyyy-MM-dd HH:mm:ss' }
		$cbUpdate.ToolTip = "dev updated:`t$devUpdated`nprod updated:`t$prodUpdated"
		$cbUpdate.Content = "$( ( $( $update[0] ).FullName -split "development" )[1] )"

		if ( ( Get-Content $update[0].FullName | Select-String "^.Synopsis " ) -match "under development" )
		{
			$cbUpdate.FontWeight = "Bold"
			$cbUpdate.Foreground = "Red"
			$cbUpdate.ToolTip = "Under development`n$( $cbUpdate.ToolTip )"
		}
		$cbUpdate.VerticalContentAlignment = "Center"
		$cbUpdate.Add_Checked( { $this.Foreground = "Green"; CheckChecked } )
		$cbUpdate.Add_UnChecked( { $this.Foreground = "Black"; CheckChecked } )

		$spUpdateList.AddChild( $cbUpdate )
	}
	$lblUpdateInfo.Content = "$( ( $spUpdateList.Children | where { $_.IsEnabled -and ( $_.Tag -ne $null ) } ).Count ) files updated"
	if ( ( $spUpdateList.Children | where { -not ( $_.IsEnabled ) -and ( $_.Tag -ne $null ) } ).Count -gt 0 )
	{
		$lblUpdateInfo.Content += "`n$( ( $spUpdateList.Children | where { -not ( $_.IsEnabled ) -and ( $_.Tag -ne $null ) } ).Count ) under development"
	}
}

############################################################################
# Lists all files that were updated in production but not updating it in dev
function AddControlsForUpdatedProdFiles
{
	$l = New-Object System.Windows.Controls.Label
	$l.Content = "Dessa har uppdaterats i produktion, men inte i dev."
	$spOtherUpdates.AddChild( $l )
	foreach ( $file in $filesUpdatedInProd )
	{
		$l = New-Object System.Windows.Controls.Label
		$l.Content = "$( $file[1].Name )`n`t$( $file[1].LastWriteTime.ToString() ) in prod.`n`t$( $file[0].LastWriteTime.ToString() ) in dev."
		$l.Tag = $file
		$l.Add_MouseRightButtonDown( { $this.Tag | foreach { & 'C:\Program Files (x86)\Notepad++\notepad++.exe' $_.FullName } } )
		$spOtherUpdates.AddChild( $l )
	}
}

#####################################################################################
# If one or more checkboxes is checked, enable updatebutton and show informationlabel
# If no checkbox is checked, disable updatebutton and hide informationlabel
function CheckChecked
{
	if ( ( $spUpdateList.Children | where { $_.IsChecked -and ( $_.Tag -ne $null ) } ).Count -gt 0 )
	{
		$btnUpdateScripts.IsEnabled = $true
		$lblInfo.Content = "Only update files you know that you have changed yourself"
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

	$fileCheckboxes = $spUpdateList.Children | where { $_.IsChecked -and ( $_.Tag -ne $null ) }
	foreach ( $fileCheckbox in $fileCheckboxes )
	{
		$updatedFile = Get-Item $fileCheckbox.Tag.Split( "`n" )[0]
		if ( $fileCheckbox.Tag.Split( "`n" )[1] -eq $null ) { $updatedFileDestination = $fileCheckbox.Tag.Split( "`n" )[1] }
		else { $updatedFileDestination = $prodRoot + "\" + ( $updatedFile.FullName.Replace( "$devRoot\", "" ) ) }

		if ( Test-Path $updatedFileDestination ) { Copy-Item -Path $updatedFile.FullName -Destination $updatedFileDestination -Force }
		else { New-Item -Path $updatedFileDestination -Value ( Get-Content $updatedFile.FullName ) -ItemType File -Force | Out-Null }

		$spUpdateList.Children.Remove( $fileCheckbox )
		$loop++
	}

	$ofs = ", "
	$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
	$LogText = "Updating $( [string]( $fileCheckboxes.Content ) )"
	if ( @( $Script.filesUpdatedInProd ).Count -gt 0 )
	{
		$LogText += "`n`tFiles updated in prod, but not in dev: "
		$LogText += [string]( $Script:filesUpdatedInProd | foreach { ( $_[0].FullName -split "development" )[1] } )
	}
	$LogFilePath = "$( ( Get-Item $PSCommandPath ).Directory.Parent.FullName )\Logs\$( [datetime]::Now.Year )\$( [datetime]::Now.Month )\Update-Scripts - log.txt"
	if ( -not ( Test-Path $LogFilePath ) ) { New-Item -Path $LogFilePath -ItemType File -Force | Out-Null } # If logfile does not exist, create it
	Add-Content -Path $LogFilePath -Value ( $nudate + " " + $env:USERNAME + " [" + $env:USERDOMAIN + "] => " + $LogText )

	$lblUpdateInfo.Content = "$( $spUpdateList.Children.Count ) files updated"
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
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$Window, $vars = CreateWindow
$vars | foreach { Set-Variable -Name $_ -Value $Window.FindName( $_ ) }

$Script:devRoot = ( Get-Item $PSCommandPath ).Directory.FullName
$Script:prodRoot = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
$Script:updatedFiles = New-Object System.Collections.ArrayList
$Script:filesUpdatedInProd = New-Object System.Collections.ArrayList
$btnCheckForUpdates.Add_Click( { CheckForUpdates } )
$btnUpdateScripts.Add_Click( { UpdateScripts } )
$Window.Add_ContentRendered( { $Window.Top = 80; $Window.Activate() } )

[void] $Window.ShowDialog()
$Window.Close()
