<#
.Synopsis Clear NetID-cache for one remote computer
.Description Removes all cache-files for NetID on given computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

try
{
	$Files = Invoke-Command -ErrorAction Stop -ComputerName $ComputerName -ScriptBlock `
	{
		# Remove all items under 'C:\Windows\temp' containing iid
		$Files = Get-ChildItem -Path "C:\Windows\Temp\" -Include "*iid*" -Recurse
		$Files | ForEach-Object { Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue }
		return $Files
	}

	Write-Host $msgTable.StrDone
}
catch [System.Management.Automation.Remoting.PSRemotingTransportException]
{
	$eh = WriteErrorlogTest -LogText $_.Exception -UserInput -Severity "ConnectionFail"
	Write-Host $msgTable.ErrConn -ForegroundColor Red
	1..3 | ForEach-Object { Write-Host $msgTable."ErrConnRes$( $_ )" -ForegroundColor Red }
}
catch
{
	$eh = WriteErrorlogTest -LogText $_.Exception -UserInput -Severity "OtherFail"
	Write-Host $msgTable.ErrOther -ForegroundColor Red
	Write-Host $_
}

WriteLogTest -Text "$( $msgTable.LogNumFiles ) $( $Files.Where( { $_.Mode -notmatch "^d" } ).Count )`n$( $msgTable.LogNumFolders ) $( $Files.Where( { $_.Mode -match "^d" } ).Count )" -UserInput $ComputerName ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
EndScript
