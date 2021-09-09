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
	$return = Invoke-Command -ComputerName $ComputerName -Scriptblock { Start-Process $Using:Program }
	Write-Host "$( $msgTable.StrDone ) $Program"
}
catch
{
	$eh = WriteErrorlogTest -LogText $_ -UserInput $Program -Severity "OtherFail"
	Write-Host $msgTable.StrErr
	Write-Host $_
}

WriteLogTest -Text $return -UserInput $Program -Success ( $null -eq $eh ) | Out-Null
EndScript
