importhks persist
importhks net
function r_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "DarkYellow" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function r_debug_function ($function, $messageColor , $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Yellow" }
    Write-Host ">_ $function" -ForegroundColor $messageColor 
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function Open-SSHConnection ($target, $user) {
    $SCOPEbak = ($global:SCOPE -split "::")[0]
    persist -> SSH
    r_debug_function Open-SSHConnection DarkCyan
    r_debug "Target: $target" DarkGray
    r_debug "User: $user" DarkGray
    switch ($target) {
        { $_ -match "([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})" } { 
            $ip = $target
            if (($null -ne $ip) -and ($ip -match "([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})")) {
                r_debug "Connecting SSH remote shell to target: $target | With Ip: $ip | With User: $user" Blue 
                ssh $user@$ip
            }
        }
        Default {
            $cons = persist $target
            $cons = $cons -split "::"
            $userOr = $user
            r_debug "Possible connections for: $target | `n$($cons)" Blue 
            foreach ($con in $cons) {
                $spl = $con -split ":"
                $ip = $spl[0]
                if ($null -ne $userOr) {
                    if($spl[1] -ne $userOr) { continue }
                }
                $user = $spl[1]
                if($spl.length -eq 3) { $key = $spl[2] }

                if (($null -ne $ip) -and ($ip -match "([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})")) {
                    r_debug "Connecting SSH remote shell to target: $target | With Ip: $ip | With User: $user" Blue 
                    
                    $port = Test-Port -Target $ip -Port 22 -Timeout 1000
                    r_debug "Connect result: $($port.Open)"
                    if($port.Open) {
                        if($null -eq $key) { ssh $user@$ip }
                        else { ssh -i ~/.ssh/$key $user@$ip }
                        return
                    }
                }
            }
        }
    }
    persist -> $SCOPEbak
} 
New-Alias -Name resh -Value Open-SSHConnection

function Open-SFTPConnection ($target, $user, $command) {
    $SCOPEbak = ($SCOPE -split "::")[0]
    persist -> SSH
    r_debug_function Open-SFTPConnection DarkCyan
    r_debug "Target: $target" DarkGray
    r_debug "User: $user" DarkGray
    switch ($target) {
        { $_ -match "([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})" } { 
            $ip = $target
            if (($null -ne $ip) -and ($ip -match "([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})")) {
                r_debug "Connecting SFTP remote shell to target: $target | With Ip: $ip | With User: $user | Command: $command" Blue 
                sftp $user@$ip
            }
        }
        Default {
            $cons = persist $target
            $cons = $cons -split "::"
            $userOr = $user
            r_debug "Possible connections for: $target | `n$($cons)" Blue 
            foreach ($con in $cons) {
                $spl = $con -split ":"
                $ip = $spl[0]
                if ($null -ne $userOr) {
                    if($spl[1] -ne $userOr) { continue }
                }
                $user = $spl[1]
                if($spl.length -eq 3) { $key = $spl[2] }

                if (($null -ne $ip) -and ($ip -match "([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})\.([0-9]{1,2}|[0-9]{3})")) {
                    r_debug "Connecting SFTP remote shell to target: $target | With Ip: $ip | With User: $user | Command: $command" Blue 
                  
                    $port = Test-Port -Target $ip -Port 22 -Timeout 1000
                    r_debug "Connect result: $($port.Open)"
                    if($port.Open) {
                        if($null -eq $key) { sftp $user@$ip }
                        else { sftp -i ~/.ssh/$key $user@$ip }
                        return
                    }
                }
            }
        }
    }
    persist -> $SCOPEbak
} 
New-Alias -Name resftp -Value Open-SFTPConnection

function Copy-SFTP ($computer, $target, $destination) {
    foreach ($t in $target) {
        if ($t -isnot [string]) {
            if (($t -is [System.IO.FileInfo]) -or ($t -is [System.IO.DirectoryInfo])) {
                $t = $t.fullname
            } else {
                Write-Host "Invalid object type $($t.GetType())"
                continue
            }
            if($t -match "\\\\") {
                Open-SFTPConnection -target $Computer -command $('get "' + $target + '" "' + $destination + '"' ) 
            } else {
                Open-SFTPConnection -target $Computer -command $('put "' + $target + '" "' + $destination + '"' )
            }
        }
    }
}
