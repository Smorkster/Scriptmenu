<#
.Synopsis Turn off remote computer
.Description Forces a shutdown of given computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

Stop-Computer -ComputerName $ComputerName -Force

WriteLog -LogText "$CaseNr $ComputerName"
EndScript
