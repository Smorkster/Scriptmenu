<#
.Synopsis Show running processes on remote computer
.Description Show running processes on remote computer.
.Depends WinRM
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$apps = tasklist /NH /s $ComputerName | sort
$apps

$outputFile = WriteOutput -Output $apps

WriteLog -LogText "$ComputerName`r`n`t$outputFile" | Out-Null
EndScript
