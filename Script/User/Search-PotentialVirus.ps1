<#
.Synopsis Search for potential viruses
.Requires Role_Servicedesk_Backoffice
.Description Lists all files in folders a given user have accespermission to.
.Author Smorkster (smorkster)
#>

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

$( if ( $syncHash.RbLatest.IsChecked ) { "$( $syncHash.Data.msgTable.StrOutputTimeline1 ) $( $syncHash.DC.DatePickerStart[0].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )"}
elseif ( $syncHash.DC.RbPrevDate[0] ) { "$( $syncHash.Data.msgTable.StrOutputTimeline2 ) $( $syncHash.DC.DatePickerStart[0].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )" }
else { $syncHash.Data.msgTable.StrOutputTimeline3 } )

$( $syncHash.Data.msgTable.StrLogMsgTotNumFiles ) $( $syncHash.Data.FullFileList.Count )
$( $syncHash.Data.msgTable.StrLogMsgOtherPermCount ) $( $syncHash.OtherFolderPermissions.Count )
$( $syncHash.Data.msgTable.StrLogMsgFilesMatchingFilterCount ) $( $syncHash.DC.LvFilterMatch[0].Count )
$( $syncHash.Data.msgTable.StrLogMsgFilesWithDoubleExtH ) $( $syncHash.DC.LvMultiDotsH[0].Count )
$( $syncHash.Data.msgTable.StrLogMsgFilesWithDoubleExtG ) $( $syncHash.DC.LvMultiDotsG[0].Count )
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
$( $syncHash.Data.msgTable.StrOutput3 ): $( $syncHash.DC.TbCaseNr[0] )
$( if ( $syncHash.RbLatest.IsChecked ) { "$( $syncHash.Data.msgTable.StrOutputTimeline1 ) $( $syncHash.DC.DatePickerStart[0].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )"}
elseif ( $syncHash.DC.RbPrevDate[0] ) { "$( $syncHash.Data.msgTable.StrOutputTimeline2 ) $( $syncHash.DC.DatePickerStart[0].ToShortDateString() ) -> $( ( Get-Date ).ToShortDateString() )" }
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
[string]( $syncHash.DC.LvFilterMatch[0].TT ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleMultiDotH )

$( [string]( $syncHash.DC.LvMultiDotsH[0].TT ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleMultiDotG )

$( [string]( $syncHash.DC.LvMultiDotsG[0].TT ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitleAllFiles )

$( [string]( $syncHash.LvAllFiles.ItemsSource.TT | Sort-Object ) )
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
	$syncHash.DC.GridWaitProgress[0] = [System.Windows.Visibility]::Hidden

	if ( $syncHash.Data.FullFileList.Count -gt 0 )
	{
		$syncHash.Data.FullFileList | ForEach-Object { $syncHash.Window.Resources['CvsAllFiles'].Source.Add( $_ ) }
		$syncHash.GridActionButtons.IsEnabled = $true
	}
	else
	{
		$syncHash.Window.Resources['CvsAllFiles'].Source.Add( ( [PSCustomObject]@{ Name = $syncHash.Data.msgTable.StrNoFilesFound; CreationTime = $syncHash.Start; LastWriteTime = $syncHash.End } ) )
	}
	$syncHash.LvAllFiles.ItemsSource = $syncHash.Window.Resources['CvsAllFiles'].View

	GenerateOutput
	GenerateLog
}

function PrepGetFolders
{
	<#
	.Synopsis
		Get the folders and list files
	#>

	$syncHash.GridInfo.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.FolderJob = [pscustomobject]@{ PS = [powershell]::Create().AddScript( { param ( $syncHash )
		$syncHash.Data.Groups = [System.Collections.ArrayList]::new()

		$syncHash.Data.Folders = [System.Collections.ArrayList]::new()
		$syncHash.Data.Other = [System.Collections.ArrayList]::new()

		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOPGettingFolders
		$syncHash.Data.Folders.Add( [pscustomobject]@{ Path = $syncHash.User.HomeDirectory; Name = "H:" ; Description = $syncHash.Data.msgTable.StrHomeFolder } )
		Get-ADPrincipalGroupMembership $syncHash.User.SamAccountName | Get-ADGroup -Properties Description | ForEach-Object { [void] $syncHash.Data.Groups.Add( $_ ) }

		foreach ( $g in ( $syncHash.Data.Groups | Where-Object { $_.Name -match "_(Org)|(Mig)_" } ) )
		{
			Get-ADPrincipalGroupMembership $g | Where-Object { $_.name -match ".*_Fil_.*(C|F)$" } | Get-ADGroup -Properties Description | ForEach-Object { [void] $syncHash.Data.Groups.Add( $_ ) }
		}

		$ticker = 0
		$max = ( $syncHash.Data.Groups | Where-Object { $_.Name -notmatch "_R$" } ).Count
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.StrOPFilteringFolders
		foreach ( $g in ( $syncHash.Data.Groups | Where-Object { $_.Name -notmatch "_R$" } ) )
		{
			$p = $null
			if ( $g.Description -match $syncHash.Data.msgTable.CodeGrpDescriptionMatch )
			{
				$p = ( ( $g.Description -split "$( $syncHash.Data.msgTable.StrGrpDescriptionSplit ) " )[1] -split "\." )[0] -replace " $( $syncHash.Data.msgTable.StrGrpDescriptionReplace )"
			}
			elseif ( $g.Description -match $syncHash.Data.msgTable.StrSepServer )
			{
				if ( $g.Name -match "ClientSoftware" )
				{
					$p = "\\$( $syncHash.Data.msgTable.StrSepServer )\ClientSoftware$\"
				}
				elseif ( $g.Description -match "Kar\\" )
				{
					$p = "\\$( $syncHash.Data.msgTable.StrSepServer )\$( $syncHash.Data.msgTable.StrSepServerFolder1 )\$( ( $g.Name -replace "_C" -split "$( $syncHash.Data.msgTable.StrSepServer )_" )[1] )"
				}
				elseif ( $g.Name -match "^LSF" )
				{
					$p = "\\$( $syncHash.Data.msgTable.StrSepServer )\$( $syncHash.Data.msgTable.StrSepServerFolder2 )\$( ( $g.Name -replace "_C" -split "$( $syncHash.Data.msgTable.StrSepServer )_" )[1] )"
				}
				elseif ( $g.Name -match "^Hsf" )
				{
					$p = "\\$( $syncHash.Data.msgTable.StrSepServer )\$( $syncHash.Data.msgTable.StrSepServerFolder3 )\$( ( $g.Name -replace "_C" -split "$( $syncHash.Data.msgTable.StrSepServer )_" )[1] )"
				}
			}
			else
			{
				$p = "Other"
			}

			if ( $p -eq "Other" )
			{
				[void] $syncHash.Data.Other.Add( ( [pscustomobject]@{ Path = $g.Name ; Name = $g.Name } ) )
			}
			else
			{
				if ( Test-Path $p )
				{
					if ( -not ( $syncHash.Data.Folders | Where-Object { $_.Path -eq $p } ) )
					{
						[void] $syncHash.Data.Folders.Add( ( [pscustomobject]@{ Path = $p ; Name = $g.Name ; Description = $g.Description } ) )
					}
				}
				else
				{
					[void] $syncHash.OtherFolderPermissions.Add( $g.Name )
				}
			}
			$ticker += 1
			$syncHash.DC.TotalProgress[0] = [double]( ( ( $ticker + 1 ) / $max ) * 100 )
		}

		$syncHash.Data.Folders | Sort-Object Path | ForEach-Object {
			$syncHash.DC.DgFolderList[0].Add( $_ )
		}

		$syncHash.DC.TblFolderCount[0] = $syncHash.Data.Folders.Count
		$syncHash.DC.TblFileCount[0] = $syncHash.Data.msgTable.StrWaitingFileSearch
		$syncHash.DC.TotalProgress[0] = 0.0
		$syncHash.DC.BtnStartSearch[2] = $syncHash.Data.Folders.Count -gt 0
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
		$syncHash.DC.GridWaitProgress[0] = [System.Windows.Visibility]::Visible
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.TotalProgress.Maximum = $syncHash.Data.Folders.Count } )

		foreach ( $Folder in $syncHash.Data.Folders )
		{
			$p = [powershell]::Create().AddScript( { param ( $syncHash, $Folder )
				Get-ChildItem2 $Folder.Path -File -Recurse | `
					Where-Object { $_.LastWriteTime -ge $syncHash.DC.DatePickerStart[0] } | `
					Select-Object -Property "Name", `
						"CreationTime", `
						"LastWriteTime", `
						@{ Name = "FileType"; Expression = {
							if ( [string]::IsNullOrEmpty( $_.Extension ) ) { $syncHash.Data.msgTable.StrNoExtension }
							else
							{
								try
								{
									$e = $_.Extension.ToLower()
									if ( $Desc = ( Get-ItemProperty "Registry::HKEY_Classes_root\$( ( Get-ItemProperty "Registry::HKEY_Classes_root\$e" -ErrorAction Stop )."(default)" )" )."(default)" )
									{ "$e :: $Desc" }
									else
									{ throw }
								}
								catch
								{ $e }
							}
						} }, `
						@{ Name = "FilterMatch"; Expression = {
							$n = $_.Name
							if ( $syncHash.fileFilter.ForEach( { $n -match $_ } ) -eq $true ) { $true }
							else { $false }
						} }, `
						@{ Name = "TT"; Expression = {
							if ( $_.FullName.StartsWith( $syncHash.User.HomeDirectory ) ) { $_.FullName.Replace( $syncHash.User.HomeDirectory , "H:" ) }
							else { $_.FullName }
						} }, `
						@{ Name = "Size" ; Expression = {
							if ( $_.Length -lt 1kB ) { "$( $_.Length ) B" }
							elseif ( $_.Length -gt 1kB -and $_.Length -lt 1MB ) { "$( [math]::Round( ( $_.Length / 1kB ), 2 ) ) kB" }
							elseif ( $_.Length -gt 1MB -and $_.Length -lt 1GB ) { "$( [math]::Round( ( $_.Length / 1MB ), 2 ) ) MB" }
							elseif ( $_.Length -gt 1GB -and $_.Length -lt 1TB ) { "$( [math]::Round( ( $_.Length / 1GB ), 2 ) ) GB" }
						} }, `
						@{ Name = "Owner" ; Expression = {
							$o = Get-ADUser ( ( ( Get-Acl $_.FullName ).Owner ) -split "\\" )[1]
							if ( $o.SamAccountName -eq $syncHash.User.SamAccountName ) { $syncHash.Data.msgTable.StrFileOwner }
							else { $o.Name }
						} }, `
						@{ Name = "Streams"; Expression = {
							Get-Item $_.FullName -Stream * | Select-Object Stream, @{ Name = "DataSize" ; Expression = {
								if ( $_.Length -lt 1kB ) { "$( $_.Length ) B" }
								elseif ( $_.Length -gt 1kB -and $_.Length -lt 1MB ) { "$( [math]::Round( ( $_.Length / 1kB ), 2 ) ) kB" }
								elseif ( $_.Length -gt 1MB -and $_.Length -lt 1GB ) { "$( [math]::Round( ( $_.Length / 1MB ), 2 ) ) MB" }
								elseif ( $_.Length -gt 1GB -and $_.Length -lt 1TB ) { "$( [math]::Round( ( $_.Length / 1GB ), 2 ) ) GB" }
							} }
						} } `
					| ForEach-Object { $syncHash.Data.FullFileList.Add( $_ ) }

				$Error | ForEach-Object {
					if ( $_.CategoryInfo.Activity -eq "Get-ChildItem2" )
					{ $syncHash.OtherFolderPermissions.Add( ( $_.Exception.Message -replace "\]" -split "\[" )[1] ) }
				}
				$syncHash.DC.TblFileCount[0] = $syncHash.Data.FullFileList.Count
				$syncHash.Window.Dispatcher.Invoke( [action] {
					$syncHash.DC.DgFolderList[0].Remove( $Folder )
					$syncHash.DC.TotalProgress[0] += 1
					( $syncHash.DgFolderList.GetBindingExpression( [System.Windows.Controls.DataGrid]::ItemsSourceProperty ) ).UpdateTarget()
				} )
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
		$syncHash.Window.Resources['CvsAllFiles'].Source.Clear()
		$syncHash.DC.DgFolderList[0].Clear()
		$syncHash.DC.LvFilterMatch[0].Clear()
		$syncHash.DC.LvMultiDotsH[0].Clear()
		$syncHash.DC.LvMultiDotsG[0].Clear()
		$syncHash.CbSetAccountDisabled.IsChecked = $false
		$syncHash.RbLatest.IsChecked = $true
		$syncHash.DC.GridInput[0] = $true
		$syncHash.DC.TbQuestion[0] = $syncHash.DC.TbCaseNr[0] = $syncHash.DC.TbID[0] = $syncHash.DC.TblFileCount[0] = $syncHash.DC.TblFolderCount[0] = ""
		$syncHash.OutputContent.Item( 0 ) = ""
		$syncHash.DC.TblSummary[0] = ""
		$syncHash.DC.TotalProgress[0] = 0.0
		$syncHash.TiO.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.TiFilterMatch.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.TiMDG.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.TiMDH.Visibility = [System.Windows.Visibility]::Collapsed
		$syncHash.GridInfo.Visibility = [System.Windows.Visibility]::Hidden
	} )
	$syncHash.User = $null
	$syncHash.Data.Folders.Clear()
	$syncHash.Data.FullFileList.Clear()
	$syncHash.Data.ErrorHashes.Clear()
	$syncHash.Data.ScannedForVirus.Clear()
	$syncHash.OtherFolderPermissions.Clear()
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

	$syncHash.CbSetAccountDisabled.Content = $syncHash.Data.msgTable.ContentCbSetAccountDisabled

	if ( $syncHash.TbCaseNr.Text -match "^(RITM|INC)\d{7}$" )
	{
		$syncHash.TbCaseNr.BorderBrush = "#FFABADB3"
	}
	else
	{
		$syncHash.TbCaseNr.BorderBrush = "Red"
	}

	try
	{
		$a = Get-ADUser $syncHash.TbID.Text -Properties HomeDirectory -ErrorAction Stop
		$syncHash.User = [pscustomobject]@{
			Name = $a.Name
			HomeDirectory = $a.HomeDirectory
			SamAccountName = $a.SamAccountName
			Enabled = $a.Enabled
		}
		$syncHash.DC.TblUser[0] = $syncHash.User.Name

		$syncHash.TbId.BorderBrush = "#FFABADB3"
		$syncHash.CbSetAccountDisabled.IsChecked = -not $syncHash.User.Enabled
		if ( $syncHash.CbSetAccountDisabled.IsChecked )
		{ $syncHash.CbSetAccountDisabled.Content += " ($( $syncHash.Data.msgTable.StrUserAccountAlreadyLocked ))" }

		$syncHash.DC.GridInput[1] = "{0}: {1}`n{2}: {3}" -f $syncHash.Data.msgTable.StrLogMsgId, $syncHash.TbID.Text, $syncHash.Data.msgTable.StrLogMsgCaseNr, $syncHash.TbCaseNr.Text
	}
	catch
	{
		$syncHash.TbId.BorderBrush = "Red"
		$syncHash.CbSetAccountDisabled.Content += " ($( $syncHash.Data.msgTable.StrErrUserNotFound ))"
	}
}

####################### Script start
Add-Type -AssemblyName PresentationFramework
Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]

$controls = New-Object Collections.ArrayList
[void]$controls.Add( @{ CName = "BtnAbort"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnAbort } ) } )
[void]$controls.Add( @{ CName = "BtnCloseStreamsList"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnCloseStreamsList } ) } )
[void]$controls.Add( @{ CName = "BtnCreateQuestion"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnCreateQuestion } ) } )
[void]$controls.Add( @{ CName = "BtnOpenFolder"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnOpenFolder } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentBtnOpenFolderTT } ) } )
[void]$controls.Add( @{ CName = "BtnOpenSummary"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnOpenSummary } ) } )
[void]$controls.Add( @{ CName = "BtnPrep"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnPrep } ) } )
[void]$controls.Add( @{ CName = "BtnReset"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnReset } ; @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Visible } ) } )
[void]$controls.Add( @{ CName = "BtnRunVirusScan"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnRunVirusScan } ) } )
[void]$controls.Add( @{ CName = "BtnShowFileStreams"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnShowFileStreams } ) } )
[void]$controls.Add( @{ CName = "BtnStartSearch"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnStartSearch } ; @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ; @{ PropName = "IsEnabled"; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "BtnSearchExt"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnSearchExt } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentBtnSearchExtTT } ) } )
[void]$controls.Add( @{ CName = "BtnSearchFileName"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnSearchFileName } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentBtnSearchFileNameTT } ) } )
[void]$controls.Add( @{ CName = "CbGroupExtensions"; Props = @( @{ PropName = "IsChecked"; PropVal = $true } ) } )
[void]$controls.Add( @{ CName = "CbSetAccountDisabled"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentCbSetAccountDisabled } ) } )
[void]$controls.Add( @{ CName = "DatePickerStart"; Props = @( @{ PropName = "SelectedDate"; PropVal = ( Get-Date ).AddDays( -14 ) } ) } )
[void]$controls.Add( @{ CName = "DgFolderList"; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "DgtcStreamsDataSize"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentDgtcStreamsDataSize } ) } )
[void]$controls.Add( @{ CName = "DgtcStreamsName"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentDgtcStreamsName } ) } )
[void]$controls.Add( @{ CName = "GridInput"; Props = @( @{ PropName = "IsEnabled"; PropVal = $true } ; @{ PropName = "Tag"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "GridWaitProgress"; Props = @( @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Hidden } ) } )
[void]$controls.Add( @{ CName = "LvFilterMatch"; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "LvAC"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLvColumnCreated } ) } )
[void]$controls.Add( @{ CName = "LvAN"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLvColumnName } ) } )
[void]$controls.Add( @{ CName = "LvAS"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLvColumnSize } ) } )
[void]$controls.Add( @{ CName = "LvAU"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLvColumnUpdated } ) } )
[void]$controls.Add( @{ CName = "LvAO"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLvColumnOwner } ) } )
[void]$controls.Add( @{ CName = "LvAStr"; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLvColumnStreams } ) } )
[void]$controls.Add( @{ CName = "LvMultiDotsG"; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "LvMultiDotsH"; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new() } ) } )
[void]$controls.Add( @{ CName = "RbAll"; Props = @( @{ PropName = "IsChecked"; PropVal = $false } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentRbAllToolTip } ; @{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void]$controls.Add( @{ CName = "RbLatest"; Props = @( @{ PropName = "ToolTip"; PropVal = $msgTable.ContentrbLatestToolTip } ) } )
[void]$controls.Add( @{ CName = "RbPrevDate"; Props = @( @{ PropName = "IsChecked"; PropVal = $false } ; @{ PropName = "ToolTip"; PropVal = $msgTable.ContentRbPrevDateToolTip } ; ) } )
[void]$controls.Add( @{ CName = "TblCaseNrTitle"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblCaseNrTitle } ) } )
[void]$controls.Add( @{ CName = "TblCbExpandGroups"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblCbExpandGroups } ) } )
[void]$controls.Add( @{ CName = "TblCbGroupExtensions"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblCbGroupExtensions } ) } )
[void]$controls.Add( @{ CName = "TblFileCount"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TblFileCountTitle"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblFileCountTitle } ) } )
[void]$controls.Add( @{ CName = "TblFiles"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TblFilterMatch"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblFilterMatch } ) } )
[void]$controls.Add( @{ CName = "TblFolderCountTitle"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblFolderCountTitle } ) } )
[void]$controls.Add( @{ CName = "TblFolderCount"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TblFolderListTitle"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblFolderListTitle } ) } )
[void]$controls.Add( @{ CName = "TblIdTitle"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblIdTitle } ) } )
[void]$controls.Add( @{ CName = "TblMDG"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblMDG } ) } )
[void]$controls.Add( @{ CName = "TblMDH"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblMDH } ) } )
[void]$controls.Add( @{ CName = "TblO"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblO } ) } )
[void]$controls.Add( @{ CName = "TblGroupInputTitle"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblGroupInputTitle } ) } )
[void]$controls.Add( @{ CName = "TblGroupSearchSettingsTitle"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblGroupSearchSettingsTitle } ) } )
[void]$controls.Add( @{ CName = "TblGroupSummaryTitle"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblGroupSummaryTitle } ) } )
[void]$controls.Add( @{ CName = "TblPrevDateText"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblPrevDateText } ) } )
[void]$controls.Add( @{ CName = "TblRbAllText"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblRbAllText } ) } )
[void]$controls.Add( @{ CName = "TblRbLatestText"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblRbLatest } ) } )
[void]$controls.Add( @{ CName = "TblStreamsListInfo"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentStreamsListInfo } ) } )
[void]$controls.Add( @{ CName = "TblSummary"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TblSummaryTitle"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblSummaryTitle } ) } )
[void]$controls.Add( @{ CName = "TblUser"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TblUserTitle"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblUserTitle } ) } )
[void]$controls.Add( @{ CName = "TblValuesTitle"; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblValuesTitle } ) } )
[void]$controls.Add( @{ CName = "TbCaseNr"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TbID"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "TiO"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentTiOHeader } ) } )
[void]$controls.Add( @{ CName = "TiFiles"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentTiFilesHeader } ) } )
[void]$controls.Add( @{ CName = "TiFilterMatch"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentTiFilterMatchHeader } ) } )
[void]$controls.Add( @{ CName = "TiMDG"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentTiMDGHeader } ) } )
[void]$controls.Add( @{ CName = "TiMDH"; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentTiMDHHeader } ) } )
[void]$controls.Add( @{ CName = "TotalProgress"; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Hidden } ) } )
[void]$controls.Add( @{ CName = "TbQuestion"; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void]$controls.Add( @{ CName = "Window"; Props = @( @{ PropName = "Title"; PropVal = "" } ) } )

$syncHash = CreateWindowExt $controls

$syncHash.Data.ErrorHashes = @()
$syncHash.Data.Folders = [System.Collections.ArrayList]::new()
$syncHash.Data.FullFileList = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Window.Resources['CvsAllFiles'].Source = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$syncHash.Data.msgTable = $msgTable
$syncHash.Data.ScannedForVirus = [System.Collections.ArrayList]::new()
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
		$syncHash.DC.TbQuestion[0] = "$( $syncHash.User.Name ) $( $syncHash.Data.msgTable.StrQuestion1 ) $( $syncHash.DC.TbCaseNr[0] ).`r`n$( $syncHash.Data.msgTable.StrQuestion2 )`r`n$( $syncHash.Data.msgTable.StrQuestion3 )`r`n`r`n$( [string]( $syncHash.OtherFolderPermissions | Select-Object -Unique | Sort-Object ) )"
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.TiO.Visibility = [System.Windows.Visibility]::Visible } )
	}
} )

# Create an observable collection for text as output that will respond to being updated
# Once updated, write to output-fil
$syncHash.OutputContent = New-Object System.Collections.ObjectModel.ObservableCollection[Object]
$syncHash.OutputContent.Add( "" )
$syncHash.OutputContent.Add_CollectionChanged( {
	if ( $syncHash.OutputContent.Item( 0 ) -ne "" )
	{
		$syncHash.DC.TblSummary[0] = WriteOutput -Output "$( $syncHash.OutputContent.Item( 0 ) )"
		WriteLogTest -Text $syncHash.logText -UserInput $syncHash.DC.GridInput[1] -Success $true -OutputPath $syncHash.DC.TblSummary[0] | Out-Null

		TextToSpeech -Text $syncHash.Data.msgTable.StrFileSearchFinished
		$syncHash.DC.TotalProgress[0] = 0.0
	}
} )

# Abort current filesearch
$syncHash.BtnAbort.Add_Click( {
	$syncHash.Jobs, $syncHash.FilesJob | ForEach-Object { $_.PS.Stop(); $_.PS.Dispose() }
	$syncHash.Jobs.Clear()

	$syncHash.DC.DgFolderList[0].Clear()
	$syncHash.DC.GridWaitProgress[0] = [System.Windows.Visibility]::Hidden
	$syncHash.DC.TotalProgress[1] = [System.Windows.Visibility]::Hidden
	$syncHash.DC.BtnPrep[2] = $true
	$syncHash.DC.GridInput[0] = $true
	$syncHash.DC.Window[0] = ""
	$syncHash.DC.TotalProgress[0] = 0.0
	WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgFileSearchAborted -UserInput $syncHash.DC.GridInput[1] -Success $true | Out-Null
} )

#
$syncHash.BtnCloseStreamsList.Add_Click( {
	#$syncHash.StreamsList.DataContext = $null
	$syncHash.StreamsList.Visibility = [System.Windows.Visibility]::Hidden
} )

# Copy text for question to clipboard
$syncHash.BtnCreateQuestion.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $false, $false ).psobject.BaseObject
	$syncHash.DC.TbQuestion[0] | clip
	ShowMessageBox $syncHash.Data.msgTable.StrQuestionCopied
	WriteLogTest -Text "$( $syncHash.Data.msgTable.StrLogQuestionCopied )`n**************`n$( $syncHash.DC.TbQuestion[0] )`n**************" -UserInput $syncHash.DC.GridInput[1] | Out-Null
} )

# Opens the folder selected file is located in
$syncHash.BtnOpenFolder.Add_Click( {
	$syncHash.ActiveListView.SelectedItems.TT | ForEach-Object {
		if ( $_ -match "^H:\\" ) { $Path = $_ -replace "^H:", $syncHash.User.HomeDirectory }
		else { $Path = $_ }
		Start-Process explorer -ArgumentList "/select, $Path"
	}
	WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgOpenFolder -UserInput "$( $syncHash.DC.GridInput[1] )`n$( $syncHash.ActiveListView.SelectedItems.TT )" -Success $true
} )

# Opens the summaryfile
$syncHash.BtnOpenSummary.Add_Click( { & 'C:\Program Files (x86)\Notepad++\notepad++.exe' $syncHash.DC.TblSummary[0] } )

# Prepare for filesearch by creating jobs and retrieving folderlist
$syncHash.BtnPrep.Add_Click( {
	PrepGetFolders
	PrepGetFiles
	$this.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.BtnStartSearch[1] = [System.Windows.Visibility]::Visible
	GetFolders
	WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgFolderSearch -UserInput $syncHash.DC.GridInput[1] -Success $true
} )

# Reset arrays, values and controls to default values
$syncHash.BtnReset.Add_Click( {
	if ( -not $syncHash.User.Enabled )
	{
		if ( ( ShowMessageBox -Text $syncHash.Data.msgTable.StrEnableUser -Button ( [System.Windows.MessageBoxButton]::YesNo ) ) -eq "Yes" )
		{
			Set-ADUser -Identity $syncHash.User.SamAccountName -Enabled $true
		}
	}

	Reset
	$syncHash.DC.GridInput[0] = $true
	$syncHash.DC.BtnStartSearch[1] = [System.Windows.Visibility]::Collapsed
	$syncHash.BtnPrep.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.TbCaseNr.Focus()
	$syncHash.GridActionButtons.IsEnabled = $false
} )

# Start a virus scan of selected file
$syncHash.BtnRunVirusScan.Add_Click( {
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

			if ( $PathToScan.FullName -match "\`$Recycle Bin" )
			{ ShowMessageBox -Text "$( $PathToScan.FullName )`n$( $syncHash.Data.msgTable.MsgRecycleBin )" }
			else
			{
				$Shell = New-Object -Com Shell.Application
				$ShellFolder = $Shell.NameSpace( $PathToScan.Directory.FullName )
				$ShellFile = $ShellFolder.ParseName( $PathToScan.Name )
				$ShellFile.InvokeVerb( $syncHash.Data.msgTable.StrVerbVirusScan )
				[void] $syncHash.Data.ScannedForVirus.Add( [pscustomobject]@{ Path = $PathToScan.FullName ; Time = ( Get-Date ) } )
			}
		}
		WriteLogTest -Text $syncHash.Data.msgTable.LogScannedFile -UserInput "$( $syncHash.DC.GridInput[1] )`n$( $syncHash.Data.msgTable.LogScannedFileTitle ) $( $syncHash.ActiveListView.SelectedItems.TT )" -Success $true | Out-Null
		$OFS = "`n"
		Set-Content -Value @"
$( $syncHash.OutputContent.Item( 0 ) )

***********************
$( $syncHash.Data.msgTable.StrLogMsgFilesScannedForVirus )

$( [string]( $syncHash.Data.ScannedForVirus | ForEach-Object { "$( $_.Path ) ($( Get-Date $_.Time -f "yyyy-MM-dd HH:mm:ss" ))" } ) )
"@ -Path $syncHash.DC.TblSummary[0]
	}
} )

# Search on Google for the fileextension
$syncHash.BtnSearchExt.Add_Click( {
	$SelectedExtensions = $syncHash.ActiveListView.SelectedItems.FileType | Select-Object -Unique
	foreach ( $Ext in $SelectedExtensions )
	{
		Start-Process chrome "https://www.google.com/search?q=fileextension+$( $Ext )"
	}
	WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgSearchExt -UserInput "$( $syncHash.DC.GridInput[1] )`n$SelectedExtensions" -Success $true
} )

# Search on Google for the filename
$syncHash.BtnSearchFileName.Add_Click( {
	$SelectedNames = $syncHash.ActiveListView.SelectedItems.Name | Select-Object -Unique
	foreach ( $Name in $SelectedNames )
	{
		Start-Process chrome "https://www.google.com/search?q=`"$( $Name )`""
	}
	WriteLogTest -Text $syncHash.Data.msgTable.StrLogMsgSearchFileName -UserInput "$( $syncHash.DC.GridInput[1] )`n$SelectedNames" -Success $true
} )

# List filestreams
$syncHash.BtnShowFileStreams.Add_Click( {
	$syncHash.TblStreamsListFileName.Text = $syncHash.LvAllFiles.SelectedItem.TT -replace "H:", $syncHash.User.HomeDirectory
	$syncHash.DgStreamsList.ItemsSource = , $syncHash.LvAllFiles.SelectedItem.Streams
	$syncHash.StreamsList.Visibility = [System.Windows.Visibility]::Visible
} )

# Starts the search
$syncHash.BtnStartSearch.Add_Click( {
	$this.IsEnabled = $false
	$syncHash.DC.TblFileCount[0] = ""
	$syncHash.Start = Get-Date
	if ( $syncHash.CbSetAccountDisabled.IsChecked )
	{
		Set-ADUser -Identity $syncHash.User.SamAccountName -Enabled $false
		$syncHash.User.Enabled = $false
	}

	GetFiles
} )

# Expand/collaps groups in datagrid
$syncHash.CbExpandGroups.Add_Checked( { $syncHash.Window.Resources.ExpandGroups = $true } )
$syncHash.CbExpandGroups.Add_Unchecked( { $syncHash.Window.Resources.ExpandGroups = $false } )

$syncHash.LvAllFiles.Add_SelectionChanged( { $syncHash.GridActionButtons.IsEnabled = $this.SelectedItems.Count -gt 0 } )
$syncHash.LvMultiDotsH.Add_SelectionChanged( { $syncHash.GridActionButtons.IsEnabled = $this.SelectedItems.Count -gt 0 } )
$syncHash.LvMultiDotsG.Add_SelectionChanged( { $syncHash.GridActionButtons.IsEnabled = $this.SelectedItems.Count -gt 0 } )

# Columnheader is clicked, sort items according to the columns values
$syncHash.LvAN.Add_Click( { Resort "LvAllFiles" "Name" } )
$syncHash.LvAC.Add_Click( { Resort "LvAllFiles" "CreationTime" } )
$syncHash.LvAU.Add_Click( { Resort "LvAllFiles" "LastWriteTime" } )
$syncHash.LvHN.Add_Click( { Resort "LvMultiDotsH" "Name" } )
$syncHash.LvHC.Add_Click( { Resort "LvMultiDotsH" "CreationTime" } )
$syncHash.LvHU.Add_Click( { Resort "LvMultiDotsH" "LastWriteTime" } )
$syncHash.LvGN.Add_Click( { Resort "LvMultiDotsG" "Name" } )
$syncHash.LvGC.Add_Click( { Resort "LvMultiDotsG" "CreationTime" } )
$syncHash.LvGU.Add_Click( { Resort "LvMultiDotsG" "LastWriteTime" } )

# Radiobutton for all files is selected, set startdate to two months ago
$syncHash.RbAll.Add_Checked( { $syncHash.DC.DatePickerStart[0] = ( Get-Date ).AddDays( -60 ) } )

# Radiobutton for files updated in the last two weeks, is selected
$syncHash.RbLatest.Add_Checked( { $syncHash.DC.DatePickerStart[0] = ( Get-Date ).AddDays( -14 ) } )

# Set selected listview
$syncHash.LvAllFiles.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )
$syncHash.LvMultiDotsH.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )
$syncHash.LvMultiDotsG.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )
$syncHash.LvFilterMatch.Add_IsVisibleChanged( { if ( $this.IsVisible ) { $syncHash.ActiveListView = $this } } )

# Text was entered, set user input text
$syncHash.TbCaseNr.Add_TextChanged( { UpdateUserInput } )
$syncHash.TbId.Add_TextChanged( { UpdateUserInput } )

# Progress for gettings files have updated
$syncHash.TotalProgress.Add_ValueChanged( {
	if ( $this.Value -eq $this.Maximum -and $syncHash.Jobs.Count -gt 0 ) { ListFiles }
	elseif ( $this.Value -eq 0 ) { $this.Visibility = [System.Windows.Visibility]::Hidden }
} )

# Text for quest changed set tabitemheader to include number of folders not reachable
$syncHash.TbQuestion.Add_TextChanged( {
	$syncHash.Window.Dispatcher.Invoke( [action] {
		if ( $this.LineCount -gt 4 ) { $syncHash.DC.TiO[0] = "$( $syncHash.Data.msgTable.ContenttiOHeader ) ($( $this.LineCount - 4 ))" }
		else { $syncHash.DC.TiO[0] = $syncHash.Data.msgTable.ContenttiOHeader }
	} )
 } )

# Activate window and set focus when the window is loaded
$syncHash.Window.Add_Loaded( {
	$syncHash.Window.Activate()

	$syncHash.TbCaseNr.Focus()
	$syncHash.CbExpandGroups.IsChecked = $syncHash.Window.Resources.ExpandGroups
	$syncHash.ActiveListView = $syncHash.lvAllFiles
	$syncHash.RbLatest.IsChecked = $true
} )

[void] $syncHash.Window.ShowDialog()
$global:syncHash = $syncHash
[System.GC]::Collect()
