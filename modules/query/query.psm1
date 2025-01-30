function q_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Gray" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function q_debug_function ($function, $functionColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Gray" }
    Write-Host ">_ $function" -ForegroundColor $functionColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
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
    return $obj -isnot [type](__replace $class @("\[", "]"))
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

function Get-Resolution ([switch] $hashtable) {
    $res = Get-CimInstance CIM_VideoController | Where-Object { $_.CurrentHorizontalResolution } | Select-Object SystemName, CurrentHorizontalResolution, CurrentVerticalResolution | Foreach-Object { return @($_.CurrentHorizontalResolution, $_.CurrentVerticalResolution) }
    if($hashtable){
        return @{HorizontalResolution = $res[0]; VerticalResolution = $res[1] }
    } else {
        return $res
    }
}

function Get-DirectorySum {
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
New-Alias -Name dirsum -Value Get-DirectorySum -Scope Global -Force
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

function Get-AllVolumes {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $info,
        [Parameter()]
        [switch]
        $forceWMI,
        [Parameter()]
        [string]$expand
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
    
    if($IsLinux) {
        return Get-ChildItem /dev | Where-Object { $_.name -match "^s.+?[0-9]+" -and $_.group -eq "disk" }
    }
    
    if ($forceWMI) {
        $volumes = Get-WmiObject Win32_Volume | Where-Object { ($_.driveLetter -match "[A-Z]") -and (@("NTFS", "FAT32", "EXFAT") -contains $_.FileSystem) }
        $hash = @{ Function = "Get-WmiObject"; Volumes = $volumes }
        if($expand.toLower() -match "v(ol(ume(s)?)?)?") { return $hash.Volumes }
        elseif ($expand.toLower() -match "f((un|n)(c(tion)?)?)?") { return $hash.Function }
        elseif ($expand -ne "") { Write-Host "Unrecognized argument for -expand: $expand" }
        return $hash
    }
    try {
        $volumes = Get-Volume | Where-Object { ($_.driveLetter -match "[A-Z]") -and ($_.DriveType -match "Fixed|Removable") }
        $hash = @{ Function = "Get-Volume"; Volumes = $volumes }
        if($expand.toLower() -match "v(s)?$|vol(s)?$|volume(s)?$") { return $hash.Volumes }
        elseif ($expand.toLower() -match "f$|fn$|fun$|func$|foo$|function$") { return $hash.Function }
        elseif ($expand -ne "") { Write-Host "Unrecognized argument for -expand: $expand" }
        return $hash
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        $volumes = Get-WmiObject Win32_Volume | Where-Object { ($_.driveLetter -match "[A-Z]") -and (@("NTFS", "FAT32", "EXFAT") -contains $_.FileSystem) }
        $hash = @{ Function = "Get-WmiObject"; Volumes = $volumes }
        if($expand.toLower() -match "v(ol(ume(s)?)?)?") { return $hash.Volumes }
        elseif ($expand.toLower() -match "f((un|n)(c(tion)?)?)?") { return $hash.Function }
        elseif ($expand -ne "") { Write-Host "Unrecognized argument for -expand: $expand" }
        return $hash
    }
}
New-Alias -Name allvol -Value Get-AllVolumes -Scope Global -Force

function Invoke-Query {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]
        $vertical,
        [Parameter()]
        $path,
        [Parameter(ValueFromPipeline=$true)]
        $pipe,
        [Parameter()]
        [switch]
        $cache,
        [Parameter()]
        $filter,
        [Parameter()]
        [switch]
        $recurse,
        [Parameter()]
        [switch]
        $format,
        [Parameter()]
        $depth,
        [Parameter()]
        $name,
        [Parameter()]
        $content,
        [Parameter()]
        [switch]$reverse
    )

    if($vertical -and $reverse) {
        Write-Host "Cannot accept -vertical and -reverse switches together" -ForegroundColor Red;
        return
    }

    $global:QueryResult = $null
    
    if ($null -eq $path) { $path = "$(Get-Location)" }
    
    q_debug_function "Invoke-Query" DarkCyan
    q_debug "Parameters ~|
        vertical:$vertical
        path:$path 
        pipe:$pipe 
        filter:$filter
        recurse:$recurse
        depth:$depth
        name:$name
        content:$content" DarkGray

    if(($null -ne $name)-or($null -ne $content)){
        if($null -eq $set) {
            $set =  if ($vertical)  { vquery -Path $path -Filter $filter -Recurse:$recurse -Depth $depth }
                    elseif($reverse){ rquery -Path $path -Filter $filter }
                    else            { hquery -Path $path -Depth $depth -Filter $filter }
        }
        q_debug "Set ~|
        $set"
        $found = @()
        if(!$format){
            return $set | Foreach-Object {
                $name_ = $_.name
                $isDir_ = $_.PSisDirectory
                if(!$isDir_ -and ($null -ne $content)) { $content_ = Get-Content $_.fullname -Force -ErrorAction SilentlyContinue }
                if ($null -ne $name) {
                    if($name_ -match $name) { 
                        if($found -contains $_.fullname) { return }
                        if($cache) { if($null -eq $global:QueryResult) { $global:QueryResult = @($_) } else { $global:QueryResult += $_ } }
                        $found += $_.fullname
                        return $_ 
                        }
                }
                if (($null -ne $content) -and ($null -ne $content_)) {
                    if($content_ -match $content) {
                        if($found -contains $_.fullname) { return }
                        if($cache) { if($null -eq $global:QueryResult) { $global:QueryResult = @($_) } else { $global:QueryResult += $_ } }
                        $found += $_.fullname
                        return $_ 
                    }
                }
            }
        } else {
            $null = importhks nav
            Format-ChildItem $($set | Foreach-Object {
                $name_ = $_.name
                $isDir_ = $_.PSisDirectory
                if(!$isDir_ -and ($null -ne $content)) { $content_ = Get-Content $_.fullname -Force -ErrorAction SilentlyContinue }
                if ($null -ne $name) {
                    if($name_ -match $name) { 
                        if($found -contains $_.fullname) { return }
                        if($cache) { if($null -eq $global:QueryResult) { $global:QueryResult = @($_) } else { $global:QueryResult += $_ } }
                        $found += $_.fullname
                        return $_ 
                        }
                }
                if (($null -ne $content) -and ($null -ne $content_)) {
                    if($content_ -match $content) {
                        if($found -contains $_.fullname) { return }
                        if($cache) { if($null -eq $global:QueryResult) { $global:QueryResult = @($_) } else { $global:QueryResult += $_ } }
                        $found += $_.fullname
                        return $_ 
                    }
                }
            })
            return
        }
    }

    if  ($vertical) { vquery -Path $path -Filter $filter -Recurse:$recurse -Depth $depth }
    elseif  ($reverse) { rquery -Path $path -Filter $filter }
    else            { hquery -Path $path -Depth $depth -Filter $filter }
}
New-Alias -Name query -Value Invoke-Query -Scope Global -Force
function rquery {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$path,
        [Parameter()]
        [string]$filter = "*"
    )
    if ($path -eq "") { $path = "$(Get-Location)" }
    q_debug_function "vquery" DarkCyan
    q_debug "Parameters ~|
        path:$path 
        filter:$filter"
    $res = @()
    while($path -ne ""){
        $res += Get-ChildItem $path -Filter $filter
        $path = Split-Path $path
    }
    return $res
}

function vquery {
    [CmdletBinding()]
    param (
        [Parameter()]
        $path,
        [Parameter()]
        $filter,
        [Parameter()] [switch]
        $recurse,

        [Parameter()] [int]
        $depth = 0
    )
    if ($null -eq $path) { $path = "$(Get-Location)" }
    q_debug_function "vquery" DarkCyan
    q_debug "Parameters ~|
        path:$path 
        filter:$filter
        recurse:$recurse
        depth:$depth" DarkGray
    Get-ChildItem $path -Filter $filter -Recurse:$recurse -Depth $depth -Force -ErrorAction SilentlyContinue
}

function hquery {
    [CmdletBinding()]
    param (
        [Parameter()]
        $path,
        [Parameter()]
        $depth,
        [Parameter()]
        $filter
    )
    if($null -eq $depth){ $depth = 10 }
    $depth = [int] $depth
    q_debug_function "hquery" DarkCyan
    q_debug "Parameters ~|
        path:$path 
        filter:$filter
        depth:$depth" DarkGray
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
        Get-ChildItem $path -Depth $i -filter $filter -Force -ErrorAction SilentlyContinue
    }
}

function Start-BenchMark {
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

function Test-Installed {
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
        return Test-InstalledBulk $app -allDrives:$allDrives -deep:$deep -exact:$exact -filter $filter
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
        $drives = (Get-AllVolumes).volumes.driveLetter | ForEach-Object { return "$($_[0]):" }
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

    $i = 5
    foreach ($d in $drives) {
        if ($global:prolix) { Write-Host "-------------------`n  > Querying $d - Shallow Sweeep" -ForegroundColor DarkCyan }
        if ($global:prolix) { Write-Host "`n    < Depth $i >" -ForegroundColor DarkGray }
        $res = hquery "$d" -depth $i -ErrorAction SilentlyContinue -filter $filter | Where-Object { ($exact -and ($_.name -match "^$app\.[a-zA-Z]+$") ) -or ( !$exact -and ($_.name -match $app)) } | Select-Object -First 1
        if ($null -ne $res) {
            return $res
        }
    }

    foreach ($d in $drives) {
        if ($global:prolix) { Write-Host "-------------------`n  > Querying $d - Mid Focused sweep" -ForegroundColor DarkCyan }
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

    if ($deep) {
        $i = 20
        foreach ($d in $drives) {
            if ($global:prolix) { Write-Host "-------------------`n  > Querying $d - Deep Unfocused sweep" -ForegroundColor DarkCyan }
                if ($global:prolix) { Write-Host "`n    < Depth $i >" -ForegroundColor DarkGray }
            $res = hquery "$d" -depth $i -ErrorAction SilentlyContinue -filter $filter | Where-Object { ($exact -and ($_.name -match "^$app\.[a-zA-Z]+$") ) -or ( !$exact -and ($_.name -match $app)) } | Select-Object -First 1
            if ($null -ne $res) {
                return $res
            }
        }
    }
}

function Test-InstalledBulk {
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
        $drives = (Get-AllVolumes).volumes.driveLetter | ForEach-Object { return "$($_[0]):" }
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

    $i = 5
    foreach ($d in $drives) {
        if ($global:prolix) { Write-Host "-------------------`n  > Querying $d - Shallow Sweeep" -ForegroundColor DarkCyan }
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

    foreach ($d in $drives) {
        if ($global:prolix) { Write-Host "-------------------`n  > Querying $d - Mid Focused sweep" -ForegroundColor DarkCyan }
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

    $i = 20
    if ($deep) {
        foreach ($d in $drives) {
            if ($global:prolix) { Write-Host "-------------------`n  > Querying $d - Deep Unfocused sweep" -ForegroundColor DarkCyan }
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

function Get-InstalledVersion {
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
    
    $found = Test-Installed $app -allDrives:$allDrives -deep:$deep -exact:$exact -filter $filter
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
        $depth
    )
    if ($null -ne $depth) {
        if ($depth -match "def") {
            $global:commandSearchDepth = 100
        }
        else {
            $global:commandSearchDepth = $depth
        }
    }
    $commands = Get-Content (Get-PSReadlineOption).HistorySavePath
    $len = $commands.length
    if ($last) {
        return ati $commands -last -offset 2
    }
    elseif ($i -eq -1) {
        if ($null -eq $global:commandSearchDepth) { $global:commandSearchDepth = 100 }
	#$commands = $command[($len - $global:commandSearchDepth)..($len - 1)]
        $commands = __truncate $commands -fromStart ($len - $global:commandSearchDepth)
        return $commands | Select-String $search
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

function Get-Block ($command) {
    try {
        $ErrorActionPreference = 'Stop'
        $res = (Get-Command $command).ScriptBlock
        if($null -eq $res) { $res = (Get-Command $command).Definition }
        $ErrorActionPreference = 'Continue'
        return $res
    } catch {
        $ErrorActionPreference = 'Stop'
        $res = (Get-Command $command).Definition
        $ErrorActionPreference = 'Continue'
        return $res
    }

}
New-Alias -Name gtb -Value Get-Block -Scope Global -Force

function Convert-Units {
    param (
        [double]$Value,
        [string]$FromUnit,
        [string]$ToUnit
    )

    switch ("$FromUnit-$ToUnit") {
        "inches-mm"      { return $Value * 25.4 }
        "mm-inches"      { return $Value / 25.4 }
        "kg-lb"          { return $Value * 2.20462 }
        "lb-kg"          { return $Value / 2.20462 }
        "ml-floz"        { return $Value * 0.033814 }
        "floz-ml"        { return $Value / 0.033814 }
        "cm-inches"      { return $Value / 2.54 }
        "inches-cm"      { return $Value * 2.54 }
        "meters-feet"    { return $Value * 3.28084 }
        "feet-meters"    { return $Value / 3.28084 }
        "liters-gallons" { return $Value * 0.264172 }
        "gallons-liters" { return $Value / 0.264172 }
        default {
            Write-Error "Conversion from $FromUnit to $ToUnit is not supported."
            return $null
        }
    }
}
