<#
.Synopsis Show IP configuration on remote computer
.Description Runs command 'ipconfig /all' on given computer. The Information is then listed in consolewindow.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

$conf = Invoke-Command -Computername $ComputerName -Scriptblock {
	Get-NetIPConfiguration -All -Detailed
	Get-NetIPAddress | Where-Object { $_.InterfaceAlias -notmatch "Loopback" }
}

$outputFile = WriteOutput -Output "$( $msgTable. LogConfig )`r`n$( ( $conf[0] | Out-String ).Trim() )`r`n`r`n$( $msgTable.LogInterfaces )`r`n$( ( $conf[1] | Out-String ).Trim() )"

Start-Process notepad $outputFile -Wait

WriteLogTest -Text "." -UserInput $ComputerName -Success $true -OutputPath $outputFile | Out-Null
EndScript
