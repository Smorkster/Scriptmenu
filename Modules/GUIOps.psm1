<#
.Synopsis A module for functions creating and working with GUI's
.Description Use this to import module: Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]
.State Prod
.Author Smorkster (smorkster)
#>

param ( $culture = "sv-SE" )
function CreateWindow
{
	<#
	.Synopsis
		Creates a PowerShell-object, containing a WPF-window, based on XAML-file with same name as the calling script
	.Outputs
		Returns object and an array containing the names of each named control in the XAML-file
	#>
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

function CreateWindowExt
{
	<#
	.Synopsis
		Creates a synchronized hashtable for the window and binds listed properties of their controls to datacontext
	.Description
		Creates a synchronized hashtable for the GUI generated in CreateWindow. Then binds the properties listed in input (ControlsToBind) to the datacontext of each named control. These are reached within $syncHash.DC.<name of the control>[<index of the property>].
		The hashtable contains these collections that can be used inside scripts:
		Vars - An array with the names of each named control
		Data - Hashtable to save variables, collections or objects inside scripts
		Jobs - Hashtable to store PSJobs
		Output - A string that can be used for output data
		DC - Hashtable with each bound datacontext for the named controls listed properties. This is defined from $ControlsToBind when calling the function
	.Parameter ControlsToBind
		An arraylist containing the names and values of controls and properties to bind.
		Each item in the arraylist must follow this structure:
		$arraylist.Add( @{ CName = "ControlName"
			Props = @(
				@{ PropName = "BorderBrush"
					PropVal = "Red" }
				) } )
		CName - Name of the control as entered in the XAML-file
		PropName - Name of the property. This must be one the controltypes Dependency Properties
	.Outputs
		The hashtable containing all bindings and arrays
	#>
	param ( $ControlsToBind )

	$Bindings = [hashtable]( @{} )
	$GenErrors = New-Object System.Collections.ArrayList
	$syncHash = [hashtable]::Synchronized( @{} )
	$syncHash.Data = [hashtable]( @{} )
	$syncHash.DC = [hashtable]( @{} )
	$syncHash.Jobs = [hashtable]( @{} )
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
				$p = "$( $control.Props[$i].PropName -replace "Property" )Property"
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

function ShowSplash
{
	<#
	.Synopsis
		Shows a small window at the center of the screen with given text
	.Parameter Text
		The text to show
	.Parameter Duration
		How long the text should be shown. Defaults is 1.5 seconds
	.Parameter BorderColor
		The color of the border of the window
	.Parameter SelfAdmin
		The script calling will administrate opening and closing
	#>
	param ( [string] $Text, [double] $Duration = 1.5, [string] $BorderColor = "Green", [switch] $SelfAdmin )
	$splash = [System.Windows.Window]@{ WindowStartupLocation = "CenterScreen" ; WindowStyle = "None"; ResizeMode = "NoResize"; SizeToContent = "WidthAndHeight" }
	$splash.AddChild( [System.Windows.Controls.Label]@{ Content = $Text ; BorderBrush = $BorderColor; BorderThickness = 5 } )
	if ( $SelfAdmin ) { return $splash }
	else
	{
		$splash.Show()
		Start-Sleep -Seconds $Duration
		$splash.Close()
	}
}

$RootDir = ( Get-Item $PSCommandPath ).Directory.Parent.FullName
Import-LocalizedData -BindingVariable IntmsgTable -UICulture $culture -FileName "$( ( $PSCommandPath.Split( "\" ) | Select-Object -Last 1 ).Split( "." )[0] ).psd1" -BaseDirectory "$RootDir\Localization\$culture\Modules"

try { $CallingScript = ( Get-Item $MyInvocation.PSCommandPath ) } catch {}
try { $Host.UI.RawUI.WindowTitle = "$( $IntmsgTable.ConsoleWinTitlePrefix ): $( ( ( Get-Item $MyInvocation.PSCommandPath ).FullName -split "Script" )[1] )" } catch {}

Export-ModuleMember -Function *
