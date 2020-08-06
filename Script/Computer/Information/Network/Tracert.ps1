#Description = Show networkrouting from remote computer to given address
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
$Destination = Read-Host "Target IP-address"

$Trace = Invoke-Command -Computername $ComputerName -Scriptblock { tracert $Destination }

$outputFile = WriteOutput -Output $Trace

WriteLog -LogText "$CaseNr $ComputerName`r`n`t$outputFile"
Start-Process notepad $outputFile -Wait

EndScript
