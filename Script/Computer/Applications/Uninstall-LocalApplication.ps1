<#
.Synopsis Unistall application
.Description Uninstall an application from remote computer
.Depends WinRM
.Author Smorkster (smorkster)
#>

################### Start script
Add-Type -AssemblyName PresentationFramework
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]

$controls = [System.Collections.ArrayList]::new()
[void]$controls.Add( @{ CName = "btnGetAppList" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnGetAppList } ; @{ PropName = "IsEnabled"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "btnUninstall" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUninstall } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "dgAppList" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[object] ) } ) } )
[void]$controls.Add( @{ CName = "pbUninstallations" ; Props = @( @{ PropName = "IsIndeterminate"; PropVal = $false } ; @{ PropName = "Value"; PropVal = [double] 0 } ) } )
[void]$controls.Add( @{ CName = "tbUninstallations" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = "$( $msgTable.ContentWindow ) $( $args[2] )" } ) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.ComputerName = $args[2]
$syncHash.Data.msgTable = $msgTable
$syncHash.Data.UninstalledApps = [System.Collections.ArrayList]::new()
$syncHash.Data.UninstallErrors = [System.Collections.ArrayList]::new()
$syncHash.UpdateList = {
	try
	{
		$syncHash.pUninstall.EndInvoke()
		$syncHash.pUninstall.Dispose()
	} catch {}

	$syncHash.DC.tbUninstallations[0] = $syncHash.Data.msgTable.ContentDefWinTit
	$syncHash.DC.pbUninstallations[0] = $true
	$syncHash.pFetch = [powershell]::Create().AddScript( { param ( $syncHash )
		try
		{
			$syncHash.DC.dgAppList[0] = Get-CimInstance -ComputerName $syncHash.Data.ComputerName -ClassName win32_product | Where-Object { $_.Name -ne $null } | Select-Object -Property Name, @{ Name = "Installed" ; Expression = { try { ( [datetime]::ParseExact( $_.InstallDate, "yyyyMMdd", $null ) ).ToShortDateString() } catch { $syncHash.Data.msgTable.StrNoInstallDate } } }, @{ Name = "ID"; Expression = { $_.IdentifyingNumber } } | Sort-Object Name
			$syncHash.DC.tbUninstallations[0] = ""
			$syncHash.DC.pbUninstallations[0] = $false
		} catch { }
	} ).AddArgument( $syncHash )
	$syncHash.hFetch = $syncHash.pFetch.BeginInvoke()
}

$syncHash.btnGetAppList.Add_Click( { & $syncHash.UpdateList } )
$syncHash.btnUninstall.Add_Click( {
	if ( $syncHash.dgAppList.SelectedItems.Count -gt 10 ) { $summary = "$( $syncHash.dgAppList.SelectedItems.Count ) $( $msgTable.StrAppSum )" }
	else { $summary = "`n`n$( $ofs = "`n"; [string] $syncHash.dgAppList.SelectedItems.Name )" }

	if ( [System.Windows.MessageBox]::Show( "$( $msgTable.QUninstall ) $summary", "", [System.Windows.MessageBoxButton]::YesNo ) -eq "Yes" )
	{
		$syncHash.pUninstall = [powershell]::Create().AddScript( { param ( $syncHash, $list )
			for ( $c = 0; $c -lt $list.Count; $c++ )
			{
				$syncHash.DC.tbUninstallations[0] = "$( $syncHash.Data.msgTable.StrUninstalling ) $( $list[$c].Name )"
				try
				{
					Get-CimInstance -ComputerName $syncHash.Data.ComputerName -Query "SELECT * FROM win32_product WHERE IdentifyingNumber LIKE '$( $list[$c].ID )'" | Remove-CimInstance
					$syncHash.Data.UninstalledApps.Add( $list[$c] )
				}
				catch { $syncHash.Data.UninstallErrors.Add( [pscustomobject]@{ App = $list[$c]; Error = $_ } ) }
				$syncHash.DC.pbUninstallations[1] = [double] ( ( $c / @( $list ).Count ) * 100 )
			}
			$syncHash.Window.Dispatcher.Invoke( [action] {
				$syncHash.DC.pbUninstallations[1] = 0.0
				$syncHash.DC.tbUninstallations[0] = $syncHash.Data.msgTable.StrDone
				& $syncHash.UpdateList
			} )
		} ).AddArgument( $syncHash ).AddArgument( @( $syncHash.dgAppList.SelectedItems | Where-Object { $_ } ) )
		$syncHash.hUninstall = $syncHash.pUninstall.BeginInvoke()
	}
} )

$syncHash.dgAppList.Add_SelectionChanged( { $syncHash.DC.btnUninstall[1] = ( $syncHash.dgAppList.SelectedItems.Count -gt 0 ) } )

$syncHash.Window.Add_Loaded( {
	$syncHash.dgAppList.Columns[0].Header = $msgTable.ContentNameCol
	$syncHash.dgAppList.Columns[1].Header = $msgTable.ContentInstCol
	$syncHash.dgAppList.Columns[2].Header = $msgTable.ContentIdCol
} )

$syncHash.Window.Add_Activated( { $syncHash.Window.Top = 20 } )

[void]$syncHash.Window.ShowDialog()
if ( $syncHash.Data.UninstallErrors.Count -gt 0 )
{
	$OFS = "`n`n"
	$eh = WriteErrorlogTest -LogText "$( $syncHash.Data.UninstallErrors | ForEach-Object { "$( $_.App.Name ) ($( $_.App.ID )):`n$( $_.Error )" } )" -UserInput $syncHash.Data.ComputerName -Severity "OtherFail"
}
if ( $syncHash.Data.UninstalledApps.Count -gt 0)
{
	$OFS = ", "
	WriteLogTest -Text "$( $syncHash.Data.UninstalledApps.Name | Sort-Object )" -UserInput $syncHash.Data.ComputerName -Success ( $syncHash.Data.UninstallErrors.Count -eq 0 ) -ErrorLogHash $eh | Out-Null
}
#$global:syncHash = $syncHash
