#Description = Check status of AD-account
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

#######################################
# Gets user from AD and verifies status
function LookUpUser
{
	$btnActivate.IsEnabled = $false
	$btnExtend.IsEnabled = $false
	$btnUnlock.IsEnabled = $false
	$LookedUpUser = $null

	try
	{
		$LookedUpUser = Get-ADUser $tbID.Text –Properties pwdlastset, enabled, lockedout, description, accountExpires, msDS-UserPasswordExpiryTimeComputed | select Name, pwdlastset, enabled, lockedout, description, accountExpires, @{ Name="ExpiryDate"; Expression={ [datetime]::FromFileTime( $_."msDS-UserPasswordExpiryTimeComputed" ) } }
	}
	catch
	{}

	if ( $LookedUpUser -ne $null )
	{
		Print -Text "Loaded user: $( $LookedUpUser.Name )"

		if ( ( $LookedUpUser.Description -like "Manually disabled*" ))
		{
			Print -Text "Account status: Account disabled and is not to be activated! Escalate to operations" -Color "Red"
			$status = "disabled > Operations"
		}
		else
		{
			if ( $LookedUpUser.Enabled -eq $false )
			{
				Print -Text "Kontostatus: Kontot är inaktiverat (disabled): För att aktivera kontot, se rubrik 'GAIA-konto har blivit Disabled/Inaktiverat' i artikel: GAIA - Låst konto (KB0010734)" -Color "Red"
				$status = "inaktivt"
				$btnActivate.IsEnabled = $true
			}

			if ( $LookedUpUser.LockedOut -eq $true )
			{
				Print -Text "Account locked due to too many faulty login attempts" -Color "Red"
				$status = "locked"
				$btnUnlock.IsEnabled = $true
			}

			if ( ( $LookedUpUser.Enabled -eq $true ) -and ( $LookedUpUser.LockedOut -eq $false ) )
			{
				Print -Text "Account status: Account active and unlocked."
				$status = "Green"
			}

			if ( $LookedUpUser.pwdlastset -eq 0 )
			{
				Print -Text "Password status: A passwordchange is scheduled ('User must change password at next logon' is checked). Tell the user to login wit the new password; or set new password." -Color "Red"
				$status = "scheduled passwordchange"
			}
			elseif ( $LookedUpUser.ExpiryDate -ne $null )
			{
				if ( $LookedUpUser.ExpiryDate -lt ( Get-Date ) )
				{
					Print -Text "Password status: Expirydate have passed! It is more than 200 days old and expired $( ( $LookedUpUser.ExpiryDate ).ToString( "yyyy-MM-dd" ) ). Extend validity with button below." -Color "Red"
					$status = "password validity expired"
					$btnExtend.IsEnabled = $true
				}
				else
				{
					Print -Text "Password status: Validity expires $( ( $LookedUpUser.ExpiryDate ).ToString( "yyyy-MM-dd" ) )."
					$btnExtend.IsEnabled = $true
					$status = "aktive password"
				}
			}
			else
			{
				Print -Text "Password status: Password never expires."
				$status = "unending password"
			}

			if ( -not ( ( $LookedUpUser.accountExpires -eq 0 ) -or ( $LookedUpUser.accountExpires -eq 9223372036854775807 ) ) )
			{
				if ( ( [DateTime]::FromFileTime( $LookedUpUser.accountExpires ) ) -lt ( Get-Date ) )
				{
					Print -Text "Period of validity: Account has a manualy set validity that have passed. It expired $( ( [DateTime]::FromFileTime( $LookedUpUser.accountExpires ) ).ToString( "yyyy-MM-dd" ) ). Escalate to operations." -Color "Red"
					$status = "manual validity expired > Operations"
				}
				else
				{
					Print -Text "Period of validity: Account has a manualy set validity. Account expires $( ( [DateTime]::FromFileTime( $LookedUpUser.accountExpires ) ).ToString( "yyyy-MM-dd" ) )."
					$status = "manual validity > Operations"
				}
			}
		}
		WriteLog -LogText "$( $tbID.Text.ToUpper() ) LookUp, status: $status"
	}
	else
	{
		$spOutput.Children.Clear()
	}
}

################################
# Extends password validity date
function Extend
{
	try
	{
		Set-ADUser -Identity $tbID.Text -Replace @{ pwdLastSet = 0 }
		Set-ADUser -Identity $tbID.Text -Replace @{ pwdLastSet = -1 }
		WriteLog -LogText "$( $tbID.Text.ToUpper() ) > Password validity extended"
		Print -Text "Password validity have been extended."
	}
	catch
	{
		$errorlog = WriteErrorLog -LogText "$( $tbID.Text ) > Extend password validity`r`n`tError: $( $Error[0].Exception )"
		WriteLog -LogText "$( $tbID.Text.ToUpper() ) > Error - Extend password validity`r`n`tErrorlog: $errorlog"
		Print -Text "Could not extended password validity.`n`nErrormessage: $( $Error[0] ).`n`n" -Color "Red"
		ShowMessageBox -Text "Some accounts, i.e. admin accounts, can only be handled by Operations." -Title "Error!" -Button "OK" -Icon"Error"
	}

	LookUpUser
}

##########################
# Unlocks an locked account
function Unlock
{
	try
	{
		Unlock-ADAccount $tbID.Text -Confirm:$false
		WriteLog -LogText "$( $tbID.Text.ToUpper() ) > Unlocked"
		Print -Text "Account is unlocked."
	}
	catch
	{
		$errorlog = WriteErrorLog -LogText "$( $tbID.Text ) > Unlocking of account`r`n`tError: $( $Error[0].Exception )"
		WriteLog -LogText "$( $tbID.Text.ToUpper() ) > Error - Unlocking of account`r`n`tErrorlog: $errorlog"
		Print -Text "Could not unlock account.`n`nErrormessage: $( $Error[0] )." -Color "Red"
		ShowMessageBox -Text "Some accounts, i.e. admin accounts, can only be handled by Operations." -Title "Error!" -Button "OK" -Icon"Error"
	}

	LookUpUser
}

#############################
# Enables an disabled account
function Enable
{
	try
	{
		Enable-ADAccount $tbID.Text -Confirm:$false
		WriteLog -LogText "$( $tbID.Text.ToUpper() ) > Activated"
		Print -Text "Account activated."
	}
	catch
	{
		$errorlog = WriteErrorLog -LogText "$( $tbID.Text ) > Activation of account`r`n`tError: $( $Error[0].Exception )"
		WriteLog -LogText "$( $tbID.Text.ToUpper() ) > Error - Activation`r`n`tErrorlog: $errorlog"
		Print -Text "Could not activate account.`n`nErrormessage: $( $Error[0] )." -Color "Red"
		ShowMessageBox -Text "Some accounts, i.e. admin accounts, can only be handled by Operations." -Title "Error!" -Button "OK" -Icon"Error"
	}

	LookUpUser
}

###################################
# Prints information to a new label
function Print
{
	param ( $Text, $Color = "Green" )

	$lblOutput = New-Object System.Windows.Controls.Label
	$lblOutput.Foreground = $Color
	$lblOutput.Content = "$( Get-Date -Format 'HH:mm:ss' ) $Text"
	$spOutput.AddChild( $lblOutput )
	$spOutput.UpdateLayout()
}

############################### Skriptet börjar här
$Window, $vars = CreateWindow
$vars | foreach { Set-Variable -Name $_ -Value $Window.FindName( $_ ) -Scope global }

$tbID.Add_TextChanged( { if ( $tbID.Text.Length -gt 0 ) { $btnCancel.Visibility = [System.Windows.Visibility]::Visible } else { $btnCancel.Visibility = [System.Windows.Visibility]::Collapsed } ; LookUpUser } )
$btnExtend.Add_Click( { Extend } )
$btnUnlock.Add_Click( { Unlock } )
$btnActivate.Add_Click( { Enable } )
$btnCancel.Add_Click( { if ( $spOutput.Children.Count -gt 0 ) { $spOutput.Children.Clear() } ; $tbID.Text = "" } )
$Window.Add_ContentRendered( { $Window.Top = 80; $Window.Activate() } )

[void] $Window.ShowDialog()
$Window.Close()
