#Description = Open services on remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
C:\Windows\System32\services.msc -a /computer=$ComputerName

WriteLog -LogText "$CaseNr $ComputerName"

EndScript
