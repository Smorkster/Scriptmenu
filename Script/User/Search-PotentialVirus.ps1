<#
.Synopsis Search for potential viruses [BO]
.Requires Role_Servicedesk_Backoffice
.Description Lists all files in folders a given user have accespermission to.
.Author Someone
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
		$syncHash.UserName = $a.Name
		$syncHash.UserHomeDirectory = $a.HomeDirectory
		$syncHash.UserSamAccountName = $a.SamAccountName
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
		$syncHash.DC.lblUser[0] = $syncHash.UserName
		$syncHash.DC.spInfo[0] = [System.Windows.Visibility]::Visible
		$syncHash.logText = $logText
		GetFolders
	}
	else
	{
		ShowMessageBox -Text $message.Trim() -Icon "Stop"
		if ( $message -match $syncHash.Data.msgTable.ErrInvalidID ) { $syncHash.tbID.Focus() }
		else { $syncHash.tbCaseNr.Focus() }
		$logText += $message
		WriteLog -LogText $logText | Out-Null
		$syncHash.Window.Resources.Enable = $true
	}
}

################################
# Get the folders and list files
function GetFolders
{
	return ( [powershell]::Create().AddScript( { param ( $syncHash )
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.WGettingFolders
		$syncHash.Folders = New-Object System.Collections.ArrayList
		$syncHash.Folders.Add( @( $syncHash.UserHomeDirectory, "H:" ) )
		$GGroups = @()
		$pGroups = Get-ADPrincipalGroupMembership $syncHash.UserSamAccountName | Where-Object { $_.SamAccountName -notmatch "_R$" }

		if ( $GaiaGroups = $pGroups | Where-Object { $_.SamAccountName -notlike "*_org_*" } | Where-Object { $_.SamAccountName -ne "Domain Users" } | Select-Object -ExpandProperty SamAccountName | Sort-Object )
		{
			$GaiaGroups | Sort-Object | ForEach-Object { $GGroups += ( Get-ADGroup $_ -Properties Description | Select-Object Name, Description ) }
		}
		if ( $OrgGroups = $pGroups | Where-Object { $_.SamAccountName -like "*_org_*" } | Select-Object -ExpandProperty SamAccountName | Sort-Object )
		{
			$OrgGroups | Get-ADPrincipalGroupMembership | Sort-Object | ForEach-Object { $GGroups += ( Get-ADGroup $_ -Properties Description | Select-Object Name, Description ) }
		}

		# Filter folders 
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.WFilteringFolders
		$syncHash.DC.TotalProgress[1] = [System.Windows.Visibility]::Visible

		$ticker = 0
		foreach ( $i in ( $GGroups | Where-Object { $_.Name -notmatch "_R$" } ) )
		{
			if ( $i.Description -match "\\\\dfs\\gem" )
			{
				$p = ( ( $i.Description -split " på " )[1] -split "\." )[0].Replace( "\\dfs\gem$", "G:" )
				try
				{
					Get-ChildItem $p -ErrorAction Stop | Out-Null
					$syncHash.Folders.Add( @( $p, $i.Name ) )
				}
				catch
				{
					# No permission for scriptuser
					WriteErrorLog -LogText $_
					$syncHash.OtherFolderPermissions.Add( $i.Name )
				}
			}
			elseif ( $i.Description -match "\\\\dfs\\app" )
			{
				$syncHash.OtherFolderPermissions.Add( $i.Name )
			}
			$syncHash.DC.TotalProgress[0] = [double]( ( $ticker / $GGroups.Count ) * 100 )
			$ticker++
		}

		$syncHash.DC.TotalProgress[0] = 0.0
		$syncHash.DC.Window[0] = $syncHash.Data.msgTable.WGettingFiles

		if ( $syncHash.DC.rbLatest[0] )
		{
			$jobs = New-Object System.Collections.ArrayList
			foreach ( $Folder in $syncHash.Folders )
			{
				$p = [powershell]::Create().AddScript( { param ( $syncHash, $Folder )
					Get-ChildItem2 $Folder[0] -File -Recurse | Where-Object { $_.LastWriteTime -ge $syncHash.DC.DatePickerStart[1] } | Select-Object -Property `
						@{ Name = "Name"; Expression = { $_.FullName.Replace( $Folder[0], ".." ) } }, `
						@{ Name = "Created"; Expression = { ( Get-Date $_.CreationTime -f "yyyy-MM-dd hh:mm:ss" ) } }, `
						@{ Name = "FileType"; Expression = { $ft = $_.Extension.Replace( ".", "" ); foreach ( $f in $syncHash.fileFilter ) { if ( $_.FullName -match $f ) { $ft = $syncHash.Data.msgTable.ContentFilterTitle } } ; $ft } }, `
						@{ Name = "TT"; Expression = { $_.FullName.Replace( $syncHash.UserHomeDirectory , "H:" ) } }, `
						@{ Name = "Updated"; Expression = { ( Get-Date $_.LastWriteTime -f "yyyy-MM-dd hh:mm:ss" ) } } | Select-Object -Property `
						Name, `
						Created, `
						FileType, `
						TT, `
						Updated, `
						@{ Name = "SortOrder"; Expression = { if ( $_.FileType -eq $syncHash.Data.msgTable.ContentFilterTitle ) { return 0 } ; return 1 } } | ForEach-Object { $syncHash.Data.FullFileList.Add( $_ ) }
						$syncHash.DC.lblFileCount[0] = $syncHash.Data.FullFileList.Count
				} ).AddArgument( $syncHash ).AddArgument( $Folder )
				$jobs.Add( [pscustomobject]@{ PS = $p; Handle = $p.BeginInvoke() } )
			}

			$syncHash.DC.Window[0] = $syncHash.Data.msgTable.WWaitGettingFiles
			do {
				$c = ( $jobs.Handle.IsCompleted -eq $true ).Count
				$syncHash.DC.TotalProgress[0] = [double] ( ( $c / $jobs.Count ) * 100 )
				Start-Sleep 1
			} until ( $c -eq $jobs.Count )
			$jobs | ForEach-Object { $_.PS.Runspace.Close() ; $_.PS.Runspace.Dispose() }
			Remove-Variable jobs
		}
		else
		{
			$ticker = 1
			foreach ( $Folder in $syncHash.Folders )
			{
				$syncHash.DC.Window[0] = "$( $syncHash.Data.msgTable.WGettingFilesTitle ) '$( $Folder[0] )'"
				Get-ChildItem2 $Folder[0] -File -Recurse | Where-Object { $_.LastWriteTime -ge $syncHash.DC.DatePickerStart[1] } | Select-Object -Property `
					@{ Name = "Name"; Expression = { $_.FullName.Replace( $Folder[0], ".." ) } }, `
					@{ Name = "Created"; Expression = { ( Get-Date $_.CreationTime -f "yyyy-MM-dd hh:mm:ss" ) } }, `
					@{ Name = "FileType"; Expression = { $ft = $_.Extension.Replace( ".", "" ); foreach ( $f in $syncHash.fileFilter ) { if ( $_.Extension -match $f ) { $ft = $syncHash.Data.msgTable.ContentFilterTitle } } ; $ft } }, `
					@{ Name = "TT"; Expression = { $_.FullName.Replace( $syncHash.UserHomeDirectory , "H:" ) } }, `
					@{ Name = "Updated"; Expression = { ( Get-Date $_.LastWriteTime -f "yyyy-MM-dd hh:mm:ss" ) } } | Select-Object -Property `
					Name, `
					Created, `
					FileType, `
					TT, `
					Updated, `
					@{ Name = "SortOrder"; Expression = { if ( $_.FileType -eq $syncHash.Data.msgTable.ContentFilterTitle ) { return 0 } ; return 1 } } | ForEach-Object { $syncHash.Data.FullFileList.Add( $_ ) }
				$syncHash.DC.lblFileCount[0] = $syncHash.Data.FullFileList.Count
				$syncHash.DC.TotalProgress[0] = [double] ( ( $ticker / $jobs.Count ) * 100 )
				$ticker++
			}
		}

		$List = [System.Windows.Data.ListCollectionView]$syncHash.Data.FullFileList
		$List2 = [System.Windows.Data.ListCollectionView]( $syncHash.Data.FullFileList | Where-Object { $_.TT -match "^H:\\" } | Where-Object { ( ( $_.Name.Split( "\" ) | Select-Object -Last 1 ).Split( "." ) ).Count -gt 2 } )
		$List3 = [System.Windows.Data.ListCollectionView]( $syncHash.Data.FullFileList | Where-Object { $_.TT -match "^G:\\" } | Where-Object { ( ( $_.Name.Split( "\" ) | Select-Object -Last 1 ).Split( "." ) ).Count -gt 2 } )

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
		$syncHash.DC.lvAllFiles[0] = $List

		$List2.GroupDescriptions.Add( $groupBy )
		$List2.SortDescriptions.Add( $sort1 )
		$List2.SortDescriptions.Add( $sort2 )
		$List2.SortDescriptions.Add( $sort3 )
		$syncHash.DC.lvMultiDotsH[0] = $List2

		$List3.GroupDescriptions.Add( $groupBy )
		$List3.SortDescriptions.Add( $sort1 )
		$List3.SortDescriptions.Add( $sort2 )
		$List3.SortDescriptions.Add( $sort3 )
		$syncHash.DC.lvMultiDotsG[0] = $List3

		if ( $syncHash.DC.lvAllFiles.GetItemAt( 0 ).SortOrder -eq 0 ) { $ofs = ", "; $syncHash.DC.lblFiles[0] += "`n$( $syncHash.Data.msgTable.ContentLblFilterTitle ):`n$( [string]$syncHash.fileFilter )" }

		$syncHash.DC.Window[0] = ""
		$syncHash.DC.TotalProgress[1] = [System.Windows.Visibility]::Hidden

		$ofs = "`n"
		$output = @"
$( $syncHash.Data.msgTable.StrOutput1 )

$( $syncHash.Data.msgTable.StrOutput2 ): $( $syncHash.UserName )
$( $syncHash.Data.msgTable.StrOutput3 ): $( $syncHash.DC.tbCaseNr[0] )
$( if ( $syncHash.DC.rbLatest[0] ) { $syncHash.Data.msgTable.StrOutputTimeline1 }
elseif ( $syncHash.DC.rbPrevDate[0] ) { "$( $syncHash.Data.msgTable.StrOutputTimeline2 ) $( $syncHash.DC.DatePickerStart[1].ToShortDateString() )" }
else { $syncHash.Data.msgTable.StrOutputTimeline3 } )

***********************
$( $syncHash.Data.msgTable.StrOutput4 ) $( $syncHash.Data.FullFileList.Count )


***********************
$( $syncHash.Data.msgTable.StrOutputTitle1 ):

$( [string]( $syncHash.Folders | ForEach-Object { "$( $_[0] ) ( $( $_[1] ) )" } ) )

***********************
$( $syncHash.Data.msgTable.StrOutputTitle2 )

$( [string]( $syncHash.DC.lvAllFiles[0].TT | Sort-Object ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitle3 ) H:

$( [string]( $syncHash.DC.lvMultiDotsH[0].TT ) )


***********************
$( $syncHash.Data.msgTable.StrOutputTitle4 ) G:

$( [string]( $syncHash.DC.lvMultiDotsG[0].TT ) )

***********************
$( $syncHash.Data.msgTable.StrOutputTitle5 ):

$( [string]( $split = $syncHash.DC.txtQuestion[0].Split( "`n" ) )
$split[4..$( $split.Count - 1 )] )
"@
		$syncHash.OutputContent.Item( 0 ) = $output

		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.Window.Resources.Enable = $true } )
		$syncHash.DC.btnSearch[0] = $syncHash.Data.msgTable.ContentBtnReset
	} ).AddArgument( $syncHash ) ).BeginInvoke()
}

#########################
# Opens the folder a file
function OpenFileFolder
{
	explorer ( Get-Item ( ( [pscustomobject] $syncHash.menuOpenfolder.DataContext ).TT -replace "^H:", $syncHash.UserHomeDirectory ) ).Directory.FullName
}

########################################
# Search on Google for the fileextension
function SearchExtension
{
	Start-Process chrome "https://www.google.com/search?q=fileextension+$( ( [pscustomobject] $syncHash.menuSearchExtension.DataContext ).FileType )"
}

###################################
# Search on Google for the filename
function SearchFileName
{
	Start-Process chrome "https://www.google.com/search?q=$( [string] ( ( [pscustomobject] $syncHash.menuSearchFileName.DataContext ).Name.Split( "\" ) | Select-Object -Last 1 ) )"
}

####################
# Reset all controls
function Reset
{
	$syncHash.Window.Dispatcher.Invoke( [action] {
		$syncHash.Folders = $null
		$syncHash.Data.FullFileList.Clear()
		$syncHash.DC.lvAllFiles[0] = [System.Windows.Data.ListCollectionView]@()
		$syncHash.DC.lvMultiDotsH[0] = [System.Windows.Data.ListCollectionView]@()
		$syncHash.DC.lvMultiDotsG[0] = [System.Windows.Data.ListCollectionView]@()
		$syncHash.DC.rbLatest[0] = $true
		$syncHash.DC.txtQuestion[0] = $syncHash.DC.tbCaseNr[0] = $syncHash.DC.tbID[0] = ""
		$syncHash.DC.spInfo[0] = [System.Windows.Visibility]::Hidden
		$syncHash.DC.spSummary[0] = [System.Windows.Visibility]::Hidden
		$syncHash.OutputContent.Item( 0 ) = ""
		$syncHash.OtherFolderPermissions.Clear()
		$syncHash.UserHomeDirectory = ""
		$syncHash.UserName = ""
		$syncHash.UserSamAccountName = ""
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
	$syncHash.DC.$listview[0] = $List
}

####################### Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force

$controlPropertyList = New-Object Collections.ArrayList
[void]$controlPropertyList.Add( @{ CName = "TotalProgress"
	Props = @(
		@{ PropName = "Value"; PropVal = [double] 0 }
		@{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Hidden }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lvAllFiles"
	Props = @(
		@{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lvMultiDotsH"
	Props = @(
		@{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lvMultiDotsG"
	Props = @(
		@{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) }
	) } )
[void]$controlPropertyList.Add( @{ CName = "rbLatest"
	Props = @(
		@{ PropName = "IsChecked"; PropVal = $true }
		@{ PropName = "Content"; PropVal = $msgTable.ContentrbLatest }
		@{ PropName = "ToolTip"; PropVal = $msgTable.ContentrbLatestToolTip }
	) } )
[void]$controlPropertyList.Add( @{ CName = "Window"
	Props = @(
		@{ PropName = "Title"; PropVal = "" }
	) } )
[void]$controlPropertyList.Add( @{ CName = "txtQuestion"
	Props = @(
		@{ PropName = "Text"; PropVal = "" }
	) } )
[void]$controlPropertyList.Add( @{ CName = "tiO"
	Props = @(
		@{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Hidden }
		@{ PropName = "Header"; PropVal = $msgTable.ContenttiOHeader }
	) } )
[void]$controlPropertyList.Add( @{ CName = "tbCaseNr"
	Props = @(
		@{ PropName = "Text"; PropVal = "" }
	) } )
[void]$controlPropertyList.Add( @{ CName = "tbID"
	Props = @(
		@{ PropName = "Text"; PropVal = "" }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lblIDTitle"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblIDTitle }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lblCaseNrTitle"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblCaseNrTitle }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lblValuesTitle"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblValuesTitle }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lblFiles"
	Props = @(
		@{ PropName = "Content"; PropVal = "" }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lblMDG"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblMDG }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lblMDH"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblMDH }
	) } )
[void]$controlPropertyList.Add( @{ CName = "tiFiles"
	Props = @(
		@{ PropName = "Header"; PropVal = $msgTable.ContenttiFilesHeader }
	) } )
[void]$controlPropertyList.Add( @{ CName = "tiMDH"
	Props = @(
		@{ PropName = "Header"; PropVal = $msgTable.ContenttiMDHHeader }
	) } )
[void]$controlPropertyList.Add( @{ CName = "tiMDG"
	Props = @(
		@{ PropName = "Header"; PropVal = $msgTable.ContenttiMDGHeader }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lblUser"
	Props = @(
		@{ PropName = "Content"; PropVal = "" }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lblO"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblO }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lblFileCount"
	Props = @(
		@{ PropName = "Content"; PropVal = "" }
	) } )
[void]$controlPropertyList.Add( @{ CName = "spInfo"
	Props = @(
		@{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Hidden }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lblSummary"
	Props = @(
		@{ PropName = "Content"; PropVal = "" }
	) } )
[void]$controlPropertyList.Add( @{ CName = "btnCreateQuestion"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentbtnCreateQuestion }
	) } )
[void]$controlPropertyList.Add( @{ CName = "btnOpenSummary"
	Props = @(
		@{ PropName = "Tag"; PropVal = "" }
		@{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenSummary }
	) } )
[void]$controlPropertyList.Add( @{ CName = "spSummary"
	Props = @(
		@{ PropName = "Visibility"; PropVal = [System.Windows.Visibility]::Hidden }
	) } )
[void]$controlPropertyList.Add( @{ CName = "spInput"
	Props = @(
		@{ PropName = "IsEnabled"; PropVal = $true }
	) } )
[void]$controlPropertyList.Add( @{ CName = "rbPrevDate"
	Props = @(
		@{ PropName = "IsChecked"; PropVal = $false }
		@{ PropName = "Content"; PropVal = $msgTable.ContentrbPrevDate }
		@{ PropName = "ToolTip"; PropVal = $msgTable.ContentrbPrevDateToolTip }
	) } )
[void]$controlPropertyList.Add( @{ CName = "DatePickerStart"
	Props = @(
		@{ PropName = "IsEnabled"; PropVal = $false }
		@{ PropName = "SelectedDate"; PropVal = ( Get-Date ).AddDays( -14 ) }
	) } )
[void]$controlPropertyList.Add( @{ CName = "rbAll"
	Props = @(
		@{ PropName = "IsChecked"; PropVal = $false }
		@{ PropName = "Content"; PropVal = $msgTable.ContentrbAll }
		@{ PropName = "ToolTip"; PropVal = $msgTable.ContentrbAllToolTip }
	) } )
[void]$controlPropertyList.Add( @{ CName = "btnSearch"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentBtnSearch }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lblUserTitle"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblUserTitle }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lblFileCountTitle"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblFileCountTitle }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lblSummaryTitle"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlblSummaryTitle }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lvAN"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlvColumnName }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lvAC"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlvColumnCreated }
	) } )
[void]$controlPropertyList.Add( @{ CName = "lvAU"
	Props = @(
		@{ PropName = "Content"; PropVal = $msgTable.ContentlvColumnUpdated }
	) } )

$syncHash = CreateWindowExt $controlPropertyList

$syncHash.Data.Add( "FullFileList", ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) ) # 0 All files
$syncHash.Data.msgTable = $msgTable

$syncHash.OtherFolderPermissions = ( New-Object System.Collections.ObjectModel.ObservableCollection[object] )
$syncHash.OtherFolderPermissions.Add_CollectionChanged( {
	if ( $syncHash.OtherFolderPermissions.Count -gt 0 )
	{
		$ofs = "`n"
		$syncHash.DC.txtQuestion[0] = "$( $syncHash.UserName ) $( $syncHash.Data.msgTable.WQ1 ) $( $syncHash.DC.tbCaseNr[0] ).`r`n$( $syncHash.Data.msgTable.WQ2 )`r`n$( $syncHash.Data.msgTable.WQ3 )`r`n`r`n$( [string]( $syncHash.OtherFolderPermissions | Select-Object -Unique | Sort-Object ) )"
		$syncHash.DC.tiO[0] = [System.Windows.Visibility]::Visible
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
			$syncHash.DC.spSummary[0] = [System.Windows.Visibility]::Visible
			WriteLog -LogText "$( $syncHash.logText )`r`n`tOutput: $( $syncHash.DC.btnOpenSummary[0] )" | Out-Null
		} )
	}
} )

WriteLog -LogText $syncHash.Data.msgTable.WLStart | Out-Null

$syncHash.ScriptVar = New-Object -ComObject WScript.Shell
$syncHash.fileFilter = @( ".MYD", ".MYI", "encrypted", "vvv", ".mp3", ".exe", "Anydesk", "FileSendsuite", "Recipesearch", "FromDocToPDF", ".dll", "easy2lock" )

$syncHash.btnCreateQuestion.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$syncHash.DC.txtQuestion[0] | clip
	ShowMessageBox $syncHash.Data.msgTable.MQCopied
	WriteLog -LogText $syncHash.Data.msgTable.MQLCopied | Out-Null
} )
$syncHash.btnOpenSummary.Add_Click( { & 'C:\Program Files (x86)\Notepad++\notepad++.exe' $this.Tag } )
$syncHash.btnSearch.Add_Click( {
	if ( $syncHash.DC.btnSearch[0] -eq $syncHash.Data.msgTable.ContentBtnSearch )
	{
		$syncHash.Window.Resources.Enable = $false
		CheckReady
	}
	else
	{
		Reset
		$syncHash.DC.btnSearch[0] = $syncHash.Data.msgTable.ContentBtnSearch
		$syncHash.DC.spInput[0] = $true
	}
} )
$syncHash.lvAN.Add_Click( { Resort "lvAllFiles" "Name" } )
$syncHash.lvAC.Add_Click( { Resort "lvAllFiles" "Created" } )
$syncHash.lvAU.Add_Click( { Resort "lvAllFiles" "Updated" } )
$syncHash.lvHN.Add_Click( { Resort "lvMultiDotsH" "Name" } )
$syncHash.lvHC.Add_Click( { Resort "lvMultiDotsH" "Created" } )
$syncHash.lvHU.Add_Click( { Resort "lvMultiDotsH" "Updated" } )
$syncHash.lvGN.Add_Click( { Resort "lvMultiDotsG" "Name" } )
$syncHash.lvGC.Add_Click( { Resort "lvMultiDotsG" "Created" } )
$syncHash.lvGU.Add_Click( { Resort "lvMultiDotsG" "Updated" } )
$syncHash.menuOpenfolder.Add_Click( { OpenFileFolder } )
$syncHash.menuSearchExtension.Add_Click( { SearchExtension } )
$syncHash.menuSearchFileName.Add_Click( { SearchFileName } )
$syncHash.rbAll.Add_Checked( { $syncHash.DC.DatePickerStart[1] = [datetime]::MinValue } )
$syncHash.rbLatest.Add_Checked( { $syncHash.DC.DatePickerStart[1] = ( Get-Date ).AddDays( -14 ) } )
$syncHash.rbPrevDate.Add_Checked( { $syncHash.DC.DatePickerStart[0] = $true } )
$syncHash.rbPrevDate.Add_UnChecked( { $syncHash.DC.DatePickerStart[0] = $false } )
$syncHash.TotalProgress.Add_IsVisibleChanged( { if ( $this.Visibility -eq "Hidden" ) { $syncHash.Window.Resources.Enable = $true } } )
$syncHash.txtQuestion.Add_TextChanged( {
	if ( $this.LineCount -gt 4 ) { $syncHash.DC.tiO[1] = "$( $syncHash.Data.msgTable.ContenttiOHeader ) ($( $this.LineCount - 4 ))" }
	else { $syncHash.DC.tiO[1] = $syncHash.Data.msgTable.ContenttiOHeader }
 } )
$syncHash.Window.Add_Loaded( {
	$syncHash.Window.Activate()
	$syncHash.tbCaseNr.Focus()
} )

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash
[System.GC]::Collect()
