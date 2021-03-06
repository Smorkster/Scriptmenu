<#
.Synopsis Show active networkconnections on remote computer, and related applications
.Description List all active networkconnections on given computer. The outputlist shows what processes owns the connection, where it is connected and if it is active.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

$stats = ( Invoke-Command -Computername $ComputerName -Scriptblock { netstat -b -f } ).Replace( '†', 'å' ).Replace( '„', 'ä' )

$outputFile = WriteOutput -Output $stats

Start-Process notepad $outputFile -Wait

WriteLog -LogText "$ComputerName`r`n`t$outputFile" | Out-Null
EndScript
