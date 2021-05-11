<#
.Synopsis Retart SMS & CM agents
.Description Restart SMS & CM agents on remote computer
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

Invoke-Command -ComputerName $ComputerName -Scriptblock { Restart-Service -Name 'CcmExec' ; Restart-Service -Name 'CmRcService' }

WriteLog -LogText "$( $ComputerName.ToUpper() )" | Out-Null
EndScript
