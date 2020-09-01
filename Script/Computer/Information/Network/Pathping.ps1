<#
.Synopsis Show networkrouting from remote computer to given address
.Description Shows the path for networkconnection from given computer, to given address. Will also ping the node at each stop.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

$Destination = Read-Host "Target IP-address"

$Route = Invoke-Command -Computername $ComputerName -Scriptblock { pathping $Destination }

$Route
$outputFile = WriteOutput -Output $Route -FileNameAddition $ComputerName

WriteLog -LogText "$CaseNr $ComputerName`r`n`t$outputFile"
EndScript
