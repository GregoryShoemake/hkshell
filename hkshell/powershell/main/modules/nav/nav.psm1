if ($null -eq $global:_nav_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_nav_module_location = $PSScriptRoot
    }
    else {
        $global:_nav_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}

$global:shortcuts = Get-Content "$global:_nav_module_location\nav.shortcuts.conf" 

function shct {
    foreach ($s in $global:shortcuts) {
        if(($null -eq $s) -or ($s -eq "")) { continue }
        if($null -eq $items) { $items = @(Get-Item $s -Force -ErrorAction SilentlyContinue) }
        else { $items += Get-item $s -Force -ErrorAction SilentlyContinue }
    }
    n_dir $items
}

$global:hidden_or_system = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System
function n_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "DarkYellow" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function n_debug_function ($function, $functionColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $functionColor) { $functionColor = "Yellow" }
    Write-Host ">_ $function" -ForegroundColor $functionColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function n_prolix ($message, $messageColor) {
    if (!$global:prolix) { return }
    if ($null -eq $messageColor) { $messageColor = "Cyan" }
    Write-Host $message -ForegroundColor $messageColor
}
function n_replace($string, $regex, [string] $replace) {
    if ($null -eq $string) {
        return $string
    }
    if ($null -eq $regex) {
        return $string
    }
    foreach ($r in $regex) {
        $string = $string -replace $r, $replace
    }
    return $string
}
function n_is ($obj, $class) {
    if ($null -eq $obj) { return $null -eq $class }
    if ($null -eq $class) { return $false }
    if ($class -is [System.Array]) {
        foreach ($c in $class) {
            if ($obj -is $c) { return $true }
        }
        return $false
    }
    return $obj -is [type](n_replace $class @("\[", "]"))
}
function n_int_eq {
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

function n_truncate {
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
        if (($i -gt $fromStart) -and !(n_int_eq $i $middle ) -and ($i -lt $fromEnd)) {
            $res += $array[$i]
        }
    }
    return $res
}

function n_nullemptystr ($nullable) {
    if ($null -eq $nullable) { return $true }
    if ($nullable -isnot [string]) { return $false }
    if ($nullable.length -eq 0) { return $true }
    for ($i = 0; $i -lt $nullable.length; $i++) {
        if (($nullable[$i] -ne " ") -and ($nullable[$i] -ne "`n")) { 
            return $false 
        }
    }
    return $true
}
function Test-Access($Path)
{
    try
    {
        $null = Get-ChildItem $path -ErrorAction Stop
        return $true
    }
    catch
    {
        return $false
    }
}
function Get-PathDepth ($path) {
    $split = $path -split "\\"
    for ($i = 0; $i -lt $split.length; $i++) {
        if (n_nullemptystr $split[$i]) {
            $split = n_truncate $split -indexAndDepth @($i, 1)
        }
    }
    return $split.length
}
function n_is ($obj, $class) {
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

function Get-ParentDirectory {
    [CmdletBinding()]
    param (
        [Parameter()]
        $path,
        [Parameter()]
        $until,
        [Parameter()]
        [int]$count = 0
    )
    if (n_nullemptystr $path) {
        $path = Get-Location
    }
    if (n_is $path  @([System.IO.FileInfo], [System.IO.DirectoryInfo])) {
        $path = $path.fullname
    }
    if ($count -gt 0){
        $path = Split-Path $path
        $count--
        return Get-ParentDirectory $path $count
    }
    return split-path $path
}
New-Alias -Name ".." -Value Get-ParentDirectory -Scope Global -Force
function n_pad ($string, $length, $padChar = " " ,[switch]$left) {
    n_debug_function "n_pad"
    n_debug "string:$string"
    n_debug "length:$length"
    n_debug "left:$left"
    if($null -eq $length) { $length = $string.length }
    $diff = $length - $string.length
    n_debug "difference:$diff"
    $pad = ""
    foreach ($i in $(1..$diff)) { $pad += $padChar }
    n_debug "pad:$pad | pad length: $($pad.length)"
    if($left) { $string = $pad + $string } else { $string = $string + $pad }
    $res = $string.substring(0,$length)
    n_debug_function "res:$res"
    return $res
}
function Format-ChildItem ($items, [switch]$cache) {
    if($cache) {$items = $global:QueryResult; $global:QueryResult = $null}
    $i = 0
    if($args -notcontains "-force") { $args += " -force" }
    $(if($null -eq $items) { invoke-expression "dir $args" } else { $items }) | Foreach-Object {
        $isDir = $_.psiscontainer
        $parent = if($isDir) { $_.parent.fullname } else { $_.directory.fullname }
        if($lastParent -ne $parent) {
            Write-Host "
            $parent
" -ForegroundColor DarkYellow
            $lastParent = $parent
            write-host "|_INDEX_|_TYPE__|_____LAST WRITE TIME_____|__NAME" -ForegroundColor DarkGray
        }
        $index = n_pad "[$i]" 7 " "
        $type = n_pad $(if($isDir){"[dir]"}else{"[file]"}) 7 " "
        $lastWrite = n_pad "$($_.lastwritetime)" 25 " " 
        $name = n_pad $_.name 80 " "
        if($isDir) {
            $canAccess = Test-Access $_.fullname
        } else {
            try { [IO.File]::OpenWrite($_.fullname).close();$canAccess = $true }
            catch { $canAccess = $false }
        }
        $sysOrHid = $_.Attributes -band $global:hidden_or_system
        write-host -nonewline "|" -ForegroundColor DarkGray
        write-host -nonewline $index
        write-host -nonewline "|" -ForegroundColor DarkGray
        write-host -nonewline $type -ForegroundColor $(if($isDir){"Cyan"}else{"DarkCyan"})
        write-host -nonewline "|" -ForegroundColor DarkGray
        write-host -nonewline $lastWrite
        write-host -nonewline "|" -ForegroundColor DarkGray
        write-host $name -ForegroundColor $(if($canAccess -and !$sysOrHid) { "Gray" } elseif ($canAccess -and $sysOrHidden) { "DarkGray" } elseif (!$sysOrHidden -and !$canAccess) { "Red" } else { "DarkRed" })
        $i++
    }
}
New-Alias -Name n_dir -Value Format-ChildItem -Scope Global -Force
New-Alias -Name fchi -Value Format-ChildItem -Scope Global -Force
function Show-Directories {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $path,
        [Parameter()]
        [switch]
        $D,
        [Parameter()]
        [int]
        $dep = 0

    )
    if (n_nullemptystr $path) {
        $path = "$(Get-Location)"
    }
    $path = Get-Path $path
    $depth = Get-PathDepth $path
    if ($depth -eq 1) {
        <#
        
        
        #>
        $curPrompt = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ChildItems of $path
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        Write-Host $curPrompt -ForegroundColor Blue
        n_dir $( Get-ChildItem $path -depth $dep -ErrorAction SilentlyContinue | Where-Object { ($_.psiscontainer -and $D) -or !$D } )
        <#
        
        
        #>
    }
    elseif ($depth -eq 2) {
        <#
        
        
        #>
        $par = .. $path
        $parPrompt = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ChildItems of $par
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        Write-Host $parPrompt -ForegroundColor Green
        $parC = Get-ChildItem $par
        foreach ($c in $parC) {
            if ($c.psiscontainer) { Write-Host $c.name -ForegroundColor DarkCyan }
            elseif (!$D) { Write-Host $c.name -ForegroundColor DarkGreen }
        }
        $curPrompt = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ChildItems of $path
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        Write-Host $curPrompt -ForegroundColor Blue
        n_dir $( Get-ChildItem $path -depth $dep -ErrorAction SilentlyContinue | Where-Object { ($_.psiscontainer -and $D) -or !$D } )
        <#
        
        
        #>
    }
    else {
        <#
        
        
        #>
        $par = .. $path
        $Gpar = .. $par

        $GparPrompt = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ChildItems of $Gpar
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        Write-Host $GparPrompt -ForegroundColor Red
        $GparC = Get-ChildItem $Gpar
        foreach ($c in $GparC) {
            if ($c.psiscontainer) { Write-Host $c.name }
        }

        $parPrompt = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ChildItems of $par
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        Write-Host $parPrompt -ForegroundColor Green
        $parC = Get-ChildItem $par
        foreach ($c in $parC) {
            if ($c.psiscontainer) { Write-Host $c.name -ForegroundColor DarkCyan }
            elseif (!$D) { Write-Host $c.name -ForegroundColor DarkGreen }
        }

        $curPrompt = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ChildItems of $path
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        Write-Host $curPrompt -ForegroundColor Blue
        n_dir $(Get-ChildItem $path -depth $dep -ErrorAction SilentlyContinue | Where-Object { ($_.psiscontainer -and $D) -or !$D })
        <#
        
        
        #>
    }
    write-host "






    "
}
New-Alias -Name 'D' -Value 'Show-Directories' -Scope Global -Force

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
            $f = g_match $string $r
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

function n_log {
    [CmdletBinding()]
    param (
        [Parameter()]
        $variable,
        [Parameter()]
        [int]
        $columns = 1,
        [Parameter()]
        $ForegroundColor = "Gray"
    )
    if ($variable -is [System.Array]) {
        for ($i = 1; $i -le $variable.length; $i++) {
            [int]$width = 130 / $columns
            $item = "$($variable[$i - 1])"
            while ($item.Length -lt $width) {
                $item += " "
            }
            $item = $item.Substring(0, $width)
            if ($i % $columns -eq 0) {
                Write-Host $item -ForegroundColor $ForegroundColor
            }
            else {
                Write-Host -NoNewline $item -ForegroundColor $ForegroundColor
            }
        }
    }
}

function Invoke-Go {
    [CmdletBinding()]
    param (
        [Parameter()]
        $in,
        [Parameter()]
        [switch]
        $C,
        [Parameter()]
        [switch]
        $A,
        [Parameter()]
        $Until
    )
    n_debug_function "Invoke-Query"

    if ($null -ne $Until) {

        $res = Get-ChildItem -Recurse $(Get-Location) | Where-Object { $_.psiscontainer } | Where-Object { $_.name -eq $Until }
        if ($null -eq $res) {
            $res = Get-ChildItem -Recurse $(Get-Location) | Where-Object { $_.psiscontainer } | Where-Object { $_.name -match $Until }
        }
        if ($null -eq $res) {
            Write-Host "Directory matching $Until not found" -ForegroundColor Yellow; return
        }
        if ($res.Count -gt 1) {
            Write-Host "Multiple matches for $Until" -ForegroundColor Yellow
            n_dir $res
            $index = Read-Host "Input index of desired directory: "
            $res = $res[$index]
        }
        return Invoke-Go $res.FullName

    }

    if($null -eq $in){$in = "$(Get-Location)"}
    $D = !$A
    if ($global:_debug_) { write-host " GO => $in`n  \ Create Missing Path? $C`n  \ Show All Item Types? $A" -ForegroundColor DarkGray }
    if ($in -eq "..") {
        $in = ..
    }
    elseif ($in -match "vol::(.+)::(.+)$") { $in = Get-Path $in }
    elseif ($null -ne $global:QueryResult) {
        n_debug "Parsing Query Results"
        if($in -match "^([0-9]+|f)$"){
            if($in -match "^f$"){$in = 0} 
            $in = $([int]$in) 
            if($global:QueryResult.length -le $in) { 
                Write-Host "Out of index for QueryResults: $in out of $(Query.Length)" -ForegroundColor Red
                return
            }
            $in = $global:QueryResult[$in]
            $global:QueryResult = $null
            return Invoke-Go $in.FullName -C:$C -A:$A
        }
        foreach ($s in $global:QueryResult) {
            $replaced = $s
            if ($replaced.name -match $in) {
                if ($null -eq $arr) { $arr = @($s) }
                else { $arr += $s }
                n_debug "   \ true"
            } else {
                n_debug "   \ false"
            }
        }
        if ($null -ne $arr) {
            if($arr.length -eq 1) { $in = $arr[0].fullname }
            elseif ($arr.length -gt 1) {
                Write-Host `nMultiple matches found:
                $i = 0
                foreach ($p in $arr) {
                    Write-Host "[$i] $($p.fullname)"
                    $i++
                }
                $i = [int](Read-Host "Pick index of desired path")
                $in = $arr[$i].$fullname
            }
        }
    }
    elseif (!(test-path $in)) {

        if ($global:_debug_) {
            write-host "`n~~~~~~~~~~`nShortcuts:`n" -ForegroundColor DarkCyan 
            n_log -columns 3 $global:shortcuts -ForegroundColor DarkGray 
            write-host "`n~~~~~~~~~~    `n" -ForegroundColor DarkCyan 
        }


        if($in -match "^([0-9]+|f)$"){
            if($in -match "^f$"){$in = 0} 
            n_debug "Parsing index: $in"
                $children = Get-ChildItem $(Get-Location) | Where-Object { $_.PSIsContainer }
                $in = $([int]$in) 
                $in = $children[$in]
                return Invoke-Go $in.FullName -C:$C -A:$A
        }

        foreach ($s in $global:shortcuts) {
            n_debug "Checking shortcut: $s ~? $in"
            if ($s -match $in) {
                
                if ($null -eq $arr) { $arr = @($s) }
                else { $arr += $s }
                n_debug "   \ true"
            } else {
                n_debug "   \ false"
            }
        }

        if ($null -ne $arr) {
            if($arr.length -eq 1) { $in = $arr[0] }
            elseif ($arr.length -gt 1) {
                Write-Host `nMultiple matches found:
                $i = 0
                foreach ($p in $arr) {
                    Write-Host "'[$i] $p"
                    $i++
                }
                $i = [int](Read-Host "Pick index of desired path")
                $in = $arr[$i]
            }
        }
    }

    $in = Get-Path $in
    if (Test-Path $in) {
        if($null -ne $global:project){
            if($null -eq $global:project.LastDirectory) {
                $global:project.add("LastDirectory",$in)
            } else {
                $global:project.LastDirectory = $in
            }
        }
        Set-Location $in
        D -D:$D
    }
    elseif ($C) {
        try {
            New-Item $in -ItemType Directory -force -ErrorAction Stop
            Set-Location $in -ErrorAction Stop
            D -D:$D
            if($null -ne $global:project){
                if($null -eq $global:project.LastDirectory) {
                    $global:project.add("LastDirectory",$in)
                } else {
                    $global:project.LastDirectory = $in
                }
            }
        } catch {
            Write-Error $_
        }
    }
    else {
        Write-Host Path: $in :does not exist -ForegroundColor Red
    }
}
New-Alias -Name 'G' -Value 'Invoke-Go' -Scope Global -Force

function Get-Path ([switch]$clip) {
    n_debug_function "Get-Path"
    n_debug "args:$args | argsLen:$($args.length)"
    $a_ = $args -join ""
    n_debug "argsJoined:$a_."
    $l_ = "$(Get-Location)"
    switch ($a_) {
        { ($_ -is [System.IO.FileInfo]) -or ($_ -is [System.IO.DirectoryInfo]) } {
            if ($clip) { Set-Clipboard $_.FullName } else { return $_.FullName }
        }
        { $_ -match "^match:.+$" } { 

            $regex = $($_ -split ":")[1]
            Get-ChildItem $l_ | Where-Object { $_.name -match $regex } | Foreach-Object {
                    if($null -eq $res){ $res = @($_.fullname) }
                    else { $res += ";$($_.fullname)" }
                }
             if ($clip) { Set-Clipboard $res } else { return $res }
        }
        { $_ -match "^[0-9]+$" } {
            $res = $(Get-ChildItem $l_)[$([int]$_)]
            if ($clip) { Set-Clipboard $res.fullname } else { return $res.fullname }
        }
        { $_ -match "vol::(.+)::(.+)"} {
            n_debug "parsing volume"
            $null = $a_ -match  "vol::(.+)::(.+)"
            $res =  "$(Get-Volume | Where-Object {$_.FileSystemLabel -eq $MATCHES[1] } | Select-Object -ExpandProperty DriveLetter ):$($MATCHES[2])"
            $res = $res -replace "(?!^)\\\\","\"
            n_debug "res:$res"
            if ($clip) { Set-Clipboard $res } else { return $res }
        }
        { Test-Path $_ } { 
            $res = $_ 
            if($res -notmatch "^(\\\\|[a-zA-Z]:\\)") { $res = "$pwd\$res" -replace "(?!^)\\\\","\" }
            if ($clip) { Set-Clipboard $res } else { return $res }
        }
        { !(Test-Path $_) } { 
            $res =  $_ -replace "(?!^)\\\\","\"
            if ($clip) { Set-Clipboard $res } else { return $res }
        }
        Default { if($clip) { Set-Clipboard $l_ } else { return $l_ } }
    }
}
New-Alias -Name gtp -Value Get-Path -Scope Global -Force
function Get-Root ($inputObject) {
    if($null -eq $inputObject) { $inputObject = "$(Get-Location)" } 
    if($inputObject -is [string]) {
        $inputObject = $inputObject -replace ".+::\\\\","\\"
        $pathLast = $inputObject
        $path = Split-Path $pathLast
        while(($path -ne "") -and ($path -notmatch "\\\\.+?(?!\\)")) {
            $pathLast = $path
            $path = Split-Path $pathLast
        }
        return $pathLast
    }
}
