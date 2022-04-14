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

	$syncHash.DC.dgUpdates[0].Clear()
	$syncHash.DC.dgUpdatedInProd[0].Clear()
	$syncHash.DC.dgFailedUpdates[0].Clear()
	$syncHash.tbUpdated.SelectedIndex = 0
	$syncHash.P = [powershell]::Create().AddScript( { param ( $syncHash )

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
				$listItem = [pscustomobject]@{ Name = $DevFile.Name; New = $false }
				if ( ( $RelativePath = $DevFile.Directory.FullName.Replace( "$( $syncHash.Data.devRoot )", "" ) ) -eq "" ) { $RelativePath = "\" }
			}
			else
			{
				$listItem = [pscustomobject]@{ Name = $ProdFile.Name; New = $false }
				if ( ( $RelativePath = $ProdFile.Directory.FullName.Replace( "$( $syncHash.Data.prodRoot )", "" ) ) -eq "" ) { $RelativePath = "\" }
			}

			$listItem | Add-Member -MemberType NoteProperty -Name "RelativePath" -Value $RelativePath
			$listItem | Add-Member -MemberType NoteProperty -Name "DevPath" -Value $DevFile.FullName
			$listItem | Add-Member -MemberType NoteProperty -Name "DevUpd" -Value ( Get-Date $DevFile.LastWriteTime -Format $syncHash.Data.CultureInfo.DateTimeStringFormat )
			$listItem | Add-Member -MemberType NoteProperty -Name "ProdPath" -Value $ProdFile.FullName
			$listItem | Add-Member -MemberType NoteProperty -Name "ProdUpd" -Value ( Get-Date $ProdFile.LastWriteTime -Format $syncHash.Data.CultureInfo.DateTimeStringFormat )

			if ( $null -eq $ProdFile )
			{
				$listItem.New = $true
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
				$listItem.New = $true
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
			$listItem | Add-Member -MemberType NoteProperty -Name "State" -Value $State
			$listItem | Add-Member -MemberType NoteProperty -Name "ToolTip" -Value $TT

			return $listItem
		}

		$syncHash.DC.tblUpdatesProgress[0] = $syncHash.Data.msgTable.StrCheckingUpdates
		$syncHash.DC.pbUpdates[0] = [double] 0.001

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

		$ticker = 1
		foreach ( $DevFile in $syncHash.Data.DevFiles )
		{
			$syncHash.DC.pbUpdates[0] = [double]( ( $ticker / $syncHash.Data.DevFiles.Count ) * 100 )
			$ProdFile = $syncHash.Data.ProdFiles | Where-Object { $_.Name -eq $DevFile.Name }
			if ( $null -eq $ProdFile )
			{
				$item = GetListItem $DevFile
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.dgUpdates[0].Add( $item ) } )
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
						$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.dgUpdatedInProd[0].Add( $item ) } )
					}
					else
					{
						$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.dgUpdates[0].Add( $item ) } )
					}
				}
			}
			$ticker += 1
		}

		$syncHash.DC.tblUpdatesProgress[0] = $syncHash.Data.msgTable.StrCheckingFilesInProd
		$ticker = 1
		$FilesUpdatedInProd = $syncHash.Data.ProdFiles | Where-Object {
				$_.BaseName -notin $syncHash.Data.DevFiles.BaseName -and
				$_.Name -notin $( $syncHash.Data.fileExclusion += "Start_O365Valmeny.bat", "Start_O365Valmeny.lnk", "Start_SDValmeny.bat";  $syncHash.Data.fileExclusion )
			}
		foreach ( $file in $FilesUpdatedInProd )
		{
			$syncHash.DC.pbUpdates[0] = [double]( ( $ticker / $FilesUpdatedInProd.Count ) * 100 )
			$item = GetListItem $null $file
			$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.dgUpdatedInProd[0].Add( $item ) } )
			$ticker += 1
		}

		if ( $syncHash.DC.dgUpdates[0].Count -gt 0 )
		{
			$syncHash.DC.tbUpdatesSummary[0] = "{0} {1}" -f $syncHash.DC.dgUpdates[0].Count, $syncHash.Data.msgTable.StrUpdates
			$syncHash.DC.tbDevCount[0] = $syncHash.DC.dgUpdates[0].Where( { $_.State -eq "Dev" } ).Count
			$syncHash.DC.tbTestCount[0] = $syncHash.DC.dgUpdates[0].Where( { $_.State -eq "Test" } ).Count
			$syncHash.DC.tbProdCount[0] = $syncHash.DC.dgUpdates[0].Where( { $_.State -eq "Prod" } ).Count
			$syncHash.DC.tblInfo[1] = [System.Windows.Visibility]::Visible
		}
		else
		{
			$syncHash.DC.tbDevCount[0] = $syncHash.DC.tbTestCount[0] = $syncHash.DC.tbProdCount[0] = 0
			$syncHash.DC.tblUpdateInfo[0] = $syncHash.Data.msgTable.StrNoUpdates
			$syncHash.DC.tblInfo[1] = [System.Windows.Visibility]::Collapsed
		}
		$syncHash.DC.pbUpdates[0] = 0.0
		$syncHash.Temp = $Error
	} ).AddArgument( $syncHash )
	$syncHash.H = $syncHash.P.BeginInvoke()
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

	$FilePaths | ForEach-Object { if ( Test-Path $_ ) { Start-Process $syncHash.Data.Editor $_ } }
}

function ParseSurveys
{
	<#
	.Synopsis
		Parse surveyfiles
	#>

	$splash = ShowSplash -Text $syncHash.Data.msgTable.StrSplListSurveys -SelfAdmin
	$syncHash.DC.dgSurveyScripts[0].Clear()
	Get-ChildItem "$BaseDir\Logs" -Recurse -File -Filter "*survey.json" | ForEach-Object {
		$n = $_.BaseName -replace " - Survey"
		if ( $syncHash.DC.dgSurveyScripts.ScriptName -notcontains $n )
		{ $syncHash.DC.dgSurveyScripts[0].Add( [pscustomobject]@{ ScriptName = $n ; SurveyCount = 0 ; Surveys = @{} } ) }
		Get-Content $_.FullName | ForEach-Object {
			$s = $_ | ConvertFrom-Json

			if ( ( $syncHash.DC.dgSurveyScripts[0].Where( { $_.ScriptName -eq $n } ) )[0].Surveys.Keys -notcontains $s.ScriptVersion )
			{
				( $syncHash.DC.dgSurveyScripts[0].Where( { $_.ScriptName -eq $n } ) )[0].Surveys.Add( $s.ScriptVersion, [System.Collections.ArrayList]::new() )
				( $syncHash.DC.dgSurveyScripts[0] | Where-Object { $_.ScriptName -eq $n } ).SurveyCount += 1
			}

			( $syncHash.DC.dgSurveyScripts[0].Where( { $_.ScriptName -eq $n } ) )[0].Surveys.Item( $s.ScriptVersion ).Add( $s )
		}
	}
	$splash.Close()
}

function ParseErrorlogs
{
	<#
	.Synopsis
		Parse errorlogs
	#>

	$splash = ShowSplash -Text $syncHash.Data.msgTable.StrSplReadErrorLogs -SelfAdmin
	$syncHash.DC.cbErrorLogsScriptNames[0].Clear()
	$syncHash.Data.ParsedErrorLogs.Clear()
	Get-ChildItem "$BaseDir\ErrorLogs" -Recurse -File -Filter "*.json" | Sort-Object Name | ForEach-Object {
		$n = $_.BaseName -replace " - ErrorLog"
		if ( $syncHash.Data.ParsedErrorLogs.ScriptName -notcontains $n )
		{ $syncHash.Data.ParsedErrorLogs.Add( [pscustomobject]@{ ScriptName = $n ; ScriptErrorLogs = [System.Collections.ArrayList]::new() } ) }
		Get-Content $_.FullName | ForEach-Object { ( $syncHash.Data.ParsedErrorLogs.Where( { $_.ScriptName -eq $n } ) )[0].ScriptErrorLogs.Add( ( NewErrorLog ( $_ | ConvertFrom-Json ) ) ) }
	}
	$syncHash.Data.ParsedErrorLogs | ForEach-Object { $_.ScriptErrorLogs = $_.ScriptErrorLogs }
	$syncHash.Data.ParsedErrorLogs | ForEach-Object{ $syncHash.DC.cbErrorLogsScriptNames[0].Add( $_ ) }
	$splash.Close()
}

function ParseLogs
{
	<#
	.Synopsis
		Parse logfiles
	#>

	$splash = ShowSplash -Text $syncHash.Data.msgTable.StrSplReadLogs -SelfAdmin
	$syncHash.DC.cbLogsScriptNames[0].Clear()
	$syncHash.Data.ParsedLogs.Clear()
	Get-ChildItem "$BaseDir\Logs" -Recurse -File -Filter "*log.json" | Sort-Object Name | ForEach-Object {
		$n = $_.BaseName -replace " - Log"
		if ( $syncHash.Data.ParsedLogs.ScriptName -notcontains $n )
		{ $syncHash.Data.ParsedLogs.Add( [pscustomobject]@{ ScriptName = $n ; ScriptLogs = [System.Collections.ArrayList]::new() } ) }
		Get-Content $_.FullName | ForEach-Object { ( $syncHash.Data.ParsedLogs.Where( { $_.ScriptName -eq $n } ) )[0].ScriptLogs.Add( ( NewLog ( $_ | ConvertFrom-Json ) ) ) }
	}
	$syncHash.Data.ParsedLogs | ForEach-Object { $_.ScriptLogs = $_.ScriptLogs }
	$syncHash.Data.ParsedLogs | ForEach-Object { $syncHash.DC.cbLogsScriptNames[0].Add( $_ ) }
	$splash.Close()
}

function ParseRollbacks
{
	<#
	.Synopsis
		Parse rollbacked files
	#>

	$splash = ShowSplash -Text $syncHash.Data.msgTable.StrSplReadErrorLogs -SelfAdmin
	try { $syncHash.PRollbacks.EndInvoke( $syncHash.HRollBacks ) } catch {}
	$syncHash.PRollbacks = [powershell]::Create().AddScript( { param ( $syncHash )
		[array] $syncHash.Data.RollbackFiles = Get-ChildItem $syncHash.Data.RollbackRoot -Recurse -File
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.pbListingRollbacks.Visibility = [System.Windows.Visibility]::Visible
		} )

		$syncHash.Data.RollBackData = [System.Collections.ArrayList]::new()
		foreach ( $File in $syncHash.Data.RollbackFiles )
		{
			$FileName, $Info = $File.BaseName -split " \("
			$Info = $Info -replace "\)" -split " "
			if ( [string]::IsNullOrWhiteSpace( $Info[3] ) ) { $Info += $syncHash.Data.msgTable.StrNoUpdaterSpecified }
			$FileData = [pscustomobject]@{ File = $File ; Script = ( $FileName -split "\." )[0] ; Updated = Get-Date "$( $Info[1] ) $( $Info[2] -replace "\.", ":" )" -Format $syncHash.Data.CultureInfo.DateTimeStringFormat ; UpdatedBy = $Info[3] ; Type = $File.Extension -replace "\." }

			if ( $syncHash.Data.RollBackData.Script -notcontains $FileData.Script )
			{
				$TempArray = [System.Collections.ArrayList]::new()
				$TempArray.Add( $FileData )
				[void] $syncHash.Data.RollBackData.Add( [pscustomobject]@{ Script = $FileData.Script ; FileLogs = $TempArray ; PropPath = "" } )
			}
			else
			{ ( $syncHash.Data.RollBackData.Where( { $_.Script -eq $FileData.Script } ) )[0].FileLogs.Add( $FileData ) }
		}

		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.pbListingRollbacks.Visibility = [System.Windows.Visibility]::Collapsed
			$syncHash.Window.Resources['CvsRollBackFileNames'].Source = $syncHash.Data.RollBackData
		} )
	} ).AddArgument( $syncHash )
	$syncHash.HRollBacks = $syncHash.PRollbacks.BeginInvoke()
	$splash.Close()
}

function SetLocalizations
{
	<#
	.Synopsis
		Set localized strings
	#>

	# DatagridTextColumn header and sortdescription for dgUpdates and dgUpdatedInProd
	$syncHash.dgUpdates.Columns[0].Header = $syncHash.dgUpdatedInProd.Columns[0].Header = $syncHash.Data.msgTable.ContentdgUpdatesColName
	$syncHash.dgUpdates.Columns[1].Header = $syncHash.dgUpdatedInProd.Columns[1].Header = $syncHash.Data.msgTable.ContentdgUpdatesColPath
	$syncHash.dgUpdates.Columns[2].Header = $syncHash.dgUpdatedInProd.Columns[2].Header = $syncHash.Data.msgTable.ContentdgUpdatesColDevUpd
	$syncHash.dgUpdates.Columns[3].Header = $syncHash.dgUpdatedInProd.Columns[3].Header = $syncHash.Data.msgTable.ContentdgUpdatesColProdUpd
	$syncHash.dgUpdates.Columns[4].Header = $syncHash.dgUpdatedInProd.Columns[4].Header = $syncHash.Data.msgTable.ContentdgUpdatesColProdState
	$syncHash.dgUpdates.Items.SortDescriptions.Add( ( [System.ComponentModel.SortDescription]::new( "Name", [System.ComponentModel.ListSortDirection]::Ascending ) ) )

	# DatagridTextColumn header and sortdescription for dgLogs
	$syncHash.dgLogs.Columns[0].Header = $syncHash.Data.msgTable.ContentdgLogsColLogDate
	$syncHash.dgLogs.Columns[1].Header = $syncHash.Data.msgTable.ContentdgLogsColSuccess
	$syncHash.dgLogs.Columns[2].Header = $syncHash.Data.msgTable.ContentdgLogsColOperator
	$syncHash.dgLogs.Items.SortDescriptions.Add( ( [System.ComponentModel.SortDescription]::new( "LogDate", [System.ComponentModel.ListSortDirection]::Descending ) ) )

	# DatagridTextColumn header and sortdescription for dgRollbacks
	$syncHash.dgRollbacks.Columns[0].Header = $syncHash.Data.msgTable.ContentdgRollbacksColFileName
	$syncHash.dgRollbacks.Columns[1].Header = $syncHash.Data.msgTable.ContentdgRollbacksColUpdated
	$syncHash.dgRollbacks.Columns[2].Header = $syncHash.Data.msgTable.ContentdgRollbacksColUpdatedBy
	$syncHash.dgRollbacks.Columns[3].Header = $syncHash.Data.msgTable.ContentdgRollbacksColType

	# DatagridTextColumn header and sortdescription for dgErrorLogs
	$syncHash.dgErrorLogs.Columns[0].Header = $syncHash.Data.msgTable.ContentdgErrorLogsColLogDate
	$syncHash.dgErrorLogs.Items.SortDescriptions.Add( ( [System.ComponentModel.SortDescription]::new( "LogDate", [System.ComponentModel.ListSortDirection]::Descending ) ) )

	# DatagridTextColumn headers and sortdescription for dgSurveyScripts
	$syncHash.dgSurveyScripts.Columns[0].Header = $syncHash.Data.msgTable.ContentdgSurveyScriptsColScriptName
	$syncHash.dgSurveyScripts.Columns[1].Header = $syncHash.Data.msgTable.ContentdgSurveyScriptsColSurveyCount
	$syncHash.dgSurveyScripts.Items.SortDescriptions.Add( ( [System.ComponentModel.SortDescription]::new( "ScriptName", [System.ComponentModel.ListSortDirection]::Ascending ) ) )

	# DatagridTextColumn headers for dgSurveyAnswers
	$syncHash.dgSurveyAnswers.Columns[0].Header = $syncHash.Data.msgTable.ContentdgSurveyAnswersColComment
	$syncHash.dgSurveyAnswers.Columns[1].Header = $syncHash.Data.msgTable.ContentdgSurveyAnswersColRating
	$syncHash.dgSurveyAnswers.Columns[2].Header = $syncHash.Data.msgTable.ContentdgSurveyAnswersColOperator
	$syncHash.dgSurveyAnswers.Columns[3].Header = $syncHash.Data.msgTable.ContentdgSurveyAnswersColDate

	# DatagridTextColumn headers for dgFailedUpdates
	$syncHash.dgFailedUpdates.Columns[0].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColName
	$syncHash.dgFailedUpdates.Columns[1].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColUpdateAnyway
	$syncHash.dgFailedUpdates.Columns[2].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColAcceptedVerb
	$syncHash.dgFailedUpdates.Columns[3].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColWritesToLog
	$syncHash.dgFailedUpdates.Columns[4].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColScriptInfo
	$syncHash.dgFailedUpdates.Columns[5].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColObsoleteFunctions
	$syncHash.dgFailedUpdates.Columns[6].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColInvalidLocalizations
	$syncHash.dgFailedUpdates.Columns[7].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColOrphandLocalizations
	$syncHash.dgFailedUpdates.Columns[8].Header = $syncHash.Data.msgTable.ContentdgFailedUpdatesColTODOs

	# Text for style trigger in list for survey answers
	$syncHash.dgSurveyAnswers.Columns[0].CellTemplate.Triggers.Setters[1].Value = $syncHash.Data.msgTable.ContentdgSurveyNoComment

	# DatagridTextColumn headers for datagrids in dgFailedUpdates-cells
	$syncHash.dgFailedUpdates.Resources['dgOFColHeaderFunctionName'] = $syncHash.Data.msgTable.ContentdgObsoleteFunctionsColFunctionName
	$syncHash.dgFailedUpdates.Resources['dgOFColHeaderHelpMessage'] = $syncHash.Data.msgTable.ContentdgObsoleteFunctionsColHelpMessage
	$syncHash.dgFailedUpdates.Resources['dgOFColHeaderLineNumbers'] = $syncHash.Data.msgTable.ContentdgObsoleteFunctionsColLineNumbers

	$syncHash.dgFailedUpdates.Resources['dgIVColHeaderTextLN'] = $syncHash.Data.msgTable.ContentdgInvalidLocalizationsColLineNumber
	$syncHash.dgFailedUpdates.Resources['dgIVColHeaderTextSV'] = $syncHash.Data.msgTable.ContentdgInvalidLocalizationsColScriptVar
	$syncHash.dgFailedUpdates.Resources['dgIVColHeaderTextSL'] = $syncHash.Data.msgTable.ContentdgInvalidLocalizationsColScriptLine

	$syncHash.dgFailedUpdates.Resources['dgOLColHeaderTextLVar'] = $syncHash.Data.msgTable.ContentdgOrphandLocalizationsColVariable
	$syncHash.dgFailedUpdates.Resources['dgOLColHeaderTextLVal'] = $syncHash.Data.msgTable.ContentdgOrphandLocalizationsColValue

	$syncHash.dgFailedUpdates.Resources['dgSIColHeaderTitle'] = $syncHash.Data.msgTable.ContentdgSIColHeaderTitle
	$syncHash.dgFailedUpdates.Resources['dgSIColHeaderInfoDesc'] = $syncHash.Data.msgTable.ContentdgSIColHeaderInfoDesc

	$syncHash.dgFailedUpdates.Resources['dgTDColHeaderTextL'] = $syncHash.Data.msgTable.ContentdgTDColHeaderTextL
	$syncHash.dgFailedUpdates.Resources['dgTDColHeaderTextLN'] = $syncHash.Data.msgTable.ContentdgTDColHeaderTextLN

	$syncHash.dgFailedUpdates.Resources['NoAcceptedVerb'] = $syncHash.Data.msgTable.ContentNoAcceptedVerb

	$syncHash.dgDiffList.Columns[0].Header = $syncHash.Data.msgTable.ContentdgDiffListColDevRow
	$syncHash.dgDiffList.Columns[1].Header = $syncHash.Data.msgTable.ContentdgDiffListColLineNr
	$syncHash.dgDiffList.Columns[2].Header = $syncHash.Data.msgTable.ContentdgDiffListColProdRow

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

	if ( $syncHash.tbUpdated.SelectedIndex -eq 0 ) { $LvItem = $syncHash.dgUpdates.SelectedItem }
	else { $LvItem = $syncHash.dgUpdatedInProd.SelectedItem }
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
	$Test.AcceptedVerb = ( Get-Verb ).Verb | ForEach-Object { $AV = $false } { if ( $script.BaseName -match "^$_" ) { $AV = $true } } { $AV }

	# Test if the script writes to log
	$Test.WritesToLog = ( $script | Select-String -Pattern "WriteLogTest" ).Count -gt 0

	# Test if there are any localizationvariables that are not used or are being used but does not exist
	$Test.OrphandLocalizations, $Test.InvalidLocalizations = FindOrphandLocalizations $script.BaseName

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
	if ( $syncHash.tbUpdated.SelectedIndex -eq 0 )
	{
		foreach ( $file in $syncHash.dgUpdates.SelectedItems )
		{
			if ( $file.Name -match "\.ps1$" )
			{
				$FileTest = TestScript $file
				if ( $FileTest.FailedTestCount -eq 0 )
				{ $FilesToUpdate += $file }
				else
				{ $syncHash.DC.dgFailedUpdates[0].Add( $FileTest ) }
			}
			else
			{ $FilesToUpdate += $file }
		}
	}
	elseif ( $syncHash.tbUpdated.SelectedIndex -eq 1 )
	{
		$FilesToUpdate = @( $syncHash.DC.dgFailedUpdates[0] | Where-Object { $_.UpdateAnyway } ).File
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
	if ( $syncHash.DC.dgFailedUpdates[0].Count -gt 0 )
	{
		$LogText += "`n$( $syncHash.DC.dgFailedUpdates[0].Count ) $( $syncHash.Data.msgTable.LogFailedUpdates ):`n"
		$syncHash.DC.dgFailedUpdates[0] | ForEach-Object { "$( $syncHash.Data.msgTable.LogFailedUpdatesName ) $( $_ )`n$( $syncHash.Data.msgTable.LogFailedUpdatesTestResults )" }
	}

	if ( $syncHash.DC.dgUpdatedInProd[0].Count -gt 0 )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.StrUpdatesInProd ): "
		$LogText += [string]( $syncHash.DC.dgUpdatedInProd[0] | ForEach-Object { "$( if ( $_.Path -ne "\" ) { $_.Path } )", $_.Name } )
	}

	WriteLogTest -Text $LogText -UserInput [string]$syncHash.Updated.Name -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null

	if ( $syncHash.tbUpdated.SelectedIndex -eq 0 )
	{
		$temp = $syncHash.DC.dgUpdates[0] | Where-Object { $_ -notin $syncHash.dgUpdates.SelectedItems }
		$syncHash.DC.dgUpdates[0].Clear()
		$temp | ForEach-Object { $syncHash.DC.dgUpdates[0].Add( $_ ) }
	}
	elseif ( $syncHash.tbUpdated.SelectedIndex -eq 1 )
	{
		$temp = $syncHash.DC.dgFailedUpdates[0] | Where-Object { $_.File -notin $FilesToUpdate }
		$syncHash.DC.dgFailedUpdates[0].Clear()
		if ( $temp.Count -gt 0 ) { $temp | ForEach-Object { $syncHash.DC.dgFailedUpdates[0].Add( $_ ) } }
	}
	$syncHash.DC.tblInfo[1] = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.Window[0] = ""
}

######################### Script start
Add-Type -AssemblyName PresentationFramework

$BaseDir = $args[0]
Get-ChildItem -Path "$BaseDir\Modules" -Filter "*.psm1" | ForEach-Object { Import-Module $_.FullName -Force -ArgumentList $args[1] }

$controls = [System.Collections.ArrayList]::new( @(
@{ CName = "btnCheckForUpdates" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCheckForUpdates } ) },
@{ CName = "btnClearErrorLogSearch" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnClearErrorLogSearch } ) },
@{ CName = "btnClearLogSearch" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnClearLogSearch } ) },
@{ CName = "btnDiffOpenBoth" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnDiffOpenBoth } ) },
@{ CName = "btnDiffCancel" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnDiffCancel } ) },
@{ CName = "btnDiffOpenDev" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnDiffOpenDev } ) },
@{ CName = "btnDiffOpenProd" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnDiffOpenProd } ) },
@{ CName = "btnDoRollback" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnDoRollback } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) },
@{ CName = "btnErrorLogSearch" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnErrorLogSearch } ) },
@{ CName = "btnListRollbacks" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnListRollbacks } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) },
@{ CName = "btnListSurveys" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnListSurveys } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) },
@{ CName = "btnLogSearch" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnLogSearch } ) },
@{ CName = "btnUpdatedInProdOpenBothFiles" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUpdatedInProdOpenBothFiles } ) },
@{ CName = "btnUpdatedInProdOpenDevFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUpdatedInProdOpenDevFile } ) },
@{ CName = "btnUpdatedInProdOpenDiffs" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUpdatedInProdOpenDiffs } ) },
@{ CName = "btnUpdatedInProdOpenProdFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUpdatedInProdOpenProdFile } ) },
@{ CName = "btnUpdateFailedScripts" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUpdateFailedScripts } ) },
@{ CName = "btnOpenErrorLog" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenErrorLog } ) },
@{ CName = "btnOpenOutputFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenOutputFile } ) },
@{ CName = "btnOpenRollbackFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenRollbackFile } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) },
@{ CName = "btnReadErrorLogs" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnReadErrorLogs } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) },
@{ CName = "btnReadLogs" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnReadLogs } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) },
@{ CName = "btnUpdateScripts" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUpdateScripts } ) },
@{ CName = "btnUpdatesOpenBothFiles" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUpdatesOpenBothFiles } ) },
@{ CName = "btnUpdatesOpenDevFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUpdatesOpenDevFile } ) },
@{ CName = "btnUpdatesOpenProdFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUpdatesOpenProdFile } ) },
@{ CName = "btnUpdatesOpenDiff" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUpdatesOpenDiff } ) },
@{ CName = "cbErrorLogsScriptNames" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "cbLogsFilterSuccessFailed" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentcbLogsFilterSuccessFailed } ) },
@{ CName = "cbLogsFilterSuccessSuccess" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentcbLogsFilterSuccessSuccess } ) },
@{ CName = "cbLogsScriptNames" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "cbShowDevFiles" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentcbShowDevFiles } ; @{ PropName = "IsChecked" ; PropVal = $true } ) },
@{ CName = "cbRollbackFilterTypePs1" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentcbRollbackFilterTypePs1 } ; @{ PropName = "Tooltip" ; PropVal = $msgTable.ContentcbRollbackFilterTypePs1Tooltip } ) },
@{ CName = "cbRollbackFilterTypePsd1" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentcbRollbackFilterTypePsd1 } ; @{ PropName = "Tooltip" ; PropVal = $msgTable.ContentcbRollbackFilterTypePsd1Tooltip } ) },
@{ CName = "cbRollbackFilterTypePsm1" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentcbRollbackFilterTypePsm1 } ; @{ PropName = "Tooltip" ; PropVal = $msgTable.ContentcbRollbackFilterTypePsm1Tooltip } ) },
@{ CName = "cbRollbackFilterTypeTxt" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentcbRollbackFilterTypeTxt } ; @{ PropName = "Tooltip" ; PropVal = $msgTable.ContentcbRollbackFilterTypeTxtTooltip } ) },
@{ CName = "cbRollbackFilterUpdatedBy" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "cbRollbackFilterTypeXaml" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentcbRollbackFilterTypeXaml } ; @{ PropName = "Tooltip" ; PropVal = $msgTable.ContentcbRollbackFilterTypeXamlTooltip } ) },
@{ CName = "dgFailedUpdates" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "dgSurveyScripts" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "dgUpdatedInProd" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "dgUpdates" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( [System.Collections.ObjectModel.ObservableCollection[Object]]::new() ) } ) },
@{ CName = "gbErrorInfo" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgbErrorInfo } ) },
@{ CName = "lblErrLogErrorMessage" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblErrorMessage } ) },
@{ CName = "lblRollbackFiltersTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRollbackFiltersTitle } ) },
@{ CName = "lblLogComputerNameTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLogComputerNameTitle } ) },
@{ CName = "lblLogErrorLogTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLogErrorLogTitle } ) },
@{ CName = "lblLogOutputFileTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLogOutputFileTitle } ) },
@{ CName = "lblLogTextTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLogTextTitle } ) },
@{ CName = "lblLogUserInputTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLogUserInputTitle } ) },
@{ CName = "lblErrLogComputerName" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblErrLogComputerName } ) },
@{ CName = "lblErrLogOperator" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOperator } ) },
@{ CName = "lblErrLogSeverity" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSeverity } ) },
@{ CName = "lblErrLogUserInput" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblUserInput } ) },
@{ CName = "lblRollbackFilterTypeTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRollbackFilterTypeTitle } ) },
@{ CName = "lblSurveyFilterTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSurveyFilterTitle } ) },
@{ CName = "lblSurveyScriptVersionTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSurveyScriptVersionTitle } ) },
@{ CName = "lblSurveyTotSumTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSurveyTotSumTitle } ) },
@{ CName = "lblRollbackFilterUpdatedByTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblRollbackFilterUpdatedByTitle } ) },
@{ CName = "pbUpdates" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ) },
@{ CName = "tbDevCount" ; Props = @( @{ PropName = "Text"; PropVal = "-" } ) },
@{ CName = "tbDevTitle" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttbDevTitle } ) },
@{ CName = "tblInfo" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttblInfo } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Collapsed } ) },
@{ CName = "tblUpdatedInProd" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttblUpdatedInProd } ) },
@{ CName = "tblUpdateInfo" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) },
@{ CName = "tblUpdatesProgress" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) },
@{ CName = "tbProdCount" ; Props = @( @{ PropName = "Text"; PropVal = "-" } ) },
@{ CName = "tbProdTitle" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttbProdTitle } ) },
@{ CName = "tbTestCount" ; Props = @( @{ PropName = "Text"; PropVal = "-" } ) },
@{ CName = "tbTestTitle" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttbTestTitle } ) },
@{ CName = "tbUpdatesSummary" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) },
@{ CName = "tiErrorLogs" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiErrorLogs } ) },
@{ CName = "tiFailedUpdates" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiFailedUpdates } ) },
@{ CName = "tiLogs" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiLogs } ) },
@{ CName = "tiRollback" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiRollback } ) },
@{ CName = "tiSurveys" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiSurveys } ) },
@{ CName = "tiUpdated" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiUpdated } ) },
@{ CName = "tiUpdatedInProd" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiUpdatedInProd } ) },
@{ CName = "tiUpdates" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiUpdates } ) },
@{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = $msgTable.ContentWindow } ) }
) )

$syncHash = CreateWindowExt -ControlsToBind $controls -IncludeConverters
$syncHash.Data.msgTable = $msgTable
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
$syncHash.Data.ParsedErrorLogs = [System.Collections.ObjectModel.ObservableCollection[Object]]::new()

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
$syncHash.btnCheckForUpdates.Add_Click( { CheckForUpdates } )

# Reset the controls for Errorlogs
$syncHash.btnClearErrorLogSearch.Add_Click( {
	$syncHash.btnClearErrorLogSearch.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.cbErrorLogSearchType.SelectedIndex = -1
	$syncHash.tbErrorLogSearchText.Text = ""
	$syncHash.DC.cbErrorLogsScriptNames[0].Clear()
	$syncHash.Data.ParsedErrorLogs | ForEach-Object { $syncHash.DC.cbErrorLogsScriptNames[0].Add( $_ ) }
} )

# Reset the controls for logs
$syncHash.btnClearLogSearch.Add_Click( {
	$syncHash.btnClearLogSearch.Visibility = [System.Windows.Visibility]::Collapsed
	$syncHash.cbLogSearchType.SelectedIndex = -1
	$syncHash.tbLogSearchText.Text = ""
	$syncHash.DC.cbLogsScriptNames[0].Clear()
	$syncHash.Data.ParsedLogs | ForEach-Object { $syncHash.DC.cbLogsScriptNames[0].Add( $_ ) }
} )

# Open the Dev-version of the file
$syncHash.btnDiffOpenDev.Add_Click( { OpenFile $syncHash.DiffWindow.DataContext.DevPath } )

# Open the Prod-version of the file
$syncHash.btnDiffOpenProd.Add_Click( { OpenFile $syncHash.DiffWindow.DataContext.ProdPath } )

# Open both versions of the file
$syncHash.btnDiffOpenBoth.Add_Click( { OpenFile $syncHash.DiffWindow.DataContext.DevPath, $syncHash.DiffWindow.DataContext.ProdPath } )

# Close the window
$syncHash.btnDiffCancel.Add_Click( {
	$syncHash.DiffWindow.Visibility = [System.Windows.Visibility]::Hidden
	$syncHash.DiffWindow.DataContext = $null
} )

# Rollback a file to selected version
$syncHash.btnDoRollback.Add_Click( {
	if ( $null -eq ( $ProdFile = Get-ChildItem -Path $syncHash.Data.prodRoot -Filter ( "{0}.{1}" -f $syncHash.dgRollbacks.SelectedItem.Script, $syncHash.dgRollbacks.SelectedItem.Type ) -Recurse -File | Where-Object { -not $_.FullName.StartsWith( $syncHash.Data.devRoot ) } ) )
	{
		$text = $syncHash.Data.msgTable.StrRollbackPathNotFound
		$icon = [System.Windows.MessageBoxImage]::Warning
		$button = [System.Windows.MessageBoxButton]::OK
	}
	else
	{
		$text = ( "{0}`n`n{1}`n{2}`n`n{3}`n{4}" -f $syncHash.Data.msgTable.StrRollbackVerification, $syncHash.Data.msgTable.StrRollbackVerificationPath, $ProdFile.FullName, $syncHash.Data.msgTable.StrRollbackVerificationDate, $syncHash.dgRollbacks.SelectedItem.Date )
		$icon = [System.Windows.MessageBoxImage]::Question
		$button = [System.Windows.MessageBoxButton]::YesNo
	}

	if ( ( ShowMessageBox -Text $text -Icon $icon -Button $button ) -eq "Yes" )
	{
		$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
		Set-Content -Value ( Get-Content $syncHash.dgRollbacks.SelectedItem.File.FullName ) -Path $ProdFile.FullName
		ShowMessageBox -Text $syncHash.Data.msgTable.StrRollbackDone
	}
} )

# Search the errorlogs for entered data
$syncHash.btnErrorLogSearch.Add_Click( {
	$syncHash.btnClearErrorLogSearch.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.DC.cbErrorLogsScriptNames[0].Clear()
	$syncHash.Data.ParsedErrorLogs | Where-Object { $_.ScriptErrorLogs.( $syncHash.cbErrorLogSearchType.SelectedItem.Content ) -match $syncHash.tbErrorLogSearchText.Text } | ForEach-Object { $syncHash.DC.cbErrorLogsScriptNames[0].Add( $_ ) }
} )

# List rollbacks
$syncHash.btnListRollbacks.Add_Click( { ParseRollbacks } )

# Parse surveys and load the data
$syncHash.btnListSurveys.Add_Click( { ParseSurveys } )

# Search the logs for entered data
$syncHash.btnLogSearch.Add_Click( {
	$syncHash.btnClearLogSearch.Visibility = [System.Windows.Visibility]::Visible
	$syncHash.DC.cbLogsScriptNames[0].Clear()
	$syncHash.Data.ParsedLogs | Where-Object { $_.ScriptLogs.( $syncHash.cbLogSearchType.SelectedItem.Content ) -match $syncHash.tbLogSearchText.Text } | ForEach-Object { $syncHash.DC.cbLogsScriptNames[0].Add( $_ ) }
} )

# If errorlogs have been parsed, open the selected data in the errorlogs-tab
$syncHash.btnOpenErrorLog.Add_Click( {
	if ( $syncHash.cbErrorLogsScriptNames.HasItems )
	{
		$syncHash.tbAdmin.SelectedIndex = 2
		$syncHash.cbErrorLogsScriptNames.SelectedItem = $syncHash.cbErrorLogsScriptNames.Items.Where( { $_.ScriptName -eq $syncHash.cbLogsScriptNames.Text } )[0]
		Start-Sleep 0.5
		$syncHash.dgErrorLogs.SelectedIndex = $syncHash.dgErrorLogs.Items.IndexOf( ( $syncHash.dgErrorLogs.Items.Where( { $_.Logdate -eq $syncHash.cbLogErrorlog.SelectedValue } ) )[0] )
	}
	else { ShowMessageBox -Text $syncHash.Data.msgTable.StrErrorlogsNotLoaded }
} )

# Open the outputfile
$syncHash.btnOpenOutputFile.Add_Click( { OpenFile $syncHash.cbLoOutputFiles.SelectedItem } )

# Parse errorlogs and load the data
$syncHash.btnReadErrorLogs.Add_Click( { ParseErrorlogs } )

# Parse all logs and load the data
$syncHash.btnReadLogs.Add_Click( { ParseLogs } )

# Open the selected previous version
$syncHash.btnOpenRollbackFile.Add_Click( { OpenFile $syncHash.dgRollbacks.SelectedItem.FullName } )

$syncHash.btnUpdatedInProdOpenDiffs.Add_Click( { ShowDiffWindow <#$syncHash.dgUpdatedInProd.SelectedItem#> } )
$syncHash.btnUpdatedInProdOpenDevFile.Add_Click( { OpenFile $syncHash.dgUpdatedInProd.SelectedItem.DevPath } )
$syncHash.btnUpdatedInProdOpenProdFile.Add_Click( { OpenFile $syncHash.dgUpdatedInProd.SelectedItem.ProdPath } )
$syncHash.btnUpdatedInProdOpenBothFiles.Add_Click( { OpenFile ( $syncHash.dgUpdatedInProd.SelectedItem.psobject.Properties | Where-Object { $_.Name -match "^[^R].+Path$" } | Select-Object -ExpandProperty Value ) } )
$syncHash.btnUpdatesOpenDiff.Add_Click( { ShowDiffWindow <#$syncHash.dgUpdates.SelectedItem#> } )
$syncHash.btnUpdatesOpenDevFile.Add_Click( { OpenFile $syncHash.dgUpdates.SelectedItem.DevPath } )
$syncHash.btnUpdatesOpenProdFile.Add_Click( { OpenFile $syncHash.dgUpdates.SelectedItem.ProdPath } )
$syncHash.btnUpdatesOpenBothFiles.Add_Click( { OpenFile ( $syncHash.dgUpdates.SelectedItem.psobject.Properties | Where-Object { $_.Name -match "^[^R].+Path$" } | Select-Object -ExpandProperty Value ) } )

# Update selected files
$syncHash.btnUpdateScripts.Add_Click( { UpdateScripts } )

# Update selected files
$syncHash.btnUpdateFailedScripts.Add_Click( {
	if ( @( $syncHash.DC.dgFailedUpdates[0] | Where-Object { $_.AllowUpdateAnyway -match $true } ).Count -gt 0 )
	{ UpdateScripts }
	else
	{ ShowMessageBox $syncHash.Data.msgTable.StrNoFailedSelected }
} )

# These checkboxes sets datagridrows visible or collapsed
$syncHash.cbShowDevFiles.Add_Checked( { $syncHash.Window.Resources['DevFilesVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.cbShowDevFiles.Add_Unchecked( { $syncHash.Window.Resources['DevFilesVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.cbRollbackFilterTypePs1.Add_Checked( { $syncHash.Window.Resources['RollbackRowPs1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.cbRollbackFilterTypePs1.Add_Unchecked( { $syncHash.Window.Resources['RollbackRowPs1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.cbRollbackFilterTypePsd1.Add_Checked( { $syncHash.Window.Resources['RollbackRowPsd1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.cbRollbackFilterTypePsd1.Add_Unchecked( { $syncHash.Window.Resources['RollbackRowPsd1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.cbRollbackFilterTypePsm1.Add_Checked( { $syncHash.Window.Resources['RollbackRowPsm1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.cbRollbackFilterTypePsm1.Add_Unchecked( { $syncHash.Window.Resources['RollbackRowPsm1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.cbRollbackFilterTypeTxt.Add_Checked( { $syncHash.Window.Resources['RollbackRowTxtVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.cbRollbackFilterTypeTxt.Add_Unchecked( { $syncHash.Window.Resources['RollbackRowTxtVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.cbRollbackFilterTypeXaml.Add_Checked( { $syncHash.Window.Resources['RollbackRowXamlVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.cbRollbackFilterTypeXaml.Add_Unchecked( { $syncHash.Window.Resources['RollbackRowXamlVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.cbLogsFilterSuccessFailed.Add_Checked( { $syncHash.Window.Resources['LogskRowFailedVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.cbLogsFilterSuccessFailed.Add_Unchecked( { $syncHash.Window.Resources['LogskRowFailedVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.cbLogsFilterSuccessSuccess.Add_Checked( { $syncHash.Window.Resources['LogskRowSuccessVisible'] = [System.Windows.Visibility]::Visible } )
$syncHash.cbLogsFilterSuccessSuccess.Add_Unchecked( { $syncHash.Window.Resources['LogskRowSuccessVisible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.cbSurveyFilterRating1.Add_Checked( { $syncHash.Window.Resources['SurveyRating1Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.cbSurveyFilterRating1.Add_Unchecked( { $syncHash.Window.Resources['SurveyRating1Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.cbSurveyFilterRating2.Add_Checked( { $syncHash.Window.Resources['SurveyRating2Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.cbSurveyFilterRating2.Add_Unchecked( { $syncHash.Window.Resources['SurveyRating2Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.cbSurveyFilterRating3.Add_Checked( { $syncHash.Window.Resources['SurveyRating3Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.cbSurveyFilterRating3.Add_Unchecked( { $syncHash.Window.Resources['SurveyRating3Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.cbSurveyFilterRating4.Add_Checked( { $syncHash.Window.Resources['SurveyRating4Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.cbSurveyFilterRating4.Add_Unchecked( { $syncHash.Window.Resources['SurveyRating4Visible'] = [System.Windows.Visibility]::Collapsed } )
$syncHash.cbSurveyFilterRating5.Add_Checked( { $syncHash.Window.Resources['SurveyRating5Visible'] = [System.Windows.Visibility]::Visible } )
$syncHash.cbSurveyFilterRating5.Add_Unchecked( { $syncHash.Window.Resources['SurveyRating5Visible'] = [System.Windows.Visibility]::Collapsed } )

# Click was made outside of rows and valid cells, unselect selected rows
$syncHash.dgErrorLogs.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.dgLogs.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.dgRollbacks.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.dgSurveyScripts.Add_SelectionChanged( { $syncHash.cbSurveyScriptVersion.Items.Refresh() } )
$syncHash.dgUpdates.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.dgUpdatedInProd.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )

# Activate button to update files, if any item is selected
$syncHash.dgRollbacks.Add_SelectionChanged( { $syncHash.DC.btnOpenRollbackFile[1] = $syncHash.DC.btnDoRollback[1] = $this.SelectedItem -ne $null } )

# Set all surveyfilters to be shown
$syncHash.dgSurveyScripts.Add_SelectionChanged( { 1..5 | ForEach-Object { $syncHash."cbSurveyFilterRating$_".IsChecked = $true } } )
$syncHash.cbSurveyScriptVersion.Add_SelectionChanged( { 1..5 | ForEach-Object { $syncHash."cbSurveyFilterRating$_".IsChecked = $true } } )

# If rightclick is used, open the file from dev and prod
$syncHash.dgUpdates.Add_MouseRightButtonUp( {
	if ( ( $args[1].OriginalSource.GetType() ).Name -eq "TextBlock" )
	{
		OpenFile ( $this.CurrentItem.psobject.Properties | Where-Object { $_.name -match "^[^R].+Path$" } | Select-Object -ExpandProperty Value )
	}
} )

# If rightclick is used, open the file from dev and prod
$syncHash.dgUpdatedInProd.Add_MouseRightButtonUp( {
	ShowDiffWindow $this.CurrentItem
} )

# When a script/file is selected, clear listed rollbacks and set filteroptions according to data for the selected file
$syncHash.lvRollbackFileNames.Add_SelectionChanged( {
	$syncHash.DC.cbRollbackFilterUpdatedBy[0].Clear()
	$syncHash.GetEnumerator() | Where-Object { $_.Key -match "cbRollbackFilterType" } | ForEach-Object { $syncHash."$( $_.Key )".Visibility  = [System.Windows.Visibility]::Collapsed }
	( $syncHash.dgRollbacks.ItemsSource.Type | Select-Object -Unique ) | ForEach-Object { $syncHash."cbRollbackFilterType$_".Visibility = [System.Windows.Visibility]::Visible }
	$syncHash.dgRollbacks.ItemsSource.UpdatedBy | Where-Object { $_ -ne $syncHash.Data.msgTable.StrNoUpdaterSpecified } | Select-Object -Unique | Sort-Object | ForEach-Object { $syncHash.DC.cbRollbackFilterUpdatedBy[0].Add( $_ ) }
} )

# Window rendered, do some final preparations
$syncHash.Window.Add_ContentRendered( {
	$syncHash.Window.Top = 20
	$syncHash.Window.Activate()
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
		switch ( $syncHash.tbAdmin.SelectedIndex )
		{
			0 { CheckForUpdates }
			1 { ParseLogs }
			2 { ParseErrorlogs }
			3 { ParseRollbacks }
			4 { ParseSurveys }
		}
	}
	elseif ( ( -not $syncHash.tbLogSearchText.IsFocused ) -and ( -not $syncHash.tbErrorLogSearchText.IsFocused ) )
	{
		if ( $args[1].Key -eq "D1" ) { $syncHash.tbAdmin.SelectedIndex = 0 }
		elseif ( $args[1].Key -eq "D2" ) { $syncHash.tbAdmin.SelectedIndex = 1 }
		elseif ( $args[1].Key -eq "D3" ) { $syncHash.tbAdmin.SelectedIndex = 2 }
		elseif ( $args[1].Key -eq "D4" ) { $syncHash.tbAdmin.SelectedIndex = 3 }
		elseif ( $args[1].Key -eq "D5" ) { $syncHash.tbAdmin.SelectedIndex = 4 }
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
	$syncHash.btnDiffOpenDev.IsEnabled = $null -ne $this.DataContext.DevPath
	$syncHash.btnDiffOpenProd.IsEnabled = $null -ne $this.DataContext.ProdPath
	$syncHash.btnDiffOpenBoth.IsEnabled = $null -ne $this.DataContext.ProdPath -and $null -ne $this.DataContext.DevPath
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
