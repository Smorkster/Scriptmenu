# A module for functions operating on files
# Use this to import module:
# Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

# Skapar fil f�r input av anv�ndaren, returnerar sedan inneh�llet.
# Finns filen, ers�tts inneh�llet. Om filen inte finns, skapas den.
# I filen l�ggs DefaultText in.
# Returnerar inneh�llet i fel, med DefaultText borttaget.
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

# L�ser in input fr�n konsolf�nstret, f�r data som klistras in genom Ctrl+V
# Returnerar input som en array, separerat enligt Split
function GetConsolePasteInput
{
	param ( [switch] $Folders )
	$Quit = New-Object -ComObject wscript.shell

	$Users1 = @()
	do
	{
		if ( $Folders )
		{ $Input = ( Read-Host ).Split( "`n""`n""`n""`r`n"","";" ) }
		else
		{ $Input = ( Read-Host ).Split( "`n"" `n""`n ""`r`n"","";"" "":""-""_""/""\""."" `r`n""`r`n "", ""; "": ""- ""_ ""/ ""\ "". ", [System.StringSplitOptions]::RemoveEmptyEntries ) }

		if ( $input -ne '' )
		{
			$Users1 += $input
		}
		else
		{
			$Quit.SendKeys( "Klar" )
			$Quit.SendKeys( "~" )
		}
	} until ( $input -eq "Klar" )
	$Users2 = $Users1 -ne "Klar"

	return $Users2
}

# Skriver output till fil f�r data fr�n skript alternativt en topplista.
# Returnerar s�kv�g f�r filen.
function WriteOutput
{
	param ( $FileNameAddition, $Output, $FileExtension = "txt", [switch] $Scoreboard )
	if ( $Scoreboard ) { $Folder = "Scoreboard" } else { $Folder = $env:USERNAME }

	$OutputFilePath = "$RootDir\Output\$Folder\$( if ( $FileNameAddition ) { "$FileNameAddition " } )$CallingScript, $( Get-Date -Format "yyyy-MM-dd HH.mm.ss").$FileExtension"
	if ( -not ( Test-Path $OutputFilePath ) ) { New-Item -Path $OutputFilePath -ItemType File -Force | Out-Null }
	Set-Content -Path $OutputFilePath -Value ( $Output )
	return $OutputFilePath
}

# Skriver log f�r k�rning av skript.
# Varje rad f�reg�s alltid av logdata och f�ljs av logtext fr�n skript.
function WriteLog
{
	param ( $LogText )
	$LogFilePath = "$RootDir\Logs\$( [datetime]::Now.Year )\$( [datetime]::Now.Month )\$CallingScript - log.txt" # Skapar s�kv�g f�r logfil
	if ( -not ( Test-Path $LogFilePath ) ) { New-Item -Path $LogFilePath -ItemType File -Force | Out-Null } # Finns logfilen? Om inte, skapa den
	Add-Content -Path $LogFilePath -Value ( $nudate + " " + $env:USERNAME + " [" + $env:USERDOMAIN + "] => " + $LogText )
}

# Loggar error vid k�rning av skript.
# Varje rad f�reg�s alltid av logdata och f�ljs av logtext fr�n skript.
# Returnerar s�kv�g f�r filen.
function WriteErrorlog
{
	param ( $LogText )
	$ErrorLogFilePath = "$RootDir\ErrorLogs\$( [datetime]::Now.Year )\$( [datetime]::Now.Month )\$CallingScript - Errorlog $( Get-Date -Format 'yyyyMMddHHmmss' ).txt"
	if ( -not ( Test-Path $ErrorLogFilePath ) ) { New-Item -Path $ErrorLogFilePath -ItemType File -Force | Out-Null } # Finns errorlogfilen? Om inte, skapa den
	Add-Content -Path $ErrorLogFilePath -Value ( ( Get-Date -Format "yyyy-MM-dd HH:mm:ss" ) + " " + $env:USERNAME + " [" + $env:USERDOMAIN + "] => " + $LogText )
	return $ErrorLogFilePath
}

# Visa en meddelanderuta med angiven text, samt eventuellt angiven titel, knapp, ikon.
# Returnerar vilken knapp som trycktes.
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

# Anger i konsolf�nstret att skriptet kan avslutas.
function AvslutaScript
{
	$dummy = Read-Host "`nTryck p� Enter f�r att avsluta"
	if ( $dummy -ne "" )
	{ Add-Content -Path "$RootDir\Logs\DummyQuitting.txt" -Value "$nudate $env:USERNAME $CallingScript - $dummy" }
}

# Skapar ett PowerShell-objekt inneh�llandes en f�nster, baserat p� XAML-fil f�r WPF.
# Returnerar objektet, samt en array inneh�llandes namn p� alla namngivna kontroller i filen.
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

$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
$CallingScript = ( Get-Item $MyInvocation.PSCommandPath ).BaseName
$Host.UI.RawUI.WindowTitle = "Skript: $( ( ( Get-Item $MyInvocation.PSCommandPath ).FullName -split "Skript" )[1] )"

Export-ModuleMember -Function *
