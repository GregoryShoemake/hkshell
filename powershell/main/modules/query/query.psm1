function q_is ($obj, $class) {
    if ($null -eq $obj) { return $null -eq $class }
    if ($null -eq $class) { return $false }
    if ($class -is [System.Array]) {
        foreach ($c in $class) {
            if ($obj -is $c) { return $true }
        }
        return $false
    }
    return $obj -is [type](g_replace $class @("\[", "]"))
}
function q_isnot ($obj, $class) {
    if ($null -eq $obj) { return $null -ne $class }
    if ($null -eq $class) { return $true }
    if ($class -is [System.Array]) {
        foreach ($c in $class) {
            if ($obj -is $c) { return $false }
        }
        return $true
    }
    return $obj -isnot [type](g_replace $class @("\[", "]"))
}

function q_for ([int]$iMax, [int]$jMax, [int]$kmax, [string] $startCommand, [string] $loopCommand, [string] $endCommand) {
    Invoke-Expression $startCommand
    for ($i = 0; $i -lt $iMax; $i++) {
        for ($j = 0; $j -lt $jMax; $j++) {
            for ($k = 0; $k -lt $kMax; $k++) {
                Invoke-Expression $loopCommand
            }
        }
    }
    Invoke-Expression $endCommand
}
function q_nullemptystr ($nullable) {
    if ($null -eq $nullable) { return $true }
    if ($nullable -isnot [string]) { return $false }
    if ($nullable.length -eq 0) { return $true }
    return q_for $nullable.length 1 1 '$result = $true' 'if(($nullable[$i] -ne " ") -and ($nullable[$i] -ne "`n")){ $result = $false}' 'return $result'
}
function q_int_eq {
    [CmdletBinding()]
    param (
        [Parameter()]
        [int]
        $int,
        # single int or array of ints to compare
        [Parameter()]
        $ints
    )
    if ($null -eq $ints) { return $false }
    foreach ($i in $ints) {
        if ($int -eq $i) { return $true }
    }
    return $false
}

function q_parseString ($stringable) {
    if ($stringable -is [string]) { return $stringable }
    if ($null -eq $stringable) { return "" }
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        return Out-String -InputObject $stringable -Width 100
    }
    elseif ($stringable -is [System.Array]) {
        return $stringable -join "`n"
    }
    else { return "$stringable" }
}

function q_truncate {
    [CmdletBinding()]
    param (
        # Array object passed to truncate
        [Parameter(Mandatory = $false, Position = 0)]
        [System.Array]
        $array,
        [Parameter()]
        [int]
        $fromStart = 0,
        [Parameter()]
        [int]
        $fromEnd = 0,
        [int[]]
        $indexAndDepth
    )
    $l = $array.Length
    if ($fromStart -gt 0) {
        $l = $l - $fromStart
    }
    if ($fromEnd -gt 0) {
        $l = $l - $fromEnd
    }
    else {
        $fromEnd = 1
    }
    $fromEnd = $array.Length - $fromEnd
    if (($null -ne $indexAndDepth) -and ($indexAndDepth[1] -gt 0)) {
        $l = $l - $indexAndDepth[1]
    }
    if ($l -le 0) {
        return @()
    }
    $res = @()
    $fromStart--
    if ($null -ne $indexAndDepth) {
        $middleStart = $indexAndDepth[0]
        $middleEnd = $indexAndDepth[0] + $indexAndDepth[1] - 1
        $middle = $middleStart..$middleEnd
    }
    for ($i = 0; $i -lt $array.Length; $i ++) {
        if (($i -gt $fromStart) -and !(q_int_eq $i $middle ) -and ($i -lt $fromEnd)) {
            $res += $array[$i]
        }
    }
    return $res
}
function q_convert_bytes_string ($bytes) {
    if ($bytes / 1PB -gt 1) {
        return "$([Math]::Round($bytes / 1PB, 3)) PB"
    }
    if ($bytes / 1TB -gt 1) {
        return "$([Math]::Round($bytes / 1TB, 3)) TB"
    }
    if ($bytes / 1GB -gt 1) {
        return "$([Math]::Round($bytes / 1GB, 3)) GB"
    }
    if ($bytes / 1MB -gt 1) {
        return "$([Math]::Round($bytes / 1MB, 3)) MB"
    }
    if ($bytes / 1KB -gt 1) {
        return "$([Math]::Round($bytes / 1KB, 3)) KB"
    }
    return "$bytes bytes"
}

function dirsum {
    [CmdletBinding()]
    param (
        [Parameter()]
        $directory,
        [Parameter()] [switch]
        $ls,
        [Parameter()] [switch]
        $string
    )
    if ($null -eq $directory) {
        if ($global:prolix) { Write-Host Measuring current directory -ForegroundColor DarkRed }
        $directory = "$(Get-Location)"
    }
    if ($ls) {
        $directory = Get-ChildItem $directory
    }
    if ($directory -isnot [string]) {
        if ($directory -is [System.IO.FileInfo]) {
            $directory = $directory.parent.fullname
        }
        elseif ($directory -is [System.IO.DirectoryInfo]) {
            $directory = $directory.fullname
        }
        elseif ($directory -is [System.Array]) {
            foreach ($d in $directory) {
                $s = dirsum $d
                if ($string) { $s = q_convert_bytes_string $s }
                $n = $d.name
                while ($n.length -lt 25) {
                    if ($n.length % 2 -eq 1) {
                        $n += " "
                    }
                    else {
                        $n += "."
                    }
                }
                if ($n.Length -gt 25) {
                    $n = $n.Substring(0, 25)
                }
                write-host "$n $s"
            }
            return
        }
        else {
            Write-Host Argument type $($directory.GetType()) is not a valid type -ForegroundColor Red
            return
        }
    }
    $sum = Get-ChildItem $directory -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue | Select-Object -expand sum -ErrorAction SilentlyContinue
    if ($string) {
        return q_convert_bytes_string $sum
    }
    return $sum
}
function q_between ($val, $min, $max) {
    if ($val -lt $min) { return $false }
    return $val -lt $max
}

function q_get_ext ($filename) {
    if ($filename -is [System.IO.FileInfo]) {
        $filename = $filename.name
    }
    if ($filename -isnot [string]) {
        Write-Host Argument type $($filename.GetType()) is not a valid type -ForegroundColor Red
        return
    }
    $d = -1
    $l = $filename.length
    $ext = ""
    for ($i = $l - 1; q_between $i -1 $l; $i += $d) {
        if ($d -ne -1) {
            $ext += $filename[$i]
        }
        if ($d -eq 0) { $d ++ }
        if (($filename[$i] -eq ".") -and ($ext.length -eq 0)) { $d = 0 }
    }
    return $ext
}

function AllVolumes {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $info,
        [Parameter()]
        [switch]
        $forceWMI
    )
    if ($info) {
        $i =
        '
.SYNOPSIS
    Attempts to return a list of all volumes that are fixed and have assinged drive letters with Get-Volume

    If the instance of powershell does not have that command it tries Get-WmiObject and returns a list of all volumes that are NTFS, FAT32, or EXFAT and have assigned drive letters

    return value is in the form of a hash of format:
    $hash = @{ Function = "Get-Volume"; Volumes = $volumes } or
    $hash = @{ Function = "Get-WmiObject"; Volumes = $volumes }

.PARAMS
    [Parameter()]
    [switch]
    $forceWMI

    -forceWMI can be passed to force the usage of Get-WmiObject
        '
        OutInfo $i
        return
    }
    if ($forceWMI) {
        $volumes = Get-WmiObject Win32_Volume | Where-Object { ($_.driveLetter -match "[A-Z]") -and (@("NTFS", "FAT32", "EXFAT") -contains $_.FileSystem) }
        $hash = @{ Function = "Get-WmiObject"; Volumes = $volumes }
        return $hash
    }
    try {
        $volumes = Get-Volume | Where-Object { ($_.driveLetter -match "[A-Z]") -and ($_.DriveType -eq "Fixed") }
        $hash = @{ Function = "Get-Volume"; Volumes = $volumes }
        return $hash
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        $volumes = Get-WmiObject Win32_Volume | Where-Object { ($_.driveLetter -match "[A-Z]") -and (@("NTFS", "FAT32", "EXFAT") -contains $_.FileSystem) }
        $hash = @{ Function = "Get-WmiObject"; Volumes = $volumes }
        return $hash
    }
}

function vquery {
    [CmdletBinding()]
    param (
        [Parameter()]
        $path,
        [Parameter()]
        $filter,
        [Parameter()]
        [switch]
        $recurse,
        [Parameter()]
        $depth
    )
    if ($null -ne $depth) {
        Get-ChildItem $path -Filter $filter -Recurse:$recurse -Depth $depth -Force
    }
    else {
        Get-ChildItem $path -Filter $filter -Recurse:$recurse -Force
    }
}

function hquery {
    [CmdletBinding()]
    param (
        [Parameter()]
        $path,
        [Parameter()]
        [int]
        $depth = 10,
        [Parameter()]
        $filter
    )
    if ($null -eq $path) { $path = "$(Get-Location)" }
    if ($path -is [System.IO.FileInfo]) {
        $path = $path.parent.fullname
    }
    if ($path -is [System.IO.DirectoryInfo]) {
        $path = $path.fullname
    }
    if ($path -isnot [string]) {
        Write-Host Argument type $($path.GetType()) is not a valid type -ForegroundColor Red
        return
    }
    for ($i = 0; $i -lt $depth; $i++) {
        Get-ChildItem $path -Depth $i -filter $filter -Force
    }
}

function q_benchmark {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $action
    )
    if ($action -eq "START") {
        $global:stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    }
    elseif ($action -eq "STOP") {
        $global:stopwatch.stop()
    }
}


function q_match {
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
            $f = q_match $string $r
            if (($logic -eq "OR") -and $f) { return $true }
            if (($logic -eq "AND") -and !$f) { return $false }
        }
        return ($logic -eq "AND")
    }
    $found = $string -match $regex
    if ($found) {
        if ($getMatch) {
            return $Matches[0]
        }
        return $true
    }
    if ($getMatch) { return $null }
    return $false
}
function Get-MsiDatabaseVersion {
    param (
        [string] $fn
    )

    try {
        $FullPath = (Resolve-Path $fn).Path
        $windowsInstaller = New-Object -com WindowsInstaller.Installer

        $database = $windowsInstaller.GetType().InvokeMember(
            "OpenDatabase", "InvokeMethod", $Null, 
            $windowsInstaller, @($FullPath, 0)
        )

        $q = "SELECT Value FROM Property WHERE Property = 'ProductVersion'"
        $View = $database.GetType().InvokeMember(
            "OpenView", "InvokeMethod", $Null, $database, ($q)
        )

        $View.GetType().InvokeMember("Execute", "InvokeMethod", $Null, $View, $Null)

        $record = $View.GetType().InvokeMember(
            "Fetch", "InvokeMethod", $Null, $View, $Null
        )

        $productVersion = $record.GetType().InvokeMember(
            "StringData", "GetProperty", $Null, $record, 1
        )

        $View.GetType().InvokeMember("Close", "InvokeMethod", $Null, $View, $Null)

        return $productVersion

    }
    catch {
        throw "Failed to get MSI file version the error was: {0}." -f $_
    }
}
function q_version {
    [CmdletBinding()]
    param (
        [Parameter()]
        $app
    )
    if ($global:prolix) { Write-Host "`n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`nRetrieving $app file version`n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`n" -ForegroundColor DarkRed }
    if ($null -eq $app) { 
        Write-Host NullPointerException, passed argument app $app is null -ForegroundColor Red
        return  
    }
    if ($app -is [string]) {
        try {
            $app = get-item $app
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            Write-Host NullPointerException, item at $app not found -ForegroundColor Red
            return
        }
    }
    if ($app -isnot [System.IO.FileInfo]) {
        Write-Host Argument type $($path.GetType()) is not a valid type -ForegroundColor Red
        return
    }

    if ($app.name -match "\.exe$") {
        return $app.VersionInfo.FileVersion
    }
    elseif ($app.Name -match "\.msi$") {
        return Get-MsiDatabaseVersion $app
    }
}

function installed {
    [CmdletBinding()]
    param (
        [Parameter()]
        $app,
        [Parameter()] [switch]
        $allDrives,
        [Parameter()] [switch]
        $deep,
        [Parameter()] [switch]
        $exact,
        [Parameter()]
        $filter = "*.exe"
    )
    if ($app -is [System.Array]) {
        return installedBulk $app -allDrives:$allDrives -deep:$deep -exact:$exact -filter $filter
    }
    if ($app -is [System.IO.FileInfo]) {
        $app = $app.name
    }
    elseif ($app -is [System.IO.DirectoryInfo]) {
        $app = $app.name
    }
    if ($app -isnot [string]) {
        Write-Host Argument type $($filename.GetType()) is not a valid type -ForegroundColor Red
        return
    }
    if ($global:prolix) { Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`nChecking if $app is installed`n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor DarkRed }

    $standardLocations = @(
        "\Program Files"
        "\Program Files (x86)"
        "\Users\$ENV:USERNAME\Appdata\Roaming"
        "\Users\$ENV:USERNAME\Appdata\Local"
    )

    if ($allDrives) {
        $drives = (AllVolumes).volumes.driveLetter | ForEach-Object { return "$($_[0]):" }
    }
    else { $drives = @("C:") }



    $paths = $ENV:PATH -split ";"

    if ($global:prolix) { Write-Host "-------------------`n  > Querying ENV PATH" -ForegroundColor DarkCyan }
    foreach ($p in $paths) {
        $appName = $app -replace $(q_get_ext $app), ""
        if ($p -notmatch $appName) { continue }
        if ($global:prolix) { Write-Host "`n    < Querying $p >" -ForegroundColor DarkGray }
        $res = hquery $p -ErrorAction SilentlyContinue -filter $filter | Where-Object { ($exact -and ($_.name -match "^$appName\.[a-zA-Z]+$") ) -or ( !$exact -and ($_.name -match $appName)) } | Select-Object -First 1
        if ($null -ne $res) {
            return $res
        }
    }

    foreach ($d in $drives) {
        if ($global:prolix) { Write-Host "-------------------`n  > Querying $d - Shallow Sweeep" -ForegroundColor DarkCyan }
        for ($i = 1; $i -lt 6; $i++) {
            if ($global:prolix) { Write-Host "`n    < Depth $i >" -ForegroundColor DarkGray }
            $res = hquery "$d" -depth $i -ErrorAction SilentlyContinue -filter $filter | Where-Object { ($exact -and ($_.name -match "^$app\.[a-zA-Z]+$") ) -or ( !$exact -and ($_.name -match $app)) } | Select-Object -First 1
            if ($null -ne $res) {
                return $res
            }
        }
    }


    foreach ($d in $drives) {
        if ($global:prolix) { Write-Host "-------------------`n  > Querying $d - Mid Focused sweep" -ForegroundColor DarkCyan }
        for ($i = 6; $i -lt 10; $i++) {
            foreach ($l in $standardLocations) {
                if (!(Test-Path "$d$l") ) {
                    Write-Host "`n    < $l does not exist in $d >" -ForegroundColor DarkYellow
                    continue
                }
                if ($global:prolix) { Write-Host "`n    < Depth $i : Searching $d$l >" -ForegroundColor DarkGray }
                $res = hquery "$d$l" -depth $i -ErrorAction SilentlyContinue -filter $filter | Where-Object { ($exact -and ($_.name -match "^$app\.[a-zA-Z]+$") ) -or ( !$exact -and ($_.name -match $app)) } | Select-Object -First 1
                if ($null -ne $res) {
                    return $res
                }
            }
        }
    }

    if ($deep) {
        foreach ($d in $drives) {
            if ($global:prolix) { Write-Host "-------------------`n  > Querying $d - Deep Unfocused sweep" -ForegroundColor DarkCyan }
            for ($i = 6; $i -lt 20; $i++) {
                if ($global:prolix) { Write-Host "`n    < Depth $i >" -ForegroundColor DarkGray }
                $res = hquery "$d" -depth $i -ErrorAction SilentlyContinue -filter $filter | Where-Object { ($exact -and ($_.name -match "^$app\.[a-zA-Z]+$") ) -or ( !$exact -and ($_.name -match $app)) } | Select-Object -First 1
                if ($null -ne $res) {
                    return $res
                }
            }
        }
    }
}

function installedBulk {
    [CmdletBinding()]
    param (
        [Parameter()]
        $app,
        [Parameter()] [switch]
        $allDrives,
        [Parameter()] [switch]
        $deep,
        [Parameter()] [switch]
        $exact,
        [Parameter()]
        $filter = "*.exe"
    )
    if ($app -isnot [System.Array]) {
        Write-Host Argument type $($filename.GetType()) is not a valid type -ForegroundColor Red
        return
    }
    if ($global:prolix) { Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`nChecking if any of: $app is installed`n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" -ForegroundColor DarkRed }

    $standardLocations = @(
        "\Program Files"
        "\Program Files (x86)"
        "\Users\$ENV:USERNAME\Appdata\Roaming"
        "\Users\$ENV:USERNAME\Appdata\Local"
    )

    if ($allDrives) {
        $drives = (AllVolumes).volumes.driveLetter | ForEach-Object { return "$($_[0]):" }
    }
    else { $drives = @("C:") }



    $paths = $ENV:PATH -split ";"

    if ($global:prolix) { Write-Host "-------------------`n  > Querying ENV PATH" -ForegroundColor DarkCyan }
    foreach ($p in $paths) {
        foreach ($a in $app) {
            $appName = $a -replace $(q_get_ext $a), ""
            if ($p -notmatch $appName) { continue }
            if ($global:prolix) { Write-Host "`n    < Querying $p >" -ForegroundColor DarkGray }
            $res = hquery $p -ErrorAction SilentlyContinue -filter $filter | Where-Object { ($exact -and ($_.name -match "^$appName\.[a-zA-Z]+$") ) -or ( !$exact -and ($_.name -match $appName)) } | Select-Object -First 1
            if ($null -ne $res) {
                return $res
            }
        }
    }

    foreach ($d in $drives) {
        if ($global:prolix) { Write-Host "-------------------`n  > Querying $d - Shallow Sweeep" -ForegroundColor DarkCyan }
        for ($i = 1; $i -lt 6; $i++) {
            if ($global:prolix) { Write-Host "`n    < Depth $i >" -ForegroundColor DarkGray }
            $res = hquery "$d" -depth $i -ErrorAction SilentlyContinue -filter $filter | ForEach-Object {
                if ($exact) {
                    foreach ($a in $app) {
                        if ($_.name -match "^$a\.[a-zA-Z]+$") {
                            return $_
                        }
                    }
                }
                else {
                    foreach ($a in $app) {
                        if ($_.name -match $app) {
                            return $_
                        }
                    }
                } } | Select-Object -First 1
            if ($null -ne $res) {
                return $res
            }
        }
    }


    foreach ($d in $drives) {
        if ($global:prolix) { Write-Host "-------------------`n  > Querying $d - Mid Focused sweep" -ForegroundColor DarkCyan }
        for ($i = 6; $i -lt 10; $i++) {
            foreach ($l in $standardLocations) {
                if (!(Test-Path "$d$l") ) {
                    Write-Host "`n    < $l does not exist in $d >" -ForegroundColor DarkYellow
                    continue
                }
                if ($global:prolix) { Write-Host "`n    < Depth $i : Searching $d$l >" -ForegroundColor DarkGray }
                $res = hquery "$d$l" -depth $i -ErrorAction SilentlyContinue -filter $filter | ForEach-Object {
                    if ($exact) {
                        foreach ($a in $app) {
                            if ($_.name -match "^$a\.[a-zA-Z]+$") {
                                return $_
                            }
                        }
                    }
                    else {
                        foreach ($a in $app) {
                            if ($_.name -match $app) {
                                return $_
                            }
                        }
                    } } | Select-Object -First 1
                if ($null -ne $res) {
                    return $res
                }
            }
        }
    }

    if ($deep) {
        foreach ($d in $drives) {
            if ($global:prolix) { Write-Host "-------------------`n  > Querying $d - Deep Unfocused sweep" -ForegroundColor DarkCyan }
            for ($i = 6; $i -lt 20; $i++) {
                if ($global:prolix) { Write-Host "`n    < Depth $i >" -ForegroundColor DarkGray }
                $res = hquery "$d" -depth $i -ErrorAction SilentlyContinue -filter $filter | ForEach-Object {
                    if ($exact) {
                        foreach ($a in $app) {
                            if ($_.name -match "^$a\.[a-zA-Z]+$") {
                                return $_
                            }
                        }
                    }
                    else {
                        foreach ($a in $app) {
                            if ($_.name -match $app) {
                                return $_
                            }
                        }
                    } } | Select-Object -First 1
                if ($null -ne $res) {
                    return $res
                }
            }
        }
    }
}

function installedVersion {
    [CmdletBinding()]
    param (
        [Parameter()]
        $app,
        [Parameter()] [switch]
        $allDrives,
        [Parameter()] [switch]
        $deep,
        [Parameter()] [switch]
        $exact,
        [Parameter()]
        $filter = "*.exe"
    )
    
    $found = installed $app -allDrives:$allDrives -deep:$deep -exact:$exact -filter $filter
    if ($null -ne $found) {
        return q_version $found
    }
}

function ValueAtIndex {
    [CmdletBinding()]
    param (
        [Parameter()]
        $indexable,
        # Index
        [Parameter()]
        [int]
        $i,
        [Parameter()]
        [switch]
        $last,
        # Index
        [Parameter()]
        [int]
        $offset = 1
    )
    if (q_isnot $indexable @([string], [System.Array])) {
        Write-Host Argument type $($indexable.GetType()) is not a valid type -ForegroundColor Red
        return
    }
    $last = $last -or ($i -ge ($indexable.length))
    if ($last) {
        return $indexable[$indexable.length - $offset]
    }
    else {
        return $indexable[$i]
    }
}
New-Alias -Name ati -Value ValueAtIndex -Scope Global -Force

function get-pastcommand {
    [CmdletBinding()]
    param (
        [Parameter()]
        [int]
        $i = -1,
        [Parameter()]
        [switch]
        $last,
        [Parameter()]
        [string]
        $search,
        [Parameter()]
        $setDepth
    )
    if ($null -ne $setDepth) {
        if ($setDepth -match "def") {
            $global:commandSearchDepth = 100
        }
        else {
            $global:commandSearchDepth = $setDepth
        }
    }
    $commands = Get-Content (Get-PSReadlineOption).HistorySavePath
    if ($last) {
        return ati $commands -last -offset 2
    }
    elseif (!(q_nullemptystr $search)) {
        if ($null -eq $global:commandSearchDepth) { $global:commandSearchDepth = 100 }
        $commands = q_truncate $commands -fromStart ($commands.Length - $global:commandSearchDepth)
        return $commands | Select-String $search
    }
    elseif ($i -eq -1) {
        return $commands
    }
    else {
        return $commands[$i]
    }
    
}
New-Alias -Name pastcmd -Value get-pastcommand -Scope Global -Force

function q_get_sysinfo {

    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $quick = $false,
        [Parameter()]
        [switch]
        $out
    )

    $ErrorActionPreference = 'STOP'
    if ($prolix) { Write-Host "Logging System Information" -ForegroundColor DarkCyan } 
  
    $select = @("OS name", "Version", "Registered Owner", "Original Install Date", "System", "Physical Memory")
    if ($null -eq $global:systeminfo) { $global:systemInfo = SystemInfo }
    $osversion = ([string]($global:systemInfo | Select-String "OS Version")[0])
    $length = $osversion.length
    $versionNumber = $osversion.substring(($length - 5), 5)
    $versionInfo = $versionNumber
    if ($prolix) { Write-Host "    << Version Build: $VersionInfo >>" -ForegroundColor DarkGray } 

    $qsysInfo = $global:systemInfo | Select-String $select
    $qsysInfo = q_parseString $qsysInfo
    $userInfo = net users
    $userInfo = q_parseString $userInfo 
    $selectn = @("DNS Suffix Search List", "IPv4 Address", "Physical Address", "Connection-specific DNS Suffix", "adapter", "Media State", "lmco.com")
    if ($prolix) { Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~`n    Getting Network Info >>" -ForegroundColor DarkGray } 
    $networkInfo = ipconfig /all 
    $qnetworkInfo = $networkInfo | Select-String $selectn
    $qnetworkInfo = q_parseString $qnetworkInfo 
    if ($prolix) { Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~`n    Getting CPU Info >>" -ForegroundColor DarkGray } 
    $cpuinfo = GET-wmiobject -class Win32_Processor | Select-Object *
    $qcpuinfo = $cpuinfo | Select-Object MaxClockSpeed, Name, NumberOfCores
    $qcpuinfo = q_parseString $qcpuinfo 
    if ($prolix) { Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~`n    Getting Disk Info >>" -ForegroundColor DarkGray } 
    try {
        $diskInfo = Get-Partition | Where-Object { $_.DriveLetter -match "[a-zA-Z]" } | `
            Where-Object { $_.DiskID -NotMatch "apricorn" } | `
            Select-Object DriveLetter, @{n = "Capacity [GB]"; e = { [math]::Round($_.size / 1GB, 3) } }
        $diskInfo = q_parseString $diskInfo 
        $sumItems = Get-Partition | Where-Object { $_.DriveLetter -match "[a-zA-Z]" } | `
            Where-Object { $_.DiskID -NotMatch "apricorn" }
        [long]$sum = 0
        if ($PSVersionTable.PSVersion.Major -ge 3) {
            try {
                foreach ($item in $sumItems) { [long]$sum += [long]$item.size }
            }
            catch {
                Write-Host 'q_get_sysinfo ! System does not support automated conversion from int64 to int32' -ForegroundColor Red
            }
        }
    }
    catch {
        $diskItems = Get-WmiObject -class win32_diskdrive | Where-Object { $_.Model -NotMatch "apricorn" }
        $diskInfo = $diskItems | Select-Object DeviceId, Model, @{n = "Capacity [GB]"; e = { [math]::Round($_.size / 1GB, 3) } }
        $diskInfo = q_parseString $diskInfo 
        [long]$sum = 0
        foreach ($item in $diskItems) { 
            try {
                $itemSum = $item | Select-Object -expand size
                [long]$sum += [long]$itemSum 
            }
            catch {
            }
        }
    }
    
  
    $quickInfo = "
    $($qsysInfo)
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Friendly Version Name :: $($versionInfo)
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    $($userInfo)
    $($qnetworkInfo)
    $($qcpuinfo)
    $($diskInfo)

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~    
    Sum Capacity For All Disks :: $([math]::Round(($sum / 1GB), 3)) GB
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    From global.cfg :: 
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    //TODO

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    System Notes ::
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    //TODO

    "

    if ($quick) {
        $ErrorActionPreference = 'Continue'
        return $quickInfo
    }
  
    if ($prolix) { Write-Host "~~~~~~~~~~~~~~~~~~~~~~~~~`n    Getting Detailed Info >>" -ForegroundColor DarkGray } 
    $sysInfo = q_parseString $sysInfo 
    $networkInfo = q_parseString $networkInfo 
    $cpuinfo = q_parseString $cpuinfo 
    $userInfo = Get-WmiObject win32_UserAccount -Filter { LocalAccount="True" } | Select-Object *
    $userInfo = q_parseString $userInfo 
    $boardinfo = Get-WmiObject win32_baseboard  | Select-Object *
    $boardinfo = q_parseString $boardinfo 
    try {
        $volInfo = Get-Partition | `
            Where-Object { $_.DiskID -NotMatch "apricorn" } | `
            Select-Object `
            DriveLetter, `
            Type, `
        @{n = "Capacity [GB]"; e = { [math]::Round($_.size / 1GB, 3) } }, `
            DiskId
    }
    catch {
        $volInfo = Get-WmiObject -class win32_volume | `
            Where-Object { $_.Label -notmatch "apricorn" } | `
            Select-Object `
            Name, `
            Label, `
            FileSystem, `
        @{n = "Capacity [GB]"; e = { [math]::Round($_.capacity / 1GB, 3) } }, `
        @{n = "Freespace [GB]"; e = { [math]::Round($_.freespace / 1GB, 3) } }
    }
    $ErrorActionPreference = 'Continue'
    $volInfo = q_parseString $volInfo 0
    $driveInfo = "`n ~ DISK INFO ~`n"
    $driveInfo += $diskInfo
    $driveInfo += "`n ~ VOLUME INFO ~"
    $driveInfo += $volInfo
    $peripheralInfo = Get-WMIObject -Class Win32_PnPEntity | Select-Object Name, Status, PNPClass
    $peripheralInfo = q_parseString $peripheralInfo 
    
  
    $content = 
    "
    $(Get-Date)

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // QUICK INFO: $($env:ComputerName) //////////////////////////////////////////////////////////////////////
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    $($quickInfo)

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // SYSINFO: $($env:ComputerName) //////////////////////////////////////////////////////////////////////
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    $($sysInfo)

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // LOCAL USER INFO: $($env:ComputerName) //////////////////////////////////////////////////////////////
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    $($userInfo)

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // NETINFO: $($env:ComputerName) //////////////////////////////////////////////////////////////////////
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    $($networkInfo)

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // DISK/VOLUME INFO: $($env:ComputerName) /////////////////////////////////////////////////////////////
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    $($driveInfo)

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // PROCESSOR INFO: $($env:ComputerName) ///////////////////////////////////////////////////////////////
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    $($cpuinfo)

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // MOTHERBOARD INFO: $($env:ComputerName) /////////////////////////////////////////////////////////////
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    $($boardinfo)

    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    // PERIPHERAL INFO: $($env:ComputerName) //////////////////////////////////////////////////////////////
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    $($peripheralInfo)
    "

    if ($out) {
        $paths = @(
            "C:\Users\$ENV:USERNAME\.Powershell"
        )

        $date = (Get-Date).toString('ddMMMyyyy')
        $logdate = "sysinfo-$date.log"

        foreach ($p in $paths) {
            $logDir = "$p\$ENV:COMPUTERNAME"
            $log = new-item "$logDir\$logdate" -ErrorAction SilentlyContinue -force
            if ($null -eq $log) { $log = get-item  "$logDir\$logdate" }
        }
    }

    $ErrorActionPreference = 'Continue'
    if (!$prolix) {
        $global:logsys = $content
        return
    }
  
    return $content
}
New-Alias -Name logsys -Value q_get_sysinfo -Scope Global -Force