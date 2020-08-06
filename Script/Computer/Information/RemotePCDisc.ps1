#Description = Show C: on remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
Start-Process -Filepath "C:\Windows\explorer.exe" -ArgumentList "\\$ComputerName\C$"

WriteLog -LogText "$CaseNr $ComputerName"

EndScript
