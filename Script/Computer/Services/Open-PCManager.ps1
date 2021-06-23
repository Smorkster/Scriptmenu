<#
.Synopsis Open computermanager on remote computer
.Description Open Windows computermanager, connected to given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

C:\Windows\System32\Compmgmt.msc -a /computer=$ComputerName

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
