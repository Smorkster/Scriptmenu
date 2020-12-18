<#
.Synopsis Show systeminformation for remote computer
.Description Show system information for given computer, such as operatingsystem, date of installation, installed hotfixes etc.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

$info = systeminfo /s $ComputerName

$info
$outputFile = WriteOutput -Output $info

WriteLog -LogText "$CaseNr $ComputerName`r`n`t$outputFile"
EndScript
