<#
.Synopsis Log on to remote computer as admin
.Description Starts a remote connection to computer, loggin in as administrator.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

Start-Process -Filepath "C:\Windows\System32\mstsc.exe" -ArgumentList "/v:$ComputerName /f"

WriteLogTest -Text "." -UserInput $ComputerName -Success $true | Out-Null
EndScript
