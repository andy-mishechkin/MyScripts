<#
.SYNOPSIS
Script for checking the connection to specified TCP port.
 
.DESCRIPTION
Script for checking the connection to specified TCP port. Script will be used for scanning the open TCP ports.
 
.PARAMETER -hosts
tcphost names or IP adresses for port scanning (text array).
 
.PARAMETER -StartingPort
Port number, which will be used first in the port scanning. If this parameter is specified, script will try to connect to port number since StartingPort and will increase
port number till 50000 with step 1. This parameter shouldn't be used with '-Ports' parameter.
 
.PARAMETER -Ports
Ports, which will be scanned for connection. These ports should be specified through comma separator or as the range like "(StartingPort..EndingPort)" - be aware about brackets in this case.
This parameter shouldn't be used with'-StartingPort' parameter
 
.PARAMETER -RepeatConnection
Optional switch parameter. If this parameter specified, script will scan ports in range in loop. Scanning will continue till manual stop.
 
.PARAMETER -TcpTimeout
Optional parameter for Tcp timeout value
 
.EXAMPLE
PS> .\Connect-ToTcpPort -hosts 192.168.1.1 -StartingPort 22222
 
.EXAMPLE
PS> .\Connect-ToTcpPort -hosts 192.168.1.1, 192.168.1.2 -StartingPort 22222
 
.EXAMPLE
PS> .\Connect-ToTcpPort -hosts 192.168.1.1, 192.168.1.2 -Ports 23,80,443
 
.EXAMPLE
PS> .\Connect-ToTcpPort -hosts 192.168.1.1 -PortRange 9000-9010
#>

[CmdletBinding(SupportsShouldProcess=$True)]
Param(      
       [Parameter(Mandatory, ValueFromPipeline = $True)] [string[]]$hosts,
       [Parameter()] [int]$StartingPort,
       [Parameter()] [int[]]$Ports,
       [Parameter()] [switch]$RepeatConnection,
       [Parameter()] [int]$TcpTimeout=1000                                 
) 

$Script:Timestamp = Get-Date -Format MMddyyhhmmss
function Invoke-BeginConnect {
    Param(
        [Parameter(Mandatory)] [string] $tcphost,
        [Parameter(Mandatory)] [int] $tcpport
    )
    $logfile = "$($PWD.Path)\${tcphost}_${timestamp}_scanning.txt" 
    $openportsfile = "$($PWD.Path)\${tcphost}_${timestamp}_OpenPorts.txt" 
    $TCPConnected = $true
    $TCPClient = new-Object system.Net.Sockets.TcpClient
    $TCPConnection = $TCPClient.BeginConnect($tcphost,$tcpport,$null,$null)
    $TCPConnection.AsyncWaitHandle.WaitOne($Script:TcpTimeout, $false) > $null
    try {
        Write-Debug "Try to connect to port [$tcpport] on [$tcpost]"
        $TCPClient = new-Object system.Net.Sockets.TcpClient($tcphost,$tcpport)
    }
    catch {
        $TCPConnected = $false
        Write-Host "Connect to [${tcphost}:${tcpport}] - failed"
        Out-File $logfile -Append -Force -InputObject ("Connect to [${tcphost}:${tcpport}] - failed")
    }

    if ($TCPConnected) {
        Write-Host -ForegroundColor Yellow "[${tcphost}:${tcpport}] is open"
        Out-File $logfile -Append -Force -InputObject("[${tcphost}:${tcpport}] is open")
        Out-File $openportsfile -Append -Force -InputObject("[${tcphost}:${tcpport}] is open")
        $TCPClient.Close()
    }
}

if ($StartingPort -and $Ports) {
    Write-Error"[!]Error. You should specify 'StartingPort' or 'Ports' parameter only. Not both parameters together."
    break
}
elseif (-not ($StartingPort -or $Ports)) {
    Write-Error"[!]Error. You should specify 'StartingPort' or 'Ports' parameter."
    break
}

if ($StartingPort) {
    foreach($tcphost in $hosts) {
        for($tcpport = $StartingPort; $tcpport -le 50000; $tcpport++) {
            Invoke-BeginConnect -tcphost $tcphost -tcpport $tcpport
        }
    }
}
elseif ($Ports) {
    $hostCounter=0
    for(;;) {
        $tcphost = $hosts[$hostCounter]
        foreach($tcpport in $Ports) {
            Invoke-BeginConnect -tcphost $tcphost -tcpport $tcpport
        }
        if($hostCounter -eq ($hosts.Length - 1)) {
            if($RepeatConnection) {
                $hostCounter=0
            }
            else {
                break
            }
        }
        else {
            $hostCounter++
        }
    }
}