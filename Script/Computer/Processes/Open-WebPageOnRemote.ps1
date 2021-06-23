<#
.Synopsis Open webpage on remote computer
.Description Open webpage on remote computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]
$Adress = Read-Host "$( $msgTable.QAddress )"

Invoke-Command -ComputerName $ComputerName -Scriptblock ` { Start-Process $Using:Adress }

WriteLog -LogText "$ComputerName > $Adress" | Out-Null
EndScript
