<#
.Synopsis List profiles on remote computer
.Description List profiles on remote computer.
.Depends WinRM
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$profiles = Invoke-Command -ComputerName $ComputerName -Scriptblock `
{
	$HKLMprofile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\"
	$keys = Get-ChildItem $HKLMprofile -Name -Recurse -Include 'S-1-5-21-*'
	foreach ( $key in $keys )
	{
		$key = Join-Path -Path $HKLMprofile -ChildPath $key
		@{ p = ( Get-ItemProperty $key ).ProfileImagePath ; t = ( Get-Item ( Get-ItemProperty $key ).ProfileImagePath ).CreationTime }
	}
}

$profiles | Select-Object @{ Name = $msgTable.StrProfLoc; Expression = { $_.p } }, `
	@{ Name = $msgTable.StrUser; Expression = { try { ( Get-ADUser ( $_.p -split "\\" )[-1] ).Name } catch { WriteErrorLog -LogText $_ } } }, `
	@{ Name = $msgTable.StrAge; Expression = { ( [DateTime]::Now - $_.t ).Days } } | `
	Sort-Object ( $msgTable.StrAge ) -Descending | Format-Table -AutoSize

$outputFile = WriteOutput -Output $profiles

WriteLog -LogText "$ComputerName > $( $profiles.Count )`r`n`t$outputFile" | Out-Null
EndScript
