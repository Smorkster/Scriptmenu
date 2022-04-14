<#
.Synopsis A module for functions operating at the console
.Description Use this to import module: Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force -ArgumentList $args[1]
.State Prod
.Author Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )

function AskDisplayOption
{
	<#
	.Description
		Ask the user how data in specified file should be displayed
		Valid alternatives are:
			Notepad
			Format-Table, i.e. list data in the console
			Out-GridView, i.e. a gridview window will display the data
	.Parameter File
		File to display
	.Parameter NoFT
		Format-Table will not be a valid choice
	.Parameter NoGW
		Out-GridView will not be a valid choice
	.Outputs
		Returns the selected choise
	#>

	param ( [string] $File, [switch] $NoFT, [switch] $NoGW )

	if ( $NoFT )
	{
		switch ( Read-Host $IntmsgTable.QDisplayOpNoFT )
		{
			1 { Get-Content $File | Out-GridView ; $dt = "GW" }
			2 { Start-Process notepad -ArgumentList $File ; $dt = "notepad" }
		}
	}
	elseif ( $NoGW )
	{
		switch ( Read-Host $IntmsgTable.QDisplayOpNoGW )
		{
			1 { Get-Content $File | Format-Table ; $dt = "FT" }
			2 { Start-Process notepad -ArgumentList $File ; $dt = "notepad" }
		}
	}
	else
	{
		switch ( Read-Host $IntmsgTable.QDisplayOp )
		{
			1 { Get-Content $File | Format-Table ; $dt = "FT" }
			2 { Get-Content $File | Out-GridView ; $dt = "GW" }
			3 { Start-Process notepad -ArgumentList $File ; $dt = "notepad" }
		}
	}

	return $dt
}

function GetConsolePasteInput
{
	<#
	.Description
		Reads input from the console. The data is pasted with Ctrl + V
	.Parameter Folders
		If the text entered are names of folder. Use other split rules.
	.Outputs System.Array
		The input as an array, separated according to Split
	#>

	param ( [switch] $Folders )

	$Quit = New-Object -ComObject wscript.shell

	$TextEntered = @()
	do
	{
		if ( $Folders )
		{ $Text = ( Read-Host ).Split( "`n""`n""`n""`r`n"","";", [System.StringSplitOptions]::RemoveEmptyEntries ) }
		else
		{ $Text = ( Read-Host ).Split( "`n"" `n""`n ""`r`n"","";"" "":""-""_""/""\""."" `r`n""`r`n "", ""; "": ""- ""_ ""/ ""\ "". ", [System.StringSplitOptions]::RemoveEmptyEntries ) }

		if ( $Text -ne '' )
		{
			$TextEntered += $Text
		}
		else
		{
			$Quit.SendKeys( ( $IntmsgTable.GetConsolePasteInput ) )
			$Quit.SendKeys( "~" )
		}
	} until ( $Text -eq ( $IntmsgTable.GetConsolePasteInput ) )
	$TextEntered = $TextEntered -ne ( $IntmsgTable.GetConsolePasteInput )

	return $TextEntered
}

function GetUserChoice
{
	<#
	.Description
		Display a question and run loop until a correct ansver, number up to MaxNum, or Y/N, is entered
	.Parameter MaxNum
		Highest umber the user can enter, that is a valid choise
	.Parameter YesNo
		Only yes and no answers are valid
	.Parameter ChoiceText
		Text to display when asking for answer
	#>
	param (
	[Parameter( ParameterSetName = "TypeCount", Mandatory = $true )]
		[int] $MaxNum = 2,
	[Parameter( ParameterSetName = "TypeYesNo", Mandatory = $true )]
		[switch]$YesNo,
	[Parameter( Mandatory = $true )]
		[string] $ChoiceText = $IntmsgTable.GetChoiceDefaultChoiceText
	)

	if ( $YesNo )
	{
		$err = $IntmsgTable.GetChoiceYesNo
		$comp = { "Y", "N" }
	}
	else
	{
		$comp = { 1..$MaxNum }
		if ( $MaxNum -ne 2 ) { $err = "$( $IntmsgTable.GetChoiceMaxText ) $MaxNum." }
		else { $err = $IntmsgTable.GetChoice12 }
	}

	do
	{
		$Pass = $true
		if ( ( $Choice = Read-Host $ChoiceText ) -notin ( . $comp ) )
		{
			Write-Host -ForegroundColor Red $err
			$Pass = $false
		}
	}
	until ( $Pass )

	return $Choice
}

function StartWait
{
	<#
	.Description
		Initiates sleep with a progressbar and the defined text in the console
	.Parameter SecondsToWait
		Time to for the progressbar to be visible
	.Parameter MessageText
		Text to be visible in the progressbar
	#>
	param ( $SecondsToWait, $MessageText )

	$MessageText = "$( $IntmsgTable.StartWait1 ) $SecondsToWait $( $IntmsgTable.StartWait2 ) $MessageText"
	1..$SecondsToWait | ForEach-Object { Write-Progress -Activity $MessageText -PercentComplete ( ( $_ / $SecondsToWait ) * 100 ); Start-Sleep 1 }
	Write-Progress -Activity $MessageText -Completed
}

function TextToSpeech
{
	<#
	.Description
		Use speech synthesizer to play a message
	.Parameter Text
		Text to be said
	.Parameter Voice
		The selected voice to be used
	#>

	param ( $Text, $Voice = "Microsoft David Desktop" )

	$Voice = New-Object –TypeName System.Speech.Synthesis.SpeechSynthesizer
	$Voice.SelectVoiceByHints( [System.Speech.Synthesis.VoiceGender]::Neutral )
	$Voice.SpeakAsync( $Text )
}

Add-Type -AssemblyName System.Speech
$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
try { $CallingScript = ( Get-Item $MyInvocation.PSCommandPath ).BaseName } catch { $CallingScript = $null }
Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization\$culture\Modules"

Export-ModuleMember -Function *
