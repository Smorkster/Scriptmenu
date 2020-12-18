<#
.Synopsis Open webpage on remote computer
.Description Open webpage on remote computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "
$Address = Read-Host "Write webaddress to be opened"

Invoke-Command -ComputerName $ComputerName -Scriptblock ` { start $Using:Address }

WriteLog -LogText "$CaseNr $ComputerName > $Adress"
EndScript
