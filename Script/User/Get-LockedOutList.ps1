<#
.Synopsis List where a users account have been locked
.Description Search for user in logfiles of accountlocks. Then lists at which computer the account was locked.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$UserInput = Read-Host $( $msgTable.QID )

Write-Host $msgTable.WSearching
$result = ( Get-ChildItem G:\Lit\Servicedesk\LockedOut_Log -Filter '*LogLockedOut.txt' | Select-String -Pattern $UserInput ).Line | ForEach-Object {
		$d, $t, $null, $c = $_ -split '\s+'
		"$d $t $c"
	} | Select-Object -Unique | Sort-Object

if ( $result.Count -eq 0 )
{
	Write-Host $msgTable.WNoData
}
else
{
	Write-Host $msgTable.WFoundData
	$result
}

WriteLogTest -Text "$( $msgTable.LogMessageCount ) $( $result.Count )" -UserInput $UserInput -Success $true | Out-Null
EndScript
