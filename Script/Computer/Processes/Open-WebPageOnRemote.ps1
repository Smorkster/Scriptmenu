<#
.Synopsis Open webpage on remote computer
.Description Open webpage on remote computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]
$Address = Read-Host "$( $msgTable.QAddress )"

try
{
	Invoke-Command -ComputerName $ComputerName -ScriptBlock { Start-Process $Using:Address } -ErrorAction Stop
	Write-Host $msgTable.StrDone
}
catch
{
	$eh = WriteErrorlogTest -LogText $_ -UserInput $Address -Severity "OtherFail" -ComputerName $ComputerName
	Write-Host $msgTable.StrErr
	Write-Host $_
}

WriteLogTest -UserInput $Address -ComputerName $ComputerName -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
EndScript
