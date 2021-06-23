<#
.Synopsis Get devices registered for O365
.Description Get all units registered for user in Azure
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -Argumentlist $args[1]

$w = [System.Windows.Window]@{ SizeToContent = "WidthAndHeight"; WindowStartupLocation = "CenterScreen" }
$sp = [System.Windows.Controls.StackPanel]@{ Orientation = "Vertical" }
$tb = [System.Windows.Controls.TextBox]@{ Width = 100; Height = 30; VerticalContentAlignment = "Center" }
$sp.AddChild( $tb )
$b = [System.Windows.Controls.Button]@{ Content = $msgTable.ContentSearch }
$sp.AddChild( $b )
$tbOut = [System.Windows.Controls.TextBox]@{ Width = 300; Height = 150; IsReadOnly = $true }
$sp.AddChild( $tbOut )
$w.AddChild( $sp )
$LogText = ""

$b.Add_Click( {
	$tbOut.Text = ""
	try
	{
		if ( $user = Get-AzureADUser -Filter "UserPrincipalName eq '$( ( Get-ADUser $tb.Text -Properties EmailAddress ).EmailAddress )'" )
		{
			if ( $devices = ( Get-AzureADUserRegisteredDevice -ObjectId $user.ObjectId ).DisplayName )
			{
				$tbOut.Text += $msgTable.StrDeviceTitle
				$devices | Foreach-Object { $tbOut.Text += "`n$_" }
			}
			else
			{
				$tbOut.Text += "`n$( $msgTable.StrNoDevices )"
			}
		}
		else
		{
			$tbOut.Text += $msgTable.StrErrNotFoundAzureAD
		}
	}
	catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
	{
		$tbOut.Text +=  "$( $tb.Text ) $( $msgTable. StrErrNotFoundAD )."
	}
	catch
	{
		$tbOut.Text += "$( $msgTable.StrErrGen )`n$_"
	}
} )
$w.Add_Activated( { $tb.Focus() } )
[void] $w.ShowDialog()
WriteLog -LogText "$( $tb.Text ) > $( $ofs = ", "; [string]( ( $tbOut.Text -split "`n" )[ 1..( ( $tbOut.Text -split "`n" ).Count - 1 ) ] ) )"
