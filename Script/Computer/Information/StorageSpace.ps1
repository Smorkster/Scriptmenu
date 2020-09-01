<#
.Synopsis Show free diskspace on remote computer
.Description Show free diskspace on remote computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

Invoke-Command -ComputerName $ComputerName { Get-PSDrive C } | select PSComputerName, @{ Name = "Used (GB)"; Expression = { $_.Used / 1GB } }, @{ Name = "Free (GB)"; Expression = { $_.Free / 1GB } } | ft

WriteLog -LogText "$CaseNr $ComputerName"
EndScript
