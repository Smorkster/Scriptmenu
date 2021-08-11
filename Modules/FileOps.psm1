<#
.Synopsis A module for functions operating on files
.Description Use this to import module: Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
.State Prod
.Author Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

##############################
##    Internal functions    ##
##############################

enum Success {
	Success = 1
	Failed = 0
}

enum ErrorSeverity {
	UserInputFail = 0
	ScriptLogicFail = 1
	ConnectionFail = 2
	PermissionFail = 3
	OtherFail = -1
}

###############################
# A class to define log content
class Log
{
	[ValidateNotNullOrEmpty()] [string] $LogText
	[ValidateNotNullOrEmpty()] [string] $UserInput
	[ValidateNotNullOrEmpty()] [Success] $Success
	[string] $ErrorLogFile
	[string] $ErrorLogDate
	[string] $OutputFile
	[string] $LogDate
	[string] $Operator

	Log ( $Text, $UserInput, $Success )
	{
		$this.LogText = $Text
		$this.UserInput = $UserInput
		$this.Success = $Success
	}

	Log ( [pscustomobject] $o )
	{
		$this.LogDate = $o.LogDate
		$this.LogText = $o.LogText
		$this.UserInput = $o.UserInput
		$this.Success = $o.Success
		$this.ErrorLogFile = $o.ErrorLogFile
		$this.ErrorLogDate = $o.ErrorLogDate
		$this.OutputFile = $o.OutputFile
		$this.Operator = $o.Operator
	}

	[string] ToJson()
	{
		$this.LogDate = ( Get-Date -Format "yyyy-MM-dd HH:mm:ss" )
		$this.Operator = $env:USERNAME
		return $this | ConvertTo-Json -Compress
	}
}

########################################
# A class to define content for errorlog
class ErrorLog
{
	[ValidateNotNullOrEmpty()] [string] $ErrorMessage
	[ValidateNotNullOrEmpty()] [string] $UserInput
	[ValidateNotNullOrEmpty()] [ErrorSeverity] $Severity
	[string] $LogDate
	[string] $Operator

	ErrorLog ( $ErrorMessage, $UserInput, $Severity )
	{
		$this.ErrorMessage = $ErrorMessage
		$this.UserInput = $UserInput
		$this.Severity = $Severity
	}

	ErrorLog ( [pscustomobject] $o )
	{
		$this.ErrorMessage = $o.ErrorMessage
		$this.UserInput = $o.UserInput
		$this.Severity = $o.Severity
		$this.LogDate = $o.LogDate
		$this.Operator = $o.Operator
	}

	[string] ToJson()
	{
		$this.LogDate = ( Get-Date -Format "yyyy-MM-dd HH:mm:ss" )
		$this.Operator = $env:USERNAME
		return $this | ConvertTo-Json -Compress
	}
}

#######################################
# Create the path for the file to write
# If the file does not exist, create it
function Get-LogFilePath
{
	param ( $TopFolder, $SubFolder, $FileName )

	$path = "{0}\{1}\{2}\{3}" -f $RootDir, $TopFolder, "$( if ( $SubFolder ) { $SubFolder } else { "$( [datetime]::Now.Year )\$( [datetime]::Now.Month )" } )", $FileName
	if ( -not ( Test-Path $path ) ) { New-Item -Path $path -ItemType File -Force | Out-Null }
	return $path
}

##############################
##    Exported functions    ##
##############################

########################################################################
# Creates file for input from user, then returns its content.
# If file exists, the content is replaced. Otherise the file is created.
# DefaultText is placed in the begining of the file.
# Returns the file content, with DefaultText removed.
function GetUserInput
{
	param ( $DefaultText )
	$InputFilePath = "$RootDir\Input\$env:USERNAME\$( $CallingScript.BaseName ).txt"
	if ( Test-Path -Path $InputFilePath ) { Clear-Content $InputFilePath }
	else { New-Item -Path $InputFilePath -ItemType File -Force | Out-Null }

	if ( $DefaultText ) { Set-Content $InputFilePath $DefaultText }
	Start-Process notepad $InputFilePath -Wait

	return Get-Content $InputFilePath | Where-Object { $_ -notlike $DefaultText }
}

#################################################################################################
# Writes output to corresponding file for the calling script, alternatively to a scoreboard file.
# Returns full path to the file written.
function WriteOutput
{
	param ( $FileNameAddition, $Output, $FileExtension = "txt", [switch] $Scoreboard )
	if ( $Scoreboard ) { $Folder = "Scoreboard" } else { $Folder = $env:USERNAME }

	$FileName = "{0}{1}, {2}.{3}" -f "$( if ( $FileNameAddition ) { "$FileNameAddition " } )", $CallingScript.BaseName, ( Get-Date -Format "yyyy-MM-dd HH.mm.ss" ), $FileExtension
	$OutputFilePath = Get-LogFilePath -TopFolder "Output" -SubFolder $Folder -FileName $FileName
	Set-Content -Path $OutputFilePath -Value ( $Output )
	return $OutputFilePath
}

################################################################################
# Writes log from running script
# Each row (the text from calling script) is preceded by logdata (date and user)
function WriteLog
{
	param ( $LogText )

	$LogFilePath = Get-LogFilePath -TopFolder "Logs" -FileName "$( $CallingScript.BaseName ) - log.txt"
	Add-Content -Path $LogFilePath -Value ( $nudate + " " + $env:USERNAME + " [" + $env:USERDOMAIN + "] => " + $LogText )
	return $LogFilePath
}

#####################################################################################
# Writes to log-file
# The content is extended with date, time and username of the user running the script
# Returns path to the file
function WriteLogTest
{
	[cmdletbinding()]
	param ( $Text, $UserInput, $Success, $ErrorLogHash, $OutputPath )

	$log = [Log]::new( $Text, $UserInput, $Success )
	if ( $ErrorLogHash ) { $log.ErrorLogFile = $ErrorLogHash.ErrorLogPath ; $log.ErrorLogDate = $ErrorLogHash.ErrorLogDate }
	if ( $OutputPath ) { $log.OutputFile = $OutputPath }
	$LogFilePath = Get-LogFilePath -TopFolder "Logs" -FileName "$( $CallingScript.BaseName ) - log.txt"
	Add-Content -Path $LogFilePath -Value ( $log.ToJson() )
	return $LogFilePath
}

################################################################################
# Write errorlog from running script
# Each row (the text from calling script) is preceded by logdata (date and user)
# Returns path to errorlogfile
function WriteErrorlog
{
	[cmdletbinding()]
	param ( [ parameter( ValueFromPipeline = $true ) ] $LogText )

	$ErrorLogFilePath = Get-LogFilePath -TopFolder "ErrorLogs" -FileName "$( $CallingScript.BaseName ) - Errorlog $( Get-Date -Format 'yyyyMMddHHmmss' ).txt"
	Add-Content -Path $ErrorLogFilePath -Value ( ( Get-Date -Format "yyyy-MM-dd HH:mm:ss" ) + " " + $env:USERNAME + " [" + $env:USERDOMAIN + "] => " + $LogText )
	return $ErrorLogFilePath
}

#####################################################################################
# Write to error to a logfile
# The content is extended with date, time and username of the user running the script
# Returns path to the file
function WriteErrorlogTest
{
	param ( [parameter( ValueFromPipeline = $true )] $LogText, $UserInput, $Severity )

	$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
	$ErrorLogFilePath = Get-LogFilePath -TopFolder "ErrorLogs" -FileName "$( $CallingScript.BaseName ) - Errorlog.txt"
	$el = [ErrorLog]::new( $LogText, $UserInput, $Severity )
	Add-Content -Path $ErrorLogFilePath -Value $el.ToJson()
	return @{ ErrorlogPath = $ErrorLogFilePath ; ErrorlogDate = $el.LogDate }
}

##################################################################################
# Display a messagebox with given text, and, if defined, title, icon and button/-s
# Returns which button in the messagebox was clicked
function ShowMessageBox
{
	param (
		$Text,
		$Title = "",
		$Button = "OK",
		$Icon = "Info"
	)
	return [System.Windows.MessageBox]::Show( "$Text", "$Title", "$Button", "$Icon" )
}

##################################################################################
# Prints a message in the consolewindow, that the script is done and can be exited
function EndScript
{
	$dummy = Read-Host "`n$( $IntmsgTable.FileOpsEndScript )"
	if ( $dummy -ne "" )
	{ Add-Content -Path "$RootDir\Logs\DummyQuitting.txt" -Value "$nudate $env:USERNAME $( $CallingScript.BaseName ) - $dummy" }
}

$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
try { $CallingScript = Get-Item $MyInvocation.PSCommandPath } catch {}

Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] )" -BaseDirectory "$RootDir\Localization\$culture\Modules"
try {
	Import-LocalizedData -BindingVariable msgTable -UICulture $culture -FileName $CallingScript.Name -BaseDirectory ( Get-ChildItem -Path "$RootDir\Localization\$culture" -Filter "$( $CallingScript.BaseName )*" -Recurse ).Directory.FullName -ErrorAction SilentlyContinue
} catch {}

try { $Host.UI.RawUI.WindowTitle = "$( $IntmsgTable.ConsoleWinTitlePrefix ): $( ( ( Get-Item $MyInvocation.PSCommandPath ).FullName -split "Script" )[1] )" } catch {}

Export-ModuleMember -Function EndScript, GetUserInput, ShowMessageBox, WriteErrorlog, WriteLog, WriteOutput, WriteLogTest, WriteErrorlogTest
Export-ModuleMember -Variable msgTable
