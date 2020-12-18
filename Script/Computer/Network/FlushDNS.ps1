<#
.Synopsis Clear local DNS cache on remote computer
.Description Clear local DNS cache on given computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

Invoke-Command -Computername $ComputerName -Scriptblock { ipconfig /flushdns }

Write-Host "DNS cache cleared"

WriteLog -LogText "$CaseNr $ComputerName"
EndScript
