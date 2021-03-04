<#
.Synopsis Close application on remote computer
.Description Close application on remote computer.
.Depends WinRM
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$apps = tasklist /s $ComputerName | Sort-Object

$apps
$PID = Read-Host "$( $msgTable.QPID )"
$app = ( ( ( $apps | Where-Object { $_ -match "50628" } ).Split( " " ) | Select-Object -Unique ) -join " " ).Split( " " )[0]

taskkill /F /s $ComputerName /PID $PID

WriteLog -LogText "$ComputerName $app" | Out-Null
EndScript
