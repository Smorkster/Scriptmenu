<#
.Synopsis Rensa nedladdade filer
.Description Tar bort alla filer äldre än en vecka, från gemensam mapp
.State Prod
.Requires Role_SD_BO
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1"

$files = Get-ChildItem $msgTable.CodeDirPath -File -Recurse
Write-Host "$( $files.Count ) $( $msgTable.StrDownloadCount )"

$filesToRemove = $files | Where-Object { $_.CreationTime -lt ( Get-Date ).AddDays( -7 ) }
if ( ( $percentage = [Math]::Round( ( $filesToRemove.Count / $files.Count ) * 100, 2 ) ) -gt 0 )
{
	Write-Host "$( $filesToRemove.Count ) $( $msgTable.StrOldString ) ($percentage %)"
	$filesToRemove | Foreach-Object { Remove-Item $_.FullName }
	Write-Host $msgTable.StrDone -ForegroundColor Green
}
else
{
	Write-Host $msgTable.StrNoFiles
}

WriteLogTest -Text "$( $filesToRemove.Count )`n$percentage % $( $msgTable.LogPercent )" -Success $true | Out-Null
EndScript