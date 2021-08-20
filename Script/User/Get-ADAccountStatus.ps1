<#
.Synopsis Check status of AD-account
.Description Search for a users AD-account and check if it is active and status of password. The account can be reactivated and the validity of the password can be extended. If the account requires other permissions, a message is shown.
.Author Smorkster (smorkster)
#>

#######################################
# Gets user from AD and verifies status
function LookUpUser
{
	$syncHash.btnActivate.IsEnabled = $false
	$syncHash.btnExtend.IsEnabled = $false
	$syncHash.btnUnlock.IsEnabled = $false
	$LookedUpUser = $null

	try
	{
		$LookedUpUser = Get-ADUser $syncHash.tbID.Text –Properties pwdlastset, enabled, lockedout, description, accountExpires, msDS-UserPasswordExpiryTimeComputed | Select-Object Name, pwdlastset, enabled, lockedout, description, accountExpires, @{ Name = "ExpiryDate"; Expression = { [datetime]::FromFileTime( $_."msDS-UserPasswordExpiryTimeComputed" ) } }
	}
	catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] { }
	catch { WriteErrorLogTest -LogText $_.Exception.Message -UserInput $syncHash.tbID.Text -Severity "OtherFail" }

	if ( $null -ne $LookedUpUser )
	{
		$syncHash.spOutput.Children.Clear()
		Print -Text "$( $msgTable.WReadUser ) $( $LookedUpUser.Name )"

		if ( ( $LookedUpUser.Description -match "$( $msgTable.WDescText )" ) )
		{
			Print -Text $msgTable.WBlockedUser -Color "Red"
			$status = $msgTable.WLBlockedUser
		}
		else
		{
			if ( $LookedUpUser.Enabled -eq $false )
			{
				Print -Text $msgTable.WDisabledUser -Color "Red"
				$status = $msgTable.WLDisabledUser
				$syncHash.btnActivate.IsEnabled = $true
			}

			if ( $LookedUpUser.LockedOut -eq $true )
			{
				Print -Text $msgTable.WLockedUser -Color "Red"
				$status = $msgTable.WLLockedUser
				$syncHash.btnUnlock.IsEnabled = $true
			}

			if ( ( $LookedUpUser.Enabled -eq $true ) -and ( $LookedUpUser.LockedOut -eq $false ) )
			{
				Print -Text $msgTable.WActiveUser
				$status = $msgTable.WLActiveUser
			}

			if ( $LookedUpUser.pwdlastset -eq 0 )
			{
				Print -Text $msgTable.WPasswordChange -Color "Red"
				$status = $msgTable.WLPasswordChange
			}
			elseif ( $null -ne $LookedUpUser.ExpiryDate )
			{
				if ( $LookedUpUser.ExpiryDate -lt ( Get-Date ) )
				{
					Print -Text "$( $msgTable.WExpiredPassword ) $( ( $LookedUpUser.ExpiryDate ).ToString( "yyyy-MM-dd" ) )"  -Color "Red"
					$status = $msgTable.WLExpiredPassword
					$syncHash.btnExtend.IsEnabled = $true
				}
				else
				{
					Print -Text "$( $msgTable.WFutureExpiry ) $( ( $LookedUpUser.ExpiryDate ).ToString( "yyyy-MM-dd" ) )."
					$syncHash.btnExtend.IsEnabled = $true
					$status = $msgTable.WLFutureExpiry
				}
			}
			else
			{
				Print -Text $msgTable.WNeverEndingPassword
				$status = $msgTable.WLNeverEndingPassword
			}

			if ( -not ( ( $LookedUpUser.accountExpires -eq 0 ) -or ( $LookedUpUser.accountExpires -eq 9223372036854775807 ) ) )
			{
				if ( ( [DateTime]::FromFileTime( $LookedUpUser.accountExpires ) ) -lt ( Get-Date ) )
				{
					Print -Text "$( $msgTable.WManualExpiryEnded ) $( ( [DateTime]::FromFileTime( $LookedUpUser.accountExpires ) ).ToString( "yyyy-MM-dd" ) )" -Color "Red"
					$status = $msgTable.WLManualExpiryEnded
				}
				else
				{
					Print -Text "$( $msgTable.WManualExpiry ) $( ( [DateTime]::FromFileTime( $LookedUpUser.accountExpires ) ).ToString( "yyyy-MM-dd" ) )"
					$status = $msgTable.WLManualExpiry
				}
			}
		}
		WriteLogTest -Text "LookUp, status: $status" -UserInput $syncHash.tbID.Text -Success $true -ErrorLogHash $eh | Out-Null
	}
	else
	{
		Print -Text "ID $( $syncHash.tbID.Text ) $( $msgTable.WNotFoundInAd )" -Color "Red"
	}
}

################################
# Extends password validity date
function Extend
{
	try
	{
		Set-ADUser -Identity $syncHash.tbID.Text -Replace @{ pwdLastSet = 0 }
		Set-ADUser -Identity $syncHash.tbID.Text -Replace @{ pwdLastSet = -1 }
		WriteLogTest -Text $msgTable.WPasswordExtended -UserInput $syncHash.tbID.Text -Success $true | Out-Null
		Print -Text $msgTable.WLPasswordExtended
	}
	catch
	{
		if ( $_.Exception.Message -eq "Insufficient access rights to perform the operation" ) { $severity = "PermissionFail" }
		else { $severity = "OtherFail" }

		$errorlog = WriteErrorLogTest -LogText "$( $msgTable.ErrLogExtendPassword )`n`n$_" -UserInput $syncHash.tbID.Text -Severity $severity
		WriteLogTest -Text $msgTable.ErrExtendPassword -UserInput $syncHash.tbID.Text -Success $false -ErrorLogPath $errorlog | Out-Null
		Print -Text "$( $msgTable.ErrLExtendPassword )`n`n$( $_.Exception.Message )`n`n" -Color "Red"
		ShowMessageBox -Text $msgTable.ErrMessageExtendPasswordPermission -Title "Error!" -Button "OK" -Icon "Error"
	}

	LookUpUser
}

###########################
# Unlocks an locked account
function Unlock
{
	try
	{
		Unlock-ADAccount $syncHash.tbID.Text -Confirm:$false
		WriteLogTest -Text  $msgTable.WUnlocked -UserInput $syncHash.tbID.Text -Success $true | Out-Null
		Print -Text $msgTable.WLUnlocked
	}
	catch
	{
		if ( $_.Exception.Message -eq "Insufficient access rights to perform the operation" ) { $severity = "PermissionFail" }
		else { $severity = "OtherFail" }

		$errorlog = WriteErrorLogTest -LogText "$( $msgTable.ErrLogUnlock )`n`n$_" -UserInput $syncHash.tbID.Text -Severity $severity
		WriteLog -Text $msgTable.ErrUnlock -UserInput $syncHash.tbID.Text -Success $false -ErrorlogPath $errorlog | Out-Null
		Print -Text "$( $msgTable.ErrLUnlock )`n`n$( $_.Exception.Message )" -Color "Red"
		ShowMessageBox -Text $msgTable.ErrMessageUnlockPermission -Title "Error!" -Button "OK" -Icon "Error"
	}

	LookUpUser
}

#############################
# Enables an disabled account
function Enable
{
	try
	{
		Enable-ADAccount $syncHash.tbID.Text -Confirm:$false
		WriteLogTest -Text $msgTable.WActivate -UserInput $syncHash.tbID.Text -Success $true | Out-Null
		Print -Text $msgTable.WLActivate
	}
	catch
	{
		if ( $_.Exception.Message -eq "Insufficient access rights to perform the operation" ) { $severity = "PermissionFail" }
		else { $severity = "OtherFail" }

		$errorlog = WriteErrorLogTest -LogTex "$( $msgTable.ErrLogActivate )`n`n$_" -UserInput $syncHash.tbID.Text -Severity $severity
		WriteLogTest -Text $msgTable.ErrActivate -UserInput $syncHash.tbID.Text -Success $false -ErrorlogPath $errorlog | Out-Null
		Print -Text "$( $msgTable.ErrMessageActivate )`n`n$( $_.Exception.Message )." -Color "Red"
		ShowMessageBox -Text $msgTable.ErrMessageActivatePermission -Title "Error!" -Button "OK" -Icon "Error"
	}

	LookUpUser
}

###################################
# Prints information to a new label
function Print
{
	param ( $Text, $Color = "Green" )

	$tbOutput = New-Object System.Windows.Controls.TextBlock
	$tbOutput.Foreground = $Color
	$tbOutput.Margin = "10,5,0,5"
	$tbOutput.Text = "$( Get-Date -Format 'HH:mm:ss' ) $Text"
	$tbOutput.TextWrapping = "WrapWithOverflow"
	$syncHash.spOutput.AddChild( $tbOutput )
	$syncHash.spOutput.UpdateLayout()
}

############################### Script start
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force -ArgumentList $args[1]

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "btnActivate" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnActivate } ) } )
[void]$controls.Add( @{ CName = "btnCancel" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnCancel } ) } )
[void]$controls.Add( @{ CName = "btnExtend" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnExtend } ) } )
[void]$controls.Add( @{ CName = "btnUnlock" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnUnlock } ) } )
[void]$controls.Add( @{ CName = "lblID" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblID } ) } )
[void]$controls.Add( @{ CName = "Window" ; Props = @( @{ PropName = "Title"; PropVal = $msgTable.ContentWindow } ) } )

$syncHash = CreateWindowExt $controls

$syncHash.tbID.Add_TextChanged( {
	if ( ( ( $syncHash.tbID.Text.Length -eq 4 ) -or ( $syncHash.tbID.Text -match $msgTable.CodeIdRegEx ) ) -and ( $syncHash.tbID.Text -ne $msgTable.CodeIdMatch ) ) { LookUpUser }
	else { $syncHash.spOutput.Children.Clear() }
} )
$syncHash.btnExtend.Add_Click( { Extend } )
$syncHash.btnUnlock.Add_Click( { Unlock } )
$syncHash.btnActivate.Add_Click( { Enable } )
$syncHash.btnCancel.Add_Click( { $syncHash.spOutput.Children.Clear() ; $syncHash.tbID.Text = "" } )
$syncHash.Window.Add_ContentRendered( { $syncHash.Window.Top = 80; $syncHash.Window.Activate() ; $syncHash.tbID.Focus() } )

[void] $syncHash.Window.ShowDialog()
$syncHash.Window.Close()
#$global:syncHash = $syncHash
