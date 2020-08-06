#Description = Show active networkconnections on remote computer, and related applications
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CaseNr = Read-Host "Related casenumber (if any) "
$ComputerName = $args[1]

$stats = Invoke-Command -Computername $ComputerName -Scriptblock { netstat -b -f }

$outputFile = WriteOutput -Output $stats

WriteLog -LogText "$CaseNr $ComputerName`r`n`t$outputFile"
Start-Process notepad $outputFile -Wait

EndScript
