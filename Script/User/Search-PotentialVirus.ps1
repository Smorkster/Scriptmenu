<#
.Synopsis Search for potential viruses [BO]
.Description Lists all files in folders a given user have accespermission to.
#>

###################################################################
# Checks if necessary values are given, if so enabled search-button
function CheckReady
{
	Reset
	$message = ""

	if ( -not ( ( $syncHash.DataContext[9] -match "RITM\d{7}" ) -or ( $syncHash.DataContext[9] -match "INC\d{7}" ) ) )
	{
		$message += "A valid casenumber must be given."
	}

	try
	{
		$a = Get-ADUser $syncHash.DataContext[10] -Properties HomeDirectory
		$syncHash.UserName = $a.Name
		$syncHash.UserHomeDirectory = $a.HomeDirectory
		$syncHash.UserSamAccountName = $a.SamAccountName
	} catch { $message += "`nNo useraccount found with given Id.`nEnter a valid Id and try again." }

	$logText = "$( $syncHash.DataContext[9] ) - $( $syncHash.DataContext[10] )"
	if ( $message -eq "" )
	{
		if ( $syncHash.DataContext[4] ) { $syncHash.DataContext[11] =  "Lists all files updated in the last two weeks, in folders the user have access to." }
		else { $syncHash.DataContext[11] =  "Lists all files, in folders the user have access to." }
		$syncHash.DataContext[15] = $syncHash.UserName
		$syncHash.DataContext[17] = [System.Windows.Visibility]::Visible
		$syncHash.logText = $logText
		GetFolders
	}
	else
	{
		ShowMessageBox -Text $message.Trim() -Icon "Stop"
		if ( $message -match "^A valid" ) { $syncHash.tbID.Focus() }
		else { $syncHash.tbCaseNr.Focus() }
		$logText += $message
		WriteToLog $logText
		$syncHash.Window.Resources.Enable = $true
	}
}

################################
# Get the folders and list files
function GetFolders
{
	return ( [powershell]::Create().AddScript( { param ( $syncHash )
		$syncHash.DataContext[5] = "Getting folders"
		$syncHash.Folders = New-Object System.Collections.ArrayList
		$syncHash.Folders.Add( @( $syncHash.UserHomeDirectory, "H:" ) )
		$GGroups = @()
		$pGroups = Get-ADPrincipalGroupMembership $syncHash.UserSamAccountName

		if ( $GaiaGroups = $pGroups | where { $_.SamAccountName -notlike "*_org_*" } | where { $_.SamAccountName -ne "Domain Users" } | select -ExpandProperty SamAccountName | sort )
		{
			$GaiaGroups | sort | foreach { $GGroups += ( Get-ADGroup $_ -Properties Description | select Name, Description ) }
		}
		if ( $OrgGroups = $pGroups | where { $_.SamAccountName -like "*_org_*" } | select -ExpandProperty SamAccountName | sort )
		{
			$OrgGroups | Get-ADPrincipalGroupMembership | sort | foreach { $GGroups += ( Get-ADGroup $_ -Properties Description | select Name, Description ) }
		}

		$syncHash.DataContext[5] = "Filters found folders"
		$syncHash.DataContext[6] = [System.Windows.Visibility]::Visible

		foreach ( $i in $GGroups )
		{
			if ( $i.Description -match "\\\\dfs\\gem" )
			{
				$p = ( ( ( $i.Description -split " on" )[1] -split "\." )[0].Trim() ).Replace("\\dfs\gem$","G:" )
				try
				{
					Get-ChildItem $p -ErrorAction Stop | Out-Null
					$syncHash.Folders.Add( @( $p, $i.Name ) )
				}
				catch
				{
					$syncHash.OtherFolderPermissions.Add( $i.Name )
				}
			}
			elseif ( $i.Description -match "\\\\dfs\\app" )
			{
				$syncHash.OtherFolderPermissions.Add( $i.Name )
			}
		}

		$syncHash.DataContext[0] = 0.0
		$syncHash.DataContext[5] = "Starts fetching files"

		if ( $syncHash.DataContext[4] )
		{
			$jobs = New-Object System.Collections.ArrayList
			foreach ( $Folder in $syncHash.Folders )
			{
				$p = [powershell]::Create().AddScript( { param ( $syncHash, $Folder )
					if ( $syncHash.DataContext[4] ) { $date = ( Get-Date ).AddDays( -14 ) } else { $date = [datetime]::MinValue }
					Get-ChildItem2 $Folder[0] -File -Recurse | where { $_.LastWriteTime -ge $date } | select -Property `
						@{ Name = "Name"; Expression = { $_.FullName.Replace( $Folder[0], ".." ) } }, `
						@{ Name = "Created"; Expression = { ( Get-Date $_.CreationTime -f "yyyy-MM-dd hh:mm:ss" ) } }, `
						@{ Name = "FileType"; Expression = { $ft = $_.Extension.Replace( ".", "" ); foreach ( $f in $syncHash.fileFilter ) { if ( $_.Extension -match $f ) { $ft = "Files matching filter" } } ; $ft } }, `
						@{ Name = "TT"; Expression = { $_.FullName } }, `
						@{ Name = "Updated"; Expression = { ( Get-Date $_.LastWriteTime -f "yyyy-MM-dd hh:mm:ss" ) } } | select -Property `
						Name, `
						Created, `
						FileType, `
						TT, `
						Updated, `
						@{ Name = "SortOrder"; Expression = { if ( $_.FileType -eq "Files matching filter" ) { return 0 } ; return 1 } } | foreach { $syncHash.Data[0].Add( $_ ) }
						$syncHash.DataContext[16] = $syncHash.Data[0].Count
				} ).AddArgument( $syncHash ).AddArgument( $Folder )
				$jobs.Add( [pscustomobject]@{ PS = $p; Handle = $p.BeginInvoke() } )
			}

			$syncHash.DataContext[5] = "Waiting for filefetching"
			do {
				$c = ( $jobs.Handle.IsCompleted -eq $true ).Count
				$syncHash.DataContext[0] = [double] ( ( $c / $jobs.Count ) * 100 )
				Start-Sleep 1
			} until ( $c -eq $jobs.Count )
			$jobs | foreach { $_.PS.Runspace.Close() ; $_.PS.Runspace.Dispose() }
			Remove-Variable jobs
		}
		else
		{
			$ticker = 1
			foreach ( $Folder in $syncHash.Folders )
			{
				$syncHash.DataContext[5] = "Fetching files in '$( $Folder[0] )'"
				if ( $syncHash.DataContext[4] ) { $date = ( Get-Date ).AddDays( -14 ) } else { $date = [datetime]::MinValue }
				Get-ChildItem2 $Folder[0] -File -Recurse | where { $_.LastWriteTime -ge $date } | select -Property `
					@{ Name = "Name"; Expression = { $_.FullName.Replace( $Folder[0], ".." ) } }, `
					@{ Name = "Created"; Expression = { ( Get-Date $_.CreationTime -f "yyyy-MM-dd hh:mm:ss" ) } }, `
					@{ Name = "FileType"; Expression = { $ft = $_.Extension.Replace( ".", "" ); foreach ( $f in $syncHash.fileFilter ) { if ( $_.Extension -match $f ) { $ft = "Files matching filter" } } ; $ft } }, `
					@{ Name = "TT"; Expression = { $_.FullName } }, `
					@{ Name = "Updated"; Expression = { ( Get-Date $_.LastWriteTime -f "yyyy-MM-dd hh:mm:ss" ) } } | select -Property `
					Name, `
					Created, `
					FileType, `
					TT, `
					Updated, `
					@{ Name = "SortOrder"; Expression = { if ( $_.FileType -eq "Files matching filter" ) { return 0 } ; return 1 } } | foreach { $syncHash.Data[0].Add( $_ ) }
				$syncHash.DataContext[16] = $syncHash.Data[0].Count
				$syncHash.DataContext[0] = [double] ( ( $ticker / $jobs.Count ) * 100 )
				$ticker++
			}
		}

		$List = [System.Windows.Data.ListCollectionView]$syncHash.Data[0]
		$List2 = [System.Windows.Data.ListCollectionView]( $syncHash.Data[0] | where { $_.TT -match $syncHash.UserSamAccountName } | where { ( ( $_.Name.Split( "\" ) | select -Last 1 ).Split( "." ) ).Count -gt 2 } )
		$List3 = [System.Windows.Data.ListCollectionView]( $syncHash.Data[0] | where { $_.TT -match "^G:\\" } | where { ( ( $_.Name.Split( "\" ) | select -Last 1 ).Split( "." ) ).Count -gt 2 } )

		$sort1 = New-Object System.ComponentModel.SortDescription
		$sort2 = New-Object System.ComponentModel.SortDescription
		$sort3 = New-Object System.ComponentModel.SortDescription
		$groupBy = New-Object System.Windows.Data.PropertyGroupDescription "FileType"

		$sort1.Direction = "Ascending"
		$sort1.PropertyName = "SortOrder"
		$sort2.Direction = "Ascending"
		$sort2.PropertyName = "FileType"
		$sort3.Direction = "Ascending"
		$sort3.PropertyName = "Name"

		$List.GroupDescriptions.Add( $groupBy )
		$List.SortDescriptions.Add( $sort1 )
		$List.SortDescriptions.Add( $sort2 )
		$List.SortDescriptions.Add( $sort3 )
		$syncHash.DataContext[1] = $List

		$List2.GroupDescriptions.Add( $groupBy )
		$List2.SortDescriptions.Add( $sort1 )
		$List2.SortDescriptions.Add( $sort2 )
		$List2.SortDescriptions.Add( $sort3 )
		$syncHash.DataContext[2] = $List2

		$List3.GroupDescriptions.Add( $groupBy )
		$List3.SortDescriptions.Add( $sort1 )
		$List3.SortDescriptions.Add( $sort2 )
		$List3.SortDescriptions.Add( $sort3 )
		$syncHash.DataContext[3] = $List3

		if ( $syncHash.DataContext[1].GetItemAt( 0 ).SortOrder -eq 0 ) { $ofs = ", "; $syncHash.DataContext[11] += "`nSome files matches filers:`n$( [string]$syncHash.fileFilter )" }

		$syncHash.DataContext[5] = ""
		$syncHash.DataContext[6] = [System.Windows.Visibility]::Hidden

		$output = @( "**********`r`nSearching for potential virus:`r`n`r`nUser: $( $syncHash.UserName )`r`nCasenumber: $( $syncHash.DataContext[9] )`r`nSearching: $( if ( $syncHash.DataContext[4] ) { "Files updated in the last two weeks" } else { "All availble files" } )`r`nTotal number of files: $( $syncHash.Data[0].Count )`r`n**********`r`n" )
		$output += ,"*****************`r`nFolders searched:`r`n*****************"
		$output += ( $syncHash.Folders | foreach { "$( $_[0] ) ( $( $_[1] ) )" } )
		$output += "`r`n***********`r`nAll found files:`r`n***********"
		$output += ( $syncHash.DataContext[1].TT | sort )
		$output += ,"`r`n`r`n***********************`r`nMultiple fileextensions in homefolder:`r`n***********************"
		$output += $syncHash.DataContext[2].TT
		$output += ,"`r`n`r`n***********************`r`nMultiple fileextensions in common folders:`r`n***********************"
		$output += $syncHash.DataContext[3].TT
		$output += ,"`r`n*****************`r`nMission permissions for:`r`n*****************"
		$split = $syncHash.DataContext[7].Split( "`n" )
		$output += ( $split[4..$( $split.Count - 1 )] )
		$syncHash.OutputContent.Item( 0 ) = $output

		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.Window.Resources.Enable = $true } )
		$syncHash.DataContext[9] = $syncHash.DataContext[10] = ""
	} ).AddArgument( $syncHash ) ).BeginInvoke()
}

#########################
# Opens the folder a file
function OpenFileFolder
{
	explorer ( Get-Item ( [pscustomobject] $syncHash.menuOpenfolder.DataContext ).TT ).Directory.FullName
}

########################################
# Search on Google for the fileextension
function SearchExtension
{
	start chrome "https://www.google.com/search?q=fileextension+$( ( [pscustomobject] $syncHash.menuSearchExtension.DataContext ).FileType )"
}

###################################
# Search on Google for the filename
function SearchFileName
{
	start chrome "https://www.google.com/search?q=$( ( [pscustomobject] $syncHash.menuSearchFileName.DataContext ).Name.Split( "\" ) | select -Last 1 )"
}

####################
# Reset all controls
function Reset
{
	$syncHash.Folders = $null
	$syncHash.Data[0].Clear()
	$syncHash.DataContext[1].Clear()
	$syncHash.DataContext[2].Clear()
	$syncHash.DataContext[3].Clear()
	$syncHash.DataContext[7] = ""
	$syncHash.OutputContent.Item( 0 ) = ""
	$syncHash.OtherFolderPermissions.Clear()
	$syncHash.DataContext[20] = [System.Windows.Visibility]::Hidden
	$syncHash.DataContext[17] = [System.Windows.Visibility]::Hidden
}

################################################
# Columnheader is clicked, resort listview-items
# Grouping is unchanged
function Resort
{
	param ( $index, $sortBy )

	$List = [System.Windows.Data.ListCollectionView]( $syncHash.DataContext[$index] | sort $sortBy )

	$sort1 = New-Object System.ComponentModel.SortDescription
	$sort2 = New-Object System.ComponentModel.SortDescription
	$sort3 = New-Object System.ComponentModel.SortDescription
	$groupBy = New-Object System.Windows.Data.PropertyGroupDescription "FileType"

	$sort1.Direction = "Ascending"
	$sort1.PropertyName = "SortOrder"
	$sort2.Direction = "Ascending"
	$sort2.PropertyName = "FileType"
	$sort3.Direction = "Ascending"
	$sort3.PropertyName = $sortBy

	$List.GroupDescriptions.Add( $groupBy )
	$List.SortDescriptions.Add( $sort1 )
	$List.SortDescriptions.Add( $sort2 )
	$List.SortDescriptions.Add( $sort3 )
	$syncHash.DataContext[$index] = $List
}

##############
# Write to log
function WriteToLog
{
	param ( $Text )
	WriteLog -LogText $Text
}

####################### Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$syncHash = [hashtable]::Synchronized( @{} )
$syncHash.Window, $vars = CreateWindow
$vars | foreach { $syncHash.$_ = $syncHash.Window.FindName( $_ ) }

$syncHash.Data = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$syncHash.Data.Add( ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) ) # All files

$syncHash.OtherFolderPermissions = New-Object System.Collections.ObjectModel.ObservableCollection[string]
$syncHash.OtherFolderPermissions.Add_CollectionChanged( {
	if ( $syncHash.OtherFolderPermissions.Count -gt 0 )
	{
		$ofs = "`n"
		$syncHash.DataContext[7] = "$( $syncHash.UserName ) have reported about a potential virus in case $( $syncHash.DataContext[9] ).`r`nHome- and common folders have been checked, but we lack permission for the following folders.`r`nCan you help in the investigation of these?`r`n`r`n$( [string]( $syncHash.OtherFolderPermissions | select -Unique | sort ) )"
		$syncHash.DataContext[8] = [System.Windows.Visibility]::Visible
	}
} )

$syncHash.OutputContent = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$syncHash.OutputContent.Add( "" )
$syncHash.OutputContent.Add_CollectionChanged( {
	if ( $syncHash.OutputContent.Item( 0 ) -ne "" )
	{
		$syncHash.DataContext[19] = WriteOutput -Output $syncHash.OutputContent.Item( 0 )
		$syncHash.DataContext[20] = [System.Windows.Visibility]::Visible
		$syncHash.DataContext[18] = $syncHash.DataContext[19]
		WriteToLog "$( $syncHash.logText )`r`n`tOutput: $( $syncHash.DataContext[19] )"
	}
} )

$syncHash.DataContext = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$syncHash.DataContext.Add( 0.0 ) # 0 TotalProgress
$syncHash.DataContext.Add( ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) ) # 1 All files
$syncHash.DataContext.Add( ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) ) # 2 MultiDots in H
$syncHash.DataContext.Add( ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) ) # 3 MultiDots in G
$syncHash.DataContext.Add( $true ) # 4 cbLatest
$syncHash.DataContext.Add( "" ) # 5 Window-title
$syncHash.DataContext.Add( [System.Windows.Visibility]::Hidden ) # 6 TotalProgress-visibility
$syncHash.DataContext.Add( "" ) # 7 Question-textbox content
$syncHash.DataContext.Add( [System.Windows.Visibility]::Hidden ) # 8 QuestionTab-visibility
$syncHash.DataContext.Add( "" ) # 9 tbCaseNr-Text
$syncHash.DataContext.Add( "" ) # 10 tbID-Text
$syncHash.DataContext.Add( "" ) # 11 lblFiles-Text
$syncHash.DataContext.Add( "All files" ) # 12 tiFiles header
$syncHash.DataContext.Add( "Multiple fileextensions in homefolder" ) # 13 tiMDH header
$syncHash.DataContext.Add( "Multiple fileextensions in common folders" ) # 14 tiMDG header
$syncHash.DataContext.Add( "" ) # 15 lblUser
$syncHash.DataContext.Add( "" ) # 16 lblFileCount
$syncHash.DataContext.Add( [System.Windows.Visibility]::Hidden ) # 17 spInfo-visibility
$syncHash.DataContext.Add( "" ) # 18 lblSummary
$syncHash.DataContext.Add( "" ) # 19 btnOpenSummary-Tag
$syncHash.DataContext.Add( [System.Windows.Visibility]::Hidden ) # 20 spSummary-Tag

$Bindings = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
0..( $syncHash.DataContext.Count - 1 ) | foreach { [void]$Bindings.Add( ( New-Object System.Windows.Data.Binding -ArgumentList "[$_]" ) ) }
$Bindings | foreach { $_.Mode = [System.Windows.Data.BindingMode]::TwoWay }
$syncHash.Window.DataContext = $syncHash.DataContext

[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.TotalProgress, 	[System.Windows.Controls.ProgressBar]::ValueProperty, 			$Bindings[0] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.lvAllFiles, 		[System.Windows.Controls.ListView]::ItemsSourceProperty, 		$Bindings[1] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.lvMultiDotsH, 		[System.Windows.Controls.ListView]::ItemsSourceProperty, 		$Bindings[2] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.lvMultiDotsG, 		[System.Windows.Controls.ListView]::ItemsSourceProperty, 		$Bindings[3] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.cbLatest, 			[System.Windows.Controls.CheckBox]::IsCheckedProperty, 			$Bindings[4] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.Window, 			[System.Windows.Window]::TitleProperty, 						$Bindings[5] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.TotalProgress, 	[System.Windows.Controls.ProgressBar]::VisibilityProperty, 		$Bindings[6] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.txtQuestion, 		[System.Windows.Controls.TextBox]::TextProperty, 				$Bindings[7] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.tiO, 				[System.Windows.Controls.TabItem]::VisibilityProperty, 			$Bindings[8] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.tbCaseNr, 			[System.Windows.Controls.TextBox]::TextProperty, 				$Bindings[9] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.tbID, 				[System.Windows.Controls.TextBox]::TextProperty, 				$Bindings[10] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.lblFiles, 			[System.Windows.Controls.Label]::ContentProperty, 				$Bindings[11] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.tiFiles, 			[System.Windows.Controls.TabItem]::HeaderProperty, 				$Bindings[12] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.tiMDH, 			[System.Windows.Controls.TabItem]::HeaderProperty, 				$Bindings[13] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.tiMDG, 			[System.Windows.Controls.TabItem]::HeaderProperty, 				$Bindings[14] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.lblUser, 			[System.Windows.Controls.Label]::ContentProperty, 				$Bindings[15] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.lblFileCount, 		[System.Windows.Controls.Label]::ContentProperty, 				$Bindings[16] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.spInfo, 			[System.Windows.Controls.StackPanel]::VisibilityProperty, 		$Bindings[17] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.lblSummary, 		[System.Windows.Controls.Label]::ContentProperty, 				$Bindings[18] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.btnOpenSummary, 	[System.Windows.Controls.Button]::TagProperty, 					$Bindings[19] )
[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.spSummary, 		[System.Windows.Controls.StackPanel]::VisibilityProperty, 		$Bindings[20] )

WriteToLog "Start"

$syncHash.ScriptVar = New-Object -ComObject WScript.Shell
$syncHash.fileFilter = @( ".MYD", ".MYI", "encrypted", "vvv", ".mp3", ".exe", "Anydesk", "FileSendsuite", "Recipesearch", "FromDocToPDF", "dll" )

$syncHash.btnCreateQuestion.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$syncHash.DataContext[7] | clip
	ShowMessageBox "Question haven copied to clipboard"
	WriteToLog "Copied"
} )
$syncHash.btnOpenSummary.Add_Click( { & 'C:\Program Files (x86)\Notepad++\notepad++.exe' $this.Tag } )
$syncHash.btnSearch.Add_Click( { $syncHash.Window.Resources.Enable = $false; CheckReady } )
$syncHash.lvAN.Add_Click( { Resort 1 "Name" } )
$syncHash.lvAC.Add_Click( { Resort 1 "Created" } )
$syncHash.lvAU.Add_Click( { Resort 1 "Updated" } )
$syncHash.lvHN.Add_Click( { Resort 2 "Name" } )
$syncHash.lvHC.Add_Click( { Resort 2 "Created" } )
$syncHash.lvHU.Add_Click( { Resort 2 "Updated" } )
$syncHash.lvGN.Add_Click( { Resort 3 "Name" } )
$syncHash.lvGC.Add_Click( { Resort 3 "Created" } )
$syncHash.lvGU.Add_Click( { Resort 3 "Updated" } )
$syncHash.menuOpenfolder.Add_Click( { OpenFileFolder } )
$syncHash.menuSearchExtension.Add_Click( { SearchExtension } )
$syncHash.menuSearchFileName.Add_Click( { SearchFileName } )
$syncHash.TotalProgress.Add_IsVisibleChanged( { if ( $this.Visibility -eq "Hidden" ) { $syncHash.Window.Resources.Enable = $true } } )
$syncHash.txtQuestion.Add_TextChanged( {
	if ( $this.LineCount -gt 4 ) { $syncHash.tiO.Header = "Folders with other permissions ($( $this.LineCount - 4 ))" }
	else { $syncHash.tiO.Header = "Folders with other permissions" }
 } )
$syncHash.Window.Add_Loaded( {
	$syncHash.Window.Activate()
	$syncHash.tbCaseNr.Focus()
} )

[void] $syncHash.Window.ShowDialog()
$global:g = $syncHash
[System.GC]::Collect()
