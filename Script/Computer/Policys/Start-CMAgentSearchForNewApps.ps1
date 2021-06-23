<#
.Synopsis Find newly deployed applications for remote computer
.Description Find newly deployed applications for remote computer.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]
$CaseNr = Read-Host "Related casenumber (if any) "

Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name TriggerSchedule '{00000000-0000-0000-0000-000000000022}'

WriteLog -LogText "$CaseNr $( $ComputerName.ToUpper() )"
EndScript
