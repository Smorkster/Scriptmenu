<#
.Synopsis Show C:\ on remote computer
.Description Opens Explorer C:\ for the given computer opened.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]
$folder = Read-Host $msgTable.QFolderToOpen
if ( $folder -eq "" ) { $folder = "C$" }
else { $folder = $folder.Replace( "C:", "C$" ) }

Start-Process -Filepath "C:\Windows\explorer.exe" -ArgumentList "\\$ComputerName\$folder\"

WriteLogTest -Text $folder -UserInput $ComputerName -Success $true | Out-Null
EndScript
