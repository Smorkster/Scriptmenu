<#
.Synopsis Retart SMS & CM agents
.Description Restart SMS & CM agents on remote computer
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

Invoke-Command -ComputerName $ComputerName -Scriptblock { Restart-Service -Name 'CcmExec' ; Restart-Service -Name 'CmRcService' }

WriteLog -LogText "$( $ComputerName.ToUpper() )" | Out-Null
EndScript
