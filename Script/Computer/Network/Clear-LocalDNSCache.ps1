<#
.Synopsis Clear local DNS cache on remote computer
.Description Clear local DNS cache on given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

Invoke-Command -Computername $ComputerName -Scriptblock { ipconfig /flushdns }

Write-Host "$( $msgTable.StrDone )"

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
