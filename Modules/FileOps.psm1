# A module for functions operating on files
# Use this to import module:
# Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

# Creates a file to use for input from user, then returns its content.
# If file exists, its content is replaced, otherwise a new file is created.
# DefaultText is entered as initial content.
# Returns the files content, with DefaultText removed.
function GetUserInput
{
	param ( $DefaultText )
	$InputFilePath = "$RootDir\Input\$env:USERNAME\$CallingScript.txt"
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

	return Get-Content $InputFilePath | where { $_ -notlike $DefaultText }
}

# Writes given output to file from script or scoreboard.
# Returns filepath to outputfile.
function WriteOutput
{
	param ( $FileNameAddition, $Output, $FileExtension = "txt", [switch] $Scoreboard )
	if ( $Scoreboard ) { $Folder = "Scoreboard" } else { $Folder = $env:USERNAME }

	$OutputFilePath = "$RootDir\Output\$Folder\$( if ( $FileNameAddition ) { "$FileNameAddition " } )$CallingScript, $( Get-Date -Format "yyyy-MM-dd HH.mm.ss").$FileExtension"
	if ( -not ( Test-Path $OutputFilePath ) ) { New-Item -Path $OutputFilePath -ItemType File -Force | Out-Null }
	Set-Content -Path $OutputFilePath -Value ( $Output )
	return $OutputFilePath
}

# Writes log from running script.
# Each row is preceded by default logdata, followed by logtext from script.
function WriteLog
{
	param ( $LogText )
	$LogFilePath = "$RootDir\Logs\$( [datetime]::Now.Year )\$( [datetime]::Now.Month )\$CallingScript - log.txt" 
	if ( -not ( Test-Path $LogFilePath ) ) { New-Item -Path $LogFilePath -ItemType File -Force | Out-Null }
	Add-Content -Path $LogFilePath -Value ( $nudate + " " + $env:USERNAME + " [" + $env:USERDOMAIN + "] => " + $LogText )
	return $LogFilePath
}

# Writes errorlog from running script.
# Each row is preceded by default logdata, followed by errortext from script.
# Returns filepath to file.
function WriteErrorlog
{
	param ( $LogText )
	$ErrorLogFilePath = "$RootDir\ErrorLogs\$( [datetime]::Now.Year )\$( [datetime]::Now.Month )\$CallingScript - Errorlog $( Get-Date -Format 'yyyyMMddHHmmss' ).txt"
	if ( -not ( Test-Path $ErrorLogFilePath ) ) { New-Item -Path $ErrorLogFilePath -ItemType File -Force | Out-Null }
	Add-Content -Path $ErrorLogFilePath -Value ( ( Get-Date -Format "yyyy-MM-dd HH:mm:ss" ) + " " + $env:USERNAME + " [" + $env:USERDOMAIN + "] => " + $LogText )
	return $ErrorLogFilePath
}

# Display a messagebox with given text, title, button and icon
# Returns button pressed.
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

# Displays message in console that the script can be closed.
function EndScript
{
	$dummy = Read-Host "`nPress Enter to exit"
	if ( $dummy -ne "" )
	{ Add-Content -Path "$RootDir\Logs\DummyQuitting.txt" -Value "$nudate $env:USERNAME $CallingScript - $dummy" }
}

# Creates a WPF-window, based on XAML-file with the same name as the script calling.
# Returns window and an array with all named controls in window.
function CreateWindow
{
	Add-Type -AssemblyName PresentationFramework

	$XamlFile = "$RootDir\Gui\$CallingScript.xaml"
	$inputXML = Get-Content $XamlFile -Raw
	$inputXML = $inputXML -replace "x:N", 'N' -replace '^<Win.*', '<Window'
	[XML]$XAML = $inputXML

	$reader = ( New-Object System.Xml.XmlNodeReader $Xaml )
	try
	{
		$Window = [Windows.Markup.XamlReader]::Load( $reader )
	}
	catch
	{
		Write-Host $_
		Read-Host
		throw
	}
	$vars = @()
	$xaml.SelectNodes( "//*[@Name]" ) | foreach {
		$vars += $_.Name
	}

	return $Window, $vars
}

# Current date and time
$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
# Root directory for scriptmenu
$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
# Name of the script calling
$CallingScript = ( Get-Item $MyInvocation.PSCommandPath ).BaseName
# Set title for consolewindow to scriptname
$Host.UI.RawUI.WindowTitle = "Script: $( ( ( Get-Item $MyInvocation.PSCommandPath ).FullName -split "Skript" )[1] )"

Export-ModuleMember -Function *
