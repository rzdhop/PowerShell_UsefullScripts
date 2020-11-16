#Requires -RunAsAdministrator
#script parameters
param(
    [string]$IP = $null,
    [switch]$local,
    [switch]$AutoDNS,
    [switch]$verbose,
    [switch]$v
)
Write-Host `n
Set-ExecutionPolicy Unrestricted -Scope Process

$errorCol = @{ForegroundColor = "black"; BackgroundColor = "red"}
$verboseCol = @{ForegroundColor = "white"; BackgroundColor = "DarkBlue"}
$normCol = @{ForegroundColor = "green"}

if ($verbose -or $v) {
    $v = $true
}
if ($IP -eq "" -and -not $local) {Write-Host "Use the script like that : `n ./script.ps1 <IP(string) | local> (optional)<-v | -verbose>  (optional)-AutoDNS `n -local : Set your actual IP to static (don't change it) `n -v | -verbose : Dispay more info during the process `n -AutoDNS : Set the DNS server to Google server(Default = Gateway)"; Exit}

function CheckIPv4Pattern { #check a string using a regex 
    param(
        [string]$IP_loc
    )
    $IPv4regex = "^([1-2]?[0-9]{2}|[1-9])\.([1-2]?[0-9]{2}|[1-9]|0)\.([1-2]?[0-9]{2}|[1-9]|0)\.([1-2]?[0-9]{2}|[1-9])$" 
    if ($IP_loc -match $IPv4regex){
        return $true
    } else {return $false}
}

if ($(CheckIPv4Pattern $IP) -eq $false -and -not $local) {
    Write-Host "Invalid IP format given $IP is not a valid IP address !" @errorCol
    Exit
}

#if retreiving of the IP address failed using the Wi-Fi default InterfaceAlias try by asking to the user an Interface index to select the choosen interface
Write-Host "Here Write the InterfaceIndex of your Network Interface.`n Loading Adapters...`n " @normCol
Get-NetAdapter
$InterfaceIndex = Read-Host -Prompt 'InterfaceIndex ' 

#try with the new interface (if fail ==> exit)
$ActualIPv4 = Get-NetIPAddress | Where-Object {$_.InterfaceIndex -eq $InterfaceIndex -and $_.AddressFamily -eq 'IPv4'} | Select-Object -ExpandProperty IPAddress
if (CheckIPv4Pattern $ActualIPv4){
    Write-Host "Your actual addresses : `n IPv4 : $ActualIPv4 " @verboseCol
}else {
    if ($v){Write-Host "Impossible to retreive IP addresses " "IP retreived : $ActualUPV4" @errorCol} 
    else {Write-Host "Impossible to retreive IP addresses" @errorCol}
    Exit
}

if ($v){Write-Host "Gatherring network adapter info's...`n" @normCol}
if ($local){
    $IPAddress = $ActualIPv4
 }else {$IPAddress = $IP}
[string]$DfltGateway = Get-NetIPConfiguration | Where-Object {$_.InterfaceIndex -eq $InterfaceIndex} | Select-Object -ExpandProperty IPv4DefaultGateway | Select-Object -ExpandProperty Nexthop
$prfxLen = Get-NetIPAddress | Where-Object {$_.InterfaceIndex -eq $InterfaceIndex -and $_.AddressFamily -eq 'IPv4'} | Select-Object -ExpandProperty PrefixLength

if ($v){Write-Host "Setting network adapter info's...`n" @normCol}
$IPAdap_Info = @{
    InterfaceIndex = $InterfaceIndex
    IPAddress = $IPAddress
    PrefixLength = $prfxLen
    DefaultGateway = $DfltGateway
}
if ($v){Write-Host "Setting network adapter to desired static IP: $IPAddress" @normCol}
try{
    Set-NetIPInterface -InterfaceIndex $InterfaceIndex -DHCP Disabled
}catch {continue}

New-NetIPAddress @IPAdap_Info
if($AutoDNS){
    if ($v){Write-Host "Setting the DNS server to google's DNS ('8.8.8.8'...)" @normCol}
    Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ServerAddresses ("8.8.8.8,8.8.4.4")
}else{
    if ($v){Write-Host "Setting DNS server to default value (Default Gateway)" @normCol}
    Set-DnsClientServerAddress -InterfaceIndex $InterfaceIndex -ServerAddresses $DfltGateway
}

Write-Host `n "Porcess Exited succesfully! "`n  @normCol
