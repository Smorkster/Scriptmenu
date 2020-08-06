#Description = Show systeminformation for remoter computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
$info = systeminfo /s $ComputerName

$info
$outputFile = WriteOutput -Output $info
WriteLog -LogText "$CaseNr $ComputerName`r`n`t$outputFile"

EndScript
