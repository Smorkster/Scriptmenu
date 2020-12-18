<#
.Synopsis Find newly deployed applications for remote computer
.Description Find newly deployed applications for remote computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000022}'

WriteLog -LogText "$CaseNr $( $ComputerName.ToUpper() )"
EndScript
