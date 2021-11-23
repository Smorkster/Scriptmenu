<#
.Synopsis Administration of scripts, logs, etc.
.Description Perform administration of updates, logs, reports, etc.
.State Prod
.AllowedUsers smorkster
.Author Smorkster (smorkster)
#>

#############################
# Search for any updated file
function CheckForUpdates
{
	$syncHash.P = [powershell]::Create().AddScript( { param ( $syncHash )
		#######################################
		# Get the productionstate of the script
		function GetState
		{
			param ( $devFile )

			if ( $devFile.Extension -in ".xaml",".psd1" )
			{
				$state = ( ( Get-ChildItem $syncHash.Data.devRoot -Recurse -File -Filter "$( $devFile.BaseName ).ps1" | Get-Content | Where-Object { $_ -match "^\.State" } ) -split " " )[-1]
				$TT = "$( $syncHash.Data.msgTable.StrScriptState ) '$state'"
			}
			elseif ( $devFile.Extension -in ".ps1",".psm1" )
			{
				$state = ( ( Get-Content -Path $devFile.FullName | Where-Object { $_ -match "^\.State" } ) -split " " )[1]
			}
			else
			{
				$state = $syncHash.Data.msgTable.StrOtherScriptState
			}
			return $state, $TT
		}

		#######################################
		# Create an object for the updated file
		function GetListItem
		{
			param ( $devFile, $prodFile )

			$listItem = [pscustomobject]@{
				Name = $devFile.Name
				DevPath = $devFile.FullName
				DevUpd = ( Get-Date $devFile.LastWriteTime -Format "yyyy-MM-dd hh:mm:ss" )
			}

			if ( ( $path = $devFile.Directory.FullName.Replace( "$( $syncHash.Data.devRoot )", "" ) ) -eq "" ) { $path = "\" }
			$listItem | Add-Member -MemberType NoteProperty -Name "Path" -Value $path

			if ( $null -eq $prodFile )
			{
				$new = $true
				$ProdUpd = switch ( ( $devFile.Extension -replace "\." ) )
					{
						"psd1" {
							if ( ( Get-Content $devFile.FullName )[0] -eq "ConvertFrom-StringData @'" ) { $syncHash.Data.msgTable.StrNewLocFile }
							else { $syncHash.Data.msgTable.StrNewDataFile }
							}
						"ps1" { $syncHash.Data.msgTable.StrNewScript }
						"xaml" { $syncHash.Data.msgTable.StrNewGuiFile }
						default { $syncHash.Data.msgTable.StrNewOtherFile }
					}
				$prodPath = "{0}{1}\{2}" -f $syncHash.Data.prodRoot, "$( if ( $listItem.Path -ne "\" ) { $listItem.Path } )", $listItem.Name
			}
			else
			{
				$new = $false
				$ProdUpd = ( Get-Date $prodFile.LastWriteTime -Format "yyyy-MM-dd hh:mm:ss" )
				$prodPath = $prodFile.FullName
			}
			$listItem | Add-Member -MemberType NoteProperty -Name "New" -Value $new
			$listItem | Add-Member -MemberType NoteProperty -Name "ProdUpd" -Value $ProdUpd
			$listItem | Add-Member -MemberType NoteProperty -Name "ProdPath" -Value $prodPath

			$State, $TT = ( GetState $devFile )
			$listItem | Add-Member -MemberType NoteProperty -Name "State" -Value $State
			$listItem | Add-Member -MemberType NoteProperty -Name "ToolTip" -Value $TT

			return $listItem
		}

		$syncHash.DC.pbUpdates[0] = [double] 0.001
		$syncHash.DC.btnUpdateScripts[1] = $false

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
		$syncHash.Window.Dispatcher.Invoke( [action] {
			$syncHash.DC.dgUpdates[0].Clear()
			$syncHash.DC.dgUpdatedInProd[0].Clear()
		} )
		$syncHash.up = @()
		$syncHash.uip = @()

		$syncHash.Data.devFiles = Get-ChildItem $syncHash.Data.devRoot -Directory -Exclude $syncHash.Data.dirExclusion | Get-ChildItem -File -Recurse -Exclude $syncHash.Data.fileExclusion
		$syncHash.Data.devFiles += Get-ChildItem $syncHash.Data.devRoot -File | Where-Object { $_.Name -notin $syncHash.Data.fileExclusion }
		$syncHash.Data.prodFiles = Get-ChildItem $syncHash.Data.prodRoot -Directory -Exclude $( $syncHash.Data.dirExclusion += "Development"; $syncHash.Data.dirExclusion ) | Get-ChildItem -File -Recurse -Exclude $syncHash.Data.fileExclusion
		$syncHash.Data.prodFiles += Get-ChildItem $syncHash.Data.prodRoot -File | Where-Object { $_.Name -notin $syncHash.Data.fileExclusion }
		$MD5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider

		$ticker = 1
		foreach ( $devFile in $syncHash.Data.devFiles )
		{
			$syncHash.DC.pbUpdates[0] = [double]( ( $ticker / $syncHash.Data.devFiles.Count ) * 100 )
			$prodFile = $syncHash.Data.prodFiles | Where-Object { $_.Name -eq $devFile.Name }
			if ( $null -eq $prodFile )
			{
				$item = GetListItem $devFile
				$syncHash.Window.Dispatcher.Invoke( [action] { $syncHash.DC.dgUpdatedInProd[0].Add( ( GetListItem $devFile ) ) } )
			}
			else
			{
				$devMD5 = [System.BitConverter]::ToString( $MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $devFile.FullName ) ) )
				$prodMD5 = [System.BitConverter]::ToString( $MD5.ComputeHash( [System.IO.File]::ReadAllBytes( $prodFile.FullName ) ) )

				if ( $devMD5 -ne $prodMD5 )
				{
					$item = GetListItem $devFile $prodFile
					if ( $prodFile.LastWriteTime -gt $devFile.LastWriteTime )
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

		if ( $syncHash.DC.dgUpdates[0].Count -gt 0 )
		{
			$syncHash.DC.tbUpdatesSummary[0] = "{0} {1}" -f $syncHash.DC.dgUpdates[0].Count, $syncHash.Data.msgTable.StrUpdates
			$syncHash.DC.tbDevCount[0] = $syncHash.DC.dgUpdates[0].Where( { $_.State -eq "Dev" } ).Count
			$syncHash.DC.tbTestCount[0] = $syncHash.DC.dgUpdates[0].Where( { $_.State -eq "Test" } ).Count
			$syncHash.DC.tbProdCount[0] = $syncHash.DC.dgUpdates[0].Where( { $_.State -eq "Prod" } ).Count
			$syncHash.DC.btnUpdateScripts[1] = $false
			$syncHash.DC.tblInfo[1] = [System.Windows.Visibility]::Visible
		}
		else
		{
			$syncHash.DC.tbDevCount[0] = $syncHash.DC.tbTestCount[0] = $syncHash.DC.tbProdCount[0] = 0
			$syncHash.DC.tblUpdateInfo[0] = $syncHash.Data.msgTable.StrNoUpdates
			$syncHash.DC.tblInfo[1] = [System.Windows.Visibility]::Collapsed
		}

		if ( $syncHash.DC.dgUpdatedInProd[0].Count -gt 0 )
		{
			$syncHash.DC.tiUpdatedInProd[2] = "Red"
			$syncHash.DC.tblUpdateInfo[0] += "`n{0} {1}" -f $syncHash.DC.dgUpdatedInProd[0].Count, $syncHash.Data.msgTable.StrUpdatesInProd
		}
		else
		{ $syncHash.DC.tiUpdatedInProd[2] = "#FFEBEBEB" }

		$syncHash.DC.pbUpdates[0] = 0.0
		$syncHash.Temp = $Error
	} ).AddArgument( $syncHash )
	$syncHash.H = $syncHash.P.BeginInvoke()
}

######################################################################################################
# Check if there are any localizationvariables in the localizationfile that are not used in the script
# and if there are any calls for localizationvariabels in the script that does not exist
function FindOrphandLocalizations
{
	param ( $FileName )

	$OLocs = @()
	$NullLocs = @()

	if ( $sc = Get-ChildItem -Path "$BaseDir\Script" -Filter "$FileName.ps1" -Recurse )
	{
		if ( $loc = Get-ChildItem -Path "$BaseDir\Localization" -Filter "$FileName.psd1" -Recurse )
		{
			Import-LocalizedData -BindingVariable m -BaseDirectory $loc.Directory.FullName -FileName $loc.Name
			$any = $false
			foreach ( $key in $m.Keys )
			{ if ( -not ( $sc | Select-String -Pattern "\.\b$key\b" ) ) { $OLocs += [pscustomobject]@{ LocVar = $key ; LocVal = $m.$key } } }

			# Check scriptfile
			$any = $false
			$locInScript = ( $sc | Select-String -Pattern "msgTable\." )
			foreach ( $line in $locInScript )
			{
				$v = ( $line.line.Substring( $line.line.LastIndexOf( "msgTable" ) + 9 ) -split "\W" )[0]
				if ( $v -notin $m.Keys )
				{ $NullLocs += [pscustomobject]@{ ScVar = $v; ScLine = $line.line ; ScLineNr = $line.linenumber } }
			}
		}
	}
	return $OLocs, $NullLocs
}

###################################
# Test if script is viable to update
function TestScript
{
	param ( $File )

	$Script = Get-Item $File
	$Test = [pscustomobject]@{ Script = $Script; OK = $true; ObsoleteFunctions = @(); AcceptedVerb = $false; WritesToLog = $false; OrphandLocalizations = $null; InvalidLocalizations = $null }

	# Test if obsolete functions are used
	foreach ( $f in $ObsoletFunctions )
	{
		$Test.ObsoleteFunctions += $script | `
			Select-String -Pattern "\b$( $f.FunctionName )\b" | `
			Select-Object @{ Name = "Line"; Expression = { $_.LineNumber } }, `
			@{ Name = "Text" ; Expression = { $_.Line } }, `
			@{ Name = "ToolTip" ; Expression = { $f.HelpMessage } }
	}

	# Test if filename has an accepted verb
	$Test.AcceptedVerb = ( Get-Verb ).Verb | ForEach-Object { if ( $script.BaseName -match "^$_" ) { $true } }

	# Test if the script writes to log
	$Test.WritesToLog = ( $script | Select-String -Pattern "WriteLogTest" ).Count -gt 0

	# Test if there are any localizationvariabels that are not used or are being used but does not exist
	$Test.OrphandLocalizations, $Test.InvalidLocalizations = FindOrphandLocalizations $script.BaseName

	$Test.OK = ( $Test.ObsoleteFunctions.Count -eq 0 ) -and ( $Test.AcceptedVerb ) -and ( $Test.WritesToLog ) -and ( $Test.OrphandLocalizations.Count -eq 0 ) -and ( $Test.InvalidLocalizations.Count -eq 0 )
	return $Test
}

########################################################################
# If a click in a datagrid did not occur on a row, unselect selected row
function UnselectDatagrid
{
	param ( $Click, $Datagrid )

	if ( $Click.Name -ne "" ) { if ( $Datagrid.SelectedItems.Count -lt 1 ) { $Datagrid.SelectedIndex = -1 } }
}

############################################
# Update the scripts that have been selected
function UpdateScripts
{
	foreach ( $file in $syncHash.dgUpdates.SelectedItems )
	{
		if ( $file.Name -match ".ps1$" )
		{
			if ( ( $fileTest = TestScript $file.DevPath ).OK )
			{
				$OFS = "`n"
				if ( $file.New )
				{
					New-Item -ItemType File -Path $file.ProdPath -Force
					Copy-Item -Path $file.DevPath -Destination $file.ProdPath -Force
				}
				else
				{
					$RollbackPath = "$( $syncHash.Data.RollbackRoot )\$( ( Get-Date ).Year )\$( ( Get-Date ).Month )\"
					$RollbackName = "$( $file.Name ) ($( $syncHash.Data.msgTable.StrRollbackName ) $( $file.ProdUpd ), $( $env:USERNAME ))$( ( Get-Item $file.ProdPath ).Extension )" -replace ":","."
					$RollbackValue = [string]( Get-Content -Path $file.ProdPath -Encoding UTF8 )
					$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
					New-Item -Path $RollbackPath -Name $RollbackName -ItemType File -Value $RollbackValue -Force | Out-Null
					Copy-Item -Path $file.DevPath -Destination $file.ProdPath -Force
				}
			}
			else
			{
			}
		}
	}

	$OFS = "`n`t"
	$LogText = "$( $syncHash.Data.msgTable.StrLogIntro ) $( [string]( $syncHash.dgUpdates.SelectedItems | ForEach-Object { "$( if ( $_.Path -ne "\" ) { $_.Path } )", $_.Name } ) )"
	if ( $syncHash.DC.dgUpdatedInProd[0].Count -gt 0 )
	{
		$LogText += "`n$( $syncHash.Data.msgTable.StrSummaryUpInProd ): "
		$LogText += [string]( $syncHash.DC.dgUpdatedInProd[0] | ForEach-Object { "$( if ( $_.Path -ne "\" ) { $_.Path } )", $_.Name } )
	}
	WriteLog -LogText $LogText

	$temp = $syncHash.DC.dgUpdates[0] | Where-Object { $_ -notin $syncHash.dgUpdates.SelectedItems }
	$syncHash.DC.dgUpdates[0].Clear()
	$temp | ForEach-Object { $syncHash.DC.dgUpdates[0].Add( $_ ) }
	$syncHash.DC.tblInfo[1] = [System.Windows.Visibility]::Collapsed
	$syncHash.DC.Window[0] = ""
}

######################### Script start
Add-Type -AssemblyName PresentationFramework

$BaseDir = $args[0]
Import-Module "$BaseDir\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$BaseDir\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]

$controls = [System.Collections.ArrayList]::new()
[void] $controls.Add( @{ CName = "btnCheckForUpdates" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCheckForUpdates } ) } )
[void] $controls.Add( @{ CName = "btnDoRollback" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnDoRollback } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void] $controls.Add( @{ CName = "btnListRollbacks" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnListRollbacks } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void] $controls.Add( @{ CName = "btnListSurveys" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnListSurveys } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void] $controls.Add( @{ CName = "btnOpenErrorLog" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenErrorLog } ) } )
[void] $controls.Add( @{ CName = "btnOpenOutputFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenOutputFile } ) } )
[void] $controls.Add( @{ CName = "btnOpenRollbackFile" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnOpenRollbackFile } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void] $controls.Add( @{ CName = "btnReadErrorLogs" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnReadErrorLogs } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void] $controls.Add( @{ CName = "btnReadLogs" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnReadLogs } ; @{ PropName = "IsEnabled" ; PropVal = $true } ) } )
[void] $controls.Add( @{ CName = "btnUpdateScripts" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUpdateScripts } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void] $controls.Add( @{ CName = "cbErrorLogsScriptNames" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void] $controls.Add( @{ CName = "cbLogsScriptNames" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void] $controls.Add( @{ CName = "cbRollbackScriptNames" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void] $controls.Add( @{ CName = "dgSurveyScripts" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void] $controls.Add( @{ CName = "dgUpdatedInProd" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void] $controls.Add( @{ CName = "dgUpdates" ; Props = @( @{ PropName = "ItemsSource"; PropVal = ( New-Object System.Collections.ObjectModel.ObservableCollection[Object] ) } ) } )
[void] $controls.Add( @{ CName = "gbErrorInfo" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContentgbErrorInfo } ) } )
[void] $controls.Add( @{ CName = "lblErrLogErrorMessage" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblErrorMessage } ) } )
[void] $controls.Add( @{ CName = "lblLogComputerNameTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLogComputerNameTitle } ) } )
[void] $controls.Add( @{ CName = "lblLogErrorLogTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLogErrorLogTitle } ) } )
[void] $controls.Add( @{ CName = "lblLogOutputFileTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLogOutputFileTitle } ) } )
[void] $controls.Add( @{ CName = "lblLogTextTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLogTextTitle } ) } )
[void] $controls.Add( @{ CName = "lblLogUserInputTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblLogUserInputTitle } ) } )
[void] $controls.Add( @{ CName = "lblErrLogComputerName" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblErrLogComputerName } ) } )
[void] $controls.Add( @{ CName = "lblErrLogOperator" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblOperator } ) } )
[void] $controls.Add( @{ CName = "lblErrLogSeverity" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSeverity } ) } )
[void] $controls.Add( @{ CName = "lblErrLogUserInput" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblUserInput } ) } )
[void] $controls.Add( @{ CName = "lblSurveyScriptVersionTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSurveyScriptVersionTitle } ) } )
[void] $controls.Add( @{ CName = "lblSurveyTotSumTitle" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSurveyTotSumTitle } ) } )
[void] $controls.Add( @{ CName = "pbUpdates" ; Props = @( @{ PropName = "Value"; PropVal = [double] 0 } ) } )
[void] $controls.Add( @{ CName = "tbDevCount" ; Props = @( @{ PropName = "Text"; PropVal = "-" } ) } )
[void] $controls.Add( @{ CName = "tbDevTitle" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttbDevTitle } ) } )
[void] $controls.Add( @{ CName = "tblInfo" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttblInfo } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Collapsed } ) } )
[void] $controls.Add( @{ CName = "tblUpdatedInProd" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttblUpdatedInProd } ) } )
[void] $controls.Add( @{ CName = "tblUpdateInfo" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void] $controls.Add( @{ CName = "tbProdCount" ; Props = @( @{ PropName = "Text"; PropVal = "-" } ) } )
[void] $controls.Add( @{ CName = "tbProdTitle" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttbProdTitle } ) } )
[void] $controls.Add( @{ CName = "tbTestCount" ; Props = @( @{ PropName = "Text"; PropVal = "-" } ) } )
[void] $controls.Add( @{ CName = "tbTestTitle" ; Props = @( @{ PropName = "Text"; PropVal = $msgTable.ContenttbTestTitle } ) } )
[void] $controls.Add( @{ CName = "tbUpdatesSummary" ; Props = @( @{ PropName = "Text"; PropVal = "" } ) } )
[void] $controls.Add( @{ CName = "tiErrorLogs" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiErrorLogs } ) } )
[void] $controls.Add( @{ CName = "tiLogs" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiLogs } ) } )
[void] $controls.Add( @{ CName = "tiRollback" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiRollback } ) } )
[void] $controls.Add( @{ CName = "tiSurveys" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiSurveys } ) } )
[void] $controls.Add( @{ CName = "tiUpdated" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiUpdated } ) } )
[void] $controls.Add( @{ CName = "tiUpdatedInProd" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiUpdatedInProd } ; @{ PropName = "Visibility" ; PropVal = [System.Windows.Visibility]::Visible } ; @{ PropName = "Background" ; PropVal = "#FFEBEBEB" } ) } )
[void] $controls.Add( @{ CName = "tiUpdates" ; Props = @( @{ PropName = "Header"; PropVal = $msgTable.ContenttiUpdates } ) } )
[void] $controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = $msgTable.ContentWindow } ) } )

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
$syncHash.Data.RollbackRoot = "$( $syncHash.Data.prodRoot )\UpdateRollback"
$syncHash.Data.updatedFiles = New-Object System.Collections.ArrayList
$syncHash.Data.filesUpdatedInProd = New-Object System.Collections.ArrayList
if ( Test-Path "C:\Program Files (x86)\Notepad++\notepad++.exe" ) { $syncHash.Data.Editor = "C:\Program Files (x86)\Notepad++\notepad++.exe" }
else { $syncHash.Data.Editor = "notepad" }

$syncHash.btnCheckForUpdates.Add_Click( { CheckForUpdates } )
$syncHash.btnDoRollback.Add_Click( {
	if ( $null -eq ( $op = Get-ChildItem -Path $syncHash.Data.prodRoot -Directory -Exclude "Development","Arkiv" | Get-ChildItem -File -Filter $syncHash.cbRollbackScriptNames.Text -Recurse ) )
	{
		$text = $syncHash.Data.msgTable.StrRollbackPahNotFound
		$icon = [System.Windows.MessageBoxImage]::Warning
		$button = [System.Windows.MessageBoxButton]::OK
	}
	else
	{
		$text = ( "{0}`n`n{1}`n{2}`n`n{3}`n{4}" -f $syncHash.Data.msgTable.StrRollbackVerification, $syncHash.Data.msgTable.StrRollbackVerificationPath, $op.FullName, $syncHash.Data.msgTable.StrRollbackVerificationDate, $syncHash.dgRollbacks.SelectedItem.ScriptDate )
		$icon = [System.Windows.MessageBoxImage]::Question
		$button = [System.Windows.MessageBoxButton]::YesNo
	}

	if ( ( ShowMessageBox -Text $text -Icon $icon -Button $button ) -eq "Yes" )
	{
		$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
		Set-Content -Value ( Get-Content $syncHash.dgRollbacks.SelectedItem.FullName ) -Path $op.FullName
		ShowMessageBox -Text $syncHash.Data.msgTable.StrRollbackDone
	}
} )
$syncHash.btnListRollbacks.Add_Click( {
	$splash = ShowSplash -Text $syncHash.Data.msgTable.StrSplReadErrorLogs -SelfAdmin
	$syncHash.DC.cbRollbackScriptNames[0].Clear()
	Get-ChildItem $syncHash.Data.RollbackRoot -Recurse -File | Sort-Object Name | ForEach-Object {
		$n, $ud = $_.BaseName -split " \(" -replace "\)"
		$fullname = $_.FullName
		if ( $syncHash.DC.cbRollbackScriptNames[0].ScriptName -notcontains $n )
		{ $syncHash.DC.cbRollbackScriptNames[0].Add( [pscustomobject]@{ ScriptName = $n ; ScriptLogs = [System.Collections.ArrayList]::new() } ) }
		$null, $d, $t, $u = $ud -split " " -replace "\.",":"
		( $syncHash.DC.cbRollbackScriptNames[0].Where( { $_.ScriptName -eq $n } ) )[0].ScriptLogs.Add( [pscustomobject]@{ "ScriptDate" = ( "$d $t" -replace "\.", ":" -replace "," ); "UpdatedBy" = $u ; "FullName" = $fullname } )
	}
	$splash.Close()
} )
$syncHash.btnListSurveys.Add_Click( {
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
} )
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
$syncHash.btnOpenOutputFile.Add_Click( { Start-Process -FilePath $syncHash.data.Editor -ArgumentList """$( $syncHash.cbLoOutputFiles.SelectedItem )""" } )
$syncHash.btnReadErrorLogs.Add_Click( {
	$splash = ShowSplash -Text $syncHash.Data.msgTable.StrSplReadErrorLogs -SelfAdmin
	$syncHash.DC.cbErrorLogsScriptNames[0].Clear()
	Get-ChildItem "$BaseDir\ErrorLogs" -Recurse -File -Filter "*.json" | Sort-Object Name | ForEach-Object {
		$n = $_.BaseName -replace " - ErrorLog"
		if ( $syncHash.DC.cbErrorLogsScriptNames.ScriptName -notcontains $n )
		{ $syncHash.DC.cbErrorLogsScriptNames[0].Add( [pscustomobject]@{ ScriptName = $n ; ScriptErrorLogs = [System.Collections.ArrayList]::new() } ) }
		Get-Content $_.FullName | ForEach-Object { ( $syncHash.DC.cbErrorLogsScriptNames[0].Where( { $_.ScriptName -eq $n } ) )[0].ScriptErrorLogs.Add( ( NewErrorLog ( $_ | ConvertFrom-Json ) ) ) }
	}
	$syncHash.DC.cbErrorLogsScriptNames[0] | ForEach-Object { $_.ScriptErrorLogs = $_.ScriptErrorLogs | Sort-Object LogDate -Descending }
	$splash.Close()
} )
$syncHash.btnReadLogs.Add_Click( {
	$splash = ShowSplash -Text $syncHash.Data.msgTable.StrSplReadLogs -SelfAdmin
	$syncHash.DC.cbLogsScriptNames[0].Clear()
	Get-ChildItem "$BaseDir\Logs" -Recurse -File -Filter "*log.json" | Sort-Object Name | ForEach-Object {
		$n = $_.BaseName -replace " - Log"
		if ( $syncHash.DC.cbLogsScriptNames.ScriptName -notcontains $n )
		{ $syncHash.DC.cbLogsScriptNames[0].Add( [pscustomobject]@{ ScriptName = $n ; ScriptLogs = [System.Collections.ArrayList]::new() } ) }
		Get-Content $_.FullName | ForEach-Object { ( $syncHash.DC.cbLogsScriptNames[0].Where( { $_.ScriptName -eq $n } ) )[0].ScriptLogs.Add( ( NewLog ( $_ | ConvertFrom-Json ) ) ) }
	}
	$syncHash.DC.cbLogsScriptNames[0] | ForEach-Object { $_.ScriptLogs = $_.ScriptLogs | Sort-Object LogDate -Descending }
	$splash.Close()
} )

# Open the selected previous version
$syncHash.btnOpenRollbackFile.Add_Click( { Start-Process $syncHash.Data.Editor """$( $syncHash.dgRollbacks.SelectedItem.FullName )""" } )

# Search for updated files
$syncHash.btnUpdateScripts.Add_Click( { UpdateScripts } )

# Click was made outside of rows and valid cells, unselect selected rows
$syncHash.dgErrorLogs.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.dgLogs.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.dgRollbacks.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.dgSurveyScripts.Add_SelectionChanged( { $syncHash.cbSurveyScriptVersion.Items.Refresh() } )
$syncHash.dgUpdates.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )
$syncHash.dgUpdatedInProd.Add_MouseLeftButtonUp( { UnselectDatagrid $args[1].OriginalSource $this } )

$syncHash.dgRollbacks.Add_SelectionChanged( { $syncHash.DC.btnOpenRollbackFile[1] = $syncHash.DC.btnDoRollback[1] = $this.SelectedItem -ne $null } )
$syncHash.dgUpdates.Add_MouseRightButtonUp( {
	if ( ( $args[1].OriginalSource.GetType() ).Name -eq "TextBlock" )
	{
		$d = $args[1].OriginalSource.Parent.DataContext.DevPath
		$p = $args[1].OriginalSource.Parent.DataContext.ProdPath
		if ( $null -ne $d ) { if ( Test-Path $d ) { Start-Process $syncHash.Data.Editor $d } }
		if ( $null -ne $p ) { if ( Test-Path $p ) { Start-Process $syncHash.Data.Editor $p } }
	}
} )
$syncHash.dgUpdatedInProd.Add_MouseRightButtonUp( {
	$d = $args[1].OriginalSource.Parent.DataContext.DevPath
	$p = $args[1].OriginalSource.Parent.DataContext.ProdPath
	if ( Test-Path $d ) { Start-Process $syncHash.Data.Editor $d }
	if ( Test-Path $p ) { Start-Process $syncHash.Data.Editor $p }
} )
$syncHash.dgUpdates.Add_SelectionChanged( { $syncHash.DC.btnUpdateScripts[1] = $this.SelectedItems.Count -gt 0 } )
$syncHash.Window.Add_ContentRendered( {
	$syncHash.Window.Top = 20
	$syncHash.Window.Activate()

	$syncHash.dgUpdates.Columns[0].Header = $syncHash.dgUpdatedInProd.Columns[0].Header = $syncHash.Data.msgTable.ContentdgUpdatesColName
	$syncHash.dgUpdates.Columns[1].Header = $syncHash.dgUpdatedInProd.Columns[1].Header = $syncHash.Data.msgTable.ContentdgUpdatesColPath
	$syncHash.dgUpdates.Columns[2].Header = $syncHash.dgUpdatedInProd.Columns[2].Header = $syncHash.Data.msgTable.ContentdgUpdatesColDevUpd
	$syncHash.dgUpdates.Columns[3].Header = $syncHash.dgUpdatedInProd.Columns[3].Header = $syncHash.Data.msgTable.ContentdgUpdatesColProdUpd
	$syncHash.dgUpdates.Columns[4].Header = $syncHash.dgUpdatedInProd.Columns[4].Header = $syncHash.Data.msgTable.ContentdgUpdatesColProdState
	$syncHash.dgUpdates.Items.SortDescriptions.Add( ( [System.ComponentModel.SortDescription]::new( "Name", [System.ComponentModel.ListSortDirection]::Ascending ) ) )

	$syncHash.dgLogs.Columns[0].Header = $syncHash.Data.msgTable.ContentdgLogsColLogDate
	$syncHash.dgLogs.Columns[1].Header = $syncHash.Data.msgTable.ContentdgLogsColSuccess
	$syncHash.dgLogs.Columns[2].Header = $syncHash.Data.msgTable.ContentdgLogsColOperator
	$syncHash.dgLogs.Items.SortDescriptions.Add( ( [System.ComponentModel.SortDescription]::new( "LogDate", [System.ComponentModel.ListSortDirection]::Descending ) ) )

	$syncHash.dgRollbacks.Columns[0].Header = $syncHash.Data.msgTable.ContentdgRollbacksColDate
	$syncHash.dgRollbacks.Columns[1].Header = $syncHash.Data.msgTable.ContentdgRollbacksColUpdatedBy
	$syncHash.dgRollbacks.Items.SortDescriptions.Add( ( [System.ComponentModel.SortDescription]::new( "ScriptDate", [System.ComponentModel.ListSortDirection]::Descending ) ) )

	$syncHash.dgErrorLogs.Columns[0].Header = $syncHash.Data.msgTable.ContentdgErrorLogsColLogDate
	$syncHash.dgErrorLogs.Items.SortDescriptions.Add( ( [System.ComponentModel.SortDescription]::new( "LogDate", [System.ComponentModel.ListSortDirection]::Descending ) ) )

	$syncHash.dgSurveyScripts.Columns[0].Header = $syncHash.Data.msgTable.ContentdgSurveyScriptsColScriptName
	$syncHash.dgSurveyScripts.Columns[1].Header = $syncHash.Data.msgTable.ContentdgSurveyScriptsColSurveyCount
	$syncHash.dgSurveyScripts.Items.SortDescriptions.Add( ( [System.ComponentModel.SortDescription]::new( "ScriptName", [System.ComponentModel.ListSortDirection]::Ascending ) ) )

	$syncHash.dgSurveyAnswers.Columns[0].Header = $syncHash.Data.msgTable.ContentdgSurveyAnswersColComment
	$syncHash.dgSurveyAnswers.Columns[1].Header = $syncHash.Data.msgTable.ContentdgSurveyAnswersColRating
	$syncHash.dgSurveyAnswers.Columns[2].Header = $syncHash.Data.msgTable.ContentdgSurveyAnswersColOperator
	$syncHash.dgSurveyAnswers.Columns[3].Header = $syncHash.Data.msgTable.ContentdgSurveyAnswersColDate

	$syncHash.dgSurveyAnswers.Columns[0].CellTemplate.Triggers.Setters[1].Value = $syncHash.Data.msgTable.ContentdgSurveyNoComment

	$syncHash.ObsoletFunctions = ( Get-Module ).Where( { $_.Path.StartsWith( $BaseDir ) } ) | `
	ForEach-Object { Get-Command -Module $_.Name } | `
	Where-Object { $_.Definition -match "\[Obsolete.+\]" } | `
	Select-Object -Property `
		@{ Name = "FunctionName"; Expression = { $_.Name } }, `
		@{ Name = "HelpMessage"; Expression = { ( ( ( $_.Definition -split "`n" | Select-String -Pattern "\[Obsolete.+\]" ) -split "\(" )[1] -split "\)" )[0].Trim() } }
} )

[void] $syncHash.Window.ShowDialog()
$syncHash.Window.Close()
$global:syncHash = $syncHash
