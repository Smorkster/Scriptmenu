<#
.Synopsis Unistall application
.Description Uninstall an application from remote computer
.Depends WinRM
#>

Add-Type -AssemblyName PresentationFramework
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "btn"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentButton }
		@{ PropName = "IsEnabled"; PropVal = $false }
	) } )
[void]$controls.Add( @{ CName = "dg"
	Props = @(
		@{ PropName = "HeadersVisibility"; PropVal = [System.Windows.Visibility]::Collapsed }
	) } )
[void]$controls.Add( @{ CName = "pb"
	Props = @(
		@{ PropName = "IsIndeterminate"; PropVal = $false }
		@{ PropName = "Value"; PropVal = [double] 0 }
	) } )
[void]$controls.Add( @{ CName = "pbUT"
	Props = @(
		@{ PropName = "Text"; PropVal = "" }
	) } )
[void]$controls.Add( @{ CName = "Window"
	Props = @(
		@{ PropName = "Title"; PropVal = $msgTable.ContentDefWinTit }
	) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.ComputerName = $args[1]
$syncHash.Data.msgTable = $msgTable
$syncHash.Data.Apps = New-Object System.Collections.ArrayList

$syncHash.btn.Add_Click( {
	if ( $syncHash.dg.SelectedItems.Count -gt 10 ) { $summary = "$( $syncHash.dg.SelectedItems.Count ) $( $msgTable.StrAppSum )" }
	else { $summary = "`n`n$( $ofs = "`n"; [string] $syncHash.dg.SelectedItems.Name )" }

	if ( [System.Windows.MessageBox]::Show( "$( $msgTable.QUninstall ) $summary", "", [System.Windows.MessageBoxButton]::YesNo ) -eq "Yes" )
	{
		$syncHash.DC.btn[1] = $false
		( [powershell]::Create().AddScript( { param ( $syncHash, $list )
			for ( $c = 0; $c -lt $list.Count; $c++ )
			{
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.pbUT[0] = "$( $syncHash.Data.msgTable.StrUninstalling ) $( $list[$c].Name )" } )
				Get-CimInstance -ComputerName $syncHash.Data.ComputerName -Query "SELECT * FROM win32_product WHERE IdentifyingNumber LIKE '$( $list[$c].ID )'" | Remove-CimInstance
				$syncHash.Window.Dispatcher.Invoke( [action] {
					$syncHash.DC.pb[1] = [double] ( ( $c / @( $list ).Count ) * 100 )
					$syncHash.Data.Apps.Add( $list[$c].Name )
					$syncHash.dg.Items.Remove( $list[$c] )
				} )
			}
			$syncHash.Window.Dispatcher.Invoke( [action] {
				$syncHash.DC.pb[1] = 0.0
				$syncHash.DC.pbUT[0] = $syncHash.Data.msgTable.StrDone
			} )
		} ).AddArgument( $syncHash ).AddArgument( @( $syncHash.dg.SelectedItems | Where-Object { $_ } ) ) ).BeginInvoke()
	}
} )

$syncHash.dg.Add_SelectionChanged( { $syncHash.DC.btn[1] = ( $syncHash.dg.SelectedItems.Count -gt 0 ) } )

$syncHash.Window.Add_Loaded( {
		$syncHash.dg.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $msgTable.ContentNameCol; Binding = [System.Windows.Data.Binding]@{ Path = "Name" }; MinWidth = 360 } ) )
		$syncHash.dg.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $msgTable.ContentInstCol; Binding = [System.Windows.Data.Binding]@{ Path = "Installed" }; MinWidth = 100 } ) )
		$syncHash.dg.Columns.Add( ( [System.Windows.Controls.DataGridTextColumn]@{ Header = $msgTable.ContentIdCol; Binding = [System.Windows.Data.Binding]@{ Path = "ID" }; MinWidth = 100 } ) )
		$syncHash.dg.Visibility = [System.Windows.Visibility]::Visible
} )

$syncHash.Window.Add_Activated( {
	if ( $syncHash.dg.Items.Count -eq 0 )
	{
		$syncHash.Window.Top = 20
		$syncHash.Data.list = Get-CimInstance -ComputerName $syncHash.Data.ComputerName -ClassName win32_product | Where-Object { $_.Name -ne $null } | Sort-Object Name
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.Data.list | Foreach-Object { $syncHash.dg.AddChild( [pscustomobject]@{ Name = $_.Name; Installed = ( [datetime]::ParseExact( $_.InstallDate, "yyyyMMdd", $null ) ).ToShortDateString() ; ID = $_.IdentifyingNumber } ) }
		} )
		$syncHash.DC.Window[0] = ""
	}
} )

[void]$syncHash.Window.ShowDialog()
WriteLog -LogText "$( $syncHash.Data.ComputerName ) $( $ofs = ", "; [string]( $syncHash.Data.Apps | sort ) )" | Out-Null
