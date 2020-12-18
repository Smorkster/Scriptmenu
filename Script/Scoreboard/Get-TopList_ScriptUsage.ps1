<#
.Synopsis Scoreboard for scriptusage
.Description Lists which scripts have been used the most, and by whom. Or which users have used the scripts the most, and what scripts they used.
#>

###############################
# Collect scripts and usagedata
function CollectData
{
	$Window.Title = "Reading logs..."
	$rbUsers.IsEnabled = $rbScript.IsEnabled = $true
	$logs = Get-ChildItem "$( ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName )\Logs" -Exclude "DummyQuitting.txt" -File -Recurse

	foreach ( $log in $logs )
	{
		$logName = $log.BaseName -replace " - log"
		if ( $Script:ScriptList -notcontains $logName )
		{
			$Script:ScriptList += $logName
		}
		Get-Content $log | ForEach-Object `
		{
			if ( $_ -match "^\d{4}-\d{2}-\d{2}" )
			{
				$user = ( $_ -split " " )[2].ToLower()

				if ( $Users.Keys -match $user )
				{
					if ( $Users.$user.Scripts.$logName )
					{
						$Users.$user.Scripts.$logName++
					}
					else
					{
						Add-Member -InputObject $Users.$user.Scripts -MemberType NoteProperty -Name $logName -Value 1
					}
					$Users.$user.TotalUseCount++
				}
				else
				{
					$Users.Add( $user , @{ TotalUseCount = 1; Scripts = [pscustomobject]@{ $logName = 1 }; Name = ( Get-ADUser $user ).Name } )
				}
			}
		}
	}
}

##################################################
# Get scriptList, number of uses, and its topusers
function ListByScript
{
	$TopList.Items.Clear()
	$list = @()
	foreach ( $script in $ScriptList )
	{
		$scriptTotalUseCount = 0

		$Users.Keys | Where-Object { ( $Users.$_.Scripts | Get-Member -Name $script ).Count -gt 0 } | ForEach-Object { $scriptTotalUseCount += ( $Users.$_.Scripts.$script ) }
		$list += ,[pscustomobject]@{ Name = $script; Count = $scriptTotalUseCount }
	}
	$list | Sort-Object -Descending Count | ForEach-Object { $TopList.Items.Add( $_ ) }
	$Window.Title = "Most used scripts"
}

#################################
# Get users, and the scripts used
function ListByUser
{
	$TopList.Items.Clear()
	$list = @()
	$Users.GetEnumerator() | ForEach-Object { $list += ,[pscustomobject]@{ Name = ( $_.Value.Name ); Count = $_.Value.TotalUseCount } }
	$list | Sort-Object -Descending Count | ForEach-Object { $TopList.Items.Add( $_ ) }
	$Window.Title = "Toplist users"
}

########################################
# List scripts that have never been used
function NeverUsedScripts
{
	if ( $btnNeverUsed.Content -eq "Never used" )
	{
		$CountHeader.Content = "Created"
		$rbScript.IsChecked = $false
		$rbUsers.IsChecked = $false
		$Toplist.Items.Clear()
		$scripts = Get-ChildItem "$Root\Script" -Filter "*ps1" -Exclude "SDGUI.ps1" -Recurse -File | Sort-Object Name
		$logs = Get-ChildItem "$Root\Logs" -Filter "*txt" -Recurse -File | Select-Object -ExpandProperty name | ForEach-Object { $_ -replace " - log.txt" }
		foreach ( $script in $scripts )
		{
			if ( $logs -notcontains $script.Name )
			{
				$TopList.Items.Add( [pscustomobject]@{ Name = ( $script.Name -replace ".ps1" ); Count = ( $script.CreationTime.ToShortDateString() ) } )
			}
		}
		$btnNeverUsed.Content = "Toplist"
		WriteLog -LogText "Check for never used"
	}
	else
	{
		$rbScript.IsChecked = $true
		$CountHeader.Content = "Number"
		$btnNeverUsed.Content = "Never used"
	}
}

#####################################################
# Item in list is selected, show data for that object
function TopList_SelectionChanged
{
	if ( $btnNeverUsed.Content -eq "Never used" )
	{
		$SubjectList.Children.Clear()
		if ( $null -ne $toplist.SelectedItems[0] )
		{
			$itemClicked = $TopList.SelectedItems[0]
			$list = @()

			if ( $rbScript.IsChecked )
			{
				$users.Keys | Where-Object { ( $users.$_.Scripts | Get-Member -Name $itemClicked.Name ).Count -gt 0 } | ForEach-Object { $list += ,[pscustomobject]@{ Name = ( Get-ADUser $_ ).Name; Count = $users.$_.Scripts.$( $itemClicked.Name ) } }
				$t = "Most frequent user of $( $itemClicked.Name )"
			}
			else
			{
				$Users.$( $itemClicked.Name.Split("(")[1].Trim(")") ).Scripts | Get-Member -MemberType NoteProperty | ForEach-Object { $list += ,[pscustomobject]@{ Name = $_.Name; Count = [int]( ( $_.Definition -split "=" )[1] ) } }
				$t = "Most used scripts by $( $itemClicked.Name )"
			}

			$ListTitle.Content = $t
			$list | Sort-Object -Descending Count | ForEach-Object `
			{
				$l = New-Object System.Windows.Controls.Label
				$l.Content = "($( $_.Count ))`t$( $_.Name )"
				$l.Margin = "20,0,20,0"
				$SubjectList.AddChild( $l )
			}
		}
		else
		{
			$ListTitle.Content = "Toplist scriptusage"
		}
	}
}

################################ Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$Window, $vars = CreateWindow
$vars | ForEach-Object { Set-Variable -Name $_ -Value $Window.FindName( $_ ) -Scope script }

$Script:Users = New-Object System.Collections.Hashtable
$Script:ScriptList = @()
$Script:Root = $args[0]
$btnNeverUsed.Add_Click( { NeverUsedScripts } )
$rbScript.Add_Checked( { ListByScript } )
$rbUsers.Add_Checked( { ListByUser } )
$TopList.Add_SelectionChanged( { TopList_SelectionChanged } )
$Window.Add_ContentRendered( { CollectData ; $rbScript.IsChecked = $true } )

[void] $Window.ShowDialog()
$Window.Close()
