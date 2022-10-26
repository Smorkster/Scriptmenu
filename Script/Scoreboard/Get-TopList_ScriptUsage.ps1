<#
.Synopsis Scoreboard for scriptusage
.Description Lists which scripts have been used the most, and by whom. Or which users have used the scripts the most, and what scripts they used.
.Author Smorkster (smorkster)
#>

function CollectData
{
	<#
	.Synopsis
		Collect scripts and usagedata
	#>

	$syncHash.DC.Window[0] = $syncHash.msgTable.StrOpReadingLogs
	$syncHash.DC.BtnReadLogs[1] = $false

	$syncHash.P = [powershell]::Create().AddScript( { param ( $syncHash )
		$syncHash.LogData = [System.Collections.ArrayList]::new()
		$syncHash.TotalUserList = [System.Collections.ArrayList]::new()

		$syncHash.Jobs = [System.Collections.ArrayList]::new()
		$syncHash.Logs = Get-ChildItem "$( $syncHash.Root )\Logs" -file -Recurse -Filter "*log.json"
		$syncHash.Scripts = Get-ChildItem "$( $syncHash.Root )\Script" -Filter "*.ps1" -Recurse -File

		$pool = [RunspaceFactory]::CreateRunspacePool( 1, [int]$env:NUMBER_OF_PROCESSORS )
		$pool.ApartmentState = "MTA"
		$pool.Open()

		foreach ( $script in $syncHash.Scripts )
		{
			$p = [powershell]::Create()
			[void] $p.AddScript( {
				param ( $script, $loglist, $syncHash )

				Add-Member -InputObject $script -MemberType NoteProperty -Name "FileContent" -Value ( Get-Content $script.FullName )
				Add-Member -InputObject $script -MemberType NoteProperty -Name "UserList" -Value ( [System.Collections.ArrayList]::new() )
				Add-Member -InputObject $script -MemberType NoteProperty -Name "UseCount" -Value 0
				Add-Member -InputObject $script -MemberType NoteProperty -Name "Synopsis" -Value ( [string]( ( $Script.FileContent | Select-String -Pattern "^\.Synopsis" ).Line -split " " | Select-Object -Skip 1 ) )
				Add-Member -InputObject $script -MemberType NoteProperty -Name "Author" -Value ( [string]( ( $Script.FileContent | Select-String -Pattern "^\.Author" ).Line -split " " | Select-Object -Skip 1 ) )

				foreach ( $log in $loglist )
				{
					foreach ( $json in ( Get-Content $log.FullName | ConvertFrom-Json ) )
					{
						if ( $script.UserList.Name -match $json.Operator )
						{
							$script.UserList.Where( { $_.Name -eq $json.Operator } )[0].OperatorUseCount += 1
						}
						else
						{
							$script.UserList.Add( ( [pscustomobject]@{ Name = $json.Operator ; OperatorUseCount = 1 } ) )
						}
						$script.UseCount += 1
					}
				}
				if ( $script.UserList.Count -gt 1 ) { $script.UserList = $script.UserList | Sort-Object -Descending OperatorUseCount }
				[void] $syncHash.LogData.Add( ( $script | Select-Object * ) )
			} )
			[void] $p.AddArgument( $script )
			[void] $p.AddArgument( ( $syncHash.Logs | Where-Object { $_.BaseName -match "^$( $Script.BaseName )" } ) )
			[void] $p.AddArgument( $syncHash )
			$p.RunspacePool = $pool
			[void] $syncHash.Jobs.Add( [pscustomobject]@{ P = $p; H = $p.BeginInvoke() } )
		}

		do
		{
			Start-Sleep -Seconds 1
		} until ( ( $syncHash.Jobs.H.IsCompleted -match $false ).Count -eq 0 )

		$syncHash.DC.Window[0] = $syncHash.msgTable.StrOpParseUsers

		$syncHash.LogData | `
			ForEach-Object { $_.UserList.Name } | `
			Select-Object -Unique | `
			ForEach-Object {
				$User = $_
				$obj = [pscustomobject]@{
						User = ( Get-ADUser $User ).Name
						TotalUses = $syncHash.LogData.UserList | `
							Where-Object { $_.Name -eq $User } | `
							ForEach-Object -Begin { $s = 0 } `
								-Process { $s += $_.OperatorUseCount } `
								-End { $s }
						ScriptUses = [System.Collections.ArrayList]::new()
					}

				$syncHash.LogData | `
					Where-Object { ( $_.UserList.GetEnumerator() ).Name -match $User } | `
					ForEach-Object {
						$bn = $_.BaseName
						[pscustomobject]@{
							N = $_.BaseName
							C = ( ( $syncHash.LogData | Where-Object { $_.BaseName -eq $bn } ).UserList | Where-Object { $_.Name -eq $User } ).OperatorUseCount
						}
					} | `
					Sort-Object -Descending C | `
					ForEach-Object { [void] $obj.ScriptUses.Add( $_ ) }
				[void] $syncHash.TotalUserList.Add( $obj )
			}
		$syncHash.NeverUsed = ( $syncHash.LogData | Where-Object { $_.UseCount -eq 0 } )
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.Window.Title = "..."
			$syncHash.DgScriptList.ItemsSource = $syncHash.LogData | Sort-Object -Descending UseCount
			$syncHash.DgUsers.ItemsSource = $syncHash.TotalUserList | Sort-Object -Descending TotalUses
			$syncHash.DgNeverUsed.ItemsSource = $syncHash.NeverUsed | Sort-Object BaseName
			$syncHash.Window.Title = ""
		} )
	} ).AddArgument( $syncHash )
	$syncHash.H = $syncHash.P.BeginInvoke()
}

################################ Script start
Add-Type -AssemblyName PresentationFramework
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "BtnReadLogs" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnReadLogs } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "TiNeverUsed" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiNeverUsed } ) } )
[void]$controls.Add( @{ CName = "TiScriptList" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiScriptList } ) } )
[void]$controls.Add( @{ CName = "TiUserList" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiUserList } ) } )
[void]$controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = $msgTable.StrTitleScriptUsage } ) } )

$syncHash = CreateWindowExt -ControlsToBind $controls -IncludeConverters
$syncHash.msgTable = $msgTable

$syncHash.Root = $args[0]
$syncHash.BtnReadLogs.Add_Click( { CollectData } )

$syncHash.DgScriptList.Add_SelectionChanged( {
	$syncHash.DgUseList.ItemsSource = $this.UserList
} )

$syncHash.Window.Add_ContentRendered( {
	$syncHash.DgScriptList.Columns[0].Header = $syncHash.msgTable.ContentColHeaderScriptName
	$syncHash.DgScriptList.Columns[1].Header = $syncHash.msgTable.ContentColHeaderScriptUsage
	$syncHash.DgUsers.Columns[0].Header = $syncHash.msgTable.ContentColHeaderUserName
	$syncHash.DgUsers.Columns[1].Header = $syncHash.msgTable.ContentColHeaderUserCount
	$syncHash.DgUseList.Columns[0].Header = $syncHash.msgTable.ContentColHeaderUsageName
	$syncHash.DgUseList.Columns[1].Header = $syncHash.msgTable.ContentColHeaderUsageCount
	$syncHash.DgNeverUsed.Columns[0].Header = $syncHash.msgTable.ContentColHeaderNUName
	$syncHash.DgNeverUsed.Columns[1].Header = $syncHash.msgTable.ContentColHeaderNUCount
	$syncHash.DgUseListUser.Columns[0].Header = $syncHash.msgTable.ContentDgUseListUserScriptName
	$syncHash.DgUseListUser.Columns[1].Header = $syncHash.msgTable.ContentDgUseListUserUses
	$this.Resources['StrAuthor'] = $syncHash.msgTable.StrAuthor
	$this.Resources['StrLastUpdated'] = $syncHash.msgTable.StrLastUpdated
	$this.Resources['StrSynopsis'] = $syncHash.msgTable.StrSynopsis
	$this.Top = 20
	WriteLogTest -Text Start -Success $true | Out-Null
} )

$syncHash.Window.Add_Closing( {
	$syncHash.P.Runspace.Close()
	$syncHash.P.Runspace.Dispose()
} )

[void] $syncHash.Window.ShowDialog()
$syncHash.Window.Close()
$global:syncHash = $syncHash
