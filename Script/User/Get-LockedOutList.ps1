<#
.Synopsis List where a users account have been locked
.Description Search for user in logfiles of accountlocks. Then lists at which computer the account was locked.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CaseNr = Read-Host "Related casenumber (if any) "
$UserInput = Read-Host "User id"

Write-Host "Searching logs..."
$result = Get-ChildItem G:\LockedOut_Log -Filter '*LogLockedOut.txt' | Get-Content | Where-Object { ( $_ -split " " )[2] -eq $UserInput } | ForEach-Object { "$( ( $_ -split '\s+' )[0] ) $( ( $_ -split '\s+' )[1] ) $( ( $_ -split '\s+' )[3] ) " } | Select-Object -Unique | Sort-Object

if ( $result.Count -eq 0 )
{
	Write-Host "No information about account lock was found for '$UserInput'"
}
else
{
	Write-Host "'$UserInput' was locked at these computers:"
	$result
}

WriteLog -LogText "$CaseNr $( $UserInput.ToUpper() )"
EndScript
