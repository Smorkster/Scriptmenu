<#
.Synopsis Show networkrouting from remote computer to given address
.Description Shows the path for networkconnection from given computer, to given address. Will also ping the node at each stop.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

$Destination = Read-Host "$( $msgTable.QTargetIP )"

$Route = Invoke-Command -Computername $ComputerName -Scriptblock { pathping $Destination }

$Route
$outputFile = WriteOutput -Output $Route -FileNameAddition $ComputerName

WriteLog -LogText "$ComputerName`r`n`t$outputFile" | Out-Null
EndScript
