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
	$syncHash.LookedUpUser = $null

	try
	{
		$syncHash.LookedUpUser = Get-ADUser $syncHash.tbID.Text –Properties pwdlastset, enabled, lockedout, description, accountExpires, msDS-UserPasswordExpiryTimeComputed -ErrorAction Stop | Select-Object Name, pwdlastset, enabled, lockedout, description, accountExpires, @{ Name = "ExpiryDate"; Expression = { [datetime]::FromFileTime( $_."msDS-UserPasswordExpiryTimeComputed" ) } }, DistinguishedName

		$syncHash.spOutput.Children.Clear()
		Print -Text "$( $syncHash.msgTable.StrReadUser ) $( $syncHash.LookedUpUser.Name )"

		if ( ( $syncHash.LookedUpUser.Description -match "$( $syncHash.msgTable.StrDoNotActivate )" ) )
		{
			Print -Text $syncHash.msgTable.StrUserBlocked -Color "Red"
			$status = $syncHash.msgTable.LogBlockedUser
		}
		else
		{
			if ( $syncHash.LookedUpUser.Enabled -eq $false )
			{
				Print -Text $syncHash.msgTable.StrUserDisabled -Color "Red"
				$status = $syncHash.msgTable.LogDisabledUser
				$syncHash.btnActivate.IsEnabled = $true
			}

			if ( $syncHash.LookedUpUser.LockedOut -eq $true )
			{
				Print -Text $syncHash.msgTable.StrLocked -Color "Red"
				$status = $syncHash.msgTable.LogLocked
				$syncHash.btnUnlock.IsEnabled = $true
			}

			if ( ( $syncHash.LookedUpUser.Enabled -eq $true ) -and ( $syncHash.LookedUpUser.LockedOut -eq $false ) )
			{
				Print -Text $syncHash.msgTable.StrUserActive
				$status = $syncHash.msgTable.StrActive
			}

			if ( $syncHash.LookedUpUser.pwdlastset -eq 0 )
			{
				Print -Text $syncHash.msgTable.StrPasswordChange -Color "Red"
				$status = $syncHash.msgTable.LogPasswordChange
			}
			elseif ( $null -ne $syncHash.LookedUpUser.ExpiryDate )
			{
				if ( $syncHash.LookedUpUser.ExpiryDate -lt ( Get-Date ) )
				{
					Print -Text "$( $syncHash.msgTable.StrExpiredPassword ) $( ( $syncHash.LookedUpUser.ExpiryDate ).ToString( "yyyy-MM-dd" ) )"  -Color "Red"
					$status = $syncHash.msgTable.LogExpiredPassword
					$syncHash.btnExtend.IsEnabled = $true
				}
				else
				{
					Print -Text "$( $syncHash.msgTable.StrFutureExpiry ) $( ( $syncHash.LookedUpUser.ExpiryDate ).ToString( "yyyy-MM-dd" ) )."
					$syncHash.btnExtend.IsEnabled = $true
					$status = $syncHash.msgTable.LogFutureExpiry
				}
			}
			else
			{
				Print -Text $syncHash.msgTable.StrNeverEndingPassword
				$status = $syncHash.msgTable.LogNeverEndingPassword
			}

			if ( -not ( ( $syncHash.LookedUpUser.accountExpires -eq 0 ) -or ( $syncHash.LookedUpUser.accountExpires -eq 9223372036854775807 ) ) )
			{
				if ( ( [DateTime]::FromFileTime( $syncHash.LookedUpUser.accountExpires ) ) -lt ( Get-Date ) )
				{
					Print -Text "$( $syncHash.msgTable.StrManualExpiryEnded ) $( ( [DateTime]::FromFileTime( $syncHash.LookedUpUser.accountExpires ) ).ToString( "yyyy-MM-dd" ) )" -Color "Red"
					$status = $syncHash.msgTable.LogManualExpiryEnded
				}
				else
				{
					Print -Text "$( $syncHash.msgTable.StrManualExpiry ) $( ( [DateTime]::FromFileTime( $syncHash.LookedUpUser.accountExpires ) ).ToString( "yyyy-MM-dd" ) )"
					$status = $syncHash.msgTable.LogManualExpiry
				}
			}
		}
		WriteLogTest -Text "LookUp, status: $status" -UserInput $syncHash.tbID.Text -Success $true -ErrorLogHash $eh | Out-Null
	}
	catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
	{
		Print -Text "ID $( $syncHash.tbID.Text ) $( $syncHash.msgTable.StrNotFoundInAd )" -Color "Red"
		WriteErrorlogTest -LogText $_.Exception.Message -UserInput $syncHash.tbID.Text -Severity "OtherFail"
	}
	catch
	{
		WriteErrorlogTest -LogText $_.Exception.Message -UserInput $syncHash.tbID.Text -Severity "OtherFail"
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
		WriteLogTest -Text $syncHash.msgTable.LogPasswordExtended -UserInput $syncHash.tbID.Text -Success $true | Out-Null
		Print -Text $syncHash.msgTable.StrPasswordExtended
	}
	catch
	{
		if ( $_.Exception.Message -eq "Insufficient access rights to perform the operation" ) { $severity = "PermissionFail" }
		else { $severity = "OtherFail" }

		$errorlog = WriteErrorLogTest -LogText "$( $syncHash.msgTable.ErrLogExtendPassword )`n`n$_" -UserInput $syncHash.tbID.Text -Severity $severity
		WriteLogTest -Text $syncHash.msgTable.LogErrExtendPassword -UserInput $syncHash.tbID.Text -Success $false -ErrorLogPath $errorlog | Out-Null
		Print -Text "$( $syncHash.msgTable.ErrMsgExtendPassword )`n`n$( $_.Exception.Message )`n`n" -Color "Red"
		if ( $syncHash.LookedUpUser.DistinguishedName -match $syncHash.msgTable.CodeOuSpecDep )
		{ ShowMessageBox -Text $syncHash.msgTable.ErrMsgExtendPasswordPermissionSpecDep -Title "Error!" -Button "OK" -Icon "Error" }
		else
		{ ShowMessageBox -Text $syncHash.msgTable.ErrMsgExtendPasswordPermission -Title "Error!" -Button "OK" -Icon "Error" }
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
		WriteLogTest -Text  $syncHash.msgTable.LogUnlocked -UserInput $syncHash.tbID.Text -Success $true | Out-Null
		Print -Text $syncHash.msgTable.StrUnlocked
	}
	catch
	{
		if ( $_.Exception.Message -eq "Insufficient access rights to perform the operation" ) { $severity = "PermissionFail" }
		else { $severity = "OtherFail" }

		$errorlog = WriteErrorLogTest -LogText "$( $syncHash.msgTable.ErrLogUnlock )`n`n$_" -UserInput $syncHash.tbID.Text -Severity $severity
		WriteLogTest -Text $syncHash.msgTable.LogErrUnlock -UserInput $syncHash.tbID.Text -Success $false -ErrorlogPath $errorlog | Out-Null
		Print -Text "$( $syncHash.msgTable.ErrMsgUnlock )`n`n$( $_.Exception.Message )" -Color "Red"
		if ( $syncHash.LookedUpUser.DistinguishedName -match $syncHash.msgTable.CodeOuSpecDep )
		{ ShowMessageBox -Text $syncHash.msgTable.ErrMsgUnlockPermissionSpecDep -Title "Error!" -Button "OK" -Icon "Error" }
		else
		{ ShowMessageBox -Text $syncHash.msgTable.ErrMsgUnlockPermission -Title "Error!" -Button "OK" -Icon "Error" }
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
		WriteLogTest -Text $syncHash.msgTable.LogActivated -UserInput $syncHash.tbID.Text -Success $true | Out-Null
		Print -Text $syncHash.msgTable.StrActivated
	}
	catch
	{
		if ( $_.Exception.Message -eq "Insufficient access rights to perform the operation" ) { $severity = "PermissionFail" }
		else { $severity = "OtherFail" }

		$errorlog = WriteErrorLogTest -LogTex "$( $syncHash.msgTable.ErrLogActivate )`n`n$_" -UserInput $syncHash.tbID.Text -Severity $severity
		WriteLogTest -Text $syncHash.msgTable.LogErrActivate -UserInput $syncHash.tbID.Text -Success $false -ErrorlogPath $errorlog | Out-Null
		Print -Text "$( $syncHash.msgTable.ErrMsgActivate )`n`n$( $_.Exception.Message )." -Color "Red"
		if ( $syncHash.LookedUpUser.DistinguishedName -match $syncHash.msgTable.CodeOuSpecDep )
		{ ShowMessageBox -Text $syncHash.msgTable.ErrMsgActivatePermissionSpecDep -Title "Error!" -Button "OK" -Icon "Error" }
		else
		{ ShowMessageBox -Text $syncHash.msgTable.ErrMsgActivatePermission -Title "Error!" -Button "OK" -Icon "Error" }
	}

	LookUpUser
}

###################################
# Prints information to a new label
function Print
{
	param ( $Text, $Color = "Green" )

	$tbOutput = [System.Windows.Controls.TextBlock]@{ Foreground = $Color; Margin = "10,5,0,5"; Text = "$( Get-Date -Format 'HH:mm:ss' ) $Text"; TextWrapping = "WrapWithOverflow" }
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
$syncHash.msgTable = $msgTable

$syncHash.tbID.Add_TextChanged( {
	if ( ( ( $syncHash.tbID.Text.Length -eq 4 ) -or ( $syncHash.tbID.Text -match "^gai(kat|sys)\w{4}" ) ) -and ( $syncHash.tbID.Text -ne $syncHash.msgTable.CodeIdMatch ) ) { LookUpUser }
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
