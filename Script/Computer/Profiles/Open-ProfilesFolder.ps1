<#
.Synopsis Open profilefolder on remote computer
.Description Starts Explorer with given computers profilefolder opened.
.Depends WinRM
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

explorer.exe \\$ComputerName\C$\Users

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
