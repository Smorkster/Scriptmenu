<#
.Synopsis Show C:\ on remote computer
.Description Opens Explorer C:\ for the given computer opened.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

Start-Process -Filepath "C:\Windows\explorer.exe" -ArgumentList "\\$ComputerName\C$"

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
