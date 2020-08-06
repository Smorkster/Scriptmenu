<#
.Synopsis
	Clear NETID Cache on remote computer
.DESCRIPTION
	Clear NETID Cache on remote computer
#>

#Description = Clear NetID-cache one remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force
$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
try
{
	Invoke-Command -ErrorAction Stop -ComputerName $ComputerName -ScriptBlock `
	{
		# Remove all items under C:\Windows\Temp containing iid
		Get-ChildItem -Path "C:\Windows\Temp\" -Include "*iid*" -Recurse | foreach `
		{
			Remove-Item $_ -Force -Recurse -ErrorAction SilentlyContinue
			Write-Host -ForegroundColor Green "Removed $_ on Client: $Using:ComputerName"
		}
	}

	# Write Output
	Write-Host "NetID-cache is now cleared"
}
catch
{
	Write-Host $_.Exception.Message -ForegroundColor Red
}

WriteLog -LogText "$CaseNr $ComputerName"
EndScript
