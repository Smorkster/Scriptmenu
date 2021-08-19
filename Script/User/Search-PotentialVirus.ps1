<#
.Synopsis Search for potential viruses [BO]
.Requires Role_Servicedesk_Backoffice
.Description Lists all files in folders a given user have accespermission to.
.Author Smorkster (smorkster)
#>

###################################################################
# Checks if necessary values are given, if so enabled search-button
function CheckReady
{
	$message = ""

	if ( -not ( ( $syncHash.DC.tbCaseNr[0] -match "RITM\d{7}" ) -or ( $syncHash.DC.tbCaseNr[0] -match "INC\d{7}" ) ) )
	{
		$message += $syncHash.Data.msgTable.ErrInvalidCaseNr
	}

	try
	{
		$a = Get-ADUser $syncHash.DC.tbID[0] -Properties HomeDirectory
		$syncHash.User = [pscustomobject]@{
			Name = $a.Name
			HomeDirectory = $a.HomeDirectory
			SamAccountName = $a.SamAccountName
			Enabled = $a.Enabled
		}
	}
	catch
	{
		WriteErrorLog -LogText $_
		$message += "`n$( $syncHash.Data.msgTable.ErrInvalidID )"
	}

	$logText = "$( $syncHash.DC.tbCaseNr[0] ) - $( $syncHash.DC.tbID[0] )"
	if ( $message -eq "" )
	{
		if ( $syncHash.DC.rbLatest[0] ) { $syncHash.DC.lblFiles[0] = $syncHash.Data.msgTable.ContentLblFiles2W }
		else { $syncHash.DC.lblFiles[0] = $syncHash.Data.msgTable.ContentLblFiles }
		$syncHash.DC.spInput[0] = $false
		$syncHash.DC.lblUser[0] = $syncHash.User.Name
		$syncHash.gbInfo.Visibility = [System.Windows.Visibility]::Visible
		$syncHash.logText = $logText
		return $true
	}
	else
	{
		ShowMessageBox -Text $message.Trim() -Icon "Stop" | Out-Null
		if ( $message -match $syncHash.Data.msgTable.ErrInvalidID ) { $syncHash.tbID.Focus() | Out-Null }
		else { $syncHash.tbCaseNr.Focus() | Out-Null }
		$logText += $message
		WriteLog -LogText $logText | Out-Null
		return $false
	}
}

################################
# Get the folders and list files
function GetFolders
{
	( [powershell]::Create().AddScript( { param ( $syncHash )
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOPGettingFolders
		if ( $syncHash.User.Enabled ) { $syncHash.Data.Folders.Add( [pscustomobject]@{ "Path" = $syncHash.User.HomeDirectory; "Name" = "H:" } ) }
		$syncHash.Data.GGroups = @()
		$syncHash.Data.pGroups = Get-ADPrincipalGroupMembership $syncHash.User.SamAccountName | Where-Object { $_.SamAccountName -notmatch "_R$" }

		if ( $ADGroups = $syncHash.Data.pGroups | Where-Object { $_.SamAccountName -notlike "*_org_*" -and $_.SamAccountName -ne "Domain Users" -and $_.SamAccountName -notmatch "_R$" } | Select-Object -ExpandProperty SamAccountName | Sort-Object )
		{
			$ADGroups | Sort-Object | ForEach-Object { $syncHash.Data.GGroups += ( Get-ADGroup $_ -Properties Description | Select-Object Name, Description ) }
		}
		if ( $OrgGroups = $syncHash.Data.pGroups | Where-Object { $_.SamAccountName -like "*_org_*" } | Select-Object -ExpandProperty SamAccountName | Sort-Object )
		{
			$OrgGroups | Get-ADPrincipalGroupMembership | Where-Object { $_.Name -notmatch "_R$" } | Sort-Object | ForEach-Object { $syncHash.Data.GGroups += ( Get-ADGroup $_ -Properties Description | Select-Object Name, Description ) }
		}

		# Filter folders
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOPFilteringFolders
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.TotalProgress.Visibility = [System.Windows.Visibility]::Visible } )

		for ( $syncHash.ticker = 0; $syncHash.ticker -lt ( $syncHash.Data.GGroups | Where-Object { $_.Name -notmatch "_R$" } ).Count; $syncHash.ticker += 1 )
		{
			$i = $syncHash.Data.GGroups[$syncHash.ticker]
			if ( $i.Description -match "\\\\dfs\\gem" )
			{
				$p = ( ( $i.Description -split " $( $syncHash.Data.msgTable.StrDescSplit ) " )[1] -split "\." )[0].Replace( "\\dfs\gem$", "G:" )
				try
				{
					Get-ChildItem $p -ErrorAction Stop | Out-Null
					if ( -not ( $syncHash.Data.Folders.Name -match $i.Name ) )
					{ [void] $syncHash.Data.Folders.Add( [pscustomobject]@{ "Path" = $p; "Name" = $i.Name } ) }
				}
				catch
				{
					# No permission for scriptuser
					[void] $syncHash.OtherFolderPermissions.Add( $i.Name )
				}
			}
			elseif ( $i.Description -match "\\\\dfs\\app" )
			{
				[void] $syncHash.OtherFolderPermissions.Add( $i.Name )
			}
			#$syncHash.ticker++
			$syncHash.DC.TotalProgress[0] = [double]( ( ( $syncHash.ticker + 1 ) / ( $syncHash.Data.GGroups | Where-Object { $_.Name -notmatch "_R$" } ).Count ) * 100 )
		}

		$syncHash.DC.lblFolderCount[0] = $syncHash.Data.Folders.Count
		$syncHash.DC.TotalProgress[0] = 0.0
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOPGettingFiles

		$syncHash.Jobs = New-Object System.Collections.ArrayList

		foreach ( $Folder in $syncHash.Data.Folders )
		{
			$p = [powershell]::Create().AddScript( { param ( $syncHash, $Folder )
				$files = Get-ChildItem2 $Folder.Path -File -Recurse | `
					Where-Object { $_.LastWriteTime -ge $syncHash.DC.DatePickerStart[1] } | `
					Select-Object -Property "Name", `
						@{ Name = "Created"; Expression = { ( Get-Date $_.CreationTime -f "yyyy-MM-dd hh:mm:ss" ) } }, `
						@{ Name = "FileType"; Expression = {
								if ( [string]::IsNullOrEmpty( $_.Extension ) ) { $syncHash.Data.msgTable.StrNoExtension }
								else { $_.Extension.ToLower() } } }, `
						@{ Name = "FilterMatch"; Expression = {
							$n = $_.Name
							if ( $syncHash.fileFilter.ForEach( { $n -match $_ } ) -eq $true ) { $true }
							else { $false } } }, `
						@{ Name = "TT"; Expression = {
							if ( $_.FullName.StartsWith( $syncHash.User.HomeDirectory ) ) { $_.FullName.Replace( $syncHash.User.HomeDirectory , "H:" ) }
							else { $_.FullName } } }, `
						@{ Name = "Updated"; Expression = { ( Get-Date $_.LastWriteTime -f "yyyy-MM-dd hh:mm:ss" ) } }
				$syncHash.Data.FullFileList.AddRange( $files )

				$syncHash.DC.lblFileCount[0] = $syncHash.Data.FullFileList.Count
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.TotalProgress[0] = [double] ( ( ( ( $syncHash.Jobs.Handle.IsCompleted -eq $true ).Count + 1 ) / $syncHash.Jobs.Count ) * 100 ) } )
			} ).AddArgument( $syncHash ).AddArgument( $Folder )
			[void] $syncHash.Jobs.Add( [pscustomobject]@{ PS = $p; Handle = $p.BeginInvoke() } )
		}

		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOPWaitGettingFiles
	} ).AddArgument( $syncHash ) ).BeginInvoke()
}

#######################
# Display all the files
function ListFiles
{
	if ( $syncHash.Data.FullFileList.Count -gt 0 )
	{
		# Set how items in listviews are to be grouped and sorted
		$groupBy = [System.Windows.Data.PropertyGroupDescription]::new( "FileType" )
		$sort1 = [System.ComponentModel.SortDescription]@{ Direction = "Ascending"; PropertyName = "FileType" }
		$sort2 = [System.ComponentModel.SortDescription]@{ Direction = "Ascending"; PropertyName = "Name" }

		if ( $syncHash.Data.FullFileList.Count -gt 0 )
		{
			$syncHash.Data.ListAllFiles = [System.Windows.Data.ListCollectionView]@( $syncHash.Data.FullFileList.ForEach( { $_ } ) )

			$syncHash.Data.ListAllFiles.GroupDescriptions.Add( $groupBy )
			$syncHash.Data.ListAllFiles.SortDescriptions.Add( $sort1 )
			$syncHash.Data.ListAllFiles.SortDescriptions.Add( $sort2 )
			$syncHash.DC.lvAllFiles[0] = $syncHash.Data.ListAllFiles

			$ListFilterMatched = [System.Windows.Data.ListCollectionView]@( $syncHash.Data.FullFileList | Where-Object { $_.FilterMatch -eq $true } )
			if ( $ListFilterMatched.Count -gt 0 )
			{
				$syncHash.tiFilterMatch.Visibility = [System.Windows.Visibility]::Visible
				$ListFilterMatched.GroupDescriptions.Add( $groupBy )
				$ListFilterMatched.SortDescriptions.Add( $sort1 )
				$ListFilterMatched.SortDescriptions.Add( $sort2 )
				$syncHash.DC.lvFilterMatch[0] = $ListFilterMatched
			}
			else { $syncHash.tiFilterMatch.Visibility = [System.Windows.Visibility]::Collapsed }

			$ListMultiDotH = [System.Windows.Data.ListCollectionView]@( $syncHash.Data.FullFileList | Where-Object { $_.TT -match "^H:\\" } | Where-Object { ( ( $_.Name.Split( "\" ) | Select-Object -Last 1 ).Split( "." ) ).Count -gt 2 } )
			if ( $ListMultiDotH.Count -gt 0 )
			{
				$syncHash.tiMDH.Visibility = [System.Windows.Visibility]::Visible
				$ListMultiDotH.GroupDescriptions.Add( $groupBy )
				$ListMultiDotH.SortDescriptions.Add( $sort1 )
				$ListMultiDotH.SortDescriptions.Add( $sort2 )
				$syncHash.DC.lvMultiDotsH[0] = $ListMultiDotH
			}
			else { $syncHash.tiMDH.Visibility = [System.Windows.Visibility]::Collapsed }

			$ListMultiDotG = [System.Windows.Data.ListCollectionView]@( $syncHash.Data.FullFileList | Where-Object { $_.TT -match "^G:\\" } | Where-Object { ( ( $_.Name.Split( "\" ) | Select-Object -Last 1 ).Split( "." ) ).Count -gt 2 } )
			if ( $ListMultiDotG.Count -gt 0 )
			{
				$syncHash.tiMDG.Visibility = [System.Windows.Visibility]::Visible
				$ListMultiDotG.GroupDescriptions.Add( $groupBy )
				$ListMultiDotG.SortDescriptions.Add( $sort1 )
				$ListMultiDotG.SortDescriptions.Add( $sort2 )
				$syncHash.DC.lvMultiDotsG[0] = $ListMultiDotG
			}
			else { $syncHash.tiMDG.Visibility = [System.Windows.Visibility]::Collapsed }
		}
	}

	$syncHash.DC.Window[0] = ""
	$syncHash.TotalProgress.Visibility = [System.Windows.Visibility]::Hidden
	$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.btnReset[0] = $syncHash.Data.msgTable.ContentbtnReset2 } )

	$ofs = "`n"
	$output = @"
$( $syncHash.Data.msgTable.StrOutput1 )

$( $syncHash.Data.msgTable.StrOutput2 ): $( $syncHash.User.Name )
$( $syncHash.Data.msgTable.StrOutput3 ): $( $syncHash.DC.tbCaseNr[0] )
$( if ( $syncHash.DC.rbLatest[0] ) { "$( $syncHash.Data.msgTable.StrOutputTimeline1 ) $( $syncHash.DC.DatePickerStart[1].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )"}
elseif ( $syncHash.DC.rbPrevDate[0] ) { "$( $syncHash.Data.msgTable.StrOutputTimeline2 ) $( $syncHash.DC.DatePickerStart[1].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )" }
else { $syncHash.Data.msgTable.StrOutputTimeline3 } )

***********************
$( $syncHash.Data.msgTable.StrOutput4 ) $( $syncHash.Data.FullFileList.Count )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleFolders ):

$( [string]( $syncHash.Data.Folders | ForEach-Object { "$( $_.Path ) ( $( $_.Name ) )" } ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleFoldersOtherPerm ):

$( [string]( $syncHash.OtherFolderPermissions ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleFilterMatch )
$( $syncHash.Data.msgTable.StrOutputTitleFilterMatch2 )
$( $syncHash.fileFilter )

$( [string]( $syncHash.DC.lvFilterMatch[0].TT ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleMultiDotH )

$( [string]( $syncHash.DC.lvMultiDotsH[0].TT ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleMultiDotG )

$( [string]( $syncHash.DC.lvMultiDotsG[0].TT ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleAllFiles )

$( [string]( $syncHash.DC.lvAllFiles[0].TT | Sort-Object ) )
"@

	$syncHash.OutputContent.Item( 0 ) = $output
	$syncHash.Window.Dispatcher.Invoke( [action] {  } )
	$syncHash.End = Get-Date
}

####################
# Reset all controls
function Reset
{
	$syncHash.Window.Dispatcher.Invoke( [action] {
		$syncHash.Data.Folders.Clear()
		$syncHash.DC.lvAllFiles[0] = [System.Windows.Data.ListCollectionView]@()
		$syncHash.DC.lvFilterMatch[0] = [System.Windows.Data.ListCollectionView]@()
		$syncHash.DC.lvMultiDotsH[0] = [System.Windows.Data.ListCollectionView]@()
		$syncHash.DC.lvMultiDotsG[0] = [System.Windows.Data.ListCollectionView]@()
		$syncHash.DC.rbLatest[0] = $true
		$syncHash.DC.txtQuestion[0] = $syncHash.DC.tbCaseNr[0] = $syncHash.DC.tbID[0] = $syncHash.DC.lblFileCount[0] = $syncHash.DC.lblFolderCount[0] = ""
		$syncHash.tiO.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.tiFilterMatch.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.tiMDG.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.tiMDH.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.gbInfo.Visibility = [System.Windows.Visibility]::Hidden
		$syncHash.spSummary.Visibility = [System.Windows.Visibility]::Hidden
		$syncHash.OutputContent.Item( 0 ) = ""
		$syncHash.Data.FullFileList.Clear()
		$syncHash.OtherFolderPermissions.Clear()
		$syncHash.User = $null
		$syncHash.DC.spInput[0] = $true
		$syncHash.DC.btnReset[0] = $syncHash.Data.msgTable.ContentbtnReset
	} )
}

################################################
# Columnheader is clicked, resort listview-items
# Grouping is unchanged
function Resort
{
	param ( $listview, $sortBy )

	$List = [System.Windows.Data.ListCollectionView]( $syncHash.DC.$listview[0] | Sort-Object $sortBy )

	$sort1 = New-Object System.ComponentModel.SortDescription
	$sort2 = New-Object System.ComponentModel.SortDescription
	$groupBy = New-Object System.Windows.Data.PropertyGroupDescription "FileType"

	$sort1.Direction = "Ascending"
	$sort1.PropertyName = "FileType"
	$sort2.Direction = "Ascending"
	$sort2.PropertyName = $sortBy

	$List.GroupDescriptions.Add( $groupBy )
	$List.SortDescriptions.Add( $sort1 )
	$List.SortDescriptions.Add( $sort2 )
	$syncHash.DC.$listview[0] = $List
}

####################### Script start
Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]

$controls = New-Object Collections.ArrayList
[void]$controls.Add( @{ CName = "btnCreateQuestion"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCreateQuestion } ) } )
[void]$controls.Add( @{ CName = "btnOpenFolder"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenFolder } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentbtnOpenFolderTT } ) } )
[void]$controls.Add( @{ CName = "btnOpenSummary"; Props = @( @{ PropName = "Tag"; PropVal = "" } ; @{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenSummary } ) } )
[void]$controls.Add( @{ CName = "btnReset"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnReset } ) } )
[void]$controls.Add( @{ CName = "btnSearch"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSearch } ) } )
[void]$controls.Add( @{ CName = "btnSearchExt"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSearchExt } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentbtnSearchExtTT } ) } )
[void]$controls.Add( @{ CName = "btnSearchFileName"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSearchFileName } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentbtnSearchFileNameTT } ) } )
[void]$controls.Add( @{ CName = "cbExpandGroups"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentcbExpandGroups } ) } )
[void]$controls.Add( @{ CName = "DatePickerStart"; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ; @{ PropName = "SelectedDate"; PropVal = ( Get-Date ).AddDays( -14 ) } ) } )
[void]$controls.Add( @{ CName = "gbDatePicker"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgbDatePicker } ) } )
[void]$controls.Add( @{ CName = "gbInfo"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgbInfo } ) } )
[void]$controls.Add( @{ CName = "gbSearch"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgbSearch } ) } )
[void]$controls.Add( @{ CName = "gbSettings"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgbSettings } ) } )
[void]$controls.Add( @{ CName = "lblCaseNrTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblCaseNrTitle } ) } )
[void]$controls.Add( @{ CName = "lblFileCount"; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblFileCountTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblFileCountTitle } ) } )
[void]$controls.Add( @{ CName = "lblFiles"; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblFilterMatch"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblFilterMatch } ) } )
[void]$controls.Add( @{ CName = "lblFolderCountTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblFolderCountTitle } ) } )
[void]$controls.Add( @{ CName = "lblFolderCount"; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblIDTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblIDTitle } ) } )
[void]$controls.Add( @{ CName = "lblMDG"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblMDG } ) } )
[void]$controls.Add( @{ CName = "lblMDH"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblMDH } ) } )
[void]$controls.Add( @{ CName = "lblO"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblO } ) } )
[void]$controls.Add( @{ CName = "lblSummary"; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblSummaryTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSummaryTitle } ) } )
[void]$controls.Add( @{ CName = "lblUser"; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblUserTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblUserTitle } ) } )
[void]$controls.Add( @{ CName = "lblValuesTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblValuesTitle } ) } )
[void]$controls.Add( @{ CName = "lvAllFiles"; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void]$controls.Add( @{ CName = "lvFilterMatch"; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void]$controls.Add( @{ CName = "lvAN"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlvColumnName } ) } )
[void]$controls.Add( @{ CName = "lvAC"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlvColumnCreated } ) } )
[void]$controls.Add( @{ CName = "lvAU"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlvColumnUpdated } ) } )
[void]$controls.Add( @{ CName = "lvMultiDotsG"; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void]$controls.Add( @{ CName = "lvMultiDotsH"; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void]$controls.Add( @{ CName = "rbAll"; Props = @( @{ PropName = "IsChecked"; PropVal = $false } ; @{ PropName = "Content"; PropVal = $msgTable.ContentrbAll } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentrbAllToolTip } ) } )
[void]$controls.Add( @{ CName = "rbLatest"; Props = @( @{ PropName = "IsChecked"; PropVal = $true } ; @{ PropName = "Content"; PropVal = $msgTable.ContentrbLatest } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentrbLatestToolTip } ) } )
[void]$controls.Add( @{ CName = "rbPrevDate"; Props = @( @{ PropName = "IsChecked"; PropVal = $false } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentrbPrevDateToolTip } ; ) } )
[void]$controls.Add( @{ CName = "spInput"; Props = @( @{ PropName = "IsEnabled"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "tbCaseNr"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbID"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbPrevDateText"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttbPrevDateText } ) } )
[void]$controls.Add( @{ CName = "tiO"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiOHeader } ) } )
[void]$controls.Add( @{ CName = "tiFiles"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiFilesHeader } ) } )
[void]$controls.Add( @{ CName = "tiFilterMatch"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiFilterMatchHeader } ) } )
[void]$controls.Add( @{ CName = "tiMDG"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiMDGHeader } ) } )
[void]$controls.Add( @{ CName = "tiMDH"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiMDHHeader } ) } )
[void]$controls.Add( @{ CName = "TotalProgress"; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ) } )
[void]$controls.Add( @{ CName = "txtQuestion"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "Window"; Props = @( @{ PropName = "Title"; PropVal = "" } ) } )

$syncHash = CreateWindowExt $controls

$syncHash.Data.Folders = [System.Collections.ArrayList]::new()
$syncHash.Data.FullFileList = [System.Collections.ArrayList]::new()
$syncHash.Data.msgTable = $msgTable

$syncHash.OtherFolderPermissions = ( New-Object System.Collections.ObjectModel.ObservableCollection[object] )
$syncHash.OtherFolderPermissions.Add_CollectionChanged( {
	if ( $syncHash.OtherFolderPermissions.Count -gt 0 )
	{
		$ofs = "`n"
		$syncHash.DC.txtQuestion[0] = "$( $syncHash.User.Name ) $( $syncHash.Data.msgTable.StrQuestion1 ) $( $syncHash.DC.tbCaseNr[0] ).`r`n$( $syncHash.Data.msgTable.StrQuestion2 )`r`n$( $syncHash.Data.msgTable.StrQuestion3 )`r`n`r`n$( [string]( $syncHash.OtherFolderPermissions | Select-Object -Unique | Sort-Object ) )"
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.tiO.Visibility = [System.Windows.Visibility]::Visible } )
	}
} )

$syncHash.OutputContent = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$syncHash.OutputContent.Add( "" )
$syncHash.OutputContent.Add_CollectionChanged( {
	if ( $syncHash.OutputContent.Item( 0 ) -ne "" )
	{
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.DC.btnOpenSummary[0] = WriteOutput -Output "$( $syncHash.OutputContent.Item( 0 ) )"
			$syncHash.DC.lblSummary[0] = $syncHash.DC.btnOpenSummary[0]
			$syncHash.spSummary.Visibility = [System.Windows.Visibility]::Visible
			WriteLog -LogText "$( $syncHash.logText )`r`n`tOutput: $( $syncHash.DC.btnOpenSummary[0] )" | Out-Null
		} )
		TextToSpeech -Text $syncHash.Data.msgTable.StrFileSearchFinished
	}
} )

WriteLog -LogText $syncHash.Data.msgTable.StrLogScriptStart | Out-Null

$syncHash.ScriptVar = New-Object -ComObject WScript.Shell
$syncHash.fileFilter = @( ".MYD", ".MYI", "encrypted", "vvv", ".mp3", ".exe", "Anydesk", "FileSendsuite", "Recipesearch", "FromDocToPDF", ".dll", "easy2lock" )

# Copy text for question to clipboard
$syncHash.btnCreateQuestion.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$syncHash.DC.txtQuestion[0] | clip
	ShowMessageBox $syncHash.Data.msgTable.StrQuestionCopied
	WriteLog -LogText $syncHash.Data.msgTable.StrLogQuestionCopied | Out-Null
} )
# Opens the folder a file
$syncHash.btnOpenFolder.Add_Click( { Start-Process explorer -ArgumentList "/select, $( $syncHash.lvAllFiles.SelectedItem.TT )" } )
# Opens the summaryfile
$syncHash.btnOpenSummary.Add_Click( { & 'C:\Program Files (x86)\Notepad++\notepad++.exe' $this.Tag } )
$syncHash.btnReset.Add_Click( { Reset } )
# Search on Google for the fileextension
$syncHash.btnSearchExt.Add_Click( { Start-Process chrome "https://www.google.com/search?q=fileextension+$( $syncHash.lvAllFiles.SelectedItem.FileType )" } )
# Search on Google for the filename
$syncHash.btnSearchFileName.Add_Click( { Start-Process chrome "https://www.google.com/search?q=`"$( [string]$syncHash.lvAllFiles.SelectedItem.Name )`"" } )
# Starts the search
$syncHash.btnSearch.Add_Click( {
	if ( $syncHash.DC.btnSearch[0] -eq $syncHash.Data.msgTable.ContentBtnSearch )
	{
		$syncHash.Data.FullFileList.Clear()
		$syncHash.Data.Folders.Clear()
		$syncHash.Start = Get-Date
		if ( CheckReady ) { GetFolders }
	}
	else
	{
		Reset
		$syncHash.DC.btnSearch[0] = $syncHash.Data.msgTable.ContentBtnSearch
		$syncHash.DC.spInput[0] = $true
	}
} )
$syncHash.cbExpandGroups.Add_Checked( { $syncHash.Window.Resources.ExpandGroups = $true } )
$syncHash.cbExpandGroups.Add_Unchecked( { $syncHash.Window.Resources.ExpandGroups = $false } )
# Columnheader is clicked, sort items according to the columns values
$syncHash.lvAN.Add_Click( { Resort "lvAllFiles" "Name" } )
$syncHash.lvAC.Add_Click( { Resort "lvAllFiles" "Created" } )
$syncHash.lvAU.Add_Click( { Resort "lvAllFiles" "Updated" } )
$syncHash.lvHN.Add_Click( { Resort "lvMultiDotsH" "Name" } )
$syncHash.lvHC.Add_Click( { Resort "lvMultiDotsH" "Created" } )
$syncHash.lvHU.Add_Click( { Resort "lvMultiDotsH" "Updated" } )
$syncHash.lvGN.Add_Click( { Resort "lvMultiDotsG" "Name" } )
$syncHash.lvGC.Add_Click( { Resort "lvMultiDotsG" "Created" } )
$syncHash.lvGU.Add_Click( { Resort "lvMultiDotsG" "Updated" } )
# Open folder the selected file is located in
$syncHash.menuOpenfolder.Add_Click( { OpenFileFolder } )
# Search on Google for the fileextension
$syncHash.menuSearchExtension.Add_Click( { SearchExtension } )
# Search on Google for the filename
$syncHash.menuSearchFileName.Add_Click( { SearchFileName } )
# Radiobutton for all files is selected, set startdate to two months ago
$syncHash.rbAll.Add_Checked( { $syncHash.DC.DatePickerStart[1] = ( Get-Date ).AddDays( -60 ) } )
# Radiobutton for files updated in the last two weeks, is selected
$syncHash.rbLatest.Add_Checked( { $syncHash.DC.DatePickerStart[1] = ( Get-Date ).AddDays( -14 ) } )
# Radiobutton for selected startdate, is selected
$syncHash.rbPrevDate.Add_Checked( { $syncHash.DC.DatePickerStart[0] = $true } )
# Radiobutton for selected startdate, is deselected
$syncHash.rbPrevDate.Add_UnChecked( { $syncHash.DC.DatePickerStart[0] = $false } )
# Visibility for the progressbar changed. Set resource accordingly
$syncHash.TotalProgress.Add_IsVisibleChanged( { if ( $this.Visibility -eq "Hidden" ) { } } )
# Progress for gettings files have updated
$syncHash.TotalProgress.Add_ValueChanged( {
	if ( $this.Value -ge 100 )
	{
		if ( $syncHash.Data.FullFileList.Count -ne 0 ) { ListFiles }
	}
} )
# Text for quest changed set tabitemheader to include number of folders not reachable
$syncHash.txtQuestion.Add_TextChanged( {
	if ( $this.LineCount -gt 4 ) { $syncHash.DC.tiO[0] = "$( $syncHash.Data.msgTable.ContenttiOHeader ) ($( $this.LineCount - 4 ))" }
	else { $syncHash.DC.tiO[0] = $syncHash.Data.msgTable.ContenttiOHeader }
 } )
# Activate window and set focus when the window is loaded
$syncHash.Window.Add_Loaded( {
	$syncHash.Window.Activate()
	$syncHash.tbCaseNr.Focus()
	$syncHash.cbExpandGroups.IsChecked = $syncHash.Window.Resources.ExpandGroups
} )

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash
[System.GC]::Collect()
