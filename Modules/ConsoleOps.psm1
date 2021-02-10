# A module for functions operating at the console
# Use this to import module:
# Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force

param ( $culture = "sv-SE" )
#####################################################
# Initiates sleep with a progressbar and defined text
function StartWait
{
	param( $SecondsToWait, $MessageText )
	$MessageText = "$( $IntmsgTable.StartWait1 ) $SecondsToWait $( $IntmsgTable.StartWait2 ) $MessageText"
	1..$SecondsToWait | foreach { Write-Progress -Activity $MessageText -PercentComplete ( ( $_ / $SecondsToWait ) * 100 ); Start-Sleep 1 }
	Write-Progress -Activity $MessageText -Completed
}

################################################################
# Reads input from the console. The data is pasted with Ctrl + V
# Returns the input as an array, separated according to Split
function GetConsolePasteInput
{
	param ( [switch] $Folders )
	$Quit = New-Object -ComObject wscript.shell

	$Users1 = @()
	do
	{
		if ( $Folders )
		{ $Text = ( Read-Host ).Split( "`n""`n""`n""`r`n"","";", [System.StringSplitOptions]::RemoveEmptyEntries ) }
		else
		{ $Text = ( Read-Host ).Split( "`n"" `n""`n ""`r`n"","";"" "":""-""_""/""\""."" `r`n""`r`n "", ""; "": ""- ""_ ""/ ""\ "". ", [System.StringSplitOptions]::RemoveEmptyEntries ) }

		if ( $Text -ne '' )
		{
			$Users1 += $Text
		}
		else
		{
			$Quit.SendKeys( ( $IntmsgTable.GetConsolePasteInput ) )
			$Quit.SendKeys( "~" )
		}
	} until ( $Text -eq ( $IntmsgTable.GetConsolePasteInput ) )
	$Users2 = $Users1 -ne ( $IntmsgTable.GetConsolePasteInput )

	return $Users2
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | select -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

Export-ModuleMember -Function *
