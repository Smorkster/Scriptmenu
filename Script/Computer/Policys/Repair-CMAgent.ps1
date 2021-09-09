<#
.Synopsis Repair CM agent on remote computer
.Description Repair CM agent on given computer.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

Invoke-WmiMethod -ComputerName $ComputerName -Namespace root\ccm -Class sms_client -Name RepairClient
Write-Host $msgTable.StrDone

WriteLogTest -Text "." -UserInput $ComputerName -Success $true | Out-Null
EndScript
