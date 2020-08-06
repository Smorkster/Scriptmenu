#Description = Close application on remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
$apps = tasklist /s $ComputerName | sort

$apps
$PID = Read-Host "Write processID (PID) for application to be closed"
$app = ( ( ( $apps | ? { $_ -match "50628" } ).Split( " " ) | select -Unique ) -join " " ).Split( " " )[0]

taskkill /F /s $ComputerName /PID $PID

WriteLog -LogText "$CaseNr $ComputerName $app"

EndScript
