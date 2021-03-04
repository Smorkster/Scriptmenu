<#
.Synopsis Clear local DNS cache on remote computer
.Description Clear local DNS cache on given computer.
.Depends WinRM
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

Invoke-Command -Computername $ComputerName -Scriptblock { ipconfig /flushdns }

Write-Host "$( $msgTable.StrDone )"

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
