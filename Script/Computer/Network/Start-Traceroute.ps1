<#
.Synopsis Show networkrouting from remote computer to given address
.Description Show networkrouting from remote computer to given address.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

$Destination = Read-Host "$( $msgTable.QTargetIP )"

$Trace = Invoke-Command -Computername $ComputerName -Scriptblock { tracert $Destination }

$outputFile = WriteOutput -Output $Trace

Start-Process notepad $outputFile -Wait

WriteLog -LogText "$ComputerName`r`n`t$outputFile" | Out-Null
EndScript
