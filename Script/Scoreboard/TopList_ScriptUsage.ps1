<#
.Synopsis Scoreboard for scriptusage
.Description Lists which scripts have been used the most, and by whom. Or which users have used the scripts the most, and what scripts they used.
#>

###############################
# Collect scripts and usagedata
function CollectData
{
	$rbUsers.IsEnabled = $rbScript.IsEnabled = $true
	$logs = Get-ChildItem "$( ( Get-Item $PSCommandPath ).Directory.Parent.Parent.FullName )\Logs" -Exclude "DummyQuitting.txt" -File -Recurse

	foreach ( $log in $logs )
	{
		$logName = $log.BaseName -replace " - log"
		if ( $Script:scriptList -notcontains $logName )
		{
			$Script:scriptList += $logName
		}
		Get-Content $log | foreach `
		{
			if ( $_ -match "^\d{4}-\d{2}-\d{2}" )
			{
				$user = ( $_ -split " " )[2]
				if ( $Script:users.$user )
				{
					if ( $Script:users.$user.scripts.$logName )
					{
						$Script:users.$user.scripts.$logName++
					}
					else
					{
						$Script:users.$user.scripts | Add-Member -MemberType NoteProperty -Name $logName -Value 1
					}
					$Script:users.$user.usecount++
				}
				else
				{
					$Script:users.Add( $user, @{ usecount = 1; scripts = [pscustomobject]@{ $logName = 1 } } )
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
	foreach ( $script in $Script:scriptList )
	{
		$scriptUseCount = 0

		$Script:users.Keys | where { ( $Script:users.$_.scripts | Get-Member -Name $script ).Count -gt 0 } | foreach { $scriptUseCount += ( $Script:users.$_.scripts.$script ) }
		$list += ,[pscustomobject]@{ Name = $script; Count = $scriptUseCount }
	}
	$list | sort -Descending Count | foreach { $TopList.Items.Add( $_ ) }
	$Window.Title = "Most used scripts"
}

#################################
# Get users, and the scripts used
function ListByUser
{
	$TopList.Items.Clear()
	$list = @()
	$Script:users.Keys | foreach { $list += ,[pscustomobject]@{ Name = ( ( Get-ADUser $_ ).Name ); Count = $Script:users.$_.usecount } }
	$list | sort -Descending Count | foreach { $TopList.Items.Add( $_ ) }
	$Window.Title = "Toplist users"
}

########################################
# List scripts that have never been used
function NeverUsedScripts
{
	if ( $btnNeverUsed.Content -eq "Never used" )
	{
		$Toplist.Items.Clear()
		$scripts = Get-ChildItem "$Root\Script" -Filter "*ps1" -Exclude "SDGUI.ps1" -Recurse -File | select -ExpandProperty name | foreach { $_ -replace ".ps1" } | sort
		$logs = Get-ChildItem "$Root\Logs" -Filter "*txt" -Recurse -File | select -ExpandProperty name | foreach { $_ -replace " - log.txt" }
		foreach ( $script in $scripts )
		{
			if ( $logs -notcontains $script )
			{
				$TopList.Items.Add( [pscustomobject]@{ Name = $script; Count = 0 } )
			}
		}
		$btnNeverUsed.Content = "Toplist"
	}
	else
	{
		CollectData
		$btnNeverUsed.Content = "Never used"
	}
}

#####################################################
# Item in list is selected, show data for that object
function TopList_SelectionChanged
{
	$SubjectList.Children.Clear()
	if ( $toplist.selecteditems[0] -ne $null )
	{
		$itemClicked = $TopList.SelectedItems[0]
		$list = @()

		if ( $rbScript.IsChecked )
		{
			$users.Keys | where { ( $users.$_.scripts | Get-Member -Name $itemClicked.Name ).Count -gt 0 } | foreach { $list += ,[pscustomobject]@{ Name = ( Get-ADUser $_ ).Name; Count = $users.$_.scripts.$( $itemClicked.Name ) } }
			$t = "Most frequent user of $( $itemClicked.Name )"
		}
		else
		{
			$users.$( $itemClicked.Name.Split("(")[1].Trim(")") ).scripts | Get-Member -MemberType NoteProperty | foreach { $list += ,[pscustomobject]@{ Name = $_.Name; Count = [int]( ( $_.Definition -split "=" )[1] ) } }
			$t = "Most used scripts by $( $itemClicked.Name )"
		}

		$ListTitle.Content = $t
		$list | sort -Descending Count | foreach `
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

################################ Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$Window, $vars = CreateWindow
$vars | foreach { Set-Variable -Name $_ -Value $Window.FindName( $_ ) -Scope script }

$Script:WindowTitle = "Toplist delux"
$Script:users = New-Object System.Collections.Hashtable
$Script:scriptList = @()
$Script:Root = $args[0]
$btnNeverUsed.Add_Click( { NeverUsedScripts } )
$rbScript.Add_Checked( { ListByScript } )
$rbUsers.Add_Checked( { ListByUser } )
$TopList.Add_SelectionChanged( { TopList_SelectionChanged } )
$Window.Add_ContentRendered( { CollectData ; $rbScript.IsChecked = $true } )

[void] $Window.ShowDialog()
$Window.Close()
