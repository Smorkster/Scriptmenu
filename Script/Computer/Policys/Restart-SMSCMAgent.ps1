<#
.Synopsis Retart SMS & CM agents
.Description Restart SMS & CM agents on remote computer
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

$eh += Invoke-Command -ComputerName $ComputerName -Scriptblock { Restart-Service -Name 'CcmExec' }
$eh += Invoke-Command -ComputerName $ComputerName -Scriptblock { Restart-Service -Name 'CmRcService' }

WriteLogTest -Text "." -UserInput $ComputerName -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
EndScript
