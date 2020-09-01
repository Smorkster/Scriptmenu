<#
.Synopsis Search for potential virus [BO] (under testing)
.Description List all files in given users homedirectory and shared folders the user have permission for. Files are listed by where it is located. Some files are listed by set filterrules.
#>

#####################################
# Add label with filename to filelist
function AddFile
{
	param ( $File )

	$item = New-Object System.Windows.Controls.Label

	if ( $File.Path -match ".lnk$")
	{
		$item.Content = "$( $File.Path )`n`tTarget: $( $ScriptVar.CreateShortCut( $File.Path ).TargetPath )"
	}
	else
	{
		$item.Content = $File.Path
	}
	$item.ToolTip = $File.Path

	if ( $File.FileMatch )
	{
		[void] $spFiltered.AddChild( $item )
	}
	elseif ( $file.Path -match $tbID.Text )
	{
		[void] $spMultiDotH.AddChild( $item )
	}
	else
	{
		[void] $spMultiDotG.AddChild( $item )
	}
}

##########################
# Check files for patterns
function CheckFiles
{
	param ( $Folder, $tempTitle )

	$ticker = 1
	$filelist = Get-ChildItem2 $Folder -File -Recurse
	if ( $cbLatest.IsChecked )
	{ $filelist = $filelist | where { $_.LastWriteTime -gt ( ( Get-Date ).Date.AddDays( -14 ) ) } }

	$nameMatches = @()

	foreach ( $file in $filelist )
	{
		$multiDot = $false
		$add = $false
		$matchedName = $false
		if ( ( $file.Name.Split( "." ) ).Count -gt 2 )
		{
			$multiDot = $true
			$add = $true
		}

		foreach ( $test in $fileFilter )
		{
			if ( $file.Name -like "*$test*" )
			{
				$matchedName = $true
				$nameMatches += $test
				$Script:filteredFiles += $file.FullName
				$add = $true
				
			}
		}

		if ( $add )
		{
			AddFile ( [pscustomobject]@{ Name = $file.Name; Path = $file.FullName; MultiDot = $multiDot; FileMatch = $matchedName } )
		}
	}

	return $nameMatches
}

###################################################################
# Checks if necessary values are given, if so enabled search-button
function CheckReady
{
	Reset
	$tbID.Focus()
	$message = ""
	if ( -not ( ( $tbCaseNr.Text -match "RITM\d{7}" ) -or ( $tbCaseNr.Text -match "INC\d{7}" ) ) )
	{
		$message += "A valid casenumber must be given."
	}

	if ( $( try { $User = Get-ADUser $tbID.Text -Properties HomeDirectory } catch {} ) )
	{
		$message += "`nNo account was found with given id.`nCorrect and try again."
	}

	$logText = "$( $tbCaseNr.Text ) - $( $tbID.Text )"
	if ( $message -eq "" )
	{
		CreateQuestion
		$outputFile = GetFolders
		$logText += "`r`n`tOutput: $outputFile"
	}
	else
	{
		ShowMessageBox -Text $message.Trim() -Icon "Stop"
		$logText += $message
	}
	WriteToLog $logText
}

##################################################
# Enters question for admins, to be sent if needed
function CreateQuestion
{
	$txtQuestion.Text = "$( $User.Name ) have reported potential virus in $( $tbCaseNr.Text ).`r`nFolders have been investigated, but we lack permission for these folders.`r`n"
}

##############################################################
# Filter out the fileextentions and names that have been found
# For each found, create a checkbox
function FilterFilters
{
	$filterList = $spFilters.Children | where { $_.IsChecked }
	$list = @()

	if ( $filterList.Count -eq 0 )
	{
		$list = $Script:filteredFiles
	}
	else
	{
		foreach ( $i in $filterList )
		{
			$list += $Script:filteredFiles | where { $_ -match $i.Content }
		}
	}

	$spFiltered.Children.Clear()
	foreach ( $i in ( $list | select -Unique ) )
	{
		AddFile ( [pscustomobject]@{ Path = $i; FileMatch = $true } )
	}
}

##########################################
# Get shared folders the user have permissions to
function GetCommonFolders
{
	$GGroups = @()
	$FolderList = New-Object System.Collections.ArrayList
	$n = @()
	$pGroups = Get-ADPrincipalGroupMembership $tbID.Text

	if ( $GaiaGroups = $pGroups | where { $_.SamAccountName -notlike "*_org_*" } | where { $_.SamAccountName -ne "Domain Users" } | select -ExpandProperty SamAccountName | sort )
	{
		$GaiaGroups | sort | foreach { $GGroups += ( Get-ADGroup $_ -Properties Description ) }
	}
	if ( $OrgGroups = $pGroups | where { $_.SamAccountName -like "*_org_*" } | select -ExpandProperty SamAccountName | sort )
	{
		$OrgGroups | Get-ADPrincipalGroupMembership | sort | foreach { $GGroups += ( Get-ADGroup $_ -Properties Description ) }
	}

	$Window.Title += ", filtering folders"
	foreach ( $g in $GGroups )
	{
		if ( $g.Description -match "\\" )
		{
			$f = ( $g.Description -split " for " -split " This" -split "on " )[1].TrimEnd( "." )
			try
			{
				Get-ChildItem $f -ErrorAction Stop | Out-Null
				[void] $FolderList.Add( @( $f, $g.Name ) )
			}
			catch
			{
				$txtQuestion.Text += "`n$( $g.Name )"
			}
		}
	}

	return $FolderList
}

##########################
# Get the users homefolder
function GetFolders
{
	$Window.Title = "Fetching folders"
	$Folders = @( ,@( $User.HomeDirectory, "H:" ) )
	GetCommonFolders | foreach { $Folders += ,$_ }
	$matchedNames = @()

	$ticker = 0
	foreach ( $folder in $Folders )
	{
		$Window.Title = "Checking files in '$( $folder[1] )' folder $ticker of $( $Folders.Count )"
		$matchedNames += CheckFiles ( $folder[0].Replace( "\\dfs\gem$", "G:" ) ) $tempTitle
		$ticker++
	}
	ListFilters ( $matchedNames | select -Unique | sort )
	$Folders = $null
	$Window.Title = ""
	$output = @( "**********`r`nFiltered files:`r`n**********`r`n" )
	$output += ( $spFiltered.Children ).Content
	$output += ,"`r`n`r`n**********`r`nMultiDot H:`r`n**********`r`n"
	$output += ( $spMultiDotH.Children ).Content
	$output += ,"`r`n`r`n**********`r`nMultiDot G:`r`n**********`r`n"
	$output += ( $spMultiDotG.Children ).Content
	$output += ,"`r`n`r`nOther permissions:**********`r`n"
	$split = $txtQuestion.Text.Split( "`n" )
	$output += ( $split[4..$( $split.Count - 1 )] )
	$outputfile = WriteOutput -Output $output
	return $outputfile
}

###################################
# List filters that have been found
function ListFilters
{
	param ( $filters )

	if ( ( $filters ).Count -eq 0 )
	{
		$t = New-Object System.Windows.Controls.Label
		$t.Content = "No files found, based on filters (hover mouse to show filters)"
		$ofs = ", "
		$t.ToolTip = [string]$fileFilter
		$t.FontStyle = "Italic"
		$spFilters.AddChild( $t )
	}
	else
	{
		$list = @()
		foreach ( $filter in $filters )
		{
			$cb = New-Object System.Windows.Controls.Checkbox
			$cb.Content = $filter
			$cb.Margin = "5"
			$cb.Add_Checked( {
				FilterFilters
			} )
			$cb.Add_UnChecked( {
				FilterFilters
			} )
			$spFilters.AddChild( $cb )
		}
	}
}

####################
# Reset all controls
function Reset
{
	$spFiltered.Children.Clear()
	$spMultiDotH.Children.Clear()
	$spMultiDotG.Children.Clear()
	$txtQuestion.Text = ""
	$spFilters.Children.Clear()
}

######################################
# Update info of number if files found
function UpdateInfo
{
	if ( $spFiltered.Children.Count -ne 0 ) { $tiFiltered.Header = "Filtered files ($( $spFiltered.Children.Count ))" }
	else { $tiFiltered.Header = "Filtered files" }
	if ( $spMultiDotH.Children.Count -ne 0 ) { $tiMDH.Header = "Multiple fileextentions H: ($( $spMultiDotH.Children.Count ))" }
	else { $tiMDH.Header = "Multiple fileextentions H:" }
	if ( $spMultiDotG.Children.Count -ne 0 ) { $tiMDG.Header = "Multiple fileextentions G: ($( $spMultiDotG.Children.Count ))" }
	else { $tiMDG.Header = "Multiple fileextentions G:" }
	if ( $txtQuestion.LineCount -ne -1 ) { $tiO.Header = "Folders with other permissions ($( $txtQuestion.LineCount - 4 ))" }
	else { $tiO.Header = "Folders with other permissions" }

	$h = $tiFiltered.Content.ActualHeight - $lblFilters.ActualHeight - $spFilters.RenderSize.Height
	$svFiltered.Height = $h - 25
	$svMultiDotH.Height = $h
	$svMultiDotG.Height = $h
	$txtQuestion.Height = $h
}

##############
# Write to log
function WriteToLog
{
	#TODO
	param ( $Text )
	WriteLog -LogText $Text
}

####################### Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$Window, $vars = CreateWindow
$vars | foreach { Set-Variable -Name $_ -Value $Window.FindName( $_ ) -Scope script }

WriteToLog "Start"

$User = $null
$Script:filteredFiles = @()
$fileFilter = @( ".MYD", ".MYI", "encrypted", "vvv", ".mp3", ".exe", "Anydesk", "FileSendsuite", "Recipesearch", "FromDocToPDF" )
$Window.Add_Loaded( { $Window.Activate() } )
$btnSearch.Add_Click( { CheckReady } )
$btnCreateQuestion.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$txtQuestion.Text | clip
	ShowMessageBox "Text was copied to clipboard"
	WriteToLog "Copied question to Operations"
} )
$Window.Add_LayoutUpdated( { UpdateInfo } )

[void] $Window.ShowDialog()
