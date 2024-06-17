if ($null -eq $global:_net_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_net_module_location = $PSScriptRoot
    }
    else {
        $global:_net_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}
function n_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "DarkYellow" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function n_debug_function ($function, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Yellow" }
    Write-Host ">_ $function" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function n_debug_return {
    if (!$global:_debug_) { return }
    Write-Host "#return# $($args -join " ")" -ForegroundColor Black -BackgroundColor DarkGray
    return
}
function n_prolix ($message, $messageColor) {
    if (!$global:prolix) { return }
    if ($null -eq $messageColor) { $messageColor = "Cyan" }
    Write-Host $message -ForegroundColor $messageColor
}

function n_match {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        $string,
        [Parameter(Mandatory = $false, Position = 1)]
        $regex,
        [Parameter()]
        [switch]
        $getMatch = $false,
        [Parameter()]
        $logic = "OR"
    )
    if ($null -eq $string) {
        if ($getMatch) { return $null }
        return $false
    }
    if ($null -eq $regex) {
        if ($getMatch) { return $null }
        return $false
    }
    if (($string -is [System.Array])) {
        $string = $string -join "`n"
    }
    if ($regex -is [System.Array]) {
        foreach ($r in $regex) {
            $f = p_match $string $r
            if (($logic -eq "OR") -and $f) { return $true }
            if (($logic -eq "AND") -and !$f) { return $false }
            if (($logic -eq "NOT") -and $f) { return $false }
        }
        return ($logic -eq "AND") -or ($logic -eq "NOT")
    }
    $found = $string -match $regex
    if ($found) {
        if ($getMatch) {
            return $Matches[0]
        }
        return $logic -ne "NOT"
    }
    if ($logic -eq "NOT") { return $true }
    if ($getMatch) { return $null }
    return $false
}
function Test-Ping ($target="google.com", $wait = 1000) {
    return [boolean]((ping -n 1 -w $wait $target) -match "Received = 1")
}
New-Alias -Name boing -Value Test-Ping -Scope Global -Force
function Test-Request ($target = "google.com", $wait = 1000) {
    return (Invoke-WebRequest $target -TimeoutSec ($wait / 1000)).statuscode -eq 200
}
New-Alias -Name bocurl -Value Test-Request -Scope Global -Force
function monitor($target, [float]$wait = 200, [float]$duration = [float]::MaxValue, [float]$frequency = 1, [switch] $curl) {
    $duration__ = $duration
    if($IsWindows) {
	$logPath = "C:\Users\$ENV:USERNAME\.powershell\~logs\$target.log"
    } elseif ($IsLinux) {
	$logPath = "/Home/$(whoami)/.powershell/~logs/$target.log"
    }
    Write-Host "Monitoring: $target | From: INT[$(gip)] EXT[$(gpip)] | Wait: $wait ms | Log Location: $logPath"
    $null = New-Item $logPath -ItemType File -Force
    [float]$disconnectedDuration = 0
    [int]$Tcounter = 0
    [int]$Tfailure = 0
    [int]$counter = 0
    $inital = $true
    while ($duration -gt 0) {
        $connected = if ($curl) { Test-Request $target -wait $wait } else { Test-Ping $target -wait $wait }
        if ($connected) {
            if ($disconnected -or $inital) {
                $msg = "Connection Successful: $target | At: $(Get-Date) | Disconnected Duration: $disconnectedDuration seconds"
                Write-Host $msg -ForegroundColor Green
                Add-Content $logPath -Value $msg
                $disconnectedDuration = 0
                $disconnected = $false
            }
            Start-Sleep $frequency
            $counter++
        }
        else {
            if (!$disconnected -or $inital) {
                $disconnected = $true
                $msg = "Connection Failed: $target | At: $(Get-Date) | Failure Ratio: 1/$counter"
                Write-Host $msg -ForegroundColor Red
                Add-Content $logPath -Value $msg
                $counter = 0
            }
            Start-Sleep $frequency
            $disconnectedDuration += $frequency + ($wait / 1000)
            $Tfailure++
        }
        $inital = $false
        $duration -= $frequency
        $Tcounter ++
    }
    $msg = "Finished Monitoring: $target | Total Monitor Duration: $duration__ seconds | Failure Ratio: $Tfailure/$Tcounter | Log Location: $logPath"
    Write-Host $msg
    Add-Content $logPath -Value $msg
}
function Get-IP ([switch]$interface) {
    $all = (ipconfig) -join "`n"
    $all = $all -split "adapter"
    $ip = @()
    foreach ($a in $all) {
        $found = $a | select-string "ipv4"
        if ($null -ne $found) {
            if ($found -match "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+") {
                $res = $matches[0]
                if ($interface) {
                    $split = $a -split "`n"
                    $res = "$($split[0]) $($res)"
                }
                $ip += $res 
            }
        }
    }
    return $ip
}
New-Alias -Name gip -Value Get-IP -Scope Global -Force
function Get-PublicAddress {

    $pip = ((& "nslookup" "myip.opendns.com" "208.67.222.220") | Select-Object -last 2)[0].Trim("Address:").Trim()

    if (($null -ne $pip) -and $($pip -match "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")) { return $pip } 

    $pip = $null

    if ($global:prolix) { write-host "Fetching Public IPv4" -ForegroundColor DarkCyan } 
    $ipURLs = @("ipinfo.io", "ifconfig.me", "icanhazip.com", "ident.me", "smart-ip.net")
    foreach ($url in $ipURLS) {
        if (boing $url -wait 100) {
            try { $pip = (Invoke-WebRequest -UseBasicParsing $url).Content.Trim() } catch {
                if ($global:prolix) { write-host "$url threw exception" -foregroundcolor red } 
            } 
        }
        elseif ($global:prolix) { write-host $($url + ' didn`t connect') -foregroundcolor red }
    }
    return $pip
}
New-Alias -Name gpip -Value Get-PublicAddress -Scope Global -Force

function Invoke-IPSweep ([switch]$thread) {


    ___start "Invoke-IPSweep"
    $n = ((gip) -split "\.")[2].trim()

    ___debug "Sweeping 192.168.$n.*" DarkGray
    $ips = @()

    if($thread) {
        ___debug  "Running multi-threading"
        
        $threads = $( Get-Wmiobject win32_Processor | Select-Object -expand ThreadCount)[0]

        $countPer = [Math]::Floor(255 / $threads)

        $jobs = @()
        for($i = 0; $i -lt $threads; $i++) {
            
            $start = $countPer * $i 
            $end = $start + $countPer
            $arr = $start..$end
            $jobs += Start-Job -ScriptBlock {
                param ($n, $arr)
                $ips = @()
                foreach ($i in $arr) {
                    if($null -ne ((ping "192.168.$n.$i" -n 1) | select-string "reply from")) { 
                        $ips += "192.168.$n.$i" 
                    }
                }
                write-output $ips
            }
        }
        foreach ($j_ in $jobs) {
            while($j_.State -eq "Running") { Start-Sleep -Milliseconds 125 }
            $jobIPs = Receive-Job -job $j_
            $ips += $jobIPs
        }
        return ___return $ips
    }

    ___end
    return $(1..255) | ForEach-Object {
        $ip = "192.168.$n.$_"
            ___debug "Boinging $ip"
            if(Test-Ping -target $ip -wait 250){
                ___debug "Pinged $ip Successfully" Green
                return $ip
            }
            return $null
    }
}
function n_default ($variable, $value) {
    n_debug_function "e_default"
    if ($null -eq $variable) { 
        n_debug_return variable is null
        return $value 
    }
    switch ($variable.GetType().name) {
        String { 
            if($variable -eq "") {
                n_debug_return
                return $value
            } else {
                n_debug_return
                return $variable
            }
        }
    }
}
function n_search_args ($a_, $param, [switch]$switch) {
    n_debug_function "e_search_args"    
    $c_ = $a_.Count
    n_debug "args:$a_ | len:$c_"
    n_debug "param:$param"
    n_debug "switch:$switch"
    if($switch) { 
        for ($i = 0; $i -lt $c_; $i++) {
            $a = $a_[$i]
            n_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if($null -eq $res) { 
                $res = $true 
                $a_ = e_truncate $a_ -indexAndDepth @($i,1)
            }
            else {
                throw [System.ArgumentException] "Duplicate argument passed: $param"
            }
        }
        $res = $res -and $true
        n_debug_return
        return @{
            RES = $res
            ARGS = $a_
        }
    } else {
        for ($i = 0; $i -lt $a_.length; $i++) {
            $a = $a_[$i]
            n_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if(($null -eq $res) -and ($i -lt ($c_ - 1))) { 
                $res = $a_[$i + 1]
                $a_ = e_truncate $a_ -indexAndDepth @($i,2)
            }
            elseif ($i -ge ($c_ - 1)) {
                 throw [System.ArgumentOutOfRangeException] "Argument value at position $($i + 1) out of $c_ does not exist for param $param"
            }
            elseif ($null -ne $res) {
                throw [System.ArgumentException] "Duplicate argument passed: $param"
            }
        }
        n_debug_return
        return @{
            RES = $res
            ARGS = $a_
        }
    }
}
function https {
   n_debug_function "https"
   $hash = n_search_args $args "-method"
   $method = n_default $hash.RES $args[0]
   $hash = n_search_args $hash.ARGS "-client"
   $client = n_default $hash.RES $args[1]
   $hash = n_search_args $hash.ARGS "-argumentList"
   $arguments = n_default $hash.RES $($args[2..$($args.Count)] -join " ")

   $response = Invoke-Expression "$global:_net_module_location\https.exe '$method' '$client' '$arguments'"
   return $response
}
function Test-Port ($target='localHost',$port=80,$timeout=100) {
  $requestCallback = $state = $null
  $client = New-Object System.Net.Sockets.TcpClient
  $null = $client.BeginConnect($target,$port,$requestCallback,$state)
  while($timeout -gt 0) {
    if($client.Connected) { return [pscustomobject]@{hostname=$hostname;port=$port;open=$true} }
    Start-Sleep -Milliseconds 1
    $timeout--
  }
  if ($client.Connected) { $open = $true } else { $open = $false }
  $client.Close()
  [pscustomobject]@{target=$target;port=$port;open=$open}
}
