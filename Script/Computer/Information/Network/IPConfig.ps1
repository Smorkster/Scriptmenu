#Description = Show IP configuration on remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CaseNr = Read-Host "Related casenumber (if any) "
$ComputerName = $args[1]
$conf = Invoke-Command -Computername $ComputerName -Scriptblock { ipconfig /all }

$outputFile = WriteOutput -Output $conf

WriteLog -LogText "$CaseNr $ComputerName`r`n`t$outputFile"
Start-Process notepad $outputFile -Wait

EndScript
