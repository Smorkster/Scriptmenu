<#
.Synopsis Administration of scripts, logs, etc.
.Description Perform administration of updates, logs, reports, etc.
.State Prod
.AllowedUsers smorkster
.Author Smorkster (smorkster)
#>

function CheckForUpdates
{
	<#
	.Synopsis
		Search for any updated file
	#>

	$syncHash.DC.DgUpdates[0].Clear()
	$syncHash.DC.DgUpdatedInProd[0].Clear()
	$syncHash.DC.DgFailedUpdates[0].Clear()
	$syncHash.TbUpdated.SelectedIndex = 0
	$syncHash.PParseUpdates = [powershell]::Create().AddScript( { param ( $syncHash )

		function GetState
		{
			<#
			.Synopsis
				Get the productionstate of the script
			.Parameter DevFile
				File to get developement-state for
			.Outputs
				An array with the productionstate and a string to use as tooltip
			#>

			param ( $DevFile )

			if ( $DevFile.Extension -in ".xaml",".psd1" )
			{
				$state = ( ( Get-ChildItem $syncHash.Data.devRoot -Recurse -File -Filter "$( $DevFile.BaseName ).ps1" | Get-Content | Where-Object { $_ -match "^\.State" } ) -split " " )[-1]
				$TT = "$( $syncHash.Data.msgTable.StrScriptState ) '$state'"
			}
			elseif ( $DevFile.Extension -in ".ps1",".psm1" )
			{
				$state = ( ( Get-Content -Path $DevFile.FullName | Where-Object { $_ -match "^\.State" } ) -split " " )[1]
			}
			else
			{
				$state = $syncHash.Data.msgTable.StrOtherScriptState
			}
			return $state, $TT
		}

		function GetListItem
		{
			<#
			.Synopsis
				Create an object for the file to list
			.Parameter DevFile
				Dev-file to base the object for
			.Parameter ProdFile
				Prod-file to include in the object
			.Outputs
				An object with info on the script, to be used as a listitem
			#>

			param ( $DevFile, $ProdFile )

			if ( $DevFile )
			{
				$Name = $DevFile.Name
				$New = $false
				if ( ( $RelativePath = $DevFile.Directory.FullName.Replace( "$( $syncHash.Data.devRoot )", "" ) ) -eq "" ) { $RelativePath = "\" }
			}
			else
			{
				$Name = $ProdFile.Name
				$New = $false
				if ( ( $RelativePath = $ProdFile.Directory.FullName.Replace( "$( $syncHash.Data.prodRoot )", "" ) ) -eq "" ) { $RelativePath = "\" }
			}

			$ProdUpd = try { ( Get-Date $ProdFile.LastWriteTime -Format $syncHash.Data.CultureInfo.DateTimeStringFormat ) } catch { $null }

			if ( $null -eq $ProdFile )
			{
				$New = $true
				$UpdateText = switch ( $DevFile.Extension -replace "\." )
					{
						"psd1" {
							if ( ( Get-Content $DevFile.FullName )[0] -eq "ConvertFrom-StringData @'" ) { $syncHash.Data.msgTable.StrNewLocFile }
							else { $syncHash.Data.msgTable.StrNewDataFile }
							}
						"ps1" { $syncHash.Data.msgTable.StrNewScript }
						"xaml" { $syncHash.Data.msgTable.StrNewGuiFile }
						default { $syncHash.Data.msgTable.StrNewOtherFile }
					}
				$prodPath = "{0}{1}\{2}" -f $syncHash.Data.prodRoot, "$( if ( $listItem.RelativePath -ne "\" ) { $listItem.RelativePath } )", $listItem.Name
			}
			elseif ( $null -eq $DevFile )
			{
				$New = $true
				$UpdateText = switch ( $ProdFile.Extension -replace "\." )
					{
						"psd1" {
							if ( ( Get-Content $ProdFile.FullName )[0] -eq "ConvertFrom-StringData @'" ) { $syncHash.Data.msgTable.StrNewLocFile }
							else { $syncHash.Data.msgTable.StrNewDataFile }
							}
						"ps1" { $syncHash.Data.msgTable.StrNewScript }
						"xaml" { $syncHash.Data.msgTable.StrNewGuiFile }
						default { $syncHash.Data.msgTable.StrNewOtherFile }
					}
				$devPath = "{0}{1}\{2}" -f $syncHash.Data.devRoot, "$( if ( $listItem.RelativePath -ne "\" ) { $listItem.RelativePath } )", $listItem.Name
			}

			$State, $TT = ( GetState $DevFile )

			$listItem = [pscustomobject]@{
				Name = $Name
				New = $New
				RelativePath = $RelativePath
				DevPath = $DevFile.FullName
				DevUpd = ( Get-Date $DevFile.LastWriteTime -Format $syncHash.Data.CultureInfo.DateTimeStringFormat )
				ProdPath = $ProdFile.FullName
				ProdUpd = $ProdUpd
				State = $State
				ToolTip = $TT
			}
			return $listItem
		}

		$syncHash.DC.TblUpdatesProgress[0] = $syncHash.Data.msgTable.StrCheckingUpdates
		$syncHash.DC.PbUpdates[0] = [double] 0.001

		$syncHash.Data.dirExclusion = @( "Arkiv",
							"ErrorLogs",
							"Input",
							"Logs",
							"Output",
							"UpdateRollback" )
		$syncHash.Data.fileExclusion = @( "Denna mapp är för utveckling och testning.txt",
							"Start_SDValmeny.lnk",
							"Start_SDValmeny - Dev.lnk",
							"Start_SDValmeny - Dev.bat",
							"Start_O365Valmeny - Dev.lnk",
							"Start_O365Valmeny - Dev.bat" )

		$syncHash.Data.DevFiles = Get-ChildItem $syncHash.Data.devRoot -Directory -Exclude $syncHash.Data.dirExclusion | Get-ChildItem -File -Recurse -Exclude $syncHash.Data.fileExclusion
		$syncHash.Data.DevFiles += Get-ChildItem $syncHash.Data.devRoot -File | Where-Object { $_.Name -notin $syncHash.Data.fileExclusion }
		$syncHash.Data.ProdFiles = Get-ChildItem $syncHash.Data.prodRoot -Directory -Exclude $( $syncHash.Data.dirExclusion += "Development"; $syncHash.Data.dirExclusion ) | Get-ChildItem -File -Recurse -Exclude $syncHash.Data.fileExclusion
		$syncHash.Data.ProdFiles += Get-ChildItem $syncHash.Data.prodRoot -File | Where-Object { $_.Name -notin $syncHash.Data.fileExclusion }
		$MD5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider

		$syncHash.PbUpdates.Dispatcher.Invoke( [action] { $syncHash.PbUpdates.Maximum = $syncHash.Data.DevFiles.Count } )
		foreach ( $DevFile in $syncHash.Data.DevFiles )
		{
			$ProdFile = $syncHash.Data.ProdFiles | Where-Object { $_.Name -eq $DevFile.Name }
			if ( $null -eq $ProdFile )
			{
				$item = GetListItem $DevFile
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.DgUpdates[0].Add( $item ) } )
			}
			else
			{
				$devMD5 = [System.BitConverter]::ToString( $MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $DevFile.FullName ) ) )
				$prodMD5 = [System.BitConverter]::ToString( $MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $ProdFile.FullName ) ) )

				if ( $devMD5 -ne $prodMD5 )
				{
					$item = GetListItem $DevFile $ProdFile
					if ( $ProdFile.LastWriteTime -gt $DevFile.LastWriteTime )
					{
						$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.DgUpdatedInProd[0].Add( $item ) } )
					}
					else
					{
						$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.DgUpdates[0].Add( $item ) } )
					}
				}
			}
			$syncHash.DC.PbUpdates[0] += 1
		}

		$syncHash.DC.TblUpdatesProgress[0] = $syncHash.Data.msgTable.StrCheckingFilesInProd
		$syncHash.Data.fileExclusion += "Start_O365Valmeny.bat", "Start_O365Valmeny.lnk", "Start_SDValmeny.bat", "Start_SDValmeny3.bat"
		$FilesUpdatedInProd = $syncHash.Data.ProdFiles | Where-Object {
				$_.BaseName -notin $syncHash.Data.DevFiles.BaseName -and
				$_.Name -notin $syncHash.Data.fileExclusion
			}
		$syncHash.PbUpdates.Dispatcher.Invoke( [action] { $syncHash.PbUpdates.Maximum = $FilesUpdatedInProd.Count } )
		$syncHash.DC.PbUpdates[0] += 0.0
		foreach ( $file in $FilesUpdatedInProd )
		{
			$syncHash.DC.PbUpdates[0] = [double]( ( $ticker / $FilesUpdatedInProd.Count ) * 100 )
			$item = GetListItem $null $file
			[System.Windows.MessageBox]::Show( "$( $ProdFile.Name )`n$( $item.Name )" )
			$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.DgUpdatedInProd[0].Add( $item ) } )
			$syncHash.DC.PbUpdates[0] += 1
		}

		if ( $syncHash.DC.DgUpdates[0].Count -gt 0 )
		{
			$syncHash.DC.TbUpdatesSummary[0] = "{0} {1}" -f $syncHash.DC.DgUpdates[0].Count, $syncHash.Data.msgTable.StrUpdates
			$syncHash.DC.TbDevCount[0] = $syncHash.DC.DgUpdates[0].Where( { $_.State -eq "Dev" } ).Count
			$syncHash.DC.TbTestCount[0] = $syncHash.DC.DgUpdates[0].Where( { $_.State -eq "Test" } ).Count
			$syncHash.DC.TbProdCount[0] = $syncHash.DC.DgUpdates[0].Where( { $_.State -eq "Prod" } ).Count
			$syncHash.DC.TblInfo[1] = [System.Windows.Visibility]::Visible
		}
		else
		{
			$syncHash.DC.TbDevCount[0] = $syncHash.DC.TbTestCount[0] = $syncHash.DC.TbProdCount[0] = 0
			$syncHash.DC.TblUpdateInfo[0] = $syncHash.Data.msgTable.StrNoUpdates
			$syncHash.DC.TblInfo[1] = [System.Windows.Visibility]::Collapsed
		}
		$syncHash.DC.PbUpdates[0] = 0.0
		$syncHash.Temp = $Error
	} ).AddArgument( $syncHash )
	$syncHash.HParseUpdates = $syncHash.PParseUpdates.BeginInvoke()
}

function FindOrphandLocalizations
{
	<#
	.Synopsis
		Find localizations that are not used
	.Description
		Check if there are any localizationvariables in the localizationfile that are not used in the script and if there are any calls for localizationvariables in the script that does not exist
	.Parameter FileName
		Name of scriptfile. This is also used as template for the datafile
	.Outputs
		Array with any localizationvariables that are not used, and variables that is not mentioned in the localizationfile
	#>

	param ( $FileName )

	$OrphandLocs = @()
	$NullLocs = @()

	if ( $sc = Get-ChildItem -Path "$BaseDir\Script" -Filter "$FileName.ps1" -Recurse )
	{
		if ( $loc = Get-ChildItem -Path "$BaseDir\Localization" -Filter "$FileName.psd1" -Recurse )
		{
			Import-LocalizedData -BindingVariable m -BaseDirectory $loc.Directory.FullName -FileName $loc.Name
			$any = $false
			foreach ( $key in $m.Keys )
			{ if ( -not ( $sc | Select-String -Pattern "\.\b$key\b" ) ) { $OrphandLocs += [pscustomobject]@{ LocVar = $key ; LocVal = $m.$key } } }

			# Check scriptfile
			$any = $false
			$LocalizedStrings = ( $sc | Select-String -Pattern "msgTable\." )
			foreach ( $Line in $LocalizedStrings )
			{
				$v = ( $Line.Line.Substring( $Line.Line.LastIndexOf( "msgTable" ) + 9 ) -split "\W" )[0]
				if ( $v -notin $m.Keys )
				{ $NullLocs += [pscustomobject]@{ ScVar = $v; ScLine = $Line.Line.Trim() ; ScLineNr = $Line.linenumber } }
			}
		}
	}
	return $OrphandLocs, $NullLocs
}

function OpenFile
{
	<#
	.Synopsis
		Open the specified file/-s
	.Paramter FilePaths
		Array containing any file that is to be opened
	#>

	param ( [string[]] $FilePaths )

	$FilePaths | ForEach-Object { if ( Test-Path $_ ) { Start-Process $syncHash.Data.Editor "`"$_`"" } }
}

function ParseErrorlogs
{
	<#
	.Synopsis
		Parse errorlogs
	#>

	try { $syncHash.PParseErrorLogs.EndInvoke( $syncHash.HParseErrorLogs ) } catch {}
	$syncHash.HParseErrorLogs = $syncHash.PParseErrorLogs.BeginInvoke()
}

function ParseLogs
{
	<#
	.Synopsis
		Parse logfiles
	#>

	try { $syncHash.PParseLogs.EndInvoke( $syncHash.HParseLogs ) } catch {}
	$syncHash.HParseLogs = $syncHash.PParseLogs.BeginInvoke()
}

function ParseRollbacks
{
	<#
	.Synopsis
		Parse rollbacked files
	#>

	try { $syncHash.PParseRollbacks.EndInvoke( $syncHash.HParseRollBacks ) } catch {}
	$syncHash.HParseRollBacks = $syncHash.PParseRollbacks.BeginInvoke()
}

function ParseSurveys
{
	<#
	.Synopsis
		Parse surveyfiles
	#>

	try { $syncHash.PParseSurveys.EndInvoke( $syncHash.HParseSurveys ) } catch {}
	$syncHash.HParseSurveys = $syncHash.PParseSurveys.BeginInvoke()
}

function PrepParsing
{
	$syncHash.PParseErrorLogs = [powershell]::Create( [initialsessionstate]::CreateDefault() ).AddScript( { param ( $syncHash, $Modules )
		Import-Module $Modules
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.GridErrorlogsList.Visibility = [System.Windows.Visibility]::Collapsed
			$syncHash.PbParseErrorLogs.IsIndeterminate = $true
		} )
		$syncHash.Data.ErrorLoggs = Get-ChildItem "$( $syncHash.Data.BaseDir )\ErrorLogs" -Recurse -File -Filter "*.json" | Sort-Object Name
		$syncHash.PbParseErrorLogs.Maximum = [double] $syncHash.Data.ErrorLoggs.Count
		$syncHash.DC.CbErrorLogsScriptNames[0].Clear()
		$syncHash.Data.ParsedErrorLogs.Clear()
		$syncHash.DC.PbParseErrorLogsOps[0] = 0.0
		$syncHash.DC.PbParseErrorLogs[0] = 0.0

		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.PbParseErrorLogs.IsIndeterminate = $false
		} )
		$syncHash.Data.ErrorLoggs | ForEach-Object {
			$n = $_.BaseName -replace " - ErrorLog"
			if ( $syncHash.Data.ParsedErrorLogs.ScriptName -notcontains $n )
			{ $syncHash.Data.ParsedErrorLogs.Add( [pscustomobject]@{ ScriptName = $n ; ScriptErrorLogs = [System.Collections.ArrayList]::new() } ) }
			Get-Content $_.FullName | ForEach-Object { ( $syncHash.Data.ParsedErrorLogs.Where( { $_.ScriptName -eq $n } ) )[0].ScriptErrorLogs.Add( ( NewErrorLog ( $_ | ConvertFrom-Json ) ) ) }
			$syncHash.DC.PbParseErrorLogs[0] += 1
		}
		$syncHash.DC.PbParseErrorLogsOps[0] = 1.0

		$syncHash.PbParseErrorLogs.Maximum = $syncHash.Data.ParsedErrorLogs.Count
		$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.PbParseErrorLogs.Value = 0.0 } )
		$syncHash.Data.ParsedErrorLogs | ForEach-Object {
			$_.ScriptErrorLogs = $_.ScriptErrorLogs | Sort-Object LogDate -Descending
			$syncHash.DC.PbParseErrorLogs[0] += 1
		}
		$syncHash.DC.PbParseErrorLogsOps[0] = 2.0

		$syncHash.DC.PbParseErrorLogs[0] = 0.0
		$syncHash.Data.ParsedErrorLogs | ForEach-Object {
			$syncHash.DC.CbErrorLogsScriptNames[0].Add( $_ )
			$syncHash.DC.PbParseErrorLogs[0] += 1
		}
		$syncHash.DC.PbParseErrorLogsOps[0] = 3.0
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.GridErrorlogsList.Visibility = [System.Windows.Visibility]::Visible
		} )
	} ).AddArgument( $syncHash ).AddArgument( ( Get-Module ) )

	$syncHash.PParseLogs = [powershell]::Create( [initialsessionstate]::CreateDefault() ).AddScript( { param ( $syncHash, $Modules )
		Import-Module $Modules
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.PbLogSearch.Visibility = [System.Windows.Visibility]::Visible
		} )
		$syncHash.Data.ParsedLogs.Clear()
		$syncHash.Data.ParsedLogsRecent.Clear()
		$a = Get-ChildItem "$( $syncHash.Data.BaseDir )\Logs" -Recurse -File -Filter "*log.json"
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.PbLogSearch.IsIndeterminate = $false
			$syncHash.PbLogSearch.Maximum = $a.Count
			$syncHash.PbLogSearch.Value = 0
		} )

		$a | Sort-Object Name | ForEach-Object {
			$n = $_.BaseName -replace " - Log"
			if ( $syncHash.Data.ParsedLogs.ScriptName -notcontains $n )
			{
				[void] $syncHash.Data.ParsedLogs.Add( [pscustomobject]@{ ScriptName = $n ; ScriptLogs = [System.Collections.ArrayList]::new() } )
				[void] $syncHash.Data.ParsedLogsRecent.Add( [pscustomobject]@{ ScriptName = $n ; ScriptLogs = [System.Collections.ArrayList]::new() } )
			}
			Get-Content $_.FullName | ForEach-Object {
				$log = NewLog ( $_ | ConvertFrom-Json )
				[void] ( $syncHash.Data.ParsedLogs.Where( { $_.ScriptName -eq $n } ) )[0].ScriptLogs.Add( $log )
				if ( $log.LogDate -gt ( Get-Date ).AddDays( -7 ) )
				{ [void] ( $syncHash.Data.ParsedLogsRecent.Where( { $_.ScriptName -eq $n } ) )[0].ScriptLogs.Add( $log ) }
			}
			$syncHash.DC.PbLogSearch[0] += 1
		}

		$syncHash.Data.ParsedLogs | ForEach-Object { $_.ScriptLogs = [System.Collections.ArrayList]::new( @( $_.ScriptLogs | Sort-Object -Property LogDate -Descending ) ) }
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.CbLogsScriptNames.ItemsSource = $syncHash.Data.ParsedLogs
			$syncHash.Window.Title = ""
			$syncHash.PbLogSearch.Visibility = [System.Windows.Visibility]::Collapsed
		} )
	} ).AddArgument( $syncHash ).AddArgument( ( Get-Module ) )

	$syncHash.PParseRollbacks = [powershell]::Create( [initialsessionstate]::CreateDefault() ).AddScript( { param ( $syncHash, $Modules )
		Import-Module $Modules

		[array] $syncHash.Data.RollbackFiles = Get-ChildItem $syncHash.Data.RollbackRoot -Recurse -File
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.PbListingRollbacks.Visibility = [System.Windows.Visibility]::Visible
			$syncHash.DC.LvRollbackFileNames[0].Clear()
		} )

		$syncHash.Data.RollBackData.Clear()

		foreach ( $File in $syncHash.Data.RollbackFiles )
		{
			$FileName, $Info = $File.BaseName -split " \("
			$Info = $Info -replace "\)" -split " "
			if ( [string]::IsNullOrWhiteSpace( $Info[3] ) ) { $Info += $syncHash.Data.msgTable.StrNoUpdaterSpecified }
			$FileData = [pscustomobject]@{
				File = $File
				Script = ( $FileName -split "\." )[0]
				Updated = Get-Date "$( $Info[1] ) $( $Info[2] -replace "\.", ":" )"
				UpdatedBy = $Info[3]
				Type = $File.Extension -replace "\."
			}

			if ( $syncHash.Data.RollBackData.Script -notcontains $FileData.Script )
			{
				$TempArray = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
				$TempArray.Add( $FileData )
				[void] $syncHash.Data.RollBackData.Add( [pscustomobject]@{ Script = $FileData.Script ; FileLogs = $TempArray } )
			}
			else
			{
				( $syncHash.Data.RollBackData.Where( { $_.Script -eq $FileData.Script } ) )[0].FileLogs.Add( $FileData )
			}
		}

		$syncHash.Data.RollBackData | ForEach-Object { [System.Collections.ObjectModel.ObservableCollection[object]] $_.FileLogs = $_.FileLogs | Sort-Object Updated -Descending }
		[System.Collections.ObjectModel.ObservableCollection[object]] $syncHash.Data.RollBackData = $syncHash.Data.RollBackData | Sort-Object Script
		$syncHash.Data.RollBackData | ForEach-Object { $syncHash.LvRollbackFileNames.ItemsSource.Add( $_ ) }

		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.PbListingRollbacks.Visibility = [System.Windows.Visibility]::Collapsed
		} )
	} ).AddArgument( $syncHash ).AddArgument( ( Get-Module ) )

	$syncHash.PParseSurveys = [powershell]::Create( [initialsessionstate]::CreateDefault() ).AddScript( { param ( $syncHash, $Modules )
		Import-Module $Modules

		$syncHash.Data.SurveyFiles = Get-ChildItem "$( $syncHash.Data.BaseDir )\Logs" -Recurse -File -Filter "*survey.json"
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.PbParseSurveys.Maximum = $syncHash.Data.SurveyFiles.Count
			$syncHash.PbParseSurveys.Visibility = [System.Windows.Visibility]::Visible
		} )
		$syncHash.DC.PbParseSurveys[0] = 0.0
		$syncHash.DC.DgSurveyScripts[0].Clear()

		$syncHash.Data.SurveyFiles | ForEach-Object {
			$n = $_.BaseName -replace " - Survey"
			if ( $syncHash.DC.DgSurveyScripts.ScriptName -notcontains $n )
			{ $syncHash.DC.DgSurveyScripts[0].Add( [pscustomobject]@{ ScriptName = $n ; SurveyCount = 0 ; Surveys = @{} } ) }
			Get-Content $_.FullName | ForEach-Object {
				$s = $_ | ConvertFrom-Json

				if ( ( $syncHash.DC.DgSurveyScripts[0].Where( { $_.ScriptName -eq $n } ) )[0].Surveys.Keys -notcontains $s.ScriptVersion )
				{
					( $syncHash.DC.DgSurveyScripts[0].Where( { $_.ScriptName -eq $n } ) )[0].Surveys.Add( $s.ScriptVersion, [System.Collections.ArrayList]::new() )
					( $syncHash.DC.DgSurveyScripts[0] | Where-Object { $_.ScriptName -eq $n } ).SurveyCount += 1
				}

				( $syncHash.DC.DgSurveyScripts[0].Where( { $_.ScriptName -eq $n } ) )[0].Surveys.Item( $s.ScriptVersion ).Add( $s )
			}
			$syncHash.DC.PbParseSurveys[0] += 1
		}
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.PbParseSurveys.Visibility = [System.Windows.Visibility]::Collapsed
		} )
	} ).AddArgument( $syncHash ).AddArgument( ( Get-Module ) )
}

function SetLocalizations
{
	<#
	.Synopsis
		Set localized strings
	#>

	# DatagridTextColumn header and sortdescription for dgUpdates and dgUpdatedInProd
	$syncHash.DgUpdates.Columns[0].Header = $syncHash.DgUpdatedInProd.Columns[0].Header = $syncHash.Data.msgTable.ContentdgUpdatesColName
	$syncHash.DgUpdates.Columns[1].Header = $syncHash.DgUpdatedInProd.Columns[1].Header = $syncHash.Data.msgTable.ContentdgUpdatesColPath
	$syncHash.DgUpdates.Columns[2].Header = $syncHash.DgUpdatedInProd.Columns[2].Header = $syncHash.Data.msgTable.ContentdgUpdatesColDevUpd
	$syncHash.DgUpdates.Columns[3].Header = $syncHash.DgUpdatedInProd.Columns[3].Header = $syncHash.Data.msgTable.ContentdgUpdatesColProdUpd
	$syncHash.DgUpdates.Columns[4].Header = $syncHash.DgUpdatedInProd.Columns[4].Header = $syncHash.Data.msgTable.ContentdgUpdatesColProdState
	$syncHash.DgUpdates.Items.SortDescriptions.Add( ( [System.ComponentModel.SortDescription]::new( "Name", [System.ComponentModel.ListSortDirection]::Ascending ) ) )

	# DatagridTextColumn header and sortdescription for dgLogs
	$syncHash.DgLogs.Columns[0].Header = $syncHash.Data.msgTable.ContentdgLogsColLogDate
	$syncHash.DgLogs.Columns[1].Header = $syncHash.Data.msgTable.ContentdgLogsColSuccess
	$syncHash.DgLogs.Columns[2].Header = $syncHash.Data.msgTable.ContentdgLogsColOperator
	$syncHash.DgLogs.Items.SortDescriptions.Add( ( [System.ComponentModel.SortDescription]::new( "LogDate", [System.ComponentModel.ListSortDirection]::Descending ) ) )

	# DatagridTextColumn header and sortdescription for dgRollbacks
	$syncHash.DgRollbacks.Columns[0].Header = $syncHash.Data.msgTable.ContentdgRollbacksColFileName
	$syncHash.DgRollbacks.Columns[1].Header = $syncHash.Data.msgTable.ContentdgRollbacksColUpdated
	$syncHash.DgRollbacks.Columns[2].Header = $syncHash.Data.msgTable.ContentdgRollbacksColUpdatedBy
	$syncHash.DgRollbacks.Columns[3].Header = $syncHash.Data.msgTable.ContentdgRollbacksColType

	# DatagridTextColumn header and sortdescription for dgErrorLogs
	$syncHash.DgErrorLogs.Columns[0].Header = $syncHash.Data.msgTable.ContentdgErrorLogsColLogDate
	$syncHash.DgErrorLogs.Items.SortDescriptions.Add( ( [System.ComponentModel.SortDescription]::new( "LogDate", [System.ComponentModel.ListSortDirection]::Descending ) ) )

	# DatagridTextColumn headers dgSurveyScripts
	$syncHash.DgSurveyScripts.Columns[0].Header = $syncHash.Data.msgTable.ContentdgSurveyScriptsColScriptName
	$syncHash.DgSurveyScripts.Columns[1].Header = $syncHash.Data.msgTable.ContentdgSurveyScriptsColSurveyCount

	# DatagridTextColumn headers for dgSurveyAnswers
	$syncHash.DgSurveyAnswers.Columns[0].Header = $syncHash.Data.msgTable.ContentdgSurveyAnswersColComment
	$syncHash.DgSurveyAnswers.Columns[1].Header = $syncHash.Data.msgTable.ContentdgSurveyAnswersColRating
	$syncHash.DgSurveyAnswers.Columns[2].Header = $syncHash.Data.msgTable.ContentdgSurveyAnswersColOperator
	$syncHash.DgSurveyAnswers.Columns[3].Header = $syncHash.Data.msgTable.ContentdgSurveyAnswersColDate

	# DatagridTextColumn headers for dgFailedUpdates
	$syncHash.DgFailedUpdates.Columns[0].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColName
	$syncHash.DgFailedUpdates.Columns[1].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColUpdateAnyway
	$syncHash.DgFailedUpdates.Columns[2].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColAcceptedVerb
	$syncHash.DgFailedUpdates.Columns[3].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColWritesToLog
	$syncHash.DgFailedUpdates.Columns[4].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColScriptInfo
	$syncHash.DgFailedUpdates.Columns[5].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColObsoleteFunctions
	$syncHash.DgFailedUpdates.Columns[6].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColInvalidLocalizations
	$syncHash.DgFailedUpdates.Columns[7].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColOrphandLocalizations
	$syncHash.DgFailedUpdates.Columns[8].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColTODOs

	# DatagridTextColumn headers for datagrids in dgFailedUpdates-cells
	$syncHash.DgFailedUpdates.Resources['DgOFColHeaderFunctionName'] = $syncHash.Data.msgTable.ContentdgObsoleteFunctionsColFunctionName
	$syncHash.DgFailedUpdates.Resources['DgOFColHeaderHelpMessage'] = $syncHash.Data.msgTable.ContentdgObsoleteFunctionsColHelpMessage
	$syncHash.DgFailedUpdates.Resources['DgOFColHeaderLineNumbers'] = $syncHash.Data.msgTable.ContentdgObsoleteFunctionsColLineNumbers

	$syncHash.DgFailedUpdates.Resources['DgIVColHeaderTextLN'] = $syncHash.Data.msgTable.ContentdgInvalidLocalizationsColLineNumber
	$syncHash.DgFailedUpdates.Resources['DgIVColHeaderTextSV'] = $syncHash.Data.msgTable.ContentdgInvalidLocalizationsColScriptVar
	$syncHash.DgFailedUpdates.Resources['DgIVColHeaderTextSL'] = $syncHash.Data.msgTable.ContentdgInvalidLocalizationsColScriptLine

	$syncHash.DgFailedUpdates.Resources['DgOLColHeaderTextLVar'] = $syncHash.Data.msgTable.ContentdgOrphandLocalizationsColVariable
	$syncHash.DgFailedUpdates.Resources['DgOLColHeaderTextLVal'] = $syncHash.Data.msgTable.ContentdgOrphandLocalizationsColValue

	$syncHash.DgFailedUpdates.Resources['DgSIColHeaderTitle'] = $syncHash.Data.msgTable.ContentdgSIColHeaderTitle
	$syncHash.DgFailedUpdates.Resources['DgSIColHeaderInfoDesc'] = $syncHash.Data.msgTable.ContentdgSIColHeaderInfoDesc

	$syncHash.DgFailedUpdates.Resources['DgTDColHeaderTextL'] = $syncHash.Data.msgTable.ContentdgTDColHeaderTextL
	$syncHash.DgFailedUpdates.Resources['DgTDColHeaderTextLN'] = $syncHash.Data.msgTable.ContentdgTDColHeaderTextLN

	$syncHash.DgFailedUpdates.Resources['NoAcceptedVerb'] = $syncHash.Data.msgTable.ContentNoAcceptedVerb

	$syncHash.DgDiffList.Columns[0].Header = $syncHash.Data.msgTable.ContentdgDiffListColDevRow
	$syncHash.DgDiffList.Columns[1].Header = $syncHash.Data.msgTable.ContentdgDiffListColLineNr
	$syncHash.DgDiffList.Columns[2].Header = $syncHash.Data.msgTable.ContentdgDiffListColProdRow

	$syncHash.DiffWindow.Resources['DiffRowRemoved'] = $syncHash.Data.msgTable.StrDiffRowRemoved # Text for row that was removed
	$syncHash.DiffWindow.Resources['DiffRowAdded'] = $syncHash.Data.msgTable.StrDiffRowAdded # Text for row that have been added
	$syncHash.Window.Resources['FailedTestCount'] = "$( $syncHash.Data.msgTable.StrFailedTestCount ): " # Text for number of failed tests
	$syncHash.Window.Resources['NewFileTitle'] = $syncHash.Data.msgTable.StrNewFileTitle # Text for indicating the file is new and not present in production
	$syncHash.Window.Resources['LogSearchNoType'] = $syncHash.Data.msgTable.StrLogSearchNoType # Text for indicating the file is new and not present in production
}

function ShowDiffWindow
{
	<#
	.Synopsis
		Open window to display difference between files
	#>

	if ( $syncHash.TbUpdated.SelectedIndex -eq 0 ) { $LvItem = $syncHash.DgUpdates.SelectedItem }
	else { $LvItem = $syncHash.DgUpdatedInProd.SelectedItem }
	$a = Get-Content $LvItem.DevPath
	$b = Get-Content $LvItem.ProdPath
	$c = Compare-Object $a $b -PassThru

	$syncHash.DiffList = foreach ( $DiffLine in ( $c.ReadCount | Select-Object -Unique | Sort-Object ) )
	{
		$DevLine = try { ( $c.Where( { $_.ReadCount -eq $DiffLine -and $_.SideIndicator -eq "<=" } ) )[0].Trim() } catch { "" }
		$ProdLine = try { ( $c.Where( { $_.ReadCount -eq $DiffLine -and $_.SideIndicator -eq "=>" } ) )[0].Trim() } catch { "" }

		[pscustomobject]@{ DevLine = $DevLine; ProdLine = $ProdLine; LineNr = $DiffLine }
	}

	$syncHash.DiffWindow.DataContext = [pscustomobject]@{ DiffList = $syncHash.DiffList ; DevPath = $LvItem.DevPath ; ProdPath = $LvItem.ProdPath }
	$syncHash.DiffWindow.Visibility = [System.Windows.Visibility]::Visible
	WriteLogTest -Text $syncHash.Data.msgTable.LogOpenDiffWindow -UserInput ( [string]( $LvItem.DevPath, $LvItem.ProdPath ) ) -Success $true
}

function TestScript
{
	<#
	.Synopsis
		Test if script is viable to update
	.Parameter File
		Scriptfile to test before sending to production
	.Outputs
		Array of testresults
	#>

	param ( $File )

	$Script = Get-Item $File.DevPath
	$OFS = ", "
	$Test = [pscustomobject]@{ File = $File; FailedTestCount = 0; ObsoleteFunctions = @(); AcceptedVerb = $false; WritesToLog = $false; OrphandLocalizations = @(); InvalidLocalizations = @(); ScriptInfo = @(); TODOs = @() ; AllowUpdateAnyway = $true ; UpdateAnyway = $false }

	# Test if obsolete functions are used
	foreach ( $f in $syncHash.ObsoleteFunctions )
	{
		[array]$linenumbers = ( $Script | Select-String -Pattern "\b$( $f.FunctionName )\b" ).LineNumber
		if ( $linenumbers -gt 0 ) { $Test.ObsoleteFunctions += [pscustomobject]@{ "FunctionName" = $f.FunctionName ; "HelpMessage" = $f.HelpMessage ; "LineNumbers" = [string]$linenumbers } }
	}

	# Test if filename has an accepted verb
	$Test.AcceptedVerb = ( Get-Verb ).Verb | ForEach-Object { $AV = $false } { if ( $Script.BaseName -match "^$_" ) { $AV = $true } } { $AV }

	# Test if the script writes to log
	$Test.WritesToLog = ( $Script | Select-String -Pattern "(?=\s*)(?<!.*#.*)WriteLogTest(?=.*)" ).Count -gt 0

	# Test if there are any localizationvariables that are not used or are being used but does not exist
	$Test.OrphandLocalizations, $Test.InvalidLocalizations = FindOrphandLocalizations $Script.BaseName

	# Test if script contains necessary information
	$InfoTypes = @(
		[pscustomobject]@{ Title = "Author"; InfoDesc = $syncHash.Data.msgTable.StrScriptInfoDescAuthor },
		[pscustomobject]@{ Title = "Description"; InfoDesc = $syncHash.Data.msgTable.StrScriptInfoDescDescription },
		[pscustomobject]@{ Title = "State"; InfoDesc = $syncHash.Data.msgTable.StrScriptInfoDescState },
		[pscustomobject]@{ Title = "Synopsis"; InfoDesc = $syncHash.Data.msgTable.StrScriptInfoDescSynopsis } )
	foreach ( $Info in $InfoTypes )
	{
		if ( -not ( ( Get-Content $Script ) -match "^\.$( $Info.Title )" ) )
		{ $Test.ScriptInfo += $Info }
	}

	# Test if file contains any TODO notes
	if ( $Script.Name -ne ( Get-Item $PSCommandPath ).Name )
	{ $Test.TODOs = @( $Script | Select-String -Pattern "\bTODO\b" ) }

	if ( $Test.ObsoleteFunctions.Count -ne 0 ) { $Test.FailedTestCount++ }
	if ( -not $Test.AcceptedVerb ) { $Test.FailedTestCount++ }
	if ( -not $Test.WritesToLog ) { $Test.FailedTestCount++ }
	if ( $Test.OrphandLocalizations.Count -ne 0 ) { $Test.FailedTestCount++ }
	if ( $Test.InvalidLocalizations.Count -ne 0 ) { $Test.FailedTestCount++ }
	if ( $Test.ScriptInfo.Count -ne 0 ) { $Test.FailedTestCount++ }
	if ( $Test.TODOs.Count -ne 0 ) { $Test.FailedTestCount++ }

	if ( ( $Test.ObsoleteFunctions.Count -ne 0 ) -or
		( -not $Test.AcceptedVerb ) -or
		( $Test.ScriptInfo.Count -ne 0 ) )
	{ $Test.AllowUpdateAnyway = $false }
	return $Test
}

function UncheckOtherRollbackFilters
{
	param (
		[string] $Checked
	)

	$syncHash.GetEnumerator() | Where-Object { $_.Key -match "CbRollbackFilterType" -and $_.Key -notmatch ".*$Checked" } | ForEach-Object { $_.Value.IsChecked = $false }
}

function UnselectDatagrid
{
	<#
	.Synopsis
		If a click in a datagrid did not occur on a row, unselect selected row
	.Parameter Click
		UI-Object where the click occured
	.Parameter DataGrid
		What datagrid did the click occur in
	#>

	param ( $Click, $Datagrid )

	if ( $Click.Name -ne "" ) { if ( $Datagrid.SelectedItems.Count -lt 1 ) { $Datagrid.SelectedIndex = -1 } }
}

function UpdateScripts
{
	<#
	.Synopsis
		Update the scripts that have been selected
	#>

	$syncHash.Updated = @()
	$FilesToUpdate = @()
	if ( $syncHash.TbUpdated.SelectedIndex -eq 0 )
	{
		foreach ( $file in $syncHash.DgUpdates.SelectedItems )
		{
			if ( $file.Name -match "\.ps1$" )
			{
				$FileTest = TestScript $file
				if ( $FileTest.FailedTestCount -eq 0 )
				{ $FilesToUpdate += $file }
				else
				{ $syncHash.DC.DgFailedUpdates[0].Add( $FileTest ) }
			}
			else
			{ $FilesToUpdate += $file }
		}
	}
	elseif ( $syncHash.TbUpdated.SelectedIndex -eq 1 )
	{
		$FilesToUpdate = @( $syncHash.DC.DgFailedUpdates[0] | Where-Object { $_.UpdateAnyway } ).File
	}

	foreach ( $file in $FilesToUpdate )
	{
		$OFS = "`n"
		if ( $file.New )
		{
			New-Item -ItemType File -Path $file.ProdPath -Force
			Copy-Item -Path $file.DevPath -Destination ( $file.DevPath -replace "Development\\" ) -Force
		}
		else
		{
			$RollbackPath = "$( $syncHash.Data.RollbackRoot )\$( ( Get-Date ).Year )\$( ( Get-Date ).Month )\"
			$RollbackName = "$( $file.Name ) ($( $syncHash.Data.msgTable.StrRollbackName ) $( Get-Date $file.ProdUpd -Format $syncHash.Data.CultureInfo.DateTimeFileStringFormat ), $( $env:USERNAME ))$( ( Get-Item $file.ProdPath ).Extension )" -replace ":","."
			$RollbackValue = [string]( Get-Content -Path $file.ProdPath -Encoding UTF8 )
			$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
			New-Item -Path $RollbackPath -Name $RollbackName -ItemType File -Value $RollbackValue -Force | Out-Null
			Copy-Item -Path $file.DevPath -Destination $file.ProdPath -Force
		}
		$syncHash.Updated += $file
	}

	$OFS = "`n`t"
	$LogText = "$( $syncHash.Data.msgTable.LogUpdatedIntro ) $( $syncHash.Updated.Count )`n$( [string]( $syncHash.Updated ) )"
	if ( $syncHash.DC.DgFailedUpdates[0].Count -gt 0 )
	{
		$LogText += "`n$( $syncHash.DC.DgFailedUpdates[0].Count ) $( $syncHash.Data.msgTable.LogFailedUpdates ):`n"
		$syncHash.DC.DgFailedUpdates[0] | ForEach-Object { "$( $syncHash.Data.msgTable.LogFailedUpdatesName ) $( $_ )`n$( $syncHash.Data.msgTable.LogFailedUpdatesTestResults )" }
	}

	if ( $syncHash.DC.DgUpdatedInProd[0].Count -gt 0 )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.StrUpdatesInProd ): "
		$LogText += [string]( $syncHash.DC.DgUpdatedInProd[0] | ForEach-Object { "$( if ( $_.Path -ne "\" ) { $_.Path } )", $_.Name } )
	}

	WriteLogTest -Text $LogText -UserInput [string]$syncHash.Updated.Name -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null

	if ( $syncHash.TbUpdated.SelectedIndex -eq 0 )
	{
		$temp = $syncHash.DC.DgUpdates[0] | Where-Object { $_ -notin $syncHash.DgUpdates.SelectedItems }
		$syncHash.DC.DgUpdates[0].Clear()
		$temp | ForEach-Object { $syncHash.DC.DgUpdates[0].Add( $_ ) }
	}
	elseif ( $syncHash.TbUpdated.SelectedIndex -eq 1 )
	{
		$temp = $syncHash.DC.DgFailedUpdates[0] | Where-Object { $_.File -notin $FilesToUpdate }
		$syncHash.DC.DgFailedUpdates[0].Clear()
		if ( $temp.Count -gt 0 ) { $temp | ForEach-Object { $syncHash.DC.DgFailedUpdates[0].Add( $_ ) } }
	}
	$syncHash.DC.TblInfo[1] = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.Window[0] = ""
}

######################### Script start
Add-Type -AssemblyName PresentationFramework

$BaseDir = $args[0]
Get-ChildItem -Path "$BaseDir\Modules" -Filter "*.psm1" | ForEach-Object { Import-Module $_.FullName -Force -ArgumentList $args[1] }

$controls = [System.Collections.ArrayList]::new( @(
@{ CName = "BtnCheckForUpdates" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnCheckForUpdates } ) },
@{ CName = "BtnCopyErrorInfo" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnCopyErrorInfo } ) },
@{ CName = "BtnCopyLogInfo" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnCopyLogInfo } ) },
@{ CName = "BtnCopyRollbackInfo" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnCopyRollbackInfo } ) },
@{ CName = "BtnClearErrorLogSearch" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnClearErrorLogSearch } ) },
@{ CName = "BtnClearLogSearch" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnClearLogSearch } ) },
@{ CName = "BtnDiffOpenBoth" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnDiffOpenBoth } ) },
@{ CName = "BtnDiffCancel" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnDiffCancel } ) },
@{ CName = "BtnDiffOpenDev" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnDiffOpenDev } ) },
@{ CName = "BtnDiffOpenProd" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnDiffOpenProd } ) },
@{ CName = "BtnDoRollback" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnDoRollback } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) },
@{ CName = "BtnErrorLogSearch" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnErrorLogSearch } ) },
@{ CName = "BtnListRollbacks" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnListRollbacks } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) },
@{ CName = "BtnListSurveys" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnListSurveys } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) },
@{ CName = "BtnLogSearch" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnLogSearch } ) },
@{ CName = "BtnOpenPopupCopyLogInfo" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnOpenPopupCopyLogInfo } ) },
@{ CName = "BtnUpdatedInProdOpenBothFiles" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnUpdatedInProdOpenBothFiles } ) },
@{ CName = "BtnUpdatedInProdOpenDevFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnUpdatedInProdOpenDevFile } ) },
@{ CName = "BtnUpdatedInProdOpenDiffs" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnUpdatedInProdOpenDiffs } ) },
@{ CName = "BtnUpdatedInProdOpenProdFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnUpdatedInProdOpenProdFile } ) },
@{ CName = "BtnUpdateFailedScripts" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnUpdateFailedScripts } ) },
@{ CName = "BtnOpenErrorLog" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnOpenErrorLog } ) },
@{ CName = "BtnOpenOutputFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnOpenOutputFile } ) },
@{ CName = "BtnOpenRollbackFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnOpenRollbackFile } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) },
@{ CName = "BtnReadErrorLogs" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnReadErrorLogs } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) },
@{ CName = "BtnReadLogs" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnReadLogs } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) },
@{ CName = "BtnUpdateScripts" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnUpdateScripts } ) },
@{ CName = "BtnUpdatesOpenBothFiles" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnUpdatesOpenBothFiles } ) },
@{ CName = "BtnUpdatesOpenDevFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnUpdatesOpenDevFile } ) },
@{ CName = "BtnUpdatesOpenProdFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnUpdatesOpenProdFile } ) },
@{ CName = "BtnUpdatesOpenDiff" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentBtnUpdatesOpenDiff } ) },
@{ CName = "CbCopyLogInfoIncludeErrorLogs" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentCbCopyLogInfoIncludeErrorLogs } ) },
@{ CName = "CbCopyLogInfoIncludeOutputFiles" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentCbCopyLogInfoIncludeOutputFiles } ) },
@{ CName = "CbErrorLogsScriptNames" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "CbLogsFilterSuccessFailed" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentCbLogsFilterSuccessFailed } ) },
@{ CName = "CbLogsFilterSuccessSuccess" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentCbLogsFilterSuccessSuccess } ) },
@{ CName = "CbLogsScriptNames" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "CbShowDevFiles" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentCbShowDevFiles } ; @{ PropName = "IsChecked" ; PropVal = $true } ) },
@{ CName = "CbRollbackFilterTypePs1" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentCbRollbackFilterTypePs1 } ; @{ PropName = "Tooltip" ; PropVal = $msgTable.ContentCbRollbackFilterTypePs1Tooltip } ) },
@{ CName = "CbRollbackFilterTypePsd1" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentCbRollbackFilterTypePsd1 } ; @{ PropName = "Tooltip" ; PropVal = $msgTable.ContentCbRollbackFilterTypePsd1Tooltip } ) },
@{ CName = "CbRollbackFilterTypePsm1" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentCbRollbackFilterTypePsm1 } ; @{ PropName = "Tooltip" ; PropVal = $msgTable.ContentCbRollbackFilterTypePsm1Tooltip } ) },
@{ CName = "CbRollbackFilterTypeTxt" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentCbRollbackFilterTypeTxt } ; @{ PropName = "Tooltip" ; PropVal = $msgTable.ContentCbRollbackFilterTypeTxtTooltip } ) },
@{ CName = "CbRollbackFilterTypeXaml" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentCbRollbackFilterTypeXaml } ; @{ PropName = "Tooltip" ; PropVal = $msgTable.ContentCbRollbackFilterTypeXamlTooltip } ) },
@{ CName = "DgFailedUpdates" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "DgSurveyScripts" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "DgUpdatedInProd" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "DgUpdates" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "GbLogsDisplayPeriod" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentGbLogsDisplayPeriod } ) },
@{ CName = "GbLogsFilter" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentGbLogsFilter } ) },
@{ CName = "LblErrLogErrorMessage" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblErrorMessage } ) },
@{ CName = "LblRollbackFiltersTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblRollbackFiltersTitle } ) },
@{ CName = "LblLogComputerNameTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblLogComputerNameTitle } ) },
@{ CName = "LblLogErrorLogTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblLogErrorLogTitle } ) },
@{ CName = "LblLogOutputFileTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblLogOutputFileTitle } ) },
@{ CName = "LblLogTextTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblLogTextTitle } ) },
@{ CName = "LblLogUserInputTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblLogUserInputTitle } ) },
@{ CName = "LblErrLogComputerName" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblErrLogComputerName } ) },
@{ CName = "LblErrLogOperator" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblOperator } ) },
@{ CName = "LblErrLogSeverity" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblSeverity } ) },
@{ CName = "LblErrLogUserInput" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblUserInput } ) },
@{ CName = "LblRollbackFilterTypeTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblRollbackFilterTypeTitle } ) },
@{ CName = "LblSurveyFilterTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblSurveyFilterTitle } ) },
@{ CName = "LblSurveyScriptVersionTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblSurveyScriptVersionTitle } ) },
@{ CName = "LblSurveyTotSumTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentLblSurveyTotSumTitle } ) },
@{ CName = "LvRollbackFileNames" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "PbLogSearch" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ) },
@{ CName = "PbParseErrorLogs" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ) },
@{ CName = "PbParseErrorLogsOps" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ; @{ PropName = "Maximum" ; PropVal = [double] 3 } ) },
@{ CName = "PbParseSurveys" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ) },
@{ CName = "PbUpdates" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ) },
@{ CName = "RbLogsDisplayPeriodAll" ; Props = @( @{ PropName = "Content" ; PropVal = $msgTable.ContentRbLogsDisplayPeriodAll } ) },
@{ CName = "RbLogsDisplayPeriodRecent" ; Props = @( @{ PropName = "Content" ; PropVal = $msgTable.ContentRbLogsDisplayPeriodRecent } ) },
@{ CName = "TbDevCount" ; Props = @( @{ PropName = "Text"; PropVal = "-" } ) },
@{ CName = "TbDevTitle" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTbDevTitle } ) },
@{ CName = "TblInfo" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblInfo } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Collapsed } ) },
@{ CName = "TblUpdatedInProd" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTblUpdatedInProd } ) },
@{ CName = "TblUpdateInfo" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) },
@{ CName = "TblUpdatesProgress" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) },
@{ CName = "TbProdCount" ; Props = @( @{ PropName = "Text"; PropVal = "-" } ) },
@{ CName = "TbProdTitle" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTbProdTitle } ) },
@{ CName = "TbTestCount" ; Props = @( @{ PropName = "Text"; PropVal = "-" } ) },
@{ CName = "TbTestTitle" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContentTbTestTitle } ) },
@{ CName = "TbUpdatesSummary" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) },
@{ CName = "TiErrorLogs" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentTiErrorLogs } ) },
@{ CName = "TiFailedUpdates" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentTiFailedUpdates } ) },
@{ CName = "TiLogs" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentTiLogs } ) },
@{ CName = "TiRollback" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentTiRollback } ) },
@{ CName = "TiSurveys" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentTiSurveys } ) },
@{ CName = "TiUpdated" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentTiUpdated } ) },
@{ CName = "TiUpdatedInProd" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentTiUpdatedInProd } ) },
@{ CName = "TiUpdates" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentTiUpdates } ) },
@{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = $msgTable.ContentWindow } ) }
) )

$syncHash = CreateWindowExt -ControlsToBind $controls -IncludeConverters
$syncHash.Data.msgTable = $msgTable
$syncHash.Data.BaseDir = $BaseDir
if ( $BaseDir -match "Development" )
{
	$syncHash.Data.devRoot = $BaseDir
	$syncHash.Data.prodRoot = ( Get-Item $BaseDir ).Parent.FullName
}
else
{
	$syncHash.Data.devRoot = "$BaseDir\Development"
	$syncHash.Data.prodRoot = $BaseDir
}

$syncHash.Data.ParsedLogs = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
$syncHash.Data.ParsedLogsRecent = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
$syncHash.Data.ParsedErrorLogs = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()
$syncHash.Data.RollBackData = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()

$syncHash.Data.CultureInfo = [pscustomobject]@{
	DateTimeStringFormat = "$( ( Get-Culture ).DateTimeFormat.ShortDatePattern ) $( ( Get-Culture ).DateTimeFormat.LongTimePattern )"
	DateTimeFileStringFormat = "$( ( Get-Culture ).DateTimeFormat.ShortDatePattern ) $( ( Get-Culture ).DateTimeFormat.LongTimePattern )" -replace "/", "-" -replace ":", "."
}
$syncHash.Data.RollbackRoot = "$( $syncHash.Data.prodRoot )\UpdateRollback"
$syncHash.Data.updatedFiles = New-Object System.Collections.ArrayList
$syncHash.Data.filesUpdatedInProd = New-Object System.Collections.ArrayList
if ( Test-Path "C:\Program Files (x86)\Notepad++\notepad++.exe" ) { $syncHash.Data.Editor = "C:\Program Files (x86)\Notepad++\notepad++.exe" }
else { $syncHash.Data.Editor = "notepad" }

# Start a check for any updates
$syncHash.BtnCheckForUpdates.Add_Click( { CheckForUpdates } )

# Copy the information for the currently selected error
$syncHash.BtnCopyErrorInfo.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$syncHash.gridErrorInfo.DataContext | Clip
} )

# TODO Fyll I
$syncHash.BtnCopyLogInfo.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$OFS = "`n"
	$a = @"
$( $syncHash.Data.msgTable.StrLogInfoCopyTitle ) '$( $syncHash.CbLogsScriptNames.SelectedItem.ScriptName )'

$( $syncHash.Data.msgTable.StrLogInfoCopyDate ): $( $syncHash.DgLogs.SelectedItem.LogDate )
$( $syncHash.Data.msgTable.StrLogInfoCopyOperator ): $( $syncHash.DgLogs.SelectedItem.Operator )
$( $syncHash.Data.msgTable.StrLogInfoCopySuccess ): $( $syncHash.DgLogs.SelectedItem.Success )
$( $syncHash.Data.msgTable.StrLogInfoCopyLogText ): $( $syncHash.DgLogs.SelectedItem.LogText )
"@

	if ( $syncHash.DgLogs.SelectedItem.ComputerName )
	{
		$a += "$( $syncHash.Data.msgTable.StrLogInfoCopyComputerName ): $( $syncHash.DgLogs.SelectedItem.ComputerName ) "
	}

	if ( $syncHash.DgLogs.SelectedItem.OutputFile.Count -gt 0 )
	{
		if ( $syncHash.CbCopyLogInfoIncludeOutputFiles.IsChecked )
		{
			$a += "$( $syncHash.Data.msgTable.StrLogInfoCopyOutputFile )`n"
			$syncHash.DgLogs.SelectedItem.OutputFile | ForEach-Object { $a += "$( $syncHash.Data.msgTable.StrLogInfoCopyOutputFilePath ): $_`n$( Get-Content $_ )" }
		}
		else { $a += "$( $syncHash.Data.msgTable.StrLogInfoCopyOutputFile ): $( [string]$syncHash.DgLogs.SelectedItem.OutputFile ) " }
	}

	if ( $syncHash.DgLogs.SelectedItem.ErrorLogFile.Count -gt 0 )
	{
		if ( $syncHash.CbCopyLogInfoIncludeErrorLogs.IsChecked )
		{
			$a += "$( $syncHash.Data.msgTable.StrLogInfoCopyError )"
			$syncHash.DgLogs.SelectedItem.ErrorLogFile | ForEach-Object { Get-Content $_ | ConvertFrom-Json | Out-String | ForEach-Object { $e += "$_`n" } }
		}
		else { $a += "$( $syncHash.Data.msgTable.StrLogInfoCopyErrorFilePath ): $( [string]$syncHash.DgLogs.SelectedItem.OutputFile ) " }
	}

	$a | Clip
	$syncHash.PopupCopyLogInfo.IsOpen = $false
} )

# Copy the list of updates for the currently selected script/file
$syncHash.BtnCopyRollbackInfo.Add_Click( {
	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
$a = @"
$( $syncHash.Data.msgTable.StrRollbackInfoCopyTitle ) '$( $syncHash.LvRollbackFileNames.SelectedItem.Script )'

$( $syncHash.Data.msgTable.StrRollbackInfoCopyFileLogs ):
$( $OFS = "`r`n"; $syncHash.LvRollbackFileNames.SelectedItem.FileLogs | ForEach-Object { "$( $_.File.Name )`n$( $syncHash.Data.msgTable.StrRollbackInfoCopyUpdated )`t$( ( Get-Date $_.Updated -Format "yyyy-mm-dd HH:mm:ss" ) )`n$( $syncHash.Data.msgTable.StrRollbackInfoCopyUpdater )`t$( try { ( Get-ADUser -Identity $_.UpdatedBy ).Name } catch { $syncHash.Data.msgTable.StrNoUpdaterSpecified } )`n" } )
"@
$a | Clip
} )

# Reset the controls for Errorlogs
$syncHash.BtnClearErrorLogSearch.Add_Click( {
	$syncHash.BtnClearErrorLogSearch.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.CbErrorLogSearchType.SelectedIndex = -1
	$syncHash.TbErrorLogSearchText.Text = ""
	$syncHash.DC.CbErrorLogsScriptNames[0].Clear()
	$syncHash.Data.ParsedErrorLogs | ForEach-Object { $syncHash.DC.CbErrorLogsScriptNames[0].Add( $_ ) }
} )

# Reset the controls for logs
$syncHash.BtnClearLogSearch.Add_Click( {
	$syncHash.BtnClearLogSearch.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.CbLogSearchType.SelectedIndex = -1
	$syncHash.TbLogSearchText.Text = ""
	$syncHash.DC.CbLogsScriptNames[0].Clear()
	$syncHash.Data.ParsedLogs | ForEach-Object { $syncHash.DC.CbLogsScriptNames[0].Add( $_ ) }
} )

# Open the Dev-version of the file
$syncHash.BtnDiffOpenDev.Add_Click( { OpenFile $syncHash.DiffWindow.DataContext.DevPath } )

# Open the Prod-version of the file
$syncHash.BtnDiffOpenProd.Add_Click( { OpenFile $syncHash.DiffWindow.DataContext.ProdPath } )

# Open both versions of the file
$syncHash.BtnDiffOpenBoth.Add_Click( { OpenFile $syncHash.DiffWindow.DataContext.DevPath, $syncHash.DiffWindow.DataContext.ProdPath } )

# Close the window
$syncHash.BtnDiffCancel.Add_Click( {
	$syncHash.DiffWindow.Visibility = [System.Windows.Visibility]::Hidden
	$syncHash.DiffWindow.DataContext = $null
} )

# Rollback a file to selected version
$syncHash.BtnDoRollback.Add_Click( {
	if ( $null -eq ( $ProdFile = Get-ChildItem -Path "$( $syncHash.Data.prodRoot )\Script" -Filter ( "{0}.{1}" -f $syncHash.DgRollbacks.SelectedItem.Script, $syncHash.DgRollbacks.SelectedItem.Type ) -Recurse -File ) )
	{
		$text = $syncHash.Data.msgTable.StrRollbackPathNotFound
		$icon = [System.Windows.MessageBoxImage]::Warning
		$button = [System.Windows.MessageBoxButton]::OK
	}
	else
	{
		$text = ( "{0}`n`n{1}`n{2}`n`n{3}`n{4}" -f $syncHash.Data.msgTable.StrRollbackVerification, $syncHash.Data.msgTable.StrRollbackVerificationPath, $ProdFile.FullName, $syncHash.Data.msgTable.StrRollbackVerificationDate, $syncHash.DgRollbacks.SelectedItem.Updated )
		$icon = [System.Windows.MessageBoxImage]::Question
		$button = [System.Windows.MessageBoxButton]::YesNo
	}

	if ( ( ShowMessageBox -Text $text -Icon $icon -Button $button ) -eq "Yes" )
	{
		$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
		Set-Content -Value ( Get-Content $syncHash.DgRollbacks.SelectedItem.File.FullName ) -Path $ProdFile.FullName
		ShowMessageBox -Text $syncHash.Data.msgTable.StrRollbackDone
	}
} )

# Search the errorlogs for entered data
$syncHash.BtnErrorLogSearch.Add_Click( {
	$syncHash.BtnClearErrorLogSearch.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.DC.CbErrorLogsScriptNames[0].Clear()
	$syncHash.Data.ParsedErrorLogs | Where-Object { $_.ScriptErrorLogs.( $syncHash.CbErrorLogSearchType.SelectedItem.Content ) -match $syncHash.TbErrorLogSearchText.Text } | ForEach-Object { $syncHash.DC.CbErrorLogsScriptNames[0].Add( $_ ) }
} )

# List rollbacks
$syncHash.BtnListRollbacks.Add_Click( { ParseRollbacks } )

# Parse surveys and load the data
$syncHash.BtnListSurveys.Add_Click( { ParseSurveys } )

# Search the logs for entered data
$syncHash.BtnLogSearch.Add_Click( {
	$syncHash.BtnClearLogSearch.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.DC.CbLogsScriptNames[0].Clear()
	$syncHash.Data.ParsedLogs | Where-Object { $_.ScriptLogs.( $syncHash.CbLogSearchType.SelectedItem.Content ) -match $syncHash.TbLogSearchText.Text } | ForEach-Object { $syncHash.DC.CbLogsScriptNames[0].Add( $_ ) }
} )

# If errorlogs have been parsed, open the selected data in the errorlogs-tab
$syncHash.BtnOpenErrorLog.Add_Click( {
	if ( $syncHash.CbErrorLogsScriptNames.HasItems )
	{
		$syncHash.TbAdmin.SelectedIndex = 2
		$syncHash.CbErrorLogsScriptNames.SelectedItem = $syncHash.CbErrorLogsScriptNames.Items.Where( { $_.ScriptName -eq $syncHash.CbLogsScriptNames.Text } )[0]
		Start-Sleep 0.5
		$syncHash.DgErrorLogs.SelectedIndex = $syncHash.DgErrorLogs.Items.IndexOf( ( $syncHash.DgErrorLogs.Items.Where( { $_.Logdate -eq $syncHash.CbLogErrorlog.SelectedValue } ) )[0] )
	}
	else { ShowMessageBox -Text $syncHash.Data.msgTable.StrErrorlogsNotLoaded }
} )

# Open the outputfile
$syncHash.BtnOpenOutputFile.Add_Click( { OpenFile $syncHash.CbLogOutputFiles.SelectedItem } )

# Open meny to include other data
$syncHash.BtnOpenPopupCopyLogInfo.Add_Click( { $syncHash.PopupCopyLogInfo.IsOpen = -not $syncHash.PopupCopyLogInfo.IsOpen } )

# Open the selected previous version
$syncHash.BtnOpenRollbackFile.Add_Click( { OpenFile $syncHash.DgRollbacks.SelectedItem.FullName } )

# Parse errorlogs and load the data
$syncHash.BtnReadErrorLogs.Add_Click( { ParseErrorlogs } )

# Parse all logs and load the data
$syncHash.BtnReadLogs.Add_Click( { ParseLogs } )

$syncHash.BtnUpdatedInProdOpenDiffs.Add_Click( { ShowDiffWindow <#$syncHash.DgUpdatedInProd.SelectedItem#> } )
$syncHash.BtnUpdatedInProdOpenDevFile.Add_Click( { OpenFile $syncHash.DgUpdatedInProd.SelectedItem.DevPath } )
$syncHash.BtnUpdatedInProdOpenProdFile.Add_Click( { OpenFile $syncHash.DgUpdatedInProd.SelectedItem.ProdPath } )
$syncHash.BtnUpdatedInProdOpenBothFiles.Add_Click( { OpenFile ( $syncHash.DgUpdatedInProd.SelectedItem.psobject.Properties | Where-Object { $_.Name -match "^[^R].+Path$" } | Select-Object -ExpandProperty Value ) } )
$syncHash.BtnUpdatesOpenDiff.Add_Click( { ShowDiffWindow <#$syncHash.DgUpdates.SelectedItem#> } )
$syncHash.BtnUpdatesOpenDevFile.Add_Click( { OpenFile $syncHash.DgUpdates.SelectedItem.DevPath } )
$syncHash.BtnUpdatesOpenProdFile.Add_Click( { OpenFile $syncHash.DgUpdates.SelectedItem.ProdPath } )
$syncHash.BtnUpdatesOpenBothFiles.Add_Click( { OpenFile ( $syncHash.DgUpdates.SelectedItem.psobject.Properties | Where-Object { $_.Name -match "^[^R].+Path$" } | Select-Object -ExpandProperty Value ) } )

# Update selected files
$syncHash.BtnUpdateScripts.Add_Click( { UpdateScripts } )

# Update selected files
$syncHash.BtnUpdateFailedScripts.Add_Click( {
	if ( @( $syncHash.DC.DgFailedUpdates[0] | Where-Object { $_.AllowUpdateAnyway -match $true } ).Count -gt 0 )
	{ UpdateScripts }
	else
	{ ShowMessageBox $syncHash.Data.msgTable.StrNoFailedSelected }
} )

# These checkboxes sets datagridrows visible or collapsed
$syncHash.CbShowDevFiles.Add_Checked( { $syncHash.Window.Resources['DevFilesVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.CbShowDevFiles.Add_Unchecked( { $syncHash.Window.Resources['DevFilesVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.CbRollbackFilterTypePs1.Add_Checked( { $syncHash.Window.Resources['RollbackRowPs1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.CbRollbackFilterTypePs1.Add_Unchecked( { $syncHash.Window.Resources['RollbackRowPs1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.CbRollbackFilterTypePs1.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	UncheckOtherRollbackFilters $this.Content
} )
$syncHash.CbRollbackFilterTypePsd1.Add_Checked( { $syncHash.Window.Resources['RollbackRowPsd1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.CbRollbackFilterTypePsd1.Add_Unchecked( { $syncHash.Window.Resources['RollbackRowPsd1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.CbRollbackFilterTypePsd1.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	UncheckOtherRollbackFilters $this.Content
} )
$syncHash.CbRollbackFilterTypePsm1.Add_Checked( { $syncHash.Window.Resources['RollbackRowPsm1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.CbRollbackFilterTypePsm1.Add_Unchecked( { $syncHash.Window.Resources['RollbackRowPsm1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.CbRollbackFilterTypePsm1.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	UncheckOtherRollbackFilters $this.Content
} )
$syncHash.CbRollbackFilterTypeTxt.Add_Checked( { $syncHash.Window.Resources['RollbackRowTxtVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.CbRollbackFilterTypeTxt.Add_Unchecked( { $syncHash.Window.Resources['RollbackRowTxtVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.CbRollbackFilterTypeTxt.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	UncheckOtherRollbackFilters $this.Content
} )
$syncHash.CbRollbackFilterTypeXaml.Add_Checked( { $syncHash.Window.Resources['RollbackRowXamlVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.CbRollbackFilterTypeXaml.Add_Unchecked( { $syncHash.Window.Resources['RollbackRowXamlVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.CbRollbackFilterTypeXaml.Add_MouseRightButtonDown( {
	$this.IsChecked = $true
	UncheckOtherRollbackFilters $this.Content
} )
$syncHash.CbLogsFilterSuccessFailed.Add_Checked( { $syncHash.Window.Resources['LogskRowFailedVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.CbLogsFilterSuccessFailed.Add_Unchecked( { $syncHash.Window.Resources['LogskRowFailedVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.CbLogsFilterSuccessSuccess.Add_Checked( { $syncHash.Window.Resources['LogskRowSuccessVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.CbLogsFilterSuccessSuccess.Add_Unchecked( { $syncHash.Window.Resources['LogskRowSuccessVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.CbSurveyFilterRating1.Add_Checked( { $syncHash.Window.Resources['SurveyRating1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.CbSurveyFilterRating1.Add_Unchecked( { $syncHash.Window.Resources['SurveyRating1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.CbSurveyFilterRating2.Add_Checked( { $syncHash.Window.Resources['SurveyRating2Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.CbSurveyFilterRating2.Add_Unchecked( { $syncHash.Window.Resources['SurveyRating2Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.CbSurveyFilterRating3.Add_Checked( { $syncHash.Window.Resources['SurveyRating3Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.CbSurveyFilterRating3.Add_Unchecked( { $syncHash.Window.Resources['SurveyRating3Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.CbSurveyFilterRating4.Add_Checked( { $syncHash.Window.Resources['SurveyRating4Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.CbSurveyFilterRating4.Add_Unchecked( { $syncHash.Window.Resources['SurveyRating4Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.CbSurveyFilterRating5.Add_Checked( { $syncHash.Window.Resources['SurveyRating5Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.CbSurveyFilterRating5.Add_Unchecked( { $syncHash.Window.Resources['SurveyRating5Visible'] = [System.Windows.Visibility]::Collapsed } )

# Click was made outside of rows and valid cells, unselect selected rows
$syncHash.DgErrorLogs.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.DgLogs.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.DgRollbacks.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.DgSurveyScripts.Add_SelectionChanged( { $syncHash.CbSurveyScriptVersion.Items.Refresh() } )
$syncHash.DgUpdates.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.DgUpdatedInProd.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )

# Activate button to update files, if any item is selected
$syncHash.DgRollbacks.Add_SelectionChanged( { $syncHash.DC.BtnOpenRollbackFile[1] = $syncHash.DC.BtnDoRollback[1] = $this.SelectedItem -ne $null } )

# Set all surveyfilters to be shown
$syncHash.DgSurveyScripts.Add_SelectionChanged( { 1..5 | ForEach-Object { $syncHash."CbSurveyFilterRating$_".IsChecked = $true } } )
$syncHash.CbSurveyScriptVersion.Add_SelectionChanged( { 1..5 | ForEach-Object { $syncHash."CbSurveyFilterRating$_".IsChecked = $true } } )

# If rightclick is used, open the file from dev and prod
$syncHash.DgUpdates.Add_MouseRightButtonUp( {
	if ( ( $args[1].OriginalSource.GetType() ).Name -eq "TextBlock" )
	{
		OpenFile ( $this.CurrentItem.psobject.Properties | Where-Object { $_.name -match "^[^R].+Path$" } | Select-Object -ExpandProperty Value )
	}
} )

# If rightclick is used, open the file from dev and prod
$syncHash.DgUpdatedInProd.Add_MouseRightButtonUp( {
	ShowDiffWindow $this.CurrentItem
} )

# When a script/file is selected, clear listed rollbacks and set filteroptions according to data for the selected file
$syncHash.LvRollbackFileNames.Add_SelectionChanged( {
	# Hide checkboxes for fileextensions not present in list
	$syncHash.GetEnumerator() | Where-Object { $_.Key -match "CbRollbackFilterType" } | ForEach-Object { $syncHash."$( $_.Key )".Visibility = [System.Windows.Visibility]::Collapsed }
	$syncHash.DgRollbacks.ItemsSource.Type | Select-Object -Unique | ForEach-Object { $syncHash."CbRollbackFilterType$_".Visibility = [System.Windows.Visibility]::Visible }
} )

# Set binding to all logs
$syncHash.rbLogsDisplayPeriodAll.Add_Checked( {
	$b = [System.Windows.Data.Binding]@{ ElementName = "CbLogsScriptNames"; Path = "SelectedItem.ScriptLogs" }
	[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.DgLogs, [System.Windows.Controls.DataGrid]::ItemsSourceProperty, $b )
} )

# Set binding to recent logs
$syncHash.rbLogsDisplayPeriodRecent.Add_Checked( {
	$b = [System.Windows.Data.Binding]@{ ElementName = "CbLogsScriptNames"; Path = "SelectedItem.ScriptLogsRecent" }
	[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.DgLogs, [System.Windows.Controls.DataGrid]::ItemsSourceProperty, $b )
} )

# Window rendered, do some final preparations
$syncHash.Window.Add_ContentRendered( {
	$syncHash.Window.Top = 20
	$syncHash.Window.Activate()
	PrepParsing
	SetLocalizations

	$syncHash.DiffWindow.Owner = $this
	# Get a list of obsolete functions in modules
	$syncHash.ObsoleteFunctions = ( Get-Module ).Where( { $_.Path.StartsWith( $BaseDir ) } ) | `
		ForEach-Object { Get-Command -Module $_.Name } | `
		Where-Object { $_.Definition -match "\[Obsolete.+\]" } | `
		Select-Object -Property `
			@{ Name = "FunctionName"; Expression = { $_.Name } }, `
			@{ Name = "HelpMessage"; Expression = { ( ( ( $_.Definition -split "`n" | Select-String -Pattern "\[Obsolete.+\]" ) -split "\(" )[1] -split "\)" )[0].Trim() } }
} )

# Catch keypress
$syncHash.Window.Add_KeyDown( {
	$syncHash.TempKeyDown += $args
	if ( $args[1].Key -eq "F1" )
	{
		switch ( $syncHash.TbAdmin.SelectedIndex )
		{
			0 { CheckForUpdates }
			1 { ParseLogs }
			2 { ParseErrorlogs }
			3 { ParseRollbacks }
			4 { ParseSurveys }
		}
	}
	elseif ( ( -not $syncHash.TbLogSearchText.IsFocused ) -and ( -not $syncHash.TbErrorLogSearchText.IsFocused ) )
	{
		if     ( $args[1].Key -eq "D1" ) { $syncHash.TbAdmin.SelectedIndex = 0 }
		elseif ( $args[1].Key -eq "D2" ) { $syncHash.TbAdmin.SelectedIndex = 1 }
		elseif ( $args[1].Key -eq "D3" ) { $syncHash.TbAdmin.SelectedIndex = 2 }
		elseif ( $args[1].Key -eq "D4" ) { $syncHash.TbAdmin.SelectedIndex = 3 }
		elseif ( $args[1].Key -eq "D5" ) { $syncHash.TbAdmin.SelectedIndex = 4 }
	}
} )

# Catch keypress
$syncHash.DiffWindow.Add_KeyDown( {
	if ( $args[1].Key -eq "Escape" )
	{
		$this.Visibility = [System.Windows.Visibility]::Hidden
	}
} )

# Window is rendered, do some final settings
$syncHash.DiffWindow.Add_ContentRendered( {
	$this.Top = 20
	$syncHash.BtnDiffOpenDev.IsEnabled = $null -ne $this.DataContext.DevPath
	$syncHash.BtnDiffOpenProd.IsEnabled = $null -ne $this.DataContext.ProdPath
	$syncHash.BtnDiffOpenBoth.IsEnabled = $null -ne $this.DataContext.ProdPath -and $null -ne $this.DataContext.DevPath
} )

# Center the window after resize
$syncHash.DiffWindow.Add_SizeChanged( {
	$syncHash.Temp = $args
	$this.Top = 20
	$this.Left += ( $args[1].PreviousSize.Width / 2 ) - ( $args[1].NewSize.Width / 2 )
} )

# Cancel closing, instead hide window
$syncHash.DiffWindow.Add_Closing( {
	$args[1].Cancel = $true
	$this.Visibility = [System.Windows.Visibility]::Hidden
} )

# Empty DataContext when DiffWindow is no longer visible
$syncHash.DiffWindow.Add_IsVisibleChanged( { if ( $this.Visibility -eq [System.Windows.Visibility]::Hidden ) { $this.DataContext = $null } } )

[void] $syncHash.Window.ShowDialog()
$syncHash.Window.Close()
$global:syncHash = $syncHash
