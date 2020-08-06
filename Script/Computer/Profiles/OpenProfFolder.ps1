#Description = Open profilefolder on remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
explorer.exe \\$ComputerName\C$\Users

WriteLog -LogText "$CaseNr $ComputerName"

EndScript
