<#
.Synopsis Open services on remote computer
.Description Open Windows servicesmanager, connected to the given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

try { C:\Windows\System32\services.msc -a /computer=$ComputerName }
catch
{
	$eh = WriteErrorlogTest -LogText $_ -UserInput "." -Severity "OtherFail" -ComputerName $ComputerName
	Write-Host $msgTable.StrErr
}

WriteLogTest -Success ( $null -eq $eh ) -ComputerName $ComputerName -ErrorLogHash $eh | Out-Null
EndScript
