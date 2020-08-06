#Description = Get local admin registered on remote computer
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$CaseNr = Read-Host "Related casenumber (if any) "
$ComputerName = Read-Host "Computername "

$Computer = Get-ADComputer $ComputerName -Properties adminDescription

if ( $Computer.adminDescription -eq $null )
{
	Write-Host "No LocalAdmin-account registered for computer"
	$logText = "No LocalAdmin"
}
else
{
	$logText = $Computer.adminDescription
	foreach ( $data in ( $Computer.adminDescription -split ";" | where { $_ -ne "" } ) )
	{
		$split = $data -split ":"
		Write-Host "Date: $( $split[0] )`nUser: $( $split[1] )"
	}
}

WriteLog -LogText "$CaseNr $( $Computer.Name ) > $logText"

EndScript
