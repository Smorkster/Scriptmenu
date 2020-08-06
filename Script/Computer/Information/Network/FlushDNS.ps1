#Description = Clear local DNS cache on remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
Invoke-Command -Computername $ComputerName -Scriptblock { ipconfig /flushdns }

WriteLog -LogText "$CaseNr $ComputerName"
Write-Host "DNS cache cleared"

EndScript
