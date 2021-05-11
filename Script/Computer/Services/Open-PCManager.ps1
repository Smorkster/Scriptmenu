<#
.Synopsis Open computermanager on remote computer
.Description Open Windows computermanager, connected to given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

C:\Windows\System32\Compmgmt.msc -a /computer=$ComputerName

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
