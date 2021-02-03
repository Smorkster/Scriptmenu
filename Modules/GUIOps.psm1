# A module for functions creating GUI's
# Use this to import module:
# Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force

#param ( $culture = "sv-SE" )
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
	$xaml.SelectNodes( "//*[@Name]" ) | foreach {
		$vars += $_.Name
	}

	return $Window, $vars
}

#
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

	$syncHash = [hashtable]::Synchronized( @{} )
	$Bindings = [hashtable]( @{} )
	$syncHash.Data = [hashtable]( @{} )
	$syncHash.DC = [hashtable]( @{} )
	$syncHash.Output = ""
	$syncHash.Window, $syncHash.Vars = CreateWindow

	$syncHash.Vars | foreach {
		$syncHash.$_ = $syncHash.Window.FindName( $_ )
		$Bindings.$_ = New-Object System.Collections.ObjectModel.ObservableCollection[object]
		$syncHash.DC.$_ = New-Object System.Collections.ObjectModel.ObservableCollection[object]
	}

	foreach ( $control in $ControlsToBind )
	{
		$n = $control.CName
		# Insert all predefines property values
		$control.Props | foreach { $syncHash.DC.$n.Add( $_.PropVal ) }

		# Create the bindingobjects
		0..( $control.Props.Count - 1 ) | foreach { [void] $Bindings.$n.Add( ( New-Object System.Windows.Data.Binding -ArgumentList "[$_]" ) ) }
		$Bindings.$n | foreach { $_.Mode = [System.Windows.Data.BindingMode]::TwoWay }
		# Insert bindings to controls DataContext
		$syncHash.$n.DataContext = $syncHash.DC.$n

		# Connect the bindings
		for ( $i = 0; $i -lt $control.Props.Count; $i++ )
		{
			$p = "$( $control.Props[$i].PropName )Property"
			[void][System.Windows.Data.BindingOperations]::SetBinding( $syncHash.$n, $( $syncHash.$n.DependencyObjectType.SystemType )::$p, $Bindings.$n[ $i ] )
		}
	}

	return $syncHash
}

$nudate = Get-Date -Format "yyyy-MM-dd HH:mm"
$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
try { $CallingScript = ( Get-Item $MyInvocation.PSCommandPath ) } catch {}
try { $Host.UI.RawUI.WindowTitle = "Skript: $( ( ( Get-Item $MyInvocation.PSCommandPath ).FullName -split "Skript" )[1] )" } catch {}

Export-ModuleMember -Function *
