<#
.Synopsis Scoreboard for scriptusage
.Description Lists which scripts have been used the most, and by whom. Or which users have used the scripts the most, and what scripts they used.
.Author Smorkster (smorkster)
#>

###############################
# Collect scripts and usagedata
function CollectData
{
	$syncHash.DC.Window[0] = $syncHash.msgTable.StrOpReadingLogs
	$syncHash.DC.rbUsers[1] = $syncHash.DC.rbScript[1] = $true
	$logs = Get-ChildItem "$( ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName )\Logs" -Exclude "DummyQuitting.txt" -File -Recurse

	foreach ( $log in $logs )
	{
		$logName = $log.BaseName -replace " - log"
		if ( $syncHash.ScriptList -notcontains $logName )
		{
			$syncHash.ScriptList += $logName
		}
		Get-Content $log | ForEach-Object `
		{
			if ( $_ -match "^\d{4}-\d{2}-\d{2}" )
			{
				$user = ( $_ -split " " )[2].ToLower()

				if ( $syncHash.Users.Keys -match $user )
				{
					if ( $syncHash.Users.$user.Scripts.$logName )
					{
						$syncHash.Users.$user.Scripts.$logName++
					}
					else
					{
						Add-Member -InputObject $syncHash.Users.$user.Scripts -MemberType NoteProperty -Name $logName -Value 1
					}
					$syncHash.Users.$user.TotalUseCount++
				}
				else
				{
					$syncHash.Users.Add( $user , @{ TotalUseCount = 1; Scripts = [pscustomobject]@{ $logName = 1 }; Name = ( Get-ADUser $user ).Name } )
				}
			}
		}
	}
	$syncHash.DC.rbScript[2] = $true
	$syncHash.DC.Window[0] = ""
}

##################################################
# Get scriptList, number of uses, and its topusers
function ListByScript
{
	$syncHash.DC.TopList[0].Clear()
	$list = @()
	foreach ( $script in $syncHash.ScriptList )
	{
		$scriptTotalUseCount = 0

		$syncHash.Users.Keys | Where-Object { ( $syncHash.Users.$_.Scripts | Get-Member -Name $script ).Count -gt 0 } | ForEach-Object { $scriptTotalUseCount += ( $syncHash.Users.$_.Scripts.$script ) }
		$list += ,[pscustomobject]@{ Name = $script; Count = $scriptTotalUseCount }
	}
	$syncHash.DC.TopList[0] = $list | Sort-Object -Descending Count

	$syncHash.DC.Window[0] = $syncHash.msgTable.StrTitleScripts
}

#################################
# Get users, and the scripts used
function ListByUser
{
	( [powershell]::Create().AddScript( { param ( $syncHash )
		$syncHash.DC.TopList[0].Clear()
		$list = @()
		$syncHash.Users.GetEnumerator() | ForEach-Object { $list += ,[pscustomobject]@{ Name = ( $_.Value.Name ); Count = $_.Value.TotalUseCount } }
		$syncHash.DC.TopList[0] = $list | Sort-Object -Descending Count
	} ).AddArgument( $syncHash ) ).BeginInvoke()
}

########################################
# List scripts that have never been used
function NeverUsedScripts
{
	# List scripts never used
	if ( $syncHash.DC.btnNeverUsed[0] -eq $syncHash.msgTable.StrNeverUsed )
	{
		$syncHash.DC.CountHeader[0] = $syncHash.msgTable.ContentCreatedHeader
		$syncHash.DC.rbScript[2] = $syncHash.DC.rbScript[1] = $false
		$syncHash.DC.rbUsers[2] = $syncHash.DC.rbUsers[1] = $false
		$syncHash.DC.spSortBy[0] = [System.Windows.Visibility]::Hidden
		$syncHash.DC.TopList[0].Clear()
		$scripts = Get-ChildItem -Path "$( $syncHash.Root )\Script" -Filter "*ps1" -Exclude "SDGUI.ps1" -Recurse -File | Select-Object @{ N = "Name"; E = { $_.BaseName } }, @{ N = "Count"; E = { $_.CreationTime.ToShortDateString() } }
		$logs = Get-ChildItem "$( $syncHash.Root )\Logs" -Filter "*txt" -Recurse -File -Exclude "DummyQuitting.txt" | Select-Object -ExpandProperty Name | ForEach-Object { $_ -replace " - log.txt" }
		$list = @()
		foreach ( $script in $scripts )
		{
			if ( $logs -notcontains $script.Name )
			{
				$list += [pscustomobject]@{ Name = ( $script.Name -replace ".ps1" ); Count = ( $script.Count ) }
			}
		}
		$syncHash.DC.TopList[0] = $list | Sort-Object Name
		$syncHash.DC.btnNeverUsed[0] = $syncHash.msgTable.StrTopList
		WriteLog -LogText $syncHash.msgTable.StrLogNeverused | Out-Null
	}
	# List scripts never used
	else
	{
		$syncHash.DC.rbScript[1] = $true
		$syncHash.DC.rbUsers[1] = $true
		$syncHash.DC.rbScript[2] = $true
		$syncHash.DC.spSortBy[0] = [System.Windows.Visibility]::Visible
		$syncHash.DC.CountHeader[0] = $syncHash.msgTable.ContentCountHeader
		$syncHash.DC.btnNeverUsed[0] = $syncHash.msgTable.StrNeverUsed
	}
}

#####################################################
# Item in list is selected, show data for that object
function TopList_SelectionChanged
{
	if ( $syncHash.DC.btnNeverUsed[0] -eq $syncHash.msgTable.StrNeverUsed )
	{
		$syncHash.SubjectList.Children.Clear()
		if ( $null -ne $syncHash.DC.TopList[1] )
		{
			$itemClicked = $syncHash.DC.TopList[1]
			$list = @()

			if ( $syncHash.DC.rbScript[2] )
			{
				$syncHash.Users.Keys | Where-Object { ( $syncHash.Users.$_.Scripts | Get-Member -Name $itemClicked.Name ).Count -gt 0 } | ForEach-Object { $list += ,[pscustomobject]@{ Name = ( Get-ADUser $_ ).Name; Count = $syncHash.Users.$_.Scripts.$( $itemClicked.Name ) } }
				$t = "$( $syncHash.msgTable.StrMostUsedBy ) $( $itemClicked.Name )"
			}
			else
			{
				$syncHash.Users.$( $itemClicked.Name.Split("(")[1].Trim(")") ).Scripts | Get-Member -MemberType NoteProperty | ForEach-Object { $list += ,[pscustomobject]@{ Name = $_.Name; Count = [int]( ( $_.Definition -split "=" )[1] ) } }
				$t = "$( $syncHash.msgTable.StrScriptsMostUsedBy ) $( $itemClicked.Name )"
			}

			$syncHash.DC.ListTitle[0] = $t
			$list | Sort-Object -Descending Count | ForEach-Object `
			{
				$l = New-Object System.Windows.Controls.Label
				$l.Content = "($( $_.Count ))`t$( $_.Name )"
				$l.Margin = "20,0,20,0"
				$syncHash.SubjectList.AddChild( $l )
			}
		}
		else
		{
			$syncHash.DC.ListTitle[0] = $syncHash.msgTable.StrTitleScriptUsage
		}
	}
}

function SortByCount
{
	if ( $syncHash.DC.TopList[0][0].Count -gt $syncHash.DC.TopList[0][-1].Count )
	{ $syncHash.DC.TopList[0] = $syncHash.DC.TopList[0] | Sort-Object Count }
	else
	{ $syncHash.DC.TopList[0] = $syncHash.DC.TopList[0] | Sort-Object Count -Descending }
}

function SortByName
{
	$syncHash.DC.TopList[0] = $syncHash.DC.TopList[0] | Sort-Object Name
}

################################ Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -Argumentlist $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -Argumentlist $args[1]

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "rbUsers"
	Props = @(
		@{ PropName = "BorderBrush"; PropVal = "Black" }
		@{ PropName = "IsEnabled"; PropVal = $false }
		@{ PropName = "IsChecked"; PropVal = $false }
		@{ PropName = "Content"; PropVal = $msgTable.ContentrbUsers }
	) } )
[void]$controls.Add( @{ CName = "rbScript"
	Props = @(
		@{ PropName = "BorderBrush"; PropVal = "Black" }
		@{ PropName = "IsEnabled"; PropVal = $false }
		@{ PropName = "IsChecked"; PropVal = $false }
		@{ PropName = "Content"; PropVal = $msgTable.ContentrbScript }
	) } )
[void]$controls.Add( @{ CName = "TopList"
	Props = @(
		@{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) }
		@{ PropName = "SelectedItem"; PropVal = @() }
	) } )
[void]$controls.Add( @{ CName = "Window"
	Props = @(
		@{ PropName = "Title"; PropVal = $msgTable.StrTitleScriptUsage }
	) } )
[void]$controls.Add( @{ CName = "btnNeverUsed"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.StrNeverUsed }
	) } )
[void]$controls.Add( @{ CName = "lblSortBtns"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblSortBtns }
	) } )
[void]$controls.Add( @{ CName = "NameHeader"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentNameCol }
	) } )
[void]$controls.Add( @{ CName = "CountHeader"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentCountCol }
	) } )
[void]$controls.Add( @{ CName = "ListTitle"
	Props = @(
		@{ PropName = "Content"; PropVal = "" }
	) } )
[void]$controls.Add( @{ CName = "spSortBy"
	Props = @(
		@{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Visible }
	) } )

$syncHash = CreateWindowExt $controls
$syncHash.msgTable = $msgTable

$syncHash.Users = New-Object System.Collections.Hashtable
$syncHash.ScriptList = @()
$syncHash.Root = $args[0]
$syncHash.btnNeverUsed.Add_Click( { NeverUsedScripts } )
$syncHash.rbScript.Add_Checked( { $syncHash.DC.rbUsers[0] = "Red" ; $syncHash.DC.rbScript[0] = "Green" ; ListByScript } )
$syncHash.rbUsers.Add_Checked( { $syncHash.DC.rbUsers[0] = "Green" ; $syncHash.DC.rbScript[0] = "Red" ; ListByUser } )
$syncHash.TopList.Add_SelectionChanged( { TopList_SelectionChanged } )
$syncHash.CountHeader.Add_Click( { SortByCount } )
$syncHash.NameHeader.Add_Click( { SortByName } )
$syncHash.Window.Add_ContentRendered( { CollectData ; $this.Top = 20 } )

[void] $syncHash.Window.ShowDialog()
$syncHash.Window.Close()
#$global:syncHash = $syncHash