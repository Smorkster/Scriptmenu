<#
.Synopsis Show installed printers on remote computer
.Description Show installed printers on remote computer.
.Depends WinRM
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$Printers = @()


$Printers = Get-WmiObject Win32_Printer -ComputerName $ComputerName | select Name
$Printers | Out-Host
$outputFile = WriteOutput -Output $Printers

WriteLog -LogText "$ComputerName > $( $Printers.Count )`r`n`t$outputFile" | Out-Null
EndScript
