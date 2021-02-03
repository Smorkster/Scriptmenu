<#
.Synopsis List where a users account have been locked
.Description Search for user in logfiles of accountlocks. Then lists at which computer the account was locked.
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$UserInput = Read-Host $( $msgTable.QID )

Write-Host $msgTable.WSearching
$result = Get-ChildItem G:\LockedOut_Log -Filter '*LogLockedOut.txt' | Get-Content | where { ( $_ -split " " )[2] -eq $UserInput } | foreach { "$( ( $_ -split '\s+' )[0] ) $( ( $_ -split '\s+' )[1] ) $( ( $_ -split '\s+' )[3] ) " } | select -Unique | sort

if ( $result.Count -eq 0 )
{
	Write-Host $msgTable.WNoData
}
else
{
	Write-Host $msgTable.WFoundData
	$result
}

WriteLog -LogText "$( $UserInput.ToUpper() )" | Out-Null
EndScript
