<#
.Synopsis Remove one or more profiles on remote computer
.Description Remove one or more profiles on remote computer.
.Requires Role_Servicedesk_Backoffice
.Depends WinRM
#>

function Connect
{
	$syncHash.Window.Dispatcher.Invoke( [action] {
		$syncHash.DC.lvProfileList[0].Clear()
		$syncHash.DC.lbOutput[0].Clear()
	} )

	if ( $syncHash.DC.btnConnect[0] -eq $syncHash.Data.msgTable.StrConnect )
	{
		if ( VerifyInput )
		{
			( [powershell]::Create().AddScript( { param ( $syncHash, $li )
				$syncHash.DC.txtCName[0] = $false
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.Progress[1] = $true } )
				$syncHash.DC.btnLogOutAll[0] = $false
				$syncHash.Window.Dispatcher.Invoke( [action] {
					$li.Content = "$( $syncHash.Data.msgTable.StrCheckOnline ) $( $syncHash.Data.ComputerName )"
					$syncHash.DC.lbOutput[0].Add( $li )
				} )

				try
				{
					Test-WSMan $syncHash.Data.ComputerName -ErrorAction Stop
					$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += "`n`t$( $syncHash.Data.msgTable.StrOnline )" } )
					$n = ( quser /server:$( $syncHash.data.ComputerName ) | select -Skip 1 ).Count
					$c = "`n`t$( $n ) $( $syncHash.Data.msgTable.StrUsersLoginSessions )"
					if ( $n -gt 0 )
					{
						$c += "`n`t$( $syncHash.Data.msgTable.StrUsersLoginSessionsLogOut )"
						$syncHash.DC.btnLogOutAll[1] = $syncHash.Data.msgTable.ContentLogoutUsers
					}
					else
					{
						$syncHash.DC.btnLogOutAll[1] = $syncHash.Data.msgTable.ContentGetProfiles
					}
					$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += $c } )
					$syncHash.DC.btnLogOutAll[0] = $true
					$syncHash.DC.btnConnect[0] = $syncHash.Data.msgTable.ContentBtnReset
				}
				catch
				{
					& $syncHash.WriteErrorLog $_
					$syncHash.Window.Dispatcher.Invoke( [action] {
						$li.Content += "`n`t$( $syncHash.Data.msgTable.StrOffline )"
						$li.Background = "#FFFF0000"
						$li.FontWeight = "Bold"
					} )
					$syncHash.DC.txtCName[0] = $true
				}
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.Progress[1] = $false } )
			} ).AddArgument( $syncHash ).AddArgument( [System.Windows.Controls.ListBoxItem]@{ Content = "" } ) ).BeginInvoke()
		}
	}
	else
	{
		$syncHash.DC.btnLogOutAll[0] = $false
		$syncHash.DC.btnSelectAll[0] = $false
		$syncHash.DC.btnRemoveSelected[0] = $false
		$syncHash.DC.lvProfileList[1] = $false
		$syncHash.DC.txtCName[0] = $true

		$syncHash.DC.btnConnect[0] = $syncHash.Data.msgTable.StrConnect
	}
}

function DeleteProfiles
{
	$syncHash.DC.lvProfileList[1] = $true

	$syncHash.DC.lbOutput[0].Add( [System.Windows.Controls.ListBoxItem]@{ Content = $syncHash.Data.msgTable.StrStart } )
	$RunspacePool = [runspacefactory]::CreateRunspacePool( 1, 1 )
	$RunspacePool.CleanupInterval = New-TimeSpan -Minutes 1
	$RunspacePool.Open()
	$syncHash.jobs = New-Object System.Collections.ArrayList
	$syncHash.logText = "$( $syncHash.Data.ComputerName ), $( $syncHash.lvProfileList.SelectedItems.Count ) $( $syncHash.Data.msgTable.StrProfiles )"
	$syncHash.Output = "$( $syncHash.lvProfileList.SelectedItems.Count ) $( $syncHash.Data.msgTable.StrOutputSummary ) $( $syncHash.Data.ComputerName ):"
	foreach ( $user in ( $syncHash.lvProfileList.SelectedItems ) )
	{
		$li = [System.Windows.Controls.ListBoxItem]@{ Content = $user.Name }
		$ps = [powershell]::Create()
		$ps.RunspacePool = $RunspacePool
		[void] $ps.AddScript( { param ( $syncHash, $li, $user )
			$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.lbOutput[0].Add( $li ) } )
			# region FileBackup
			$syncHash.Window.Dispatcher.Invoke( [action] {
				$li.Content += "`n`t$( $syncHash.Data.msgTable.StrStartBackup ) ($( $user.P ))... "
			} )

			$out = Invoke-Command -ComputerName $syncHash.Data.ComputerName -ScriptBlock `
			{
				param ( $id, $Name, $BackupFilePrefix )
				try
				{
					try { New-Item -Path "C:\Users" -Name Old -ItemType Directory -ErrorAction Stop } catch {}

					# Directories to backup
					"C:\Users\$id",
					"C:\Users\$id\AppData\Roaming\Microsoft\Office",
					"C:\Users\$id\AppData\Roaming\Microsoft\Signatures",
					"C:\Users\$id\AppData\Roaming\Microsoft\Sticky Notes",
					"C:\Users\$id\Favorites" | foreach {
						Get-ChildItem $_ -Recurse -ErrorAction SilentlyContinue | Copy-Item -Destination { $_.FullName -replace "$id", "Old\$id" }
					}

					# Specific files to backup
					"C:\Users\$id\AppData\Local\Google\Chrome\User Data\Default\Bookmarks",
					"C:\Users\$id\AppData\Roaming\Microsoft\OneNote\16.0\Preferences.dat" | foreach {
						if ( Test-Path $_ )
						{
							New-Item -Path ( [IO.Path]::GetDirectoryName( $_ ) -replace "$id", "Old\$id" ) `
								-Name ( [IO.Path]::GetFileName( $_ ) ) `
								-ItemType File `
								-Force `
								-Value { Get-Content -Path $_ }
						}
					}

					# Create zip-backup
					$zipDest = "C:\Users\Old\$BackupFilePrefix $Name, $( ( Get-Date ).ToShortDateString() ).zip"
					Compress-Archive -Path C:\Users\Old\$id -DestinationPath $zipDest -CompressionLevel Optimal
					Remove-Item C:\Users\Old\$id -Recurse -Force

					# Remove earlier backups
					Get-ChildItem -Path "C:\Users\Old" | where { $_.Name -match $id -and $_.LastWriteTime -lt ( Get-Date ).AddDays( -30 ) } | Remove-Item2 -Recurse

					[pscustomobject]@{ ZIP = $zipDest ; Org = "C:\Users\$id" }
				} catch { $_ }
			} -ArgumentList $user.ID, $user.Name, $syncHash.Data.msgTable.StrBackupFileName
			$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += $syncHash.Data.msgTable.StrDone } )
			# endregion FileBackup

			# region RemoveProfile
			$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += "`n`t$( $syncHash.Data.msgTable.StrRemoves ) ($( $user.ID ))... " } )
			Get-CimInstance -ComputerName $syncHash.Data.ComputerName -Class Win32_UserProfile | where { $_.LocalPath.Split( '\' )[-1] -eq $user.ID } | Remove-CimInstance
			$syncHash.Window.Dispatcher.Invoke( [action] { $li.Content += $syncHash.Data.msgTable.StrDone } )
			# endregion RemoveProfile

			$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.lvProfileList[0].Remove( $user ) } )

			if ( $out -is [System.Management.Automation.ErrorRecord] )
			{ & $syncHash.WriteErrorLog "$( $syncHash.Data.ComputerName ) - $( $out.Exception.Message )`n`t$( $out.InvocationInfo.PositionMessage )" }
			else
			{ $syncHash.Output += "`n`n$( $user.Name )`n`t$( $syncHash.Data.msgTable.StrProfLoc ) : $( $out.Org )`n`t$( $syncHash.Data.msgTable.StrBackupFileName ): $( $out.ZIP )" }

			$syncHash.Window.Dispatcher.Invoke( [action] {
				$syncHash.DC.Progress[0] = [double] ( ( ( ( $syncHash.jobs.H.IsCompleted -eq $true ).Count + 1 ) / $syncHash.jobs.Count ) * 100 )
			} )
		} ).AddArgument( $syncHash ).AddArgument( $li ).AddArgument( $user )
		[void] $syncHash.jobs.Add( [pscustomobject]@{ P = $ps ; H = $ps.BeginInvoke() } )
	}
}

########################################
# Log off all users from remote computer
function LogoffRemote
{
	if ( $syncHash.DC.btnLogOutAll[1] -eq $syncHash.Data.msgTable.ContentLogoutUsers )
	{
		$userlogins = quser /server:$( $syncHash.Data.ComputerName ) | select -Skip 1 | foreach { 
			[pscustomobject]@{
				UserID = ( Get-ADUser ( $_ -split " +" )[1] ).Name
				SessionID = $( if ( ( $_ -split " +" ).Count -eq 8 ) { ( $_ -split " +" )[3] } else { ( $_ -split " +" )[2] } )
			}
		}

		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.DC.lbOutput[0].Add( [System.Windows.Controls.ListBoxItem]@{ Content = $syncHash.Data.msgTable.StrInfoLogout } )
		} )
		SendToast -Message "$( $syncHash.Data.msgTable.StrMessageLogout )" -ComputerName $syncHash.Data.ComputerName
		Start-Sleep -Seconds 10
		$userlogins | foreach { logoff $_.SessionID /server:$( $syncHash.Data.ComputerName ) }

		$syncHash.Window.Dispatcher.Invoke( [action] {
			$ofs = "`n`t"
			$syncHash.DC.lbOutput[0].Add( [System.Windows.Controls.ListBoxItem]@{ Content = "$( @( $userlogins ).Count ) $( $syncHash.Data.msgTable.StrLoggedOutUsers )`n`t$( [string]( $userlogins.UserID ) )" } )
		} )
	}

	Get-CimInstance -ComputerName $( $syncHash.Data.ComputerName ) -ClassName Win32_UserProfile | where { ( -not $_.Special ) `
			-and ( $_.LocalPath -notmatch "default" ) `
			-and ( $_.LocalPath -notmatch $env:USERNAME ) `
			-and ( -not [string]::IsNullOrEmpty( $_.LocalPath ) ) } | foreach {
		[pscustomobject]@{
			P = $_.LocalPath
			ID = ( $_.LocalPath -split "\\" )[2].ToUpper()
			Name = ( Get-ADUser ( $_.LocalPath -split "\\" )[2] ).Name
			LastUsed = $_.LastUseTime.ToShortDateString()
		}
	} | sort Name | foreach { $syncHash.DC.lvProfileList[0].Add( $_ ) }
	if ( $syncHash.DC.lvProfileList[0].Count -gt 0 )
	{
		$syncHash.DC.btnSelectAll[0] = $true
		$syncHash.DC.lvProfileList[1] = $true
	}
	else
	{
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.lbOutput[0].Add( [System.Windows.Controls.ListBoxItem]@{ Content = $msgTable.StrNoProfiles } ) } )
		$syncHash.DC.lvProfileList[1] = $false
	}

	$syncHash.DC.btnLogOutAll[0] = $false
	$syncHash.DC.btnRemoveSelected[0] = $false
}

function VerifyInput
{
	$c1 = $false
	if ( $syncHash.Data.ComputerName -match $syncHash.Data.msgTable.CodeComputerMatch )
	{
		try
		{
			$role = Get-ADComputer $syncHash.Data.ComputerName -Properties Memberof | select -ExpandProperty MemberOf | where { $_ -match "_Wrk_.+PC," }
			$role | foreach { if ( $_ -match $syncHash.Data.msgTable.CodeRoleMatch ) { $c1 = $true } }
			if ( -not $c1 )
			{
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.lbOutput[0].Add( ( [System.Windows.Controls.ListBoxItem]@{ Content = "$( $syncHash.Data.msgTable.StrWrongRole )`n`t$( $ofs = "`n`t"; $role | foreach { ( ( $_ -split "=" )[1] -split "," )[0] } )"; Background = "#FFFF0000" } ) ) } )
			}
		}
		catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
		{
			WriteErrorLog -LogText $_
			$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.lbOutput[0].Add( ( [System.Windows.Controls.ListBoxItem]@{ Content = $syncHash.Data.msgTable.StrNameNotInAd; Background = "#FFFF0000" } ) ) } )
		}
		catch
		{
			WriteErrorLog -LogText $_
			$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.lbOutput[0].Add( ( [System.Windows.Controls.ListBoxItem]@{ Content = "$( $syncHash.Data.msgTable.StrAdError)`n$_"; Background = "#FFFF0000" } ) ) } )
		}
	}
	elseif ( $syncHash.Data.ComputerName -match $syncHash.Data.msgTable.CodeComputerMismatch )
	{
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.lbOutput[0].Add( ( [System.Windows.Controls.ListBoxItem]@{ Content = $syncHash.Data.msgTable.StrWrongOrg; Background = "#FFFF0000" } ) ) } )
	}
	else
	{
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.lbOutput[0].Add( ( [System.Windows.Controls.ListBoxItem]@{ Content = $syncHash.Data.msgTable.StrWrongName; Background = "#FFFF0000" } ) ) } )
	}

	return $c1
}

########################### Script start
$BaseDir = $args[0]
Import-Module "$BaseDir\Modules\FileOps.psm1" -Force
Import-Module "$BaseDir\Modules\GUIOps.psm1" -Force
Import-Module "$BaseDir\Modules\RemoteOps.psm1" -Force

$controlProperties = New-Object Collections.ArrayList
[void]$controlProperties.Add( @{ CName = "Progress"
	Props = @(
		@{ PropName = "Value"; PropVal = [double] 0 }
		@{ PropName = "IsIndeterminate"; PropVal = $false }
	) } )
[void]$controlProperties.Add( @{ CName = "spComputer"
	Props = @(
		@{ PropName = "IsEnabled"; PropVal = $true }
		@{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Visible }
	) } )
[void]$controlProperties.Add( @{ CName = "lbOutput"
	Props = @(
		@{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) }
	) } )
[void]$controlProperties.Add( @{ CName = "lvProfileList"
	Props = @(
		@{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) }
		@{ PropName = "IsEnabled"; PropVal = $false }
	) } )
[void]$controlProperties.Add( @{ CName = "txtCName"
	Props = @(
		@{ PropName = "IsEnabled"; PropVal = $true }
	) } )
[void]$controlProperties.Add( @{ CName = "btnRemoveSelected"
	Props = @(
		@{ PropName = "IsEnabled"; PropVal = $false }
		@{ PropName = "Content"; PropVal = $msgTable.ContentRemoveSelected }
	) } )
[void]$controlProperties.Add( @{ CName = "btnSelectAll"
	Props = @(
		@{ PropName = "IsEnabled"; PropVal = $false }
		@{ PropName = "Content"; PropVal = $msgTable.ContentSelectAll }
	) } )
[void]$controlProperties.Add( @{ CName = "btnLogOutAll"
	Props = @(
		@{ PropName = "IsEnabled"; PropVal = $false }
		@{ PropName = "Content"; PropVal = $msgTable.ContentLogoutUsers }
	) } )
[void]$controlProperties.Add( @{ CName = "btnConnect"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.StrConnect }
	) } )
[void]$controlProperties.Add( @{ CName = "lblComputerName"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblComputerName }
	) } )
[void]$controlProperties.Add( @{ CName = "gwcID"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentgwcID }
	) } )
[void]$controlProperties.Add( @{ CName = "gwcName"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentgwcName }
	) } )
[void]$controlProperties.Add( @{ CName = "gwcLastUse"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentgwcLastUse }
	) } )

$syncHash = CreateWindowExt $controlProperties

$syncHash.WriteLog = { 
	$p = "$BaseDir\Logs\$( ( Get-Date ).Year )\$( ( Get-Date ).Month )\$( ( ( Split-Path $PSCommandPath -Leaf ) -split "\." )[0] ) - log.txt"
	if ( -not ( Test-Path $p ) ) { New-Item -Path $p -ItemType File -Force }
	Add-Content -Value "$( Get-Date -f "yyyy-MM-dd HH:mm:ss" ) $( $env:USERNAME ) => $( $args[0] )" -Path $f.FullName }
$syncHash.WriteOutput = {
	$f = New-Item -Path "$BaseDir\Output\$( $env:USERNAME )" -Name "$( ( ( Split-Path $PSCommandPath -Leaf ) -split "\." )[0] ), $( Get-Date -Format "yyyy-MM-dd HH.mm.ss" ).txt" -ItemType File -Force
	Add-Content -Value "$( Get-Date -f "yyyy-MM-dd HH:mm:ss" ) $( $env:USERNAME ) => $( $args[0] )" -Path $f.FullName }
$syncHash.WriteErrorLog = {
	$f = New-Item -Path "$BaseDir\ErrorLogs\$( ( Get-Date ).Year )\$( ( Get-Date ).Month )" -Name "$( ( ( Split-Path $PSCommandPath -Leaf ) -split "\." )[0] ) - ErrorLog $( Get-Date -Format "yyyy-MM-dd HH.mm.ss" ).txt" -ItemType File -Force
	Add-Content -Value "$( Get-Date -f "yyyy-MM-dd HH:mm:ss" ) $( $env:USERNAME ) => $( $args[0] )" -Path $f.FullName }

$syncHash.Data.msgTable = $msgTable
$syncHash.btnConnect.Add_Click( { Connect } )

$syncHash.btnSelectAll.Add_Click( {
	if ( $syncHash.DC.btnSelectAll[1] -eq $syncHash.Data.msgTable.ContentSelectAll )
	{
		$syncHash.lvProfileList.SelectAll()
		$syncHash.DC.btnSelectAll[1] = $syncHash.Data.msgTable.ContentDeselectAll
	}
	else
	{
		$syncHash.lvProfileList.UnselectAll()
		$syncHash.DC.btnSelectAll[1] = $syncHash.Data.msgTable.ContentSelectAll
	}
} )

$syncHash.btnRemoveSelected.Add_Click( { DeleteProfiles } )
$syncHash.btnLogOutAll.Add_Click( { LogoffRemote } )

$syncHash.lvProfileList.Add_SelectionChanged( {
	if ( $syncHash.lvProfileList.SelectedItems.Count -eq 0 )
	{
		$syncHash.DC.btnRemoveSelected[0] = $false
	}
	else
	{
		$syncHash.DC.btnRemoveSelected[0] = $true
	}
} )

$syncHash.Progress.Add_ValueChanged( {
	if ( $this.Value -ge 100 )
	{
		$syncHash.logText += "`n`t$( WriteOutput -Output $( $syncHash.Output ) )"
		$logFile = WriteLog -LogText $syncHash.logText
		$syncHash.DC.lvProfileList[1] = $true

		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.Progress[0] = [double] ( 0 ) } )
	}
} )

$syncHash.txtCName.Add_TextChanged( {
	$syncHash.Data.ComputerName = $syncHash.txtCName.Text.Trim()
} )
$syncHash.txtCName.Add_KeyDown( { if ( $args[1].Key -eq "Return" ) { Connect } } )

$syncHash.Window.Add_ContentRendered( {
	$syncHash.Window.Top = 80
	$syncHash.Window.Activate()
	$syncHash.txtCName.Focus()
} )

$syncHash.Data.ComputerName = $syncHash.txtCName.Text = $args[1]

[void] $syncHash.Window.ShowDialog()
$syncHash.Window.Close()
