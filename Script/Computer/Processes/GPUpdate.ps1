#Description = Start Group policy update on remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
Invoke-GPUPDATE -Computer $ComputerName -Force

WriteLog -LogText "$CaseNr $ComputerName"

EndScript
