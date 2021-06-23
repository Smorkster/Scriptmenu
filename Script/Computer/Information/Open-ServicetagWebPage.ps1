<#
.Synopsis Open webpage for computer servicetag
.Description Gets the manufacturer and the computers servicetag, then opens the appropriate webpage. Use this to show the computers remaining warranty.
.Depends WinRM
.Author Smorkster (smorkster)
#>

Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force -ArgumentList $args[1]

$ComputerName = $args[2]

# Get remote servicetag.
$Vendor = wmic /node:$ComputerName csproduct get vendor
$Servicetag = (wmic /node:$ComputerName csproduct get identifyingnumber)[2].Trim()

# Open Google Chrome with manufacturer webpage for servicetag
if ( $Vendor -match "Dell" )
{
	$adress = "http://www.dell.com/support/my-support/se/sv/sebsdt1/product-support/servicetag/$Servicetag"
}
elseif ( $Vendor -match "Lenovo")
{
	$adress = "https://pcsupport.lenovo.com/us/en/products/$Servicetag"
}
Start-Process chrome.exe $adress

WriteLog -LogText "$ComputerName" | Out-Null
EndScript
