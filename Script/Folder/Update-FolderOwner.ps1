<#
.Synopsis Change owner of a folder on G:\
.Description Perform a shared folder ownership change on G:\.
.State Prod
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

do
{
	$Customer = Read-Host $msgTable.StrQOrg
	switch ( $Customer )
	{
		$msgTable.StrOrg1 { $GroupPrefix = $msgTable.CodeOrg1GrpPrefix }
		$msgTable.StrOrg2 { $GroupPrefix = $msgTable.CodeOrg2GrpPrefix }
		$msgTable.StrOrg3 { $GroupPrefix = $msgTable.CodeOrg3GrpPrefix }
		"Q" { $GroupPrefix = "Q" }
		default { Write-Host $msgTableStrInvalidOrgInput; $GroupPrefix = "" }
	}
}
until ( $GroupPrefix -ne "" )

if ( $GroupPrefix -eq "Q" )
{
	Write-Host $msgTable.StrAborting
	$logText = $msgTable.LogAbortingInit
}
else
{
	$NameInput = Read-Host $msgTable.StrQName
	if ( $NameInput -match "^G:\\$Customer" )
	{
		$TestPath = $NameInput
	}
	else
	{
		$Folder = $NameInput.Replace( " ", "_" ).Replace( "å", "a" ).Replace( "ä", "a" ).Replace( "ö", "o" )
		$ADFolder = $GroupPrefix + $Folder
		$TestPath = "G:\$Customer\$NameInput"
	}

	if ( Test-Path $TestPath )
	{
		$ReadOwner = Get-ADGroup ( $ADFolder + $msgTable.CodeAdNameReadSuffix ) -Properties ManagedBy | Select-Object -ExpandProperty ManagedBy
		$ChangeOwner = Get-ADGroup ( $ADFolder + $msgTable.CodeAdNameWriteSuffix ) -Properties ManagedBy | Select-Object -ExpandProperty ManagedBy

		if ( $null -eq $ReadOwner ) { $ReadOwner = Get-ADUser $ReadOwner | Select-Object -ExpandProperty Name }
		else { $ReadOwner = $msgTable.StrNoReadOwner }

		if ( $null -ne $ChangeOwner ) { $ChangeOwner = Get-ADUser $ChangeOwner | Select-Object -ExpandProperty Name }
		else { $ChangeOwner = $msgTable.StrNoWriteOwner }

		if ( $ReadOwner -ne $ChangeOwner )
		{
			Write-Host "'$Folder' $( $msgTable.StrDiffOwnerInfo1 )"
			Write-Host "$( $msgTable.StrDiffOwnerReadTitle ): $ReadOwner"
			Write-Host "$( $msgTable.StrDiffOwnerWriteTitle ): $ChangeOwner"
			Write-Host "`n`n$( $msgTable.StrDiffOwnerInfo2 ) $( $msgTable.StrInfoEnd )`n"
		}
		else
		{
			Write-Host "`n$( $msgTable.StrCurrOwnerInfo ) '$Folder':`n$ChangeOwner. $( $msgTable.StrInfoEnd )`n"
		}

		$id = Read-Host $msgTable.StrQNewOwner

		if ( $id -eq "Q" )
		{
			Write-Host $msgTable.StrAborting
			$logText = $msgTable.LogAbortingOwner
		}
		else
		{
			try
			{
				$NewOwner = Get-ADUser -Identity $id -Properties * -ErrorAction Stop
				if ( $NewOwner.Enabled )
				{
					Set-ADGroup ( $ADFolder + $msgTable.CodeAdNameReadSuffix ) -ManagedBy $NewOwner
					Set-ADGroup ( $ADFolder + $msgTable.CodeAdNameWriteSuffix ) -ManagedBy $NewOwner
					Write-Host "`n$( $msgTable.StrNewOwnerInfo ) $( $NewOwner.Name )`n"
					$logText = "$TestPath`n$( $NewOwner.Name ) "
				}
				else
				{
					Write-Host "$( $NewOwner.Name ) $( $msgTable.ErrMsgAdUserDisabled )"
					$logText = $msgTable.LogAdUserDisabled
					$eh = WriteErrorlogTest -LogText "$( $msgTable.ErrLogAdUserDisabled )`n$_" -UserInput $id -Severity "UserInputFail"
				}
			}
			catch
			{
				Write-Host $msgTable.ErrMsgNoAdUser
				$logText = $msgTable.LogAdUserNotFound
				$eh = WriteErrorlogTest -LogText "$( $msgTable.ErrLogAdUserNotFound )`n$_" -UserInput $id -Severity "UserInputFail"
			}
		}
	}
	else
	{
		Write-Host "$( $msgTable.ErrMsgPath ) '$TestPath'"
		$logText = "$TestPath $( $msgTable.ErrLogPath )"
	}
}

WriteLogTest -Text $logText -UserInput "$( $msgTable.StrCustomerInput ) $Customer`n$( $msgTable.StrOwnerInput ) $id" -Success ( $null -eq $eh ) -ErrorLogHash $eh | Out-Null
EndScript
