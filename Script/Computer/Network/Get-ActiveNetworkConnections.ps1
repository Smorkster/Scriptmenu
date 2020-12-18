<#
.Synopsis Show active networkconnections on remote computer, and related applications
.Description List all active networkconnections on given computer. The outputlist shows what processes owns the connection, where it is connected and if it is active.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

$stats = Invoke-Command -Computername $ComputerName -Scriptblock { netstat -b -f }

$outputFile = WriteOutput -Output $stats

Start-Process notepad $outputFile -Wait

WriteLog -LogText "$CaseNr $ComputerName`r`n`t$outputFile"
EndScript
