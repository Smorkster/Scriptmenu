# A module for functions operating at the console
# Use this to import module:
# Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force

# Initializes waiting, with given messagetext
function StartWait
{
	param( $SecondsToWait, $MessageText )
	$MessageText = "Var god vänta i $SecondsToWait sekunder $MessageText"
	1..$SecondsToWait | ForEach-Object { Write-Progress -Activity $MessageText -PercentComplete ( ( $_ / $SecondsToWait ) * 100 ); Start-Sleep 1 }
	Write-Progress -Activity $MessageText -Completed
}

# Reads input from console
# For data to be pasted with Ctrl+V
# Returns input as array
function GetConsolePasteInput
{
	param ( [switch] $Folders )
	$Quit = New-Object -ComObject wscript.shell

	$Users1 = @()
	do
	{
		if ( $Folders )
		{ $ControlInput = ( Read-Host ).Split( "`n""`n""`n""`r`n"","";" ) }
		else
		{ $ControlInput = ( Read-Host ).Split( "`n"" `n""`n ""`r`n"","";"" "":""-""_""/""\""."" `r`n""`r`n "", ""; "": ""- ""_ ""/ ""\ "". ", [System.StringSplitOptions]::RemoveEmptyEntries ) }

		if ( $ControlInput -ne '' )
		{
			$Users1 += $ControlInput
		}
		else
		{
			$Quit.SendKeys( "Klar" )
			$Quit.SendKeys( "~" )
		}
	} until ( $input -eq "Klar" )
	$Users2 = $Users1 -ne "Klar"

	return $Users2
}

Export-ModuleMember -Function *
