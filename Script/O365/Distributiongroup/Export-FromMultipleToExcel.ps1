<#
.Synopsis Exports members from multiple distributiongroups to an Excel-file
.Description Get a list of distributiongroupaddresses from clipboard, then gets its Exchange-object and members. This is then entered in an Exchel-file, each distributiongroup is entered in a separate worksheet. The file is then saved in the Output-folder for the user.
.State Prod
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force

$syncHash = [hashtable]::Synchronized( @{} )
$syncHash.Win = [System.Windows.Window]@{ SizeToContent = "WidthAndHeight" }
$syncHash.Grid = [System.Windows.Controls.Grid]@{ }
$syncHash.GridColDef1 = [System.Windows.Controls.ColumnDefinition]@{ MinWidth = "400" }
$syncHash.GridColDef2 = [System.Windows.Controls.ColumnDefinition]@{ Width = "500*"; MinWidth = 500; MaxWidth = 500 }
$syncHash.GridRowDef1 = [System.Windows.Controls.RowDefinition]@{ Height = 30 }
$syncHash.GridRowDef2 = [System.Windows.Controls.RowDefinition]@{ Height = "1*" }
$syncHash.Grid.ColumnDefinitions.Add( $syncHash.GridColDef1 )
$syncHash.Grid.ColumnDefinitions.Add( $syncHash.GridColDef2 )
$syncHash.Grid.RowDefinitions.Add( $syncHash.GridRowDef1 )
$syncHash.Grid.RowDefinitions.Add( $syncHash.GridRowDef2 )

$syncHash.DataGrid = [System.Windows.Controls.DataGrid]@{ RowHeight = 25 }
$syncHash.DataGrid.Columns.Add( [System.Windows.Controls.DataGridTextColumn]@{ Header = $msgTable.ContentDgC1Header; Binding = [System.Windows.Data.Binding]@{ Path = "Address" } } )
$syncHash.DataGrid.Columns.Add( [System.Windows.Controls.DataGridTextColumn]@{ Header = $msgTable.ContentDgC2Header; Binding = [System.Windows.Data.Binding]@{ Path = "MemCount" } } )
$syncHash.ExportButton = [System.Windows.Controls.Button]@{ Content = $msgTable.ContentbtnExport }
$syncHash.ImportButton = [System.Windows.Controls.Button]@{ Content = $msgTable.ContentbtnImport; ToolTip = $msgTable.ContentbtnImportToolTip }
$syncHash.SP = [System.Windows.Controls.StackPanel]@{}

# Add controls to grid and set column and row
@( $syncHash.DataGrid, 0, 1 ), @( $syncHash.ImportButton, 0, 0 ), @( $syncHash.ExportButton, 1, 0 ), @( $syncHash.SP, 1, 1 ) | ForEach-Object { $syncHash.Grid.AddChild( $_[0] ) ; [System.Windows.Controls.Grid]::SetColumn( $_[0], $_[1] ) ; [System.Windows.Controls.Grid]::SetRow( $_[0], $_[2] ) }

$syncHash.Win.Content = $syncHash.Grid

$syncHash.DistGroups = New-Object System.Collections.ArrayList
$syncHash.NotFound = New-Object System.Collections.ArrayList
$syncHash.msgTable = $msgTable
$syncHash.BaseDir = $args[0]

$syncHash.ExportButton.Add_Click( {
	$excel = New-Object -ComObject excel.application 
	$excel.visible = $false
	$excelWorkbook = $excel.Workbooks.Add()

	$ticker = 1
	#Iterate through all groups, one at a time
	foreach ( $group in $syncHash.DistGroups )
	{
		#Get members of this group
		#region Create worksheet
		if ( $ticker -eq 1 ) { $excelTempsheet = $excelWorkbook.ActiveSheet }
		else { $excelTempsheet = $excelWorkbook.Worksheets.Add() }

		$tempname = $group.Group.DisplayName -replace "\\", "_" -replace "/", "_" -replace "\*", "_" -replace "\[", "_" -replace "]", "_" -replace ":", "_" -replace "\?", "_"

		if ( $tempname.Length -gt 31 )
		{
			try { $excelTempsheet.Name = $tempname.SubString( 0, 31 ) }
			catch { $excelTempsheet.Name = $group.Group.PrimarySMTPAddress.SubString( 0, 31 ) }
		} else {
			$excelTempsheet.Name = $tempname
		}
		#endregion

		#region Add Members
		$row = 1
		$excelTempsheet.Cells.Item( $row, 1 ) = $syncHash.msgTable.StrSSTitleName
		$excelTempsheet.Cells.Item( $row, 2 ) = $group.Group.DisplayName
		$row = 2
		$excelTempsheet.Cells.Item( $row, 1 ) = $syncHash.msgTable.StrSSTitleAddress
		$excelTempsheet.Cells.Item( $row, 2 ) = $group.Group.PrimarySMTPAddress
		$row = 3
		$excelTempsheet.Cells.Item( $row, 1 ) = $syncHash.msgTable.StrSSTitleOwner
		1..3 | Foreach-Object { $excelTempsheet.Cells.Item( $_, 1 ).Font.Bold = $true }

		if ( @( $group.Group.ManagedBy ).Count -eq 0 )
		{
			$excelTempsheet.Cells.Item( $row, 2 ) = $syncHash.msgTable.StrNoOwner
			$row = $row + 1
		}
		else
		{
			foreach ( $owner in $group.Group.ManagedBy )
			{
				if ( $owner -like "*MIG-User*" ) { $excelTempsheet.Cells.Item( $row, 2 ) = $syncHash.msgTable.StrNoOwner }
				else { $excelTempsheet.Cells.Item( $row, 2 ) = $owner }
				$row = $row + 1
			}
		}

		$row = $row + 1
		$excelTempsheet.Cells.Item( $row, 1 ) = $syncHash.msgTable.StrSSTitleMembers
		$startTableRow = $row
		$excelTempsheet.Cells.Item( $row, 2 ) = $syncHash.msgTable.StrSSTitleMemAddr

		$row = $row + 1
		$memberArray = @()
		$memberMailArray = @()
		if ( @( $group.Members ).Count -eq 0 )
		{
			$memberArray += $syncHash.msgTable.StrNoMembers
			$memberMailArray += "-"
		}
		else
		{
			foreach ( $member in $group.Members )
			{
				$memberArray += $member.Name
				$memberMailArray += $member.PrimarySMTPAddress
			}
		}
		Set-Clipboard -Value $memberArray
		$excelTempsheet.Cells.Item( $row, 1 ).PasteSpecial() | Out-Null
		Set-Clipboard -Value $memberMailArray
		$excelTempsheet.Cells.Item( $row, 2 ).PasteSpecial() | Out-Null
		$excelRange = $excelTempsheet.UsedRange
		$excelRange.EntireColumn.AutoFit() | Out-Null
		$excelTempsheet.ListObjects.Add( 1, $excelTempsheet.Range( $excelTempsheet.Cells.Item( $startTableRow, 1 ), $excelTempsheet.Cells.Item( $excelTempsheet.usedrange.rows.count, 2 ) ), 0, 1 ) | Out-Null
		#endregion Add Members
		$ticker = $ticker + 1
	}

	if ( @( $syncHash.NotFound ).Count -gt 0 )
	{
		$excelTempsheet = $excelWorkbook.Worksheets.Add()
		$excelTempsheet.Name = $syncHash.msgTable.StrSSNotFound
		$row = 2
		$excelTempsheet.Cells.Item( $row, 1 ) = $syncHash.msgTable.StrNotFound
		$excelTempsheet.Cells.Item( $row, 1 ).Font.Bold = $true
		$row = $row + 1
		foreach ( $name in $syncHash.NotFound )
		{
			$excelTempsheet.Cells.Item( $row, 1 ) = $name
			$row = $row + 1
		}
		$excelRange = $excelTempsheet.UsedRange
		$excelRange.EntireColumn.AutoFit() | Out-Null
		$excelTempsheet.ListObjects.Add( 1, $excelTempsheet.Range( $excelTempsheet.Cells.Item( 2, 1 ), $excelTempsheet.Cells.Item( $excelTempsheet.usedrange.rows.count + 1, 1 ) ), 0, 1 ) | Out-Null
	}

	$syncHash.FilePath = "$( $syncHash.BaseDir )\Output\$( $env:USERNAME )\$( $syncHash.Data.msgTable.StrFileNamePrefix ) ($( Get-Date -f "yyyy-MM-dd HH.mm.ss" )).xlsx"
	$excelWorkbook.SaveAs( $syncHash.FilePath )
	$excelWorkbook.Close()
	$excel.Quit()

	[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excelRange ) | Out-Null
	[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excelTempsheet ) | Out-Null
	[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excelWorkbook ) | Out-Null
	[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excel ) | Out-Null
	[System.GC]::Collect()
	[System.GC]::WaitForPendingFinalizers()
	Remove-Variable excel

	$tb = [System.Windows.Controls.TextBlock]@{ Text = "$( $syncHash.msgTable.StrExportDone )`n$( $syncHash.FilePath )"; Foreground = "Green"; TextWrapping = "Wrap"; Margin = 5 }
	$tb.Add_MouseLeftButtonUp( { $syncHash.FilePath | clip ; ShowSplash -Text $syncHash.msgTable.StrPathCopied } )
	$syncHash.SP.AddChild( $tb )
} )

# Verify if distributiongroup exists, if so get object and members
$syncHash.ImportButton.Add_Click( {
	Get-Clipboard | Where-Object { $_ } | ForEach-Object {
		$a = $_
		try
		{
			$g = Get-DistributionGroup -Identity $_ -ErrorAction Stop
			$o = [pscustomobject]@{ Group = $g; Members = ( Get-DistributionGroupMember -Identity $a ) }
			$syncHash.DistGroups.Add( $o )
			$syncHash.DataGrid.AddChild( [pscustomobject]@{ "Address" = $g.DisplayName; "MemCount" = @( $o.Members ).Count } )
		}
		catch
		{
			$syncHash.NotFound.Add( $a )
		}
	}

	if ( $syncHash.NotFound.Count -gt 0 ) { $syncHash.SP.AddChild( ( [System.Windows.Controls.TextBlock]@{ Text = "$( $msgTable.StrNotFound )`n$( $ofs = "`n"; [string] $syncHash.NotFound )"; Foreground = "Red"; TextWrapping = "WrapWithOverflow"; Margin = 5 } ) ) }
} )

[void] $syncHash.Win.ShowDialog()
$global:syncHash = $syncHash
