<#
.Synopsis Show networkrouting from remote computer to given address
.Description Show networkrouting from remote computer to given address.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

$Destination = Read-Host "$( $msgTable.QTargetIP )"

$Trace = Invoke-Command -Computername $ComputerName -Scriptblock { Test-NetConnection $using:Destination -TraceRoute }

$OFS = "`r`n`t"
$outputFile = WriteOutput -Output "$( $msgTable.LogIP ): $( $Trace.RemoteAddress )`r`n$( $msgTable.LogComputerName ): $( $Trace.ComputerName )`r`n$( $msgTable.LogTR ): $( [string]$Trace.TraceRoute )"

Start-Process notepad $outputFile -Wait

WriteLogTest -Text $Destination -UserInput $ComputerName -Success $true -OutputPath $outputFile | Out-Null
EndScript
