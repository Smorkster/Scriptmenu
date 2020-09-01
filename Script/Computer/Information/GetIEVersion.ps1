<#
.Synopsis Show Internet Explorer version on remote computer
.Description Show Internet Explorer version on remote computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
$keyname = 'SOFTWARE\\Microsoft\\Internet Explorer'
$reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey( 'LocalMachine', $ComputerName )

$key = $reg.OpenSubkey( $keyname )
$value = $key.GetValue( 'svcVersion' )

$value
WriteLog -LogText "$CaseNr $ComputerName"
EndScript
