# A module for functions operating on files
# Use this to import module:
# Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

param ( $culture = "sv-SE" )
########################################################################
# Creates file for input from user, then returns its content.
# If file exists, the content is replaced. Otherise the file is created.
# DefaultText is placed in the begining of the file.
# Returns the file content, with DefaultText removed.
function GetUserInput
{
	param ( $DefaultText )
	$InputFilePath = "$RootDir\Input\$env:USERNAME\$( $CallingScript.BaseName ).txt"
	if ( Test-Path -Path $InputFilePath )
	{
		Clear-Content $InputFilePath
	}
	else
	{
		New-Item -Path $InputFilePath -ItemType File -Force | Out-Null
	}

	if ( $DefaultText )
	{
		Set-Content $InputFilePath $DefaultText
	}
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

	$OutputFilePath = "$RootDir\Output\$Folder\$( if ( $FileNameAddition ) { "$FileNameAddition " } )$( $CallingScript.BaseName ), $( Get-Date -Format "yyyy-MM-dd HH.mm.ss").$FileExtension"
	if ( -not ( Test-Path $OutputFilePath ) ) { New-Item -Path $OutputFilePath -ItemType File -Force | Out-Null }
	Set-Content -Path $OutputFilePath -Value ( $Output )
	return $OutputFilePath
}

################################
# Writes log from running script
# Each row (the text from calling script) is preceded by logdata (date and user)
function WriteLog
{
	param ( $LogText )
	$LogFilePath = "$RootDir\Logs\$( [datetime]::Now.Year )\$( [datetime]::Now.Month )\$( $CallingScript.BaseName ) - log.txt" # Create path for logfile
	if ( -not ( Test-Path $LogFilePath ) ) { New-Item -Path $LogFilePath -ItemType File -Force | Out-Null } # Does a file at path exist? If not, create file
	Add-Content -Path $LogFilePath -Value ( $nudate + " " + $env:USERNAME + " [" + $env:USERDOMAIN + "] => " + $LogText )
	return $LogFilePath
}

####################################
# Write errorlog from running script
# Each row (the text from calling script) is preceded by logdata (date and user)
# Returns path to errorlogfile
function WriteErrorlog
{
	param ( $LogText )
	$ErrorLogFilePath = "$RootDir\ErrorLogs\$( [datetime]::Now.Year )\$( [datetime]::Now.Month )\$( $CallingScript.BaseName ) - Errorlog $( Get-Date -Format 'yyyyMMddHHmmss' ).txt"
	if ( -not ( Test-Path $ErrorLogFilePath ) ) { New-Item -Path $ErrorLogFilePath -ItemType File -Force | Out-Null } # Does a file at path exist? If not, create file
	Add-Content -Path $ErrorLogFilePath -Value ( ( Get-Date -Format "yyyy-MM-dd HH:mm:ss" ) + " " + $env:USERNAME + " [" + $env:USERDOMAIN + "] => " + $LogText )
	return $ErrorLogFilePath
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
$CallingScript = ( Get-Item $MyInvocation.PSCommandPath )
$Host.UI.RawUI.WindowTitle = "$( $IntmsgTable.ConsoleWinTitlePrefix ): $( ( ( Get-Item $MyInvocation.PSCommandPath ).FullName -split "Script" )[1] )"
Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | select -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"
try { Import-LocalizedData -BindingVariable msgTable -UICulture $culture -FileName $CallingScript.Name -BaseDirectory ( $CallingScript.Directory.FullName -replace "Script", "Localization\$culture" ) -ErrorAction SilentlyContinue } catch {}

Export-ModuleMember -Function *
Export-ModuleMember -Variable msgTable
