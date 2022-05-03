<#
.Synopsis Search for potential viruses
.Requires Role_Servicedesk_Backoffice
.Description Lists all files in folders a given user have accespermission to.
.Author Smorkster (smorkster)
function CheckReady
{
	<#
	.Synopsis
		Checks if necessary values are given, if so enabled search-button
	#>
	$message = ""

	if ( -not ( ( $syncHash.DC.tbCaseNr[0] -match "^RITM\d{7}" ) -or ( $syncHash.DC.tbCaseNr[0] -match "^INC\d{7}" ) ) )
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
		$syncHash.Data.ErrorHashes += WriteErrorLogTest -LogText "$( $syncHash.Data.msgTable.ErrLogInvalidId )`n$_)" -UserInput $syncHash.DC.tbID[0] -Severity "UserInputFail"
		$message += "`n$( $syncHash.Data.msgTable.ErrInvalidID )"
	}

	$syncHash.logText = "$( $syncHash.DC.tbCaseNr[0] ) - $( $syncHash.DC.tbID[0] )"
	if ( $message -eq "" )
	{
		if ( $syncHash.rbLatest.IsChecked ) { $syncHash.DC.lblFiles[0] = $syncHash.Data.msgTable.ContentLblFiles2W }
		else { $syncHash.DC.lblFiles[0] = $syncHash.Data.msgTable.ContentLblFiles }
		$syncHash.DC.gridInput[0] = $false
		$syncHash.DC.lblUser[0] = $syncHash.User.Name
		$syncHash.gbInfo.Visibility = [System.Windows.Visibility]::Visible
		return $true
	}
	else
	{
		ShowMessageBox -Text $message.Trim() -Icon "Stop" | Out-Null
		$syncHash.logText += $message
		return $false
	}
}

function GenerateLog
{
	<#
	.Synopsis
		Create logtext
	#>

	$syncHash.logText = @"
$( $syncHash.Data.msgTable.StrLogMsgSearchTime ): $( $syncHash.Start.ToString( "yyyy-MM-dd HH:mm:ss"  ) ) - $( $syncHash.End.ToString( "HH:mm:ss" ) )
$( $a = $syncHash.End - $syncHash.Start
"{0} h, {1} m, {2} s" -f $a.hours, $a.minutes, $a.seconds )

$( if ( $syncHash.rbLatest.IsChecked ) { "$( $syncHash.Data.msgTable.StrOutputTimeline1 ) $( $syncHash.DC.DatePickerStart[1].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )"}
elseif ( $syncHash.DC.rbPrevDate[0] ) { "$( $syncHash.Data.msgTable.StrOutputTimeline2 ) $( $syncHash.DC.DatePickerStart[1].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )" }
else { $syncHash.Data.msgTable.StrOutputTimeline3 } )

$( $syncHash.Data.msgTable.StrLogMsgTotNumFiles ) $( $syncHash.Data.FullFileList.Count )
$( $syncHash.Data.msgTable.StrLogMsgOtherPermCount ) $( $syncHash.OtherFolderPermissions.Count )
$( $syncHash.Data.msgTable.StrLogMsgFilesMatchingFilterCount ) $( $syncHash.DC.lvFilterMatch[0].Count )
$( $syncHash.Data.msgTable.StrLogMsgFilsWithDoubleExtH ) $( $syncHash.DC.lvMultiDotsH[0].Count )
$( $syncHash.Data.msgTable.StrLogMsgFilsWithDoubleExtG ) $( $syncHash.DC.lvMultiDotsG[0].Count )
"@
}

function GenerateOutput
{
	<#
	.Synopsis
		Create the outputtext
	#>

	$ofs = "`n"
	$syncHash.OutputContent.Item( 0 ) = @"
$( $syncHash.Data.msgTable.StrOutput1 )

$( $syncHash.Data.msgTable.StrOutput2 ): $( $syncHash.User.Name )
$( $syncHash.Data.msgTable.StrOutput3 ): $( $syncHash.DC.tbCaseNr[0] )
$( if ( $syncHash.rbLatest.IsChecked ) { "$( $syncHash.Data.msgTable.StrOutputTimeline1 ) $( $syncHash.DC.DatePickerStart[1].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )"}
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
$( $ofs = ", "
$syncHash.fileFilter )

$( 	$ofs = "`n"
[string]( $syncHash.DC.lvFilterMatch[0].TT ) )


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
}

function GetFolders
{
	<#
	.Synopsis
		Start the job to get folderlist
	#>

	$syncHash.TotalProgress.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.FolderJob.Handle = $syncHash.FolderJob.PS.BeginInvoke()
}

function GetFiles
{
	<#
	.Synopsis
		Start the job to get all files
	#>

	$syncHash.TotalProgress.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.FilesJob.Handle = $syncHash.FilesJob.PS.BeginInvoke()
}

function ListFiles
{
	<#
	.Synopsis
		List all the files
	#>

	$syncHash.End = Get-Date
	$syncHash.DC.Window[0] = ""
	$syncHash.DC.gridWaitProgress[0] = [System.Windows.Visibility]::Hidden

	if ( $syncHash.Data.FullFileList.Count -gt 0 )
	{
		# Set how items in listviews are to be grouped and sorted
		$groupBy = [System.Windows.Data.PropertyGroupDescription]::new( "FileType" )
		$sort1 = [System.ComponentModel.SortDescription]@{ Direction = "Ascending"; PropertyName = "FileType" }
		$sort2 = [System.ComponentModel.SortDescription]@{ Direction = "Ascending"; PropertyName = "Name" }

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
		$syncHash.spActionButtons.IsEnabled = $true
	}
	else
	{
		$syncHash.DC.lvAllFiles[0].Add( ( [PSCustomObject]@{ Name = $syncHash.Data.msgTable.StrNoFilesFound; CreationTime = $syncHash.Start; LastWriteTime = $syncHash.End } ) )
	}

	GenerateOutput
	GenerateLog
}

function PrepGetFolders
{
	<#
	.Synopsis
		Get the folders and list files
	#>

	$syncHash.gridInfo.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.FolderJob = [pscustomobject]@{ PS = [powershell]::Create().AddScript( { param ( $syncHash )
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOPGettingFolders

		$syncHash.Data.Folders.Add( [pscustomobject]@{ "Path" = $syncHash.User.HomeDirectory; "Name" = "H:" } )
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

		for ( $ticker = 0; $ticker -lt ( $syncHash.Data.GGroups | Where-Object { $_.Name -notmatch "_R$" } ).Count; $ticker += 1 )
		{
			$i = $syncHash.Data.GGroups[$ticker]
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
			$syncHash.DC.TotalProgress[0] = [double]( ( ( $ticker + 1 ) / ( $syncHash.Data.GGroups | Where-Object { $_.Name -notmatch "_R$" } ).Count ) * 100 )
		}

		$syncHash.Data.Folders | Sort-Object Path | ForEach-Object {
			if ( $_.Name -eq "^H:" )
			{ $syncHash.DC.dgFolderList[0].Add( ( [pscustomobject]@{ "Path" = $_.Name ; "Name" = $_.Name } ) ) }
			else
			{ $syncHash.DC.dgFolderList[0].Add( ( [pscustomobject]@{ "Path" = $_.Path ; "Name" = $_.Name } ) ) }
		}
		$syncHash.DC.lblFolderCount[0] = $syncHash.Data.Folders.Count
		$syncHash.DC.lblFileCount[0] = $syncHash.Data.msgTable.StrWaitingFileSearch
		$syncHash.DC.TotalProgress[0] = 0.0
		$syncHash.DC.btnStartSearch[2] = $syncHash.Data.Folders.Count -gt 0
	} ).AddArgument( $syncHash ) ; Handle = $null }
}

function PrepGetFiles
{
	<#
	.Description
		Create the job (runspace) that will retrieve a list of all files the user have permission for
	#>

	$syncHash.FilesJob = [pscustomobject]@{ PS = [powershell]::Create().AddScript( { param ( $syncHash )
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOPGettingFiles
		$syncHash.DC.gridWaitProgress[0] = [System.Windows.Visibility]::Visible
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.TotalProgress.Maximum = $syncHash.Data.Folders.Count } )

		foreach ( $Folder in $syncHash.Data.Folders )
		{
			$p = [powershell]::Create().AddScript( { param ( $syncHash, $Folder )
				$files = Get-ChildItem2 $Folder.Path -File -Recurse | `
					Where-Object { $_.LastWriteTime -ge $syncHash.DC.DatePickerStart[1] } | `
					Select-Object -Property "Name", `
						"CreationTime", `
						"LastWriteTime", `
						@{ Name = "FileType"; Expression = {
								if ( [string]::IsNullOrEmpty( $_.Extension ) ) { $syncHash.Data.msgTable.StrNoExtension }
								else { $_.Extension.ToLower() } } }, `
						@{ Name = "FilterMatch"; Expression = {
							$n = $_.Name
							if ( $syncHash.fileFilter.ForEach( { $n -match $_ } ) -eq $true ) { $true }
							else { $false } } }, `
						@{ Name = "TT"; Expression = {
							if ( $_.FullName.StartsWith( $syncHash.User.HomeDirectory ) ) { $_.FullName.Replace( $syncHash.User.HomeDirectory , "H:" ) }
							else { $_.FullName } } } | ForEach-Object { $syncHash.Data.FullFileList.Add( $_ ) }

				$syncHash.DC.lblFileCount[0] = $syncHash.Data.FullFileList.Count
				$syncHash.DC.dgFolderList[0] = @( $syncHash.DC.dgFolderList[0] | Where-Object { $Folder.Name -ne $_.Name } )
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.TotalProgress[0] += 1 } )
			} ).AddArgument( $syncHash ).AddArgument( $Folder )
			[void] $syncHash.Jobs.Add( [pscustomobject]@{ PS = $p; Handle = $p.BeginInvoke() } )
		}

		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOPWaitGettingFiles
	} ).AddArgument( $syncHash ) ; Handle = $null }
}

function Reset
{
	<#
	.Synopsis
		Reset all controls
	#>

	$syncHash.Window.Dispatcher.Invoke( [action] {
		$syncHash.Data.Folders.Clear()
		$syncHash.Data.FullFileList.Clear()
		$syncHash.Data.ErrorHashes.Clear()
		$syncHash.OtherFolderPermissions.Clear()
		$syncHash.DC.lvAllFiles[0] = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
		$syncHash.DC.dgFolderList[0] = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
		$syncHash.DC.lvFilterMatch[0] = [System.Windows.Data.ListCollectionView]@()
		$syncHash.DC.lvMultiDotsH[0] = [System.Windows.Data.ListCollectionView]@()
		$syncHash.DC.lvMultiDotsG[0] = [System.Windows.Data.ListCollectionView]@()
		$syncHash.cbSetAccountDisabled.IsChecked = $false
		$syncHash.rbLatest.IsChecked = $true
		$syncHash.DC.gridInput[0] = $true
		$syncHash.DC.txtQuestion[0] = $syncHash.DC.tbCaseNr[0] = $syncHash.DC.tbID[0] = $syncHash.DC.lblFileCount[0] = $syncHash.DC.lblFolderCount[0] = ""
		$syncHash.OutputContent.Item( 0 ) = ""
		$syncHash.DC.lblSummary[0] = ""
		$syncHash.DC.TotalProgress[0] = 0.0
		$syncHash.User = $null
		$syncHash.tiO.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.tiFilterMatch.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.tiMDG.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.tiMDH.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.gbInfo.Visibility = [System.Windows.Visibility]::Hidden
		$syncHash.gridInfo.Visibility = [System.Windows.Visibility]::Hidden
	} )
	$syncHash.Jobs | ForEach-Object { $_.PS.Stop() ; $_.PS.Runspace.Close() ; $_.PS.Runspace.Dispose() }
	$syncHash.Jobs.Clear()
}

function Resort
{
	<#
	.Description
		Columnheader is clicked, resort listview-items
		Grouping is unchanged
	#>

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

function UpdateUserInput
{
	<#
	.Description
		Textboxes have new data, create a "UserInput"-string for logging purposes
	#>

	$syncHash.cbSetAccountDisabled.Content = $syncHash.Data.msgTable.ContentcbSetAccountDisabled
	$syncHash.DC.gridInput[1] = "{0}: {1}`n{2}: {3}" -f $syncHash.Data.msgTable.StrLogMsgId, $syncHash.tbID.Text, $syncHash.Data.msgTable.StrLogMsgCaseNr, $syncHash.tbCaseNr.Text
	try
	{
		$syncHash.cbSetAccountDisabled.IsChecked = -not ( Get-ADUser -Identity $syncHash.tbID.Text ).Enabled
		if ( $syncHash.cbSetAccountDisabled.IsChecked )
		{ $syncHash.cbSetAccountDisabled.Content += " ($( $syncHash.Data.msgTable.StrUserAccountAlreadyLocked ))" }
	}
	catch { $syncHash.cbSetAccountDisabled.Content += " ($( $syncHash.Data.msgTable.StrErrUserNotFound ))" }
}

####################### Script start
Add-Type -AssemblyName PresentationFramework
Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]

$controls = New-Object Collections.ArrayList
[void]$controls.Add( @{ CName = "btnAbort"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnAbort } ) } )
[void]$controls.Add( @{ CName = "btnCreateQuestion"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCreateQuestion } ) } )
[void]$controls.Add( @{ CName = "btnOpenFolder"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenFolder } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentbtnOpenFolderTT } ) } )
[void]$controls.Add( @{ CName = "btnOpenSummary"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenSummary } ) } )
[void]$controls.Add( @{ CName = "btnPrep"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnPrep } ; @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Visible } ) } )
[void]$controls.Add( @{ CName = "btnReset"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnReset } ; @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Visible } ) } )
[void]$controls.Add( @{ CName = "btnRunVirusScan"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnRunVirusScan } ) } )
[void]$controls.Add( @{ CName = "btnStartSearch"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnStartSearch } ; @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnSearchExt"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSearchExt } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentbtnSearchExtTT } ) } )
[void]$controls.Add( @{ CName = "btnSearchFileName"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSearchFileName } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentbtnSearchFileNameTT } ) } )
[void]$controls.Add( @{ CName = "cbExpandGroups"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentcbExpandGroups } ) } )
[void]$controls.Add( @{ CName = "cbSetAccountDisabled"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentcbSetAccountDisabled } ) } )
[void]$controls.Add( @{ CName = "DatePickerStart"; Props = @( @{ PropName = "IsEnabled"; PropVal = $false } ; @{ PropName = "SelectedDate"; PropVal = ( Get-Date ).AddDays( -14 ) } ) } )
[void]$controls.Add( @{ CName = "dgFolderList"; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "gbDatePicker"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgbDatePicker } ) } )
[void]$controls.Add( @{ CName = "gbInfo"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgbInfo } ) } )
[void]$controls.Add( @{ CName = "gbSearch"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgbSearch } ) } )
[void]$controls.Add( @{ CName = "gbSettings"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgbSettings } ) } )
[void]$controls.Add( @{ CName = "gridInput"; Props = @( @{ PropName = "IsEnabled"; PropVal = $true } ; @{ PropName = "Tag"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "gridWaitProgress"; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Hidden } ) } )
[void]$controls.Add( @{ CName = "lblCaseNrTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblCaseNrTitle } ) } )
[void]$controls.Add( @{ CName = "lblFileCount"; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblFileCountTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblFileCountTitle } ) } )
[void]$controls.Add( @{ CName = "lblFiles"; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblFilterMatch"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblFilterMatch } ) } )
[void]$controls.Add( @{ CName = "lblFolderCountTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblFolderCountTitle } ) } )
[void]$controls.Add( @{ CName = "lblFolderCount"; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblFolderListTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblFolderListTitle } ) } )
[void]$controls.Add( @{ CName = "lblIDTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblIDTitle } ) } )
[void]$controls.Add( @{ CName = "lblMDG"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblMDG } ) } )
[void]$controls.Add( @{ CName = "lblMDH"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblMDH } ) } )
[void]$controls.Add( @{ CName = "lblO"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblO } ) } )
[void]$controls.Add( @{ CName = "lblSummary"; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblSummaryTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSummaryTitle } ) } )
[void]$controls.Add( @{ CName = "lblUser"; Props = @( @{ PropName = "Content"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "lblUserTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblUserTitle } ) } )
[void]$controls.Add( @{ CName = "lblValuesTitle"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblValuesTitle } ) } )
[void]$controls.Add( @{ CName = "lvAllFiles"; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "lvFilterMatch"; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "lvAN"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlvColumnName } ) } )
[void]$controls.Add( @{ CName = "lvAC"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlvColumnCreated } ) } )
[void]$controls.Add( @{ CName = "lvAU"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlvColumnUpdated } ) } )
[void]$controls.Add( @{ CName = "lvMultiDotsG"; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "lvMultiDotsH"; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "rbAll"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbAll } ; @{ PropName = "IsChecked"; PropVal = $false } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentrbAllToolTip } ; @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "rbLatest"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentrbLatest } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentrbLatestToolTip } ) } )
[void]$controls.Add( @{ CName = "rbPrevDate"; Props = @( @{ PropName = "IsChecked"; PropVal = $false } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentrbPrevDateToolTip } ; ) } )
[void]$controls.Add( @{ CName = "tbCaseNr"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbID"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "tbPrevDateText"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttbPrevDateText } ) } )
[void]$controls.Add( @{ CName = "tiO"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiOHeader } ) } )
[void]$controls.Add( @{ CName = "tiFiles"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiFilesHeader } ) } )
[void]$controls.Add( @{ CName = "tiFilterMatch"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiFilterMatchHeader } ) } )
[void]$controls.Add( @{ CName = "tiMDG"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiMDGHeader } ) } )
[void]$controls.Add( @{ CName = "tiMDH"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiMDHHeader } ) } )
[void]$controls.Add( @{ CName = "TotalProgress"; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden } ) } )
[void]$controls.Add( @{ CName = "txtQuestion"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "Window"; Props = @( @{ PropName = "Title"; PropVal = "" } ) } )

$syncHash = CreateWindowExt $controls

$syncHash.Data.ErrorHashes = @()
$syncHash.Data.Folders = [System.Collections.ArrayList]::new()
$syncHash.Data.FullFileList = [System.Collections.ArrayList]::new()
$syncHash.Data.msgTable = $msgTable
$syncHash.fileFilter = @( ".MYD", ".MYI", "encrypted", "vvv", ".mp3", ".exe", "Anydesk", "FileSendsuite", "Recipesearch", "FromDocToPDF", ".dll", "easy2lock" )
$syncHash.Jobs = [System.Collections.ArrayList]::new()
$syncHash.ScriptVar = New-Object -ComObject WScript.Shell

WriteLogTest -Text $syncHash.Data.msgTable.StrLogScriptStart -UserInput "-" -Success $true | Out-Null

# Create an observable collection for a list of folders the scriptuser does not have permission to, that will respond to being updated
# Once updated, make the tabitem visible and fill textbox with folderlist and question
$syncHash.OtherFolderPermissions = ( New-Object System.Collections.ObjectModel.ObservableCollection[object] )
$syncHash.OtherFolderPermissions.Add_CollectionChanged( {
	if ( $syncHash.OtherFolderPermissions.Count -gt 0 )
	{
		$ofs = "`n"
		$syncHash.DC.txtQuestion[0] = "$( $syncHash.User.Name ) $( $syncHash.Data.msgTable.StrQuestion1 ) $( $syncHash.DC.tbCaseNr[0] ).`r`n$( $syncHash.Data.msgTable.StrQuestion2 )`r`n$( $syncHash.Data.msgTable.StrQuestion3 )`r`n`r`n$( [string]( $syncHash.OtherFolderPermissions | Select-Object -Unique | Sort-Object ) )"
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.tiO.Visibility = [System.Windows.Visibility]::Visible } )
	}
} )

# Create an observable collection for text as output that will respond to being updated
# Once updated, write to output-fil
$syncHash.OutputContent = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$syncHash.OutputContent.Add( "" )
$syncHash.OutputContent.Add_CollectionChanged( {
	if ( $syncHash.OutputContent.Item( 0 ) -ne "" )
	{
		$syncHash.DC.lblSummary[0] = WriteOutput -Output "$( $syncHash.OutputContent.Item( 0 ) )"
		WriteLogTest -Text $syncHash.logText -UserInput $syncHash.DC.gridInput[1] -Success $true -OutputPath $syncHash.DC.lblSummary[0] | Out-Null

		TextToSpeech -Text $syncHash.Data.msgTable.StrFileSearchFinished
		$syncHash.DC.TotalProgress[0] = 0.0
	}
} )

# Abort current filesearch
$syncHash.btnAbort.Add_Click( {
	ShowMessageBox -Text $syncHash.Jobs.Count
	$syncHash.Jobs, $syncHash.FilesJob | ForEach-Object { $_.PS.Stop(); $_.PS.Dispose() }
	$syncHash.Jobs.Clear()

	$syncHash.DC.dgFolderList[0] = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
	$syncHash.DC.gridWaitProgress[0] = [System.Windows.Visibility]::Hidden
	$syncHash.DC.TotalProgress[1] = [System.Windows.Visibility]::Hidden
	$syncHash.DC.btnStartSearch[2] = $true
	$syncHash.DC.gridInput[0] = $true
	$syncHash.DC.Window[0] = ""
	$syncHash.DC.TotalProgress[0] = 0.0
	WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgFileSearchAborted -UserInput $syncHash.DC.gridInput[1] -Success $true | Out-Null
} )

# Copy text for question to clipboard
$syncHash.btnCreateQuestion.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $false, $false ).psobject.BaseObject
	$syncHash.DC.txtQuestion[0] | clip
	ShowMessageBox $syncHash.Data.msgTable.StrQuestionCopied
	WriteLogTest -Text "$( $syncHash.Data.msgTable.StrLogQuestionCopied )`n**************`n$( $syncHash.DC.txtQuestion[0] )`n**************" -UserInput $syncHash.DC.gridInput[1] | Out-Null
} )

# Opens the folder selected file is located in
$syncHash.btnOpenFolder.Add_Click( {
	$syncHash.ActiveListView.SelectedItems.TT | ForEach-Object {
		if ( $_ -match "^H:\\" ) { $Path = $_ -replace "^H:", $syncHash.User.HomeDirectory }
		else { $Path = $_ }
		Start-Process explorer -ArgumentList "/select, $Path"
	}
	WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgOpenFolder -UserInput "$( $syncHash.DC.gridInput[1] )`n$( $syncHash.ActiveListView.SelectedItems.TT )" -Success $true
} )

# Opens the summaryfile
$syncHash.btnOpenSummary.Add_Click( { & 'C:\Program Files (x86)\Notepad++\notepad++.exe' $syncHash.DC.lblSummary[0] } )

# Prepare for filesearch by creating jobs and retrieving folderlist
$syncHash.btnPrep.Add_Click( {
	if ( CheckReady )
	{
		PrepGetFolders
		PrepGetFiles
		$this.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.DC.btnStartSearch[1] = [System.Windows.Visibility]::Visible
		GetFolders
		WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgFolderSearch -UserInput $syncHash.DC.gridInput[1] -Success $true
	}
	else { WriteLogTest -Text $syncHash.logText -UserInput $syncHash.DC.gridInput[1] -Success $false -ErrorLogHash $syncHash.DC.ErrorHashes }
} )

# Reset arrays, values and controls to default values
$syncHash.btnReset.Add_Click( {
	Reset
	$syncHash.DC.gridInput[0] = $true
	$syncHash.DC.btnStartSearch[1] = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.btnPrep[1] = [System.Windows.Visibility]::Visible
	$syncHash.tbCaseNr.Focus()
	$syncHash.spActionButtons.IsEnabled = $false

	if ( ( ShowMessageBox -Text $syncHash.Data.msgTable.StrEnableUser -Button ( [System.Windows.MessageBoxButton]::YesNo ) ) -eq "Yes" )
	{
		Set-ADUser -Identity $syncHash.DC.tbID.Text -Enabled $true
	}
} )

# Start a virus scan of selected file
$syncHash.btnRunVirusScan.Add_Click( {
	if ( $syncHash.ActiveListView.SelectedItems.Count -gt 0 )
	{
		if ( $syncHash.ActiveListView.SelectedItems.Count -gt 2 )
		{ ShowMessageBox -Text $syncHash.Data.msgTable.StrMultiFileVirusSearch }

		foreach ( $File in $syncHash.ActiveListView.SelectedItems )
		{
			if ( $File.TT -match "^H:\\" )
			{ $path = $File.TT -replace "^H:", $syncHash.User.HomeDirectory }
			else
			{ $path = $File.TT }
			$PathToScan = Get-Item $path

			$Shell = New-Object -Com Shell.Application
			$ShellFolder = $Shell.NameSpace( $PathToScan.Directory.FullName )
			$ShellFile = $ShellFolder.ParseName( $PathToScan.Name )
			$ShellFile.InvokeVerb( $syncHash.Data.msgTable.StrVerbVirusScan )
		}
		WriteLogTest -Text $syncHash.Data.msgTable.LogScannedFile -UserInput "$( $syncHash.DC.gridInput[1] )`n$( $syncHash.Data.msgTable.LogScannedFileTitle ) $( $syncHash.ActiveListView.SelectedItems.TT )" -Success $true | Out-Null
	}
} )

# Search on Google for the fileextension
$syncHash.btnSearchExt.Add_Click( {
	$SelectedExtensions = $syncHash.ActiveListView.SelectedItems.FileType | Select-Object -Unique
	foreach ( $Ext in $SelectedExtensions )
	{
		Start-Process chrome "https://www.google.com/search?q=fileextension+$( $Ext )"
	}
	WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgSearchExt -UserInput "$( $syncHash.DC.gridInput[1] )`n$SelectedExtensions" -Success $true
} )

# Search on Google for the filename
$syncHash.btnSearchFileName.Add_Click( {
	$SelectedNames = $syncHash.ActiveListView.SelectedItems.Name | Select-Object -Unique
	foreach ( $Name in $SelectedNames )
	{
		Start-Process chrome "https://www.google.com/search?q=`"$( $Name )`""
	}
	WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgSearchFileName -UserInput "$( $syncHash.DC.gridInput[1] )`n$SelectedNames" -Success $true
} )

# Starts the search
$syncHash.btnStartSearch.Add_Click( {
	$this.IsEnabled = $false
	$syncHash.DC.lblFileCount[0] = ""
	$syncHash.Start = Get-Date
	if ( $syncHash.cbSetAccountDisabled.IsChecked )
	{ Set-ADUser -Identity $syncHash.User.SamAccountName -Enabled $false }

	GetFiles
} )

# Expand/collaps groups in datagrid
$syncHash.cbExpandGroups.Add_Checked( { $syncHash.Window.Resources.ExpandGroups = $true } )
$syncHash.cbExpandGroups.Add_Unchecked( { $syncHash.Window.Resources.ExpandGroups = $false } )

# Columnheader is clicked, sort items according to the columns values
$syncHash.lvAN.Add_Click( { Resort "lvAllFiles" "Name" } )
$syncHash.lvAC.Add_Click( { Resort "lvAllFiles" "CreationTime" } )
$syncHash.lvAU.Add_Click( { Resort "lvAllFiles" "LastWriteTime" } )
$syncHash.lvHN.Add_Click( { Resort "lvMultiDotsH" "Name" } )
$syncHash.lvHC.Add_Click( { Resort "lvMultiDotsH" "CreationTime" } )
$syncHash.lvHU.Add_Click( { Resort "lvMultiDotsH" "LastWriteTime" } )
$syncHash.lvGN.Add_Click( { Resort "lvMultiDotsG" "Name" } )
$syncHash.lvGC.Add_Click( { Resort "lvMultiDotsG" "CreationTime" } )
$syncHash.lvGU.Add_Click( { Resort "lvMultiDotsG" "LastWriteTime" } )

# Radiobutton for all files is selected, set startdate to two months ago
$syncHash.rbAll.Add_Checked( { $syncHash.DC.DatePickerStart[1] = ( Get-Date ).AddDays( -60 ) } )

# Radiobutton for files updated in the last two weeks, is selected
$syncHash.rbLatest.Add_Checked( { $syncHash.DC.DatePickerStart[1] = ( Get-Date ).AddDays( -14 ) } )

# Set selected listview
$syncHash.lvAllFiles.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )
$syncHash.lvMultiDotsH.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )
$syncHash.lvMultiDotsG.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )
$syncHash.lvFilterMatch.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )

# Text was entered, set user input text
$syncHash.tbCaseNr.Add_TextChanged( { UpdateUserInput } )
$syncHash.tbID.Add_TextChanged( { UpdateUserInput } )

# Progress for gettings files have updated
$syncHash.TotalProgress.Add_ValueChanged( {
	if ( $this.Value -eq $this.Maximum -and $syncHash.Jobs.Count -gt 0 ) { ListFiles }
	elseif ( $this.Value -eq 0 ) { $this.Visibility = [System.Windows.Visibility]::Hidden }
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
	$syncHash.ActiveListView = $syncHash.lvAllFiles
	$syncHash.rbLatest.IsChecked = $true
} )

[void] $syncHash.Window.ShowDialog()
$global:syncHash = $syncHash
[System.GC]::Collect()
