<#
.Synopsis Show running processes on remote computer
.Description Show running processes on remote computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

try
{
	Write-Host $msgTable.StrGettingProcesses
	$apps = Invoke-Command -scriptblock { Get-Process } -ComputerName $ComputerName | Select-Object Name, Id, CPU, MainWindowTitle, @{ Name = "Memory (MB)"; Expression = { [math]::Round( $_.WS / 1MB, 2 ) } }, Responding, Path
}
catch
{
	$eh = WriteErrorlogTest -LogText $_ -UserInput "-" -Severity "OtherFail" -ComputerName $ComputerName
	Write-Host $msgTable.StrError
}

$outputFile = WriteOutput -Output ( $apps | Format-Table | Out-String )

switch ( ( $disp = Read-Host $msgTable.QDisplayInfo ) )
{
	1 { $apps | Format-Table | Out-Host }
	2 { $apps | Out-GridView }
	3 { Start-Process notepad $outputFile }
}

WriteLogTest -ComputerName $ComputerName -UserInput "$( $msgTable.LogDispType ) $disp" -Success ( $null -eq $eh ) -ErrorLogHash $eh -OutputPath $outputFile | Out-Null
EndScript
