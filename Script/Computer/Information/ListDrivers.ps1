<#
.Synopsis Show installed drivers on remote computer
.Description Lists all installed drivers on given computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
$Drivers = ( driverquery /s $ComputerName /v /fo table ) -replace "ÿ", ","

$Drivers
$outputFile = WriteOutput -Output $Drivers

WriteLog -LogText "$CaseNr $ComputerName`r`n`t$outputFile"
Start-Process notepad $outputFile -Wait

EndScript
