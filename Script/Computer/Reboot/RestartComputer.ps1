#Description = Restart remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
Restart-Computer -ComputerName $ComputerName -Force -Wait -For PowerShell -Timeout 300 -Delay 2
WriteLog -LogText "$CaseNr $ComputerName"

EndScript
