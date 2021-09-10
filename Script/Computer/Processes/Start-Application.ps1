<#
.Synopsis Start application on remote computer
.Description Start application on remote computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

$Program = Read-Host "$( $msgTable.QApp )"

try
{
	Invoke-Command -ComputerName $ComputerName -ScriptBlock { Start-Process $Using:Program }
	Write-Host "$( $msgTable.StrDone ) $Program"
}
catch
{
	$eh = WriteErrorlogTest -LogText $_ -UserInput $Program -Severity "OtherFail" -ComputerName $ComputerName
	Write-Host $msgTable.StrErr
	Write-Host $_
}

WriteLogTest -UserInput $Program -Success ( $null -eq $eh ) -ComputerName $ComputerName | Out-Null
EndScript
