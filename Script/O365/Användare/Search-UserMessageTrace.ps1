<#
.Synopsis Get mail messagetrace to and/or from specified user
.Description Do a messagetrace in Office365 from a given sender and/or receiver. Start and End-dates can be specified
#>

function Export
{
	( [powershell]::Create().AddScript( { param ( $syncHash )
		$excel = New-Object -ComObject excel.application 
		$excel.visible = $false
		$excelWorkbook = $excel.Workbooks.Add()
		$excelWorksheet = $excelWorkbook.ActiveSheet

		$OutputEncoding = ( New-Object System.Text.UnicodeEncoding $False, $False ).psobject.BaseObject
		$syncHash.Data.Trace.Received | clip
		$excelWorksheet.Cells.Item( 1, 1 ).PasteSpecial() | Out-Null
		$syncHash.Data.Trace.SenderAddress | clip
		$excelWorksheet.Cells.Item( 2, 2 ).PasteSpecial() | Out-Null
		$syncHash.Data.Trace.RecipientAddress | clip
		$excelWorksheet.Cells.Item( 2, 3 ).PasteSpecial() | Out-Null
		$syncHash.Data.Trace.Subject | clip
		$excelWorksheet.Cells.Item( 2, 4 ).PasteSpecial() | Out-Null
		$syncHash.Data.Trace.Status | clip
		$excelWorksheet.Cells.Item( 2, 5 ).PasteSpecial() | Out-Null

		$excelWorksheet.Cells.Item( 1, 1 ) = "Receivedate"
		$excelWorksheet.Cells.Item( 1, 2 ) = "SenderAddress"
		$excelWorksheet.Cells.Item( 1, 3 ) = "RecipientAddress"
		$excelWorksheet.Cells.Item( 1, 4 ) = "Subject"
		$excelWorksheet.Cells.Item( 1, 5 ) = "Status"

		$range = $excelWorksheet.Range( $excelWorksheet.Cells.Item( 2, 1 ), $excelWorksheet.Cells.Item( $syncHash.Data.Trace.Count + 1, 1 ) )
		$range.NumberFormat = $syncHash.Data.msgTable.StrExportDateFormat

		$excelRange = $excelWorksheet.UsedRange
		$excelRange.EntireColumn.AutoFit() | Out-Null
		$excelWorksheet.ListObjects.Add( 1, $excelWorksheet.Range( $excelWorksheet.Cells.Item( 1, 1 ), $excelWorksheet.Cells.Item( $excelWorksheet.usedrange.rows.count, 5 ) ), 0, 1 ) | Out-Null
		$excelWorkbook.SaveAs( $syncHash.Data.FileToSave.FileName )
		$excelWorkbook.Close()
		$excel.Quit()

		[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excelRange ) | Out-Null
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excelWorksheet ) | Out-Null
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excelWorkbook ) | Out-Null
		[System.Runtime.Interopservices.Marshal]::ReleaseComObject( $excel ) | Out-Null
		[System.GC]::Collect()
		[System.GC]::WaitForPendingFinalizers()
		Remove-Variable excel
	} ).AddArgument( $syncHash ) ).BeginInvoke()
}

function ValidateInput
{
	if ( $null -ne $syncHash.Data.SenderEmail -or $null -ne $syncHash.Data.ReceiverEmail ) { $syncHash.DC.btnSearch[1] = $true }
	else { $syncHash.DC.btnSearch[1] = $false }
}

##################### Scriptstart
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force
Import-Module "$( $args[0] )\Modules\GUIOps.psm1" -Force
Import-Module "$( $args[0] )\Modules\ConsoleOps.psm1" -Force

$controls = New-Object System.Collections.ArrayList
[void]$controls.Add( @{ CName = "btnExport" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnExport } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "btnReset" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnReset } ) } )
[void]$controls.Add( @{ CName = "btnSearch" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentbtnSearch } ; @{ PropName = "IsEnabled" ; PropVal = $false } ) } )
[void]$controls.Add( @{ CName = "dpEnd" ; Props = @( @{ PropName = "SelectedDate"; PropVal = Get-Date } ) } )
[void]$controls.Add( @{ CName = "dpStart" ; Props = @( @{ PropName = "SelectedDate"; PropVal = ( Get-Date ).AddDays( -10 ) } ) } )
[void]$controls.Add( @{ CName = "lblEnd" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblEnd } ) } )
[void]$controls.Add( @{ CName = "lblReceiver" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblReceiver } ) } )
[void]$controls.Add( @{ CName = "lblSender" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblSender } ) } )
[void]$controls.Add( @{ CName = "lblStart" ; Props = @( @{ PropName = "Content"; PropVal = $msgTable.ContentlblStart } ) } )
[void]$controls.Add( @{ CName = "lvResult" ; Props = @( @{ PropName = "ItemsSource"; PropVal = [System.Collections.ObjectModel.ObservableCollection[Object]]::new( ) } ) } )

$syncHash = CreateWindowExt $controls
$syncHash.Data.msgTable = $msgTable

$syncHash.dpEnd.DisplayDateEnd = Get-Date
$syncHash.dpEnd.DisplayDateStart = ( Get-Date ).Date.AddDays( -10 )
$syncHash.dpStart.DisplayDateEnd = Get-Date
$syncHash.dpStart.DisplayDateStart = ( Get-Date ).Date.AddDays( -10 )

$syncHash.tbSender.Add_TextChanged( {
	if ( $this.Text -match "^\S{1,}@\S{2,}\.\S{2,}$" )
	{
		$syncHash.Data.SenderEmail = $this.Text
	}
	else { $syncHash.Data.SenderEmail = $null }
	ValidateInput
} )
$syncHash.tbReceiver.Add_TextChanged( {
	if ( $this.Text -match "^\S{1,}@\S{2,}\.\S{2,}$" )
	{
		$syncHash.Data.ReceiverEmail = $this.Text
	}
	else { $syncHash.Data.ReceiverEmail = $null }
	ValidateInput
} )

$syncHash.dpEnd.Add_KeyDown( {
	if ( $args[1].Key -eq "Escape" ) { $this.SelectedDate = Get-Date }
	ValidateInput
} )
$syncHash.dpEnd.Add_LostFocus( {
	if ( $null -eq $this.SelectedDate ) { $this.SelectedDate = Get-Date }
	ValidateInput
} )

$syncHash.dpStart.Add_SelectedDateChanged( { ValidateInput } )
$syncHash.dpStart.Add_KeyDown( {
	if ( $args[1].Key -eq "Escape" ) { $this.SelectedDate = ( Get-Date ).AddDays( -10 ) }
	ValidateInput
} )
$syncHash.dpStart.Add_LostFocus( {
	if ( $null -eq $this.SelectedDate ) { $this.SelectedDate = ( Get-Date ).AddDays( -10 ) }
	ValidateInput
} )

$syncHash.btnExport.Add_Click( {
	$dialogFileName = $syncHash.Data.msgTable.StrExportDefaultFileName
	if ( $syncHash.Data.SenderEmail -ne $null ) { $dialogFileName += " $( $syncHash.Data.msgTable.StrExportFileNameFrom ) $( $syncHash.Data.SenderEmail )" }
	if ( $syncHash.Data.ReceiverEmail -ne $null ) { $dialogFileName += " $( $syncHash.Data.msgTable.StrExportFileNameFo ) $( $syncHash.Data.ReceiverEmail )" }
	$dialogFileName += " $( $syncHash.Data.msgTable.StrExportFileNameDates ) $( $syncHash.DC.dpStart[0].ToShortDateString() ) - $( $syncHash.DC.dpEnd[0].ToShortDateString() )"

	$fileDialog = [Microsoft.Win32.SaveFileDialog]@{ DefaultExt = ".xlsx"; Filter = "Excel-files | *.xlsx" ; FileName = $dialogFileName }
	if ( $fileDialog.ShowDialog() )
	{
		$syncHash.Data.FileToSave = $fileDialog
		Export
	}
} )
$syncHash.btnReset.Add_Click( {
	$syncHash.tbSender.Text = ""
	$syncHash.tbReceiver.Text = ""
	$syncHash.DC.dpStart[0] = $null
	$syncHash.DC.dpEnd[0] = $null
	$syncHash.Data.Trace.Clear()
	$syncHash.DC.lvResult[0].Clear()
} )
$syncHash.btnSearch.Add_Click( {
	$syncHash.Data.Trace.Clear()
	$syncHash.DC.lvResult[0].Clear()
	$param = @{}
	if ( $syncHash.Data.SenderEmail -ne $null ) { $param.SenderAddress = $syncHash.Data.SenderEmail }
	if ( $syncHash.Data.ReceiverEmail -ne $null ) { $param.RecipientAddress = $syncHash.Data.ReceiverEmail }
	if ( $syncHash.Data.StartDate -ne $null ) { $param.StartDate = $syncHash.Data.StartDate } else { $param.StartDate = ( Get-Date ).AddDays( -10 ) }
	if ( $syncHash.Data.EndDate -ne $null ) { $param.EndDate = $syncHash.Data.EndDate } else { $param.EndDate = ( Get-Date ) }

	$syncHash.Data.Trace = Get-MessageTrace @param
	$syncHash.Data.Trace | Select-Object `
		@{ Name = "Received" ; Expression = { "$( $syncHash.data.Trace[0].Received.ToShortDateString() ) $( $syncHash.data.Trace[0].Received.ToShortTimeString() )" } }, `
		SenderAddress, RecipientAddress, Subject, MessageTraceId | Foreach-Object {
		$item = [System.Windows.Controls.ListViewItem]@{ Content = $_ }
		$item.ToolTip = "Message Trace ID: $( $_.MessageTraceID )"
		$syncHash.DC.lvResult[0].Add( $item )
	}
	TextToSpeech -Text ( $syncHash.Data.msgTable.StrDone )
	$syncHash.DC.btnExport[1] = $syncHash.Data.Trace.Count -gt 0
} )

$syncHash.Window.Add_Loaded( { $syncHash.tbSender.Focus() ; $syncHash.tbReceiver.Text = "carl.franzen@sll.se" } )

[void] $syncHash.Window.ShowDialog()
#$global:syncHash = $syncHash
