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
	Invoke-Command -ErrorAction Stop -ComputerName $ComputerName -ScriptBlock `
	{
		# Remove all items under C:\Windows\temp containing iid
		Get-ChildItem -Path "C:\Windows\Temp\" -Include "*iid*" -Recurse | ForEach-Object `
		{
			Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue
		}
	}

	Write-Host $msgTable.StrDone
}
catch [System.Management.Automation.Remoting.PSRemotingTransportException]
{
	WriteErrorLog -LogText $_.Exception
	Write-Host $msgTable.ErrConn -ForegroundColor Red
	1..3 | ForEach-Object { Write-Host $msgTable."ErrConnRes$( $_ )" -ForegroundColor Red }
}
catch
{
	WriteErrorLog -LogText $_.Exception
	Write-Host $msgTable.ErrOther -ForegroundColor Red
	Write-Host $_
}

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
