#Description = Release remote computers IP-address and request new
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
Invoke-Command -Computername $ComputerName -Scriptblock { ipconfig /release | ipconfig /renew }

WriteLog -LogText "$CaseNr $ComputerName"

EndScript
