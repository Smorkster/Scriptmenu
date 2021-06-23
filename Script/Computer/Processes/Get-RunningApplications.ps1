<#
.Synopsis Show running processes on remote computer
.Description Show running processes on remote computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

$apps = tasklist /NH /s $ComputerName | Sort-Object
$apps

$outputFile = WriteOutput -Output $apps

WriteLog -LogText "$ComputerName`r`n`t$outputFile" | Out-Null
EndScript
