# A module for functions creating GUI's
# Use this to import module:
# Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force

param ( $culture = "sv-SE" )
################################################################################################################
# Creates a PowerShell-objects, containing a WPF-window, based on XAML-file with same name as the calling script
# Returns object and an array containing the names of each named control in the XAML-file
function CreateWindow
{
	Add-Type -AssemblyName PresentationFramework

	$XamlFile = "$RootDir\Gui\$( $CallingScript.BaseName ).xaml"
	$inputXML = Get-Content $XamlFile -Raw
	$inputXML = $inputXML -replace "x:N", 'N' -replace '^<Win.*', '<Window'
	[XML]$XAML = $inputXML

	$reader = ( New-Object System.Xml.XmlNodeReader $Xaml )
	try
	{
		$Window = [Windows.Markup.XamlReader]::Load( $reader )
	}
	catch
	{
		Write-Host $_
		Read-Host
		throw
	}
	$vars = @()
	$xaml.SelectNodes( "//*[@Name]" ) | Foreach-Object {
		$vars += $_.Name
	}

	return $Window, $vars
}

# Creates a synchronized hashtable containing:
#	* Each named control, with its name from XAML-file, at "top-level", including main Window even if it is not named
#	* Vars - Array with names of each named control
#	* Data - Hashtable for a script to save variables
#	* Output - String to be used for output data
#	* DC - Hashtable with each bound datacontext for controls properties. This is defined from $ControlsToBind when calling the function
# Returns the hashtable
function CreateWindowExt
{
	param ( $ControlsToBind )

	$Bindings = [hashtable]( @{} )
	$GenErrors = New-Object System.Collections.ArrayList
	$syncHash = [hashtable]::Synchronized( @{} )
	$syncHash.Data = [hashtable]( @{} )
	$syncHash.DC = [hashtable]( @{} )
	$syncHash.Output = ""
	$syncHash.Window, $syncHash.Vars = CreateWindow

	$syncHash.Vars | Foreach-Object {
		$syncHash.$_ = $syncHash.Window.FindName( $_ )
		$Bindings.$_ = New-Object System.Collections.ObjectModel.ObservableCollection[object]
		$syncHash.DC.$_ = New-Object System.Collections.ObjectModel.ObservableCollection[object]
	}

	foreach ( $control in $ControlsToBind )
	{
		if ( ( $n = $control.CName ) -in $syncHash.DC.Keys )
		{
			# Insert all predefines property values
			$control.Props | Foreach-Object { $syncHash.DC.$n.Add( $_.PropVal ) }

			# Create the bindingobjects
			0..( $control.Props.Count - 1 ) | Foreach-Object { [void] $Bindings.$n.Add( ( New-Object System.Windows.Data.Binding -ArgumentList "[$_]" ) ) }
			$Bindings.$n | Foreach-Object { $_.Mode = [System.Windows.Data.BindingMode]::TwoWay }
			# Insert bindings to controls DataContext
			$syncHash.$n.DataContext = $syncHash.DC.$n

			# Connect the bindings
			for ( $i = 0; $i -lt $control.Props.Count; $i++ )
			{
				$p = "$( $control.Props[$i].PropName )Property"
				try
				{
					[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.$n, $( $syncHash.$n.DependencyObjectType.SystemType )::$p, $Bindings.$n[ $i ] )
				}
				catch { [void] $GenErrors.Add( "$n$( $IntmsgTable.ErrNoProperty ) '$p'") }
			}
		}
		else { [void] $GenErrors.Add( "$( $IntmsgTable.ErrNoControl ) $n" ) }
	}

	if ( $GenErrors.Count -gt 0 )
	{
		$ofs = "`n"
		[void] [System.Windows.MessageBox]::Show( "$( $IntmsgTable.ErrAtGen ):`n`n$GenErrors" )
	}

	return $syncHash
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization"

try { $CallingScript = ( Get-Item $MyInvocation.PSCommandPath ) } catch {}
try { $Host.UI.RawUI.WindowTitle = "$( $IntmsgTable.ConsoleWinTitlePrefix ): $( ( ( Get-Item $MyInvocation.PSCommandPath ).FullName -split "Script" )[1] )" } catch {}

Export-ModuleMember -Function *
