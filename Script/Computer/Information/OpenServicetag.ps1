#Description = Open webpage for computer servicetag
Import-Module "$( $args[0] )\Modules\FileOps.psm1" -Force

$ComputerName = $args[1]

$CaseNr = Read-Host "Related casenumber (if any) "
# Get remote servicetag.
$Vendor = wmic /node:$ComputerName csproduct get vendor
$Servicetag = ( wmic /node:$ComputerName csproduct get identifyingnumber )[2].Trim()

# Open Google Chrome with manufacturer webpage for servicetag
if ( $Vendor -match "Dell" )
{
	$adress = "http://www.dell.com/support/my-support/se/sv/sebsdt1/product-support/servicetag/$Servicetag"
}
elseif ( $Vendor -match "Lenovo" )
{
	$adress = "https://pcsupport.lenovo.com/us/en/products/$Servicetag"
}
Start-Process chrome.exe $adress

WriteLog -LogText "$CaseNr $ComputerName"

EndScript
