<#
.Synopsis List profiles on remote computer
.Description List profiles on remote computer.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]
$CaseNr = Read-Host "Related casenumber (if any) "

$profileName = Invoke-Command -ComputerName $ComputerName -Scriptblock `
{
	#Creates a variable to hold the path for profiles in the registry
	$HKLMprofile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\"
	$keys = Get-ChildItem $HKLMprofile -Name -Recurse -Include 'S-1-5-21-*'
	$profileName = @()
	foreach ( $key in $keys )
	{
		$key = Join-Path -Path $HKLMprofile -ChildPath $key
		$profileName += ( Get-ItemProperty $key ).ProfileImagePath
	}
	$profileName
}

Write-Host $profileName

$outputFile = WriteOutput -Output $profileName

WriteLog -LogText "$CaseNr $ComputerName > $( $profileName.Count )`r`n`t$outputFile"
EndScript
