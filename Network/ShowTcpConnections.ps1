<#
.SYNOPSIS
 
ShowTcpConnection.ps1 - script for getting the TCP connections and print information to the screen
 
.DESCRIPTION
ShowTcpConnection.ps1 - script for getting the TCP connections and print information to the screen. Used for checking and monitoring of TCP connections.
 
.PARAMETER -OutGridView
With 'OutGridView' parameter script will present information using the Out-GridView commandlet
 
.PARAMETER -Monitor
With 'Monitor' parameter scritp will update connection information periodically and show new and closed connections
 
.PARAMETER -CheckInterval
'CheckInterval' parameters defines the time in secconds between getting the TCP connections in the 'Monitor' mode. Default value - 60 sec.
 
.PARAMETER -LocalAddress
Specifies an array of local IP addresses. This parameter is correspond '-LocalAddress' parameter of Get-NetTCPConnection cmdlet
 
.PARAMETER -LocalPort
Specifies an array of local ports. This parameter is correspond '-LocalPort' parameter of Get-NetTCPConnection cmdlet
 
.PARAMETER -RemoteAddress.
Specifies an array of remote IP addresses. This parameter is correspond '-RemoteAddress' parameter of Get-NetTCPConnection cmdlet
 
.PARAMETER -RemotePort
Specifies an array of remote ports. This parameter is correspond '-RemotePort' parameter of Get-NetTCPConnection cmdlet
 
.PARAMETER -State
Specifies an array of TCP states. This parameter is correspond '-State' parameter of Get-NetTCPConnection cmdlet
 
.PARAMETER -AppliedSettings
Specifies an array of values of applied settings. This parameter is correspond '-AppliedSetting' parameter of Get-NetTCPConnection cmdlet
 
.PARAMETER -ProcessId
Specifies the PID of the owning process of a TCP connection. This parameter is correspond '-OwningProcess' parameter of Get-NetTCPConnection cmdlet
 
.PARAMETER -ProcessName
Specifies the names of the owning processes of a TCP connection. In this case script will show only TCP connections of correspond processes.
 
.PARAMETER -ExcludeProcessName
Specifies the names of the owning processes which will be excluded from report.
 
.PARAMETER -WriteFile
When this parameter is specified, script will write output information to file $PsScriptRoot\ShowTcpConnection_log.txt
 
.EXAMPLE
PS> .\ShowTcpConnections.ps1
In this case script will dump all TCP connections to the screen.
 
.EXAMPLE
PS> .\ShowTcpConnections.ps1 -OutGridView
In this case script will show all TCP connections using Out-GridView cmdlet.
 
.EXAMPLE
PS> .\ShowTcpConnections.ps1 -Monitor
Script will monitor TCP connections and renew connections data in default checking interval 60 sec.
 
.EXAMPLE
PS .\ShowTcpConnections.ps1 -Monitor -CheckInterval 120
Script will monitor TCP connections and renew connections data in checking interval 120 sec.
 
.EXAMPLE
PS .\ShowTcpConnections.ps1 -ProcessName Skype
Script will show TCP connections of Skype processes.
 
.EXAMPLE
PS .\ShowTcpConnection.ps1 -ProcessName Skype, outlook, MicrosoftEdgeCP
Script will show TCP connections of Skype, outlook, MicrosoftEdgeCP processes.
 
.EXAMPLE
PS .\ShowTcpConnection.ps1 -ExcludeProcessName Skype, outlook, MicrosoftEdgeCP
Script will show TCP connections of all porocesses except of Skype, outlook, MicrosoftEdgeCP processes.
 
.EXAMPLE
PS .\ShowTcpConnection.ps1 -Monitor -CheckInterval 10 -ProcessName Skype, outlook, MicrosoftEdgeCP
Script will monitor TCP connections and renew connections data in checking interval 10 sec for Skype, outlook, MicrosoftEdgeCP processes only.
#>

param(
    [Parameter()] [switch] $OutGridView,
    [Parameter()] [switch] $Monitor,
    [Parameter()] [int] $CheckInterval = 60,
    [Parameter()] [string[]] $LocalAddress,
    [Parameter()] [int[]] $LocalPort,
    [Parameter()] [string[]] $RemoteAddress,
    [Parameter()] [int[] ]$RemotePort,
    [Parameter()] [string[]] $State,
    [Parameter()] [string[]] $AppliedSettings,
    [Parameter()] [int[]] $ProcessId,
    [Parameter()] [string[]] $ProcessName,
    [Parameter()] [string[]] $ExcludeProcessName,
    [Parameter()] [switch] $WriteFile
)

function Get-TcpConnectionInfo {
    param(
        [Parameter(Mandatory)] [hashtable] $GetNetTcpConnectionParams,
        [Parameter()] [string[]] $ProcessName,
        [Parameter()] [string[]] $ExcludeProcessName
    )

    Out-Debug "Function [Get-TcpConnectionInfo]"
    $CimTcpConnections = Get-NetTcpConnection @GetNetTcpConnectionParams

    if ($ProcessName) { 
        $CurrentPrNames = $ProcessName
    }
    elseif ($ExcludeProcessName) { 
        $CurrentPrNames = $ExcludeProcessName
    }

    if ($CurrentPrNames) {
        $Ids = New-Object System.Collections.Generic.List[int]
        foreach($CurrentPrName in $CurrentPrNames) {
            Get-Process -Name $CurrentPrName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id | ForEach-Object { $Ids.Add($_) }
        }
        if ($ProcessName) { 
            $CimTcpConnections = $CimTcpConnections | Where-Object {$_.OwningProcess -in $Ids } 
        }
        elseif($ExcludeProcessName) { 
            $CimTcpConnections = $CimTcpConnections | Where-Object {$_.OwningProcess -notin $Ids } 
        }
    }
    $TotalConnections = $CimTcpConnections.Count
    Out-Debug "Total connections: [$TotalConnections]"

    $Connections = New-Object System.Collections.Generic.List[PsObject]
    $Svcs = @{}

    $CimTcpConnections | ForEach-Object {
        $Connection = New-Object PSObject
        $Connection | Add-Member Noteproperty LocalAddress $_.LocalAddress
        $Connection | Add-Member Noteproperty LocalPort $_.LocalPort
        $Connection | Add-Member Noteproperty RemoteAdderss $_.RemoteAddress
        $Connection | Add-Member Noteproperty RemotePort $_.RemotePort
        $Connection | Add-Member Noteproperty State $_.State
        $Connection | Add-Member Noteproperty AppliedSetting $_.AppliedSetting
        $Connection | Add-Member Noteproperty PID $_.OwningProcess
        $Connection | Add-Member Noteproperty CreationTime $_.CreationTime

        $PsId = $_.OwningProcess
        try {
            $Process = Get-Process -Id $PsId -ErrorAction Stop
            $PsName = $Process.Name
            $PsPath = $Process.Path
        }
        catch {
            Write-Error "[!] Process with ID [$PsId] is not found"
            Out-Debug "[!] Process with ID [$PsId] is not found"
            try {
                $PsConnection = Get-NetTCPConnection -OwningProcess $PsId -ErrorAction Stop
            }
            catch {
                Out-Debug "Connection with [$PsId] is not found"
                $PsConnection = $null
            }

            if ($PsConnection) {
                Write-Warning "[!] Connection without running process:"
                $Info = $PsConnection | Format-Table -AutoSize
                Out-Info -Info $Info
            }
            $PsName = 'Undefined'
            $PsPath = 'Undefined'
        }

        if ($PsName -eq 'svchost') {
            $WmiSvcs = Get-CimInstance -ClassName Win32_service | Where-Object { $_.ProcessId -eq $PsId }
            foreach ($WmiSvc in $WmiSvcs) {
                $SvcName = $WmiSvc.Name
                $DisplayName = (Get-Service -Name $SvcName).DisplayName
                $Names += "$SvcName, $DisplayName`n" 
            }
            if (-not ($Svcs.ContainsKey($PsId))) {
                $Svcs.Add($PsId,$Names) > $null
            }
        }
        else {
            $Names = $null
        }
        $Connection | Add-Member Noteproperty ProcessName $PsName
        $Connection | Add-Member Noteproperty ProcessPath $PsPath
        $Connection | Add-Member Noteproperty Services $Names
        Out-Debug $Connection

        $Connections.Add($Connection) > $null
    }
    $Connections
}

function Show-CompareResult {
    param(
        [Parameter(Mandatory, ValueFromPipeline=$true)] [ValidateSet('<=','=>')] [string] $SideIndicator
    )

    Begin {
        Out-Debug "Function [Show-CompareResult]. BEGIN section."
        $DiffArrList =     New-Object System.Collections.Generic.List[PsObject]
        $Diffs = Compare-Object -ReferenceObject $Script:RefConnections -DifferenceObject $Script:DiffConnections -Property PID -PassThru
    }
    Process {
        Out-Debug "Function [Show-CompareResult]. PROCESS section."
        Out-Debug "SideIndicator variable: [$SideIndicator]"
        $Diffs | Where-Object {$_.SideIndicator -eq $SideIndicator} | ForEach-Object {
            $DiffArrList.Add($_) > $null
        }
        if ($SideIndicator -eq '<=') { 
            Out-Info -Info "Closed connections:" 
        }
        elseif (
            $SideIndicator -eq '=>') { Out-Info -Info "New connections:"
        }

        if ($DiffArrList.Count -gt 0) {
            $Info = $DiffArrList | Format-Table -AutoSize
            Out-Info -Info $Info
        }
        else {
            Out-Info -Info "No connections"
        }
        $DiffArrList.Clear()
    }
}

function Out-Info {
    Param(
        [Parameter(Mandatory)] [string] $Info
    )

    Out-Debug "Function [Out-Info]."
    Write-Output $Info
    if ($Script:WriteFile) {
        $Info | Out-File -FilePath "$PsScriptRoot\ShowTcpConnections_log.txt" -Append
    }

    if ($DebugPreference -eq "Continue") {
        "Result:" | Out-File -FilePath "$PsScriptRoot\ShowTcpConnections_debug.txt" -Append
        $Info | Out-File -FilePath "$PsScriptRoot\ShowTcpConnections_debug.txt" -Append
    }
}

function Out-Debug
{
    Param(
        [Parameter(Mandatory)] [string] $Info
    )

    Write-Debug $Info
    if ($DebugPreference -eq "Continue") {
        $Info | Out-File -FilePath "$PsScriptRoot\ShowTcpConnections_debug.txt" -Append
    }
}

function Write-TimeStamp {
    Out-Debug "Function [Write-TimeStamp]."
    $Timestamp = Get-Date
    Out-Info "`n---------------------------------"
    Out-Info "Time stamp: [$Timestamp]"
}

#$DebugPreference = 'Continue';
$GetNetTcpConnectionParams = @{}

if ($LocalAddress) { $GetNetTcpConnectionParams.Add('LocalAddress', $LocalAddress) }
if ($LocalPort)  { $GetNetTcpConnectionParams.Add('LocalPort', $LocalPort) }
if ($RemoteAddress) { $GetNetTcpConnectionParams.Add('RemoteAddress', $RemoteAddress) }
if ($RemotePort) { $GetNetTcpConnectionParams.Add('RemoteAddress', $RemotePort) }
if ($State) { $GetNetTcpConnectionParams.Add('State', $State) }
if ($AppliedSettings) { $GetNetTcpConnectionParams.Add('AppliedSetting', $AppliedSettings) }
if ($ProcessId) { $GetNetTcpConnectionParams.Add('OwningProcess', $ProcessId) }


$GetTcpConnectionInfoParams = @{
    'GetNetTcpConnectionParams' = $GetNetTcpConnectionParams
}
if ($ProcessName) { $GetTcpConnectionInfoParams.Add('ProcessName', $ProcessName) }
if ($ExcludeProcessName) { $GetTcpConnectionInfoParams.Add('ExcludeProcessName', $ExcludeProcessName) }

Write-TimeStamp
if ($OutGridView) {
    $TcpConnections = Get-TcpConnectionInfo @GetTcpConnectionInfoParams
    $TcpConnections | Out-GridView
    if ($WriteFile) { 
        $TcpConnections | Format-Table -AutoSize | Out-File -FilePath "$PsScriptRoot\ShowTcpConnections_log.txt" -Append 
    }
}
elseif ($Monitor) {
    for($i=0;;$i++) {
           Out-Debug "Monitor Iteration: $i"
        if($i -eq 0) {
            Out-Debug "--------------------------------"
            Out-Debug "Getting the RefConnection object"
            $Script:RefConnections = Get-TcpConnectionInfo @GetTcpConnectionInfoParams
            Out-Info -Info ($Script:RefConnections | Format-Table -AutoSize)
        }
        else {
            Write-TimeStamp
            if($i -gt 1) {
                Out-Debug "Set RefConnections -> DiffConnections"
                $Script:RefConnections = $Script:DiffConnections
            }
            Out-Debug "--------------------------------"
            Out-Debug "Getting the DiffConnection object"
            $Script:DiffConnections = Get-TcpConnectionInfo @GetTcpConnectionInfoParams
            '<=','=>' | Show-CompareResult
        }
        Start-Sleep -Seconds $CheckInterval
    }
}
else {
    $TcpConnections = Get-TcpConnectionInfo @GetTcpConnectionInfoParams
    Out-Info -Info ($TcpConnections | Format-Table -AutoSize)
}


