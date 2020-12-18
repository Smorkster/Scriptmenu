<#
.Synopsis Close application on remote computer
.Description Close application on remote computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

$apps = tasklist /s $ComputerName | Sort-Object

$apps
$ID = Read-Host "Write processID (PID) for application to be closed"
$app = ( ( ( $apps | Where-Object { $_ -match "50628" } ).Split( " " ) | Select-Object -Unique ) -join " " ).Split( " " )[0]

taskkill /F /s $ComputerName /PID $ID

WriteLog -LogText "$CaseNr $ComputerName $app"
EndScript
