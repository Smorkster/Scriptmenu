<#
.Synopsis Administration of scripts, logs, etc.
.Description Perform administration of updates, logs, reports, etc.
.State Prod
.AllowedUsers smorkster
.Author Smorkster (smorkster)
#>

#############################
# Search for any updated file
function CheckForUpdates
{
	$syncHash.DC.btnUpdateScripts[1] = $false
	$syncHash.Data.dirExclusion = @( "ErrorLogs",
						"Input",
						"Logs",
						"Output",
						"UpdateRollback" )
	$syncHash.Data.fileExclusion = @( ( Get-Item $PSCommandPath ).Name )
	$syncHash.DC.dgUpdates[0].Clear()
	$syncHash.DC.dgUpdatedInProd[0].Clear()

	$syncHash.Data.devFiles = Get-ChildItem $syncHash.Data.devRoot -Directory -Exclude $syncHash.Data.dirExclusion | Get-ChildItem -File -Recurse -Exclude $syncHash.Data.fileExclusion
	$syncHash.Data.devFiles += Get-ChildItem $syncHash.Data.devRoot -File | Where-Object { $_.Name -notin $syncHash.Data.fileExclusion }
	$syncHash.Data.prodFiles = Get-ChildItem $syncHash.Data.prodRoot -Directory -Exclude $( $syncHash.Data.dirExclusion += "Development"; $syncHash.Data.dirExclusion ) | Get-ChildItem -File -Recurse -Exclude $syncHash.Data.fileExclusion
	$syncHash.Data.prodFiles += Get-ChildItem $syncHash.Data.prodRoot -File | Where-Object { $_.Name -notin $syncHash.Data.fileExclusion }
	$syncHash.Data.MD5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider

	foreach ( $devFile in $syncHash.Data.devFiles )
	{
		$prodFile = $syncHash.Data.prodFiles | Where-Object { $_.Name -eq $devFile.Name }
		if ( $null -eq $prodFile )
		{
			$syncHash.DC.dgUpdates[0].Add( ( GetListItem $devFile ) )
		}
		else
		{
			$devMD5 = [System.BitConverter]::ToString( $syncHash.Data.MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $devFile.FullName ) ) )
			$prodMD5 = [System.BitConverter]::ToString( $syncHash.Data.MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $prodFile.FullName ) ) )

			if ( $devMD5 -ne $prodMD5 )
			{
				if ( $prodFile.LastWriteTime -gt $devFile.LastWriteTime )
				{
					$syncHash.DC.dgUpdatedInProd[0].Add( ( GetListItem $devFile $prodFile ) )
				}
				else
				{
					$syncHash.DC.dgUpdates[0].Add( ( GetListItem $devFile $prodFile ) )
				}
			}
		}
	}

	if ( $syncHash.DC.dgUpdates[0].Count -gt 0 )
	{
		$OFS = ", "
		$syncHash.DC.tblUpdateInfo[0] = "{0} {1}`n{2}" -f $syncHash.DC.dgUpdates[0].Count, $syncHash.Data.msgTable.StrUpdates, "$( $syncHash.DC.dgUpdates[0] | Group-Object -Property State | ForEach-Object { "{0} {1} {2}" -f $_.Count, $syncHash.Data.msgTable.StrScanSummary, $_.Name } )"
		$syncHash.DC.btnUpdateScripts[1] = $false
		$syncHash.DC.tblInfo[1] = [System.Windows.Visibility]::Visible
	}
	else
	{
		$syncHash.DC.tblUpdateInfo[0] = $syncHash.Data.msgTable.StrNoUpdates
		$syncHash.DC.tblInfo[1] = [System.Windows.Visibility]::Collapsed
	}

	if ( $syncHash.DC.dgUpdatedInProd[0].Count -gt 0 )
	{
		$syncHash.DC.tiUpdatedInProd[2] = "Red"
		$syncHash.DC.tblUpdateInfo[0] += "`n{0} {1}" -f $syncHash.DC.dgUpdatedInProd[0].Count, $syncHash.Data.msgTable.StrUpdatesInProd
	}
	else { $syncHash.DC.tiUpdatedInProd[2] = "#FFEBEBEB" }
}

###################################
# Create an object for the updated file
function GetListItem
{
	param ( $devFile, $prodFile )

	$listItem = [pscustomobject]@{
		Name = $devFile.Name
		DevPath = $devFile.FullName
		DevUpd = ( Get-Date $devFile.LastWriteTime -Format "yyyy-MM-dd hh:mm:ss" )
	}

	if ( ( $path = $devFile.Directory.FullName.Replace( "$( $syncHash.Data.devRoot )", "" ) ) -eq "" ) { $path = "\" }
	$listItem | Add-Member -MemberType NoteProperty -Name "Path" -Value $path

	if ( $null -eq $prodFile )
	{
		$new = $true
		$ProdUpd = switch ( ( $devFile.Extension -replace "\." ) )
			{
				"psd1" {
					if ( ( Get-Content $devFile.FullName )[0] -eq "ConvertFrom-StringData @'" ) { $syncHash.Data.msgTable.StrNewLocFile }
					else { $syncHash.Data.msgTable.StrNewDataFile }
					}
				"ps1" { $syncHash.Data.msgTable.StrNewScript }
				"xaml" { $syncHash.Data.msgTable.StrNewGuiFile }
				default { $syncHash.Data.msgTable.StrNewOtherFile }
			}
		$prodPath = "{0}{1}\{2}" -f $syncHash.Data.prodRoot, "$( if ( $listItem.Path -ne "\" ) { $listItem.Path } )", $listItem.Name
	}
	else
	{
		$new = $false
		$ProdUpd = ( Get-Date $prodFile.LastWriteTime -Format "yyyy-MM-dd hh:mm:ss" )
		$prodPath = $prodFile.FullName
	}
	$listItem | Add-Member -MemberType NoteProperty -Name "New" -Value $new
	$listItem | Add-Member -MemberType NoteProperty -Name "ProdUpd" -Value $ProdUpd
	$listItem | Add-Member -MemberType NoteProperty -Name "ProdPath" -Value $prodPath

	$State, $TT = ( GetState $devFile )
	$listItem | Add-Member -MemberType NoteProperty -Name "State" -Value $State
	$listItem | Add-Member -MemberType NoteProperty -Name "ToolTip" -Value $TT

	return $listItem
}

#######################################
# Get the productionstate of the script
function GetState
{
	param ( $devFile )

	if ( $devFile.Extension -in ".xaml",".psd1" )
	{
		$state = ( ( Get-ChildItem $syncHash.Data.devRoot.FullName -Recurse -File -Filter "$( $devFile.BaseName ).ps1" | Select-String -Pattern "^\.State" ) -split " " )[-1]
		$TT = "$( $syncHash.Data.msgTable.StrScriptState ) $state"
	}
	elseif ( $devFile.Extension -in ".ps1",".psm1" )
	{
		$state = ( ( Select-String -Path $devFile.FullName -Pattern "^\.State" ) -split " " )[1]
	}
	else
	{
		$state = "Other"
	}
	return $state, $TT
}

########################################################################
# If a click in a datagrid did not occur on a row, unselect selected row
function UnselectDatagrid
{
	param ( $ClickType, $Datagrid )

	if ( $ClickType -ne "TextBlock" ) { $Datagrid.SelectedIndex = -1 }

}

############################################
# Update the scripts that have been selected
function UpdateScripts
{
	foreach ( $file in $syncHash.dgUpdates.SelectedItems )
	{
		$OFS = "`n"
		if ( $file.New )
		{
			New-Item -ItemType File -Path $file.ProdPath -Force
			Copy-Item -Path $file.DevPath -Destination $file.ProdPath -Force
		}
		else
		{
			$RollbackPath = "$( $syncHash.Data.RollbackRoot )\$( ( Get-Date ).Year )\$( ( Get-Date ).Month )\"
			$RollbackName = "$( $file.Name ) ($( $syncHash.Data.msgTable.StrRollbackName ) $( $file.ProdUpd ), $( $env:USERNAME ))$( ( Get-Item $file.ProdPath ).Extension )" -replace ":","."
			$RollbackValue = [string]( Get-Content -Path $file.ProdPath -Encoding UTF8 )
			$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
			New-Item -Path $RollbackPath -Name $RollbackName -ItemType File -Value $RollbackValue -Force | Out-Null
			Copy-Item -Path $file.DevPath -Destination $file.ProdPath -Force
		}
	}

	$OFS = "`n`t"
	$LogText = "$( $syncHash.Data.msgTable.StrLogIntro ) $( [string]( $syncHash.dgUpdates.SelectedItems | ForEach-Object { "$( if ( $_.Path -ne "\" ) { $_.Path } )", $_.Name } ) )"
	if ( $syncHash.DC.dgUpdatedInProd[0].Count -gt 0 )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.StrSummaryUpInProd ): "
		$LogText += [string]( $syncHash.DC.dgUpdatedInProd[0] | ForEach-Object { "$( if ( $_.Path -ne "\" ) { $_.Path } )", $_.Name } )
	}
	WriteLog -LogText $LogText

	$syncHash.DC.dgUpdates[0] = $syncHash.dgUpdates.Items | Where-Object { $_ -notin $syncHash.dgUpdates.SelectedItems }
	$syncHash.DC.tblInfo[1] = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.Window[0] = ""
}

######################### Script start
Add-Type -AssemblyName PresentationFramework
$BaseDir = $args[0]
Import-Module "$BaseDir\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$BaseDir\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]

$controls = [System.Collections.ArrayList]::new()
[void] $controls.Add( @{ CName = "btnCheckForUpdates" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCheckForUpdates } ) } )
[void] $controls.Add( @{ CName = "btnDoRollback" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnDoRollback } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void] $controls.Add( @{ CName = "btnListRollbacks" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnListRollbacks } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void] $controls.Add( @{ CName = "btnOpenErrorLog" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenErrorLog } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void] $controls.Add( @{ CName = "btnOpenRollbackFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenRollbackFile } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void] $controls.Add( @{ CName = "btnReadErrorLogs" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnReadErrorLogs } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void] $controls.Add( @{ CName = "btnReadLogs" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnReadLogs } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void] $controls.Add( @{ CName = "btnUpdateScripts" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUpdateScripts } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void] $controls.Add( @{ CName = "cbErrorLogsScriptNames" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void] $controls.Add( @{ CName = "cbLogsScriptNames" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void] $controls.Add( @{ CName = "cbRollbackScriptNames" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void] $controls.Add( @{ CName = "dgErrorLogs" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void] $controls.Add( @{ CName = "dgLogs" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void] $controls.Add( @{ CName = "dgUpdatedInProd" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void] $controls.Add( @{ CName = "dgUpdates" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void] $controls.Add( @{ CName = "gbErrorInfo" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgbErrorInfo } ) } )
[void] $controls.Add( @{ CName = "lblErrorMessage" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblErrorMessage } ) } )
[void] $controls.Add( @{ CName = "lblOperator" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOperator } ) } )
[void] $controls.Add( @{ CName = "lblSeverity" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSeverity } ) } )
[void] $controls.Add( @{ CName = "lblUserInput" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblUserInput } ) } )
[void] $controls.Add( @{ CName = "tblInfo" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttblInfo } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void] $controls.Add( @{ CName = "tblUpdatedInProd" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttblUpdatedInProd } ) } )
[void] $controls.Add( @{ CName = "tblUpdateInfo" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void] $controls.Add( @{ CName = "tiErrorLogs" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiErrorLogs } ) } )
[void] $controls.Add( @{ CName = "tiLogs" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiLogs } ) } )
[void] $controls.Add( @{ CName = "tiRollback" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiRollback } ) } )
[void] $controls.Add( @{ CName = "tiUpdated" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiUpdated } ) } )
[void] $controls.Add( @{ CName = "tiUpdatedInProd" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiUpdatedInProd } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Visible } ; @{ PropName = "Background" ; PropVal = "#FFEBEBEB" } ) } )
[void] $controls.Add( @{ CName = "tiUpdates" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiUpdates } ) } )
[void] $controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = $msgTable.ContentWindow } ) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.msgTable = $msgTable
if ( $BaseDir -match "Development" )
{
	$syncHash.Data.devRoot = $BaseDir
	$syncHash.Data.prodRoot = ( Get-Item $BaseDir ).Parent.FullName
}
else
{
	$syncHash.Data.devRoot = "$BaseDir\Development"
	$syncHash.Data.prodRoot = $BaseDir
}
$syncHash.Data.RollbackRoot = "$( $syncHash.Data.prodRoot )\UpdateRollback"
$syncHash.Data.updatedFiles = New-Object System.Collections.ArrayList
$syncHash.Data.filesUpdatedInProd = New-Object System.Collections.ArrayList
if ( Test-Path "C:\Program Files (x86)\Notepad++\notepad++.exe" ) { $syncHash.Data.Editor = "C:\Program Files (x86)\Notepad++\notepad++.exe" }
else { $syncHash.Data.Editor = "notepad" }
$syncHash.Data.ErrorLogs = [hashtable]::new()
$syncHash.Data.Logs = [hashtable]::new()

$syncHash.btnCheckForUpdates.Add_Click( { CheckForUpdates } )
$syncHash.btnDoRollback.Add_Click( {
	if ( $null -eq ( $op = Get-ChildItem -Path $syncHash.Data.prodRoot -Directory -Exclude "Development","Arkiv" | Get-ChildItem -File -Filter $syncHash.cbRollbackScriptNames.Text -Recurse ) )
	{
		$text = $syncHash.Data.msgTable.StrRollbackPahNotFound
		$icon = [System.Windows.MessageBoxImage]::Warning
		$button = [System.Windows.MessageBoxButton]::OK
	}
	else
	{
		$text = ( "{0}`n`n{1}`n{2}`n`n{3}`n{4}" -f $syncHash.Data.msgTable.StrRollbackVerification, $syncHash.Data.msgTable.StrRollbackVerificationPath, $op.FullName, $syncHash.Data.msgTable.StrRollbackVerificationDate, $syncHash.dgRollbacks.SelectedItem.ScriptDate )
		$icon = [System.Windows.MessageBoxImage]::Question
		$button = [System.Windows.MessageBoxButton]::YesNo
	}

	if ( ( ShowMessageBox -Text $text -Icon $icon -Button $button ) -eq "Yes" )
	{
		$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
		Set-Content -Value ( Get-Content $syncHash.dgRollbacks.SelectedItem.FullName ) -Path $op.FullName
		ShowMessageBox -Text $syncHash.Data.msgTable.StrRollbackDone
	}
} )
$syncHash.btnListRollbacks.Add_Click( {
	Get-ChildItem $syncHash.Data.RollbackRoot -Recurse -File | Sort-Object BaseName | ForEach-Object {
		$n, $ud = $_.BaseName -split " \(" -replace "\)"
		$fullname = $_.FullName
		if ( $syncHash.DC.cbRollbackScriptNames[0].ScriptName -notcontains $n )
		{ $syncHash.DC.cbRollbackScriptNames[0].Add( [pscustomobject]@{ "ScriptName" = $n ; "ScriptLogs" = [System.Collections.ArrayList]::new() } ) }
		$null, $d, $t = $ud -split " " -replace "\.",":"
		( $syncHash.DC.cbRollbackScriptNames[0].Where( { $_.ScriptName -eq $n } ) )[0].ScriptLogs.Add( [pscustomobject]@{ "ScriptDate" = ( "$d $t" -replace "\.", ":" ); "UpdatedBy" = $u ; "FullName" = $fullname } )
	}
} )
$syncHash.btnOpenErrorLog.Add_Click( {
	if ( $syncHash.cbErrorLogsScriptNames.HasItems )
	{
		$syncHash.tbAdmin.SelectedIndex = 2
		$syncHash.cbErrorLogsScriptNames.SelectedItem = $syncHash.cbLogsScriptNames.Text
		Start-Sleep 0.5
		$syncHash.dgErrorLogs.SelectedIndex = $syncHash.dgErrorLogs.Items.IndexOf( ( $syncHash.dgErrorLogs.Items.Where( { $_.Logdate -eq $syncHash.dgLogs.SelectedItem.ErrorLogDate } ) )[0] )
	}
	else { ShowMessageBox -Text $syncHash.Data.msgTable.StrErrorlogsNotLoaded }
} )
$syncHash.btnReadErrorLogs.Add_Click( {
	$splash = ShowSplash -Text $syncHash.Data.msgTable.StrSplReadErrorLogs -SelfAdmin
	Get-ChildItem "$BaseDir\ErrorLogs" -Recurse -File -Filter "*.json" | ForEach-Object {
		$n = $_.BaseName -replace " - ErrorLog"
		if ( -not ( $syncHash.Data.ErrorLogs.Keys -contains $n ) )
		{ $syncHash.Data.ErrorLogs.Add( $n, [System.Collections.ArrayList]::new() ) | Out-Null }
		Get-Content $_.FullName | ForEach-Object { $_ | ConvertFrom-Json } | Sort-Object LogDate | ForEach-Object { $syncHash.Data.ErrorLogs.$n.Add( $_ ) }
	}
	$syncHash.Data.ErrorLogs.Keys | Sort-Object | ForEach-Object { $syncHash.DC.cbErrorLogsScriptNames[0].Add( $_ ) }
	$splash.Close()
} )
$syncHash.btnReadLogs.Add_Click( {
	$splash = ShowSplash -Text $syncHash.Data.msgTable.StrSplReadLogs -SelfAdmin
	Get-ChildItem "$BaseDir\Logs" -Recurse -File -Filter "*.json" | ForEach-Object {
		$n = $_.BaseName -replace " - Log"
		if ( -not ( $syncHash.Data.Logs.Keys -contains $n ) )
		{ $syncHash.Data.Logs.Add( $n, [System.Collections.ArrayList]::new() ) | Out-Null }
		Get-Content $_.FullName | ForEach-Object {
			$l = $_ | ConvertFrom-Json
			try { $l | Add-Member -MemberType NoteProperty -Name "ErrorlogNick" -Value ( [string]$l.ErrorlogFile[-12..-1] -replace " " ) -PassThru } catch { $l }
		} | Sort-Object LogDate | ForEach-Object { $syncHash.Data.Logs.$n.Add( $_ ) }
	}
	$syncHash.Data.Logs.Keys | Sort-Object | ForEach-Object { $syncHash.DC.cbLogsScriptNames[0].Add( $_ ) }
	$splash.Close()
} )
$syncHash.btnOpenRollbackFile.Add_Click( { Start-Process $syncHash.Data.Editor """$( $syncHash.dgRollbacks.SelectedItem.FullName )""" } )
$syncHash.btnUpdateScripts.Add_Click( { UpdateScripts } )
$syncHash.cbErrorLogsScriptNames.Add_SelectionChanged( {
	$syncHash.DC.dgErrorLogs[0] = $syncHash.Data.ErrorLogs.( $syncHash.cbErrorLogsScriptNames.SelectedItem ) | Sort-Object -Property LogDate -Descending
} )
$syncHash.cbLogsScriptNames.Add_SelectionChanged( {
	$syncHash.DC.dgLogs[0] = $syncHash.Data.Logs.( $syncHash.cbLogsScriptNames.SelectedItem ) | Sort-Object -Property LogDate -Descending
} )
$syncHash.dgLogs.Add_SelectionChanged( { $syncHash.DC.btnOpenErrorLog[1] = $this.SelectedItem.ErrorlogNick -ne $null } )
$syncHash.dgErrorLogs.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource.GetType().Name $this } )
$syncHash.dgLogs.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource.GetType().Name $this } )
$syncHash.dgRollbacks.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource.GetType().Name $this } )
$syncHash.dgUpdates.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource.GetType().Name $this } )
$syncHash.dgUpdatedInProd.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource.GetType().Name $this } )
$syncHash.dgRollbacks.Add_SelectionChanged( { $syncHash.DC.btnOpenRollbackFile[1] = $syncHash.DC.btnDoRollback[1] = $this.SelectedItem -ne $null } )
$syncHash.dgUpdates.Add_MouseRightButtonUp( {
	if ( ( $args[1].OriginalSource.GetType() ).Name -eq "TextBlock" )
	{
		$d = $args[1].OriginalSource.Parent.DataContext.DevPath
		$p = $args[1].OriginalSource.Parent.DataContext.ProdPath
		if ( $null -ne $d ) { if ( Test-Path $d ) { Start-Process $syncHash.Data.Editor $d } }
		if ( $null -ne $p ) { if ( Test-Path $p ) { Start-Process $syncHash.Data.Editor $p } }
	}
} )
$syncHash.dgUpdatedInProd.Add_MouseRightButtonUp( {
	$d = $args[1].OriginalSource.Parent.DataContext.DevPath
	$p = $args[1].OriginalSource.Parent.DataContext.ProdPath
	if ( Test-Path $d ) { Start-Process $syncHash.Data.Editor $d }
	if ( Test-Path $p ) { Start-Process $syncHash.Data.Editor $p }
} )
$syncHash.dgUpdates.Add_SelectionChanged( { $syncHash.DC.btnUpdateScripts[1] = $this.SelectedItems.Count -gt 0 } )
$syncHash.Window.Add_ContentRendered( {
	$syncHash.Window.Top = 80
	$syncHash.Window.Activate()
	$syncHash.dgUpdates.Columns[0].Header = $syncHash.dgUpdatedInProd.Columns[0].Header = $syncHash.Data.msgTable.ContentdgUpdatesColName
	$syncHash.dgUpdates.Columns[1].Header = $syncHash.dgUpdatedInProd.Columns[1].Header = $syncHash.Data.msgTable.ContentdgUpdatesColPath
	$syncHash.dgUpdates.Columns[2].Header = $syncHash.dgUpdatedInProd.Columns[2].Header = $syncHash.Data.msgTable.ContentdgUpdatesColDevUpd
	$syncHash.dgUpdates.Columns[3].Header = $syncHash.dgUpdatedInProd.Columns[3].Header = $syncHash.Data.msgTable.ContentdgUpdatesColProdUpd
	$syncHash.dgUpdates.Columns[4].Header = $syncHash.dgUpdatedInProd.Columns[4].Header = $syncHash.Data.msgTable.ContentdgUpdatesColProdState
	$syncHash.dgLogs.Columns[0].Header = $syncHash.Data.msgTable.ContentdgLogsColLogDate
	$syncHash.dgLogs.Columns[1].Header = $syncHash.Data.msgTable.ContentdgLogsColLogText
	$syncHash.dgLogs.Columns[2].Header = $syncHash.Data.msgTable.ContentdgLogsColUserInput
	$syncHash.dgLogs.Columns[3].Header = $syncHash.Data.msgTable.ContentdgLogsColSuccess
	$syncHash.dgLogs.Columns[4].Header = $syncHash.Data.msgTable.ContentdgLogsColErrorlogDate
	$syncHash.dgLogs.Columns[5].Header = $syncHash.Data.msgTable.ContentdgLogsColOutputFile
	$syncHash.dgLogs.Columns[6].Header = $syncHash.Data.msgTable.ContentdgLogsColOperator
	$syncHash.dgRollbacks.Columns[0].Header = $syncHash.Data.msgTable.ContentdgRollbacksColDate
	$syncHash.dgRollbacks.Columns[1].Header = $syncHash.Data.msgTable.ContentdgRollbacksColUpdatedBy
	$syncHash.dgErrorLogs.Columns[0].Header = $syncHash.Data.msgTable.ContentdgErrorLogsColLogDate
} )

[void] $syncHash.Window.ShowDialog()
$syncHash.Window.Close()
#$global:syncHash = $syncHash