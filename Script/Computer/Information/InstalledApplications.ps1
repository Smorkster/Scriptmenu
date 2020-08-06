#Description = Show installed applications on remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
Write-Host "Fetching installed applications on $ComputerName"

$applications = wmic /node:$ComputerName product get name | foreach { $_.Trim() } | where { $_ -ne "" -and $_ -ne "Name" } | sort

$applications
$outputFile = WriteOutput -Output $applications
WriteLog -LogText "$CaseNr $ComputerName`r`n`t$outputFile"

EndScript
