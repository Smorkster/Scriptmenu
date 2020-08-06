#Description = Start application on remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
$Program = Read-Host "Name application to be started"

Invoke-Command -ComputerName $ComputerName -Scriptblock { start $Using:Program }

WriteLog -LogText "$CaseNr $ComputerName $Program"

EndScript
