#Description = Show installed printers on remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$Printers = @()

$CaseNr = Read-Host "Related casenumber (if any) "
$key = 'SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\Print\\Connections'
$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey( 'LocalMachine', $ComputerName )

foreach ( $sub in $reg.OpenSubkey( $key ).GetSubKeyNames() )
{
	$subkey = $reg.OpenSubKey( "$( $key )\$( $sub )" )
	$Printers += $subkey.GetValue( 'Printer' )
}

Write-Host $Printers

$outputFile = WriteOutput -Output $Printers
WriteLog -LogText "$CaseNr $ComputerName > $( $Printers.Count )`r`n`t$outputFile"

EndScript
