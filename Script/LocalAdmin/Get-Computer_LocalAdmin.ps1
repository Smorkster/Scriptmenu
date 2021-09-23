<#
.Synopsis Get local admin registered on remote computer
.Description Get local admin registered on remote computer.
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = Read-Host "$( $msgTable.QComputer )"

try
{
	$Computer = Get-ADComputer $ComputerName -Properties adminDescription

	if ( $null -eq $Computer.adminDescription )
	{
		Write-Host "$( $msgTable.StrNoLA )"
		$logText = $msgTable.StrLogNoLA
	}
	else
	{
		foreach ( $data in ( $Computer.adminDescription -split ";" -split ":" | Where-Object { $_ } ) )
		{
			try
			{
				[datetime]::Parse( $data ) | Out-Null
				$list += "$( $msgTable.StrOutDate ): $data`n"
			}
			catch { $list += "$( $msgTable.StrOutUser ): $data`n`n" }
		}
		$logText = "$( $Computer.adminDescription)`n`n$list"
	}
}
catch
{
	$eh = WriteErrorlogTest -LogText $_ -UserInput $ComputerName -Severity "UserInputFail"
	Write-Host "$( $msgTable.ErrMsg ) '$ComputerName'"
}

WriteLogTest -Text $logText -ComputerName $ComputerName -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
EndScript
