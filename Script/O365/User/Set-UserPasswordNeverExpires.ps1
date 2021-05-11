<#
.Synopsis Sets a users password to never expire
.Description Set an individual user's password to never expire
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$w = [System.Windows.Window]@{ SizeToContent = "WidthAndHeight" }
$spmain = [System.Windows.Controls.StackPanel]@{ Orientation = "Vertical" ; Margin = 5 }

$spControls = [System.Windows.Controls.StackPanel]@{ Orientation = "Horizontal" }
$spControls.AddChild( ( $lblID = [System.Windows.Controls.Label]@{ Content = $msgTable.ContentlblID } ) )
$spControls.AddChild( ( $tbID = [System.Windows.Controls.Textbox]@{ Width = 50 ; VerticalContentAlignment = "Center" ; HorizontalContentAlignment = "Center" } ) )
$spControls.AddChild( ( $btnSave = [System.Windows.Controls.Button]@{ Content = $msgTable.ContentbtnSave ; IsEnabled = $false } ) )

$spSetting = [System.Windows.Controls.StackPanel]@{ Orientation = "Vertical" }
$spSetting.AddChild( ( $lblSetting = [System.Windows.Controls.Label]@{ Content = $msgTable.ContentlblSetting } ) )
$spSetting.AddChild( ( $spRBs = [System.Windows.Controls.StackPanel]@{ Orientation = "Vertical" } ) )
$spRBs.AddChild( ( $rbNone = [System.Windows.Controls.RadioButton]@{ Content = $msgTable.ContentrbNone ; Margin = "0,0,0,10" } ) )
$spRBs.AddChild( ( $rbDisabled = [System.Windows.Controls.RadioButton]@{ Content = $msgTable.ContentrbDisabled } ) )

$lres = [System.Windows.Controls.Label]@{ Content = "" }

$spmain.AddChild( $spControls )
$spmain.AddChild( $spSetting )
$spmain.AddChild( $lres )
$w.Content = $spmain

$rbNone.Add_Checked( { if ( $null -ne $script:az.PasswordPolicies ) { $btnSave.IsEnabled = $true } else { $btnSave.IsEnabled = $false } } )
$rbDisabled.Add_Checked( { if ( $null -eq $script:az.PasswordPolicies ) { $btnSave.IsEnabled = $true } else { $btnSave.IsEnabled = $false } } )
$tbID.Add_TextChanged( {
	if ( $this.Text.Length -ge 4 )
	{
		try
		{
			Get-ADUser -Identity $this.Text -Properties * -ErrorAction Stop
			if ( $script:az = Get-AzureADUser -SearchString $tbID.Text )
			{
				if ( $null -eq $script:az.PasswordPolicies ) { $rbNone.IsChecked = $true }
				else { $rbDisabled.IsChecked = $true }
			}
			else { $lres.Content = $msgTable.ErrAzureADNotFound }
		}
		catch { $lres.Content = $msgTable.ErrADNotFound }
	}
} )
$btnSave.Add_Click( {
	try
	{
		Set-AzureADUser -ObjectId $script:az.ObjectId -PasswordPolicies DisablePasswordExpiration
		WriteLog -LogText $this.Text
		$lres.Content = $msgTable.StrDone
	}
	catch { $lres.Content = $_.Exception.Message }
} )
$w.Add_ContentRendered( { $this.Activate() ; $tbID.Focus() } )
[void] $w.ShowDialog()
