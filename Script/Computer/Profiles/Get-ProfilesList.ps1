<#
.Synopsis List profiles on remote computer
.Description List profiles on remote computer.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

[array]$profiles = Invoke-Command -ComputerName $ComputerName -Scriptblock `
{
	$HKLMprofile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\"
	$keys = Get-ChildItem $HKLMprofile -Name -Recurse -Include 'S-1-5-21-*'
	foreach ( $key in $keys )
	{
		$key = Join-Path -Path $HKLMprofile -ChildPath $key
		@{ p = ( Get-ItemProperty $key ).ProfileImagePath ; t = ( Get-Item ( Get-ItemProperty $key ).ProfileImagePath ).CreationTime }
	}
} | Select-Object @{ Name = $msgTable.StrUser; Expression = { try { ( Get-ADUser ( $_.p -split "\\" )[-1] ).Name } catch { WriteErrorLog -LogText $_ } } }, `
	@{ Name = $msgTable.StrProfLoc; Expression = { $_.p } }, `
	@{ Name = $msgTable.StrAge; Expression = { ( [DateTime]::Now - $_.t ).Days } } | `
	Sort-Object @{ Expression = { $_.$( $msgTable.StrAge ) }; Ascending = $false }, @{ Expression = { $_.$( $msgTable.StrUser ) }; Ascending = $true } | Format-Table -AutoSize

if ( 0 -eq $profiles.Count )
{ $output = $msgTable.LogNoProfiles }
else
{ $output = ( $profiles | Out-String ).Trim() }

$output | Out-Host
$outputFile = WriteOutput -Output "$( $msgTable.StrCompName ) $ComputerName`n$output"

WriteLog -LogText "$ComputerName > $( $profiles.Count )`r`n`t$outputFile" | Out-Null
EndScript
