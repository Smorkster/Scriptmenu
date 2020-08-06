#Description = List where a users account have been locked
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CaseNr = Read-Host "Related casenumber (if any) "
$UserInput = Read-Host "User id"

Write-Host "Searching logs..."
$result = Get-ChildItem G:\LockedOut_Log -Filter '*LogLockedOut.txt' | Get-Content | where { ( $_ -split " " )[2] -eq $UserInput } | foreach { "$( ( $_ -split '\s+' )[0] ) $( ( $_ -split '\s+' )[1] ) $( ( $_ -split '\s+' )[3] ) " } | select -Unique | sort

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
