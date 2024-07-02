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

function Copy-SFTP {
    ___start 'Copy-SFTP'
        # Expected format "vol:/path../file -> hks@hostname://root/path../dest"
        # Expected format "hks@hostname://root/path../file -> vol:/path../dest"
    $command = $args -join " "

    if($command.toLower() -match "h(elp)$") {
        return '
### NAME
`Copy-SFTP` - A PowerShell function to copy files to and from remote servers using SFTP.

### SYNOPSIS
`Copy-SFTP` `source -> destination`

### DESCRIPTION
The `Copy-SFTP` function allows users to copy files or directories to and from remote servers using the SFTP protocol. The command can handle both local-to-remote and remote-to-local transfers based on the specified source and destination paths.

### USAGE
The function expects the source and destination paths to be in one of the following formats:
- `vol:/local/path/file -> user@hostname:/remote/path/dest`
- `user@hostname:/remote/path/file -> vol:/local/path/dest`

### PARAMETERS
`source`
Specifies the source file or directory. The source can be either a local path or a remote path.

`destination`
Specifies the destination file or directory. The destination can be either a local path or a remote path.

### EXAMPLES
#### Example 1: Copy a local file to a remote server
```powershell
Copy-SFTP "vol:/local/path/file -> user@hostname:/remote/path/dest"
```
This command copies the local file `/local/path/file` to the remote path `/remote/path/dest` on the specified server.

#### Example 2: Copy a remote file to a local directory
```powershell
Copy-SFTP "user@hostname:/remote/path/file -> vol:/local/path/dest"
```
This command copies the remote file `/remote/path/file` from the specified server to the local path `/local/path/dest`.

### DEBUGGING
The function includes debugging statements (denoted by `___debug`) which can be uncommented to provide additional output for troubleshooting.

### NOTES
- Ensure that the paths are correctly specified and that the remote server supports SFTP.
- The function uses `sftp` to perform the file transfer. Make sure `sftp` is installed and available in your environment.
- Authentication to the remote server will be required. Ensure you have the necessary permissions and credentials.

### AUTHOR
Atypic - Chill Hipster Coder Master

### SEE ALSO
`sftp(1)`, `scp(1)`
        '
    }

    ___debug "command:$command"
    $split = ($command -split "(/s)?->(/s)?").trim()

    $target = $split[0]
    ___debug "target:$target"
    $destination = $split[1]
    ___debug "destination:$destination"

    if(Test-Path $(Get-Path $target)) {
        $target = Get-Path $target
        $recurse = if((Get-Item $target).PsIsContainer) {" -R"} else {""}
        $destSplit = $destination -split ":"
        $userHost = $destSplit[0]
        $destination = $destSplit[1]
        ___debug "put$recurse $target $destination | sftp $($userHost)" 
        "put$recurse $target $destination" | sftp $userHost
    }elseif(Test-Path $(Get-Path $destination)) {
        $destination = Get-Path $destination
        $targetSplit = $target -split ":"
        $userHost = $targetSplit[0]
        $target = $targetSplit[1]
        #___debug "sftp $($userHost):$target $destination" 
        ___debug "get $target $destination | sftp $($userHost)" 
    
        "get $target $destination" | sftp $userHost
        #sftp -q "$($userHost):$target $destination"
    }

    ___end
}
