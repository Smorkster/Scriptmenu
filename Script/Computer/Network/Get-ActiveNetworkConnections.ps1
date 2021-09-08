<#
.Synopsis Show active networkconnections on remote computer, and related applications
.Description List all active networkconnections on given computer. The outputlist shows what processes owns the connection, where it is connected and if it is active.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

Write-Host $msgTable.StrStart
$processList = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
	$processList = [System.Collections.ArrayList]::new()
	Get-NetTCPConnection | ForEach-Object {
		$n = ( Get-Process -Id $_.OwningProcess ).Name
		$id = $_.OwningProcess
		$st = $_.State
		$t = $_.RemoteAddress
		$so = $_.LocalAddress

		if ( -not ( $processList.Process -match $n ) ) { $processList.Add( [pscustomobject]@{ Process = $n; IdList = [System.Collections.ArrayList]::new() } ) | Out-Null }

		if ( -not ( $id -in ( $processList.Where( { $_.Process -match $n } ) ).IdList.Id ) )
		{
			( $processList.Where( { $_.Process -match $n } ) )[0].IdList.Add( [pscustomobject]@{ Id = $id; ConList = [System.Collections.ArrayList]::new() } ) | Out-Null
		}

		( ( $processList.Where( { $_.Process -match $n } ) )[0].IdList.Where( { $_.Id -eq $id } ) )[0].ConList.Add( @{ Target = $t; Source = $so; State = $st } ) | Out-Null
	}
	return $processList
}

$output = $processList | ForEach-Object {
	"$( $msgTable.StrAppTitle ) ""$( $_.Process )""`r`n$( ( $_.IdList | ForEach-Object {
			"`t$( $msgTable.StrPIDTitle ): $( $_.Id )`r`n"
			$_.ConList | ForEach-Object { "`t`t$( $msgTable.StrTargetIP ): $( $_.Target ) $( $msgTable.StrSourceIP ): $( $_.Source ) $( $msgTable.StrStatus ): $( $_.State )`r`n" }
		} ) )`r`n"
} | Out-String

$outputFile = WriteOutput -Output $output

switch ( Read-Host $msgTable.QShowAs )
{
	1 { $output | Out-Host }
	2 { Start-Process notepad $outputFile -Wait }
}

WriteLogTest -Text "$( $processList.Process.Count ) $( $msgTable.LogSummary )" -UserInput $ComputerName -Success $true -OutputPath $outputFile | Out-Null
EndScript
