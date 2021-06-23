<#
.Synopsis Open profilefolder on remote computer
.Description Starts Explorer with given computers profilefolder opened.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

explorer.exe \\$ComputerName\C$\Users

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
