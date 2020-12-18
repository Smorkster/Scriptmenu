<#
.Synopsis Show running processes on remote computer
.Description Show running processes on remote computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

$apps = tasklist /NH /s $ComputerName | sort
$apps

$outputFile = WriteOutput -Output $apps

WriteLog -LogText "$CaseNr $ComputerName`r`n`t$outputFile"
EndScript
