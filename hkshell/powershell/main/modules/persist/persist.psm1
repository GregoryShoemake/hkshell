[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $arguments
)

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#   ~ ~  u t i l i t y   f u n c t i o n s  ~ ~   #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

#These functions allow this module to be completely independent of other modules, but still have 
#the legibility desired


$userDir = "~\.hkshell\persist"
if(!(Test-Path $userDir)) { mkdir $userDir }

function p_ehe {
    Write-Error 'administrative rights required to access host global cfg'
}

function p_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "DarkYellow" }
    Write-Host "    \\ $message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " #$meta# " -ForegroundColor Yellow
    }
}
function p_debug_function ($function, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Yellow" }
    Write-Host ">_ $function" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " #$meta# " -ForegroundColor Yellow
    }
}
function p_debug_return {
    if (!$global:_debug_) { return }
    Write-Host "#return# $($args -join " ")" -ForegroundColor Black -BackgroundColor DarkGray
    return
}
function p_default ($variable, $value) {
    p_debug_function "e_default"
    if ($null -eq $variable) { 
        p_debug_return variable is null
        return $value 
    }
    switch ($variable.GetType().name) {
        String { 
            if($variable -eq "") {
                p_debug_return
                return $value
            } else {
                p_debug_return
                return $variable
            }
        }
    }
}
function p_hash_to_string {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [HashTable[]]$HashTable
    )
    process {
        foreach ($item in $HashTable) {
            foreach ($entry in $item.GetEnumerator()) {
                "{0}={1}" -f $entry.Key, $entry.Value
            }
        }
    }
}
function p_int_equal {
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
function p_truncate {
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
    p_debug_function "p_truncate"
    p_debug "array:
$(Out-String -inputObject $array)//"

    $l = $array.Length
    if ($fromStart -gt 0) {
        $l = $l - $fromStart
    }
    if ($fromEnd -gt 0) {
        $l = $l - $fromEnd
    }
    elseif(($fromStart -eq 0) -and ($null -eq $indexAndDepth)) {
        $fromEnd = 1
    }
    $fromEnd = $array.Length - $fromEnd
    if (($null -ne $indexAndDepth) -and ($indexAndDepth[1] -gt 0)) {
        $l = $l - $indexAndDepth[1]
    }
    if ($l -le 0) {
        p_debug_return empty array
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
        if (($i -gt $fromStart) -and !(p_int_equal $i $middle ) -and ($i -lt $fromEnd)) {
            $res += $array[$i]
        }
    }
    p_debug_return $(Out-String -inputObject $res)
    return $res
}
function p_search_args ($a_, $param, [switch]$switch, [switch]$all, [switch]$untilSwitch) {
    p_debug_function "p_search_args"    
    $c_ = $a_.Count
    p_debug "args:$a_ | len:$c_"
    p_debug "param:$param"
    p_debug "switch:$switch"
    if($switch) { 
        for ($i = 0; $i -lt $c_; $i++) {
            $a = $a_[$i]
            p_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if($null -eq $res) { 
                $res = $true 
                $a_ = p_truncate $a_ -indexAndDepth @($i,1)
            }
            else {
                throw [System.ArgumentException] "Duplicate argument passed: $param"
            }
        }
        $res = $res -and $true
        p_debug_return "@{ RES=$res ; ARGS=$a_ }"
        return @{
            RES = $res
            ARGS = $a_
        }
    } else {
        for ($i = 0; $i -lt $a_.length; $i++) {
            $a = $a_[$i]
            p_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if(($null -eq $res) -and ($i -lt ($c_ - 1))) {
                if($all) {
                    $ibak = $i
                    $res = @()
                    $remove = 1
                    for ($i = $i + 1; $i -lt ($c_); $i++) {
                        if($untilSwitch -and ($a_[$i] -match "^-")) {
                            p_debug "[-untilSwitch] next switch found"
                            break
                        }
                        $res += $a_[$i]
                        $remove++
                    }
                    $res = $res -join " "
                    $a_ = p_truncate $a_ -indexAndDepth @($ibak, $remove)
                } else {
                    $res = $a_[$i + 1]
                    if($res -match "^-") { 
                        $res = $null 
                        p_debug "switch argument expected, not found" Red
                    } else {
                        $a_ = p_truncate $a_ -indexAndDepth @($i,2)
                    }
                }
            }
            elseif ($i -ge ($c_ - 1)) {
                 throw [System.ArgumentOutOfRangeException] "Argument value at position $($i + 1) out of $c_ does not exist for param $param"
            }
            elseif ($null -ne $res) {
                throw [System.ArgumentException] "Duplicate argument passed: $param"
            }
        }
        p_debug_return "@{ RES=$res ; ARGS=$a_ }"
        return @{
            RES = $res
            ARGS = $a_
        }
    }
}
function p_stringify_regex ($regex) {
    if ($null -eq $regex) { return $regex }
    $needReplace = @(
        "\\"
        "\@"
        "\~" 
        "\%"
        "\$" 
        "\&"
        "\^" 
        "\*"
        "\("
        "\)" 
        "\[" 
        "\]" 
        "\." 
        "\+" 
        "\?" 
    )
    foreach ($n in $needReplace) {
        $regex = $regex -replace $n, $n
    }
    return $regex
}

function p_npath ($path) { return !(test-path $path) }
function p_elevated { return (new-object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
function .. {
    [CmdletBinding()]
    param (
        [Parameter()]
        $path
    )
    if ($null -eq $path) { $path = "$(Get-Location)" }
    if ($path -is [string]) {
        $path = Split-Path $path
    }
    if ($path -is [System.IO.FileInfo]) {
        $path = $path.Directory.fullname
    }
    if ($path -is [System.IO.DirectoryInfo]) {
        $path = $path.parent.fullname
    }
    else {
        return $path
    }
}
function p_replace($string, $regex, [string] $replace) {
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
function p_for ([int]$iMax, [int]$jMax, [int]$kmax, [string] $startCommand, [string] $loopCommand, [string] $endCommand) {
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
function p_split ($string, $regex) {
    if ($null -eq $string) {
        return $string
    }
    if ($null -eq $regex) {
        return $string
    }
    if ($string -is [System.Array]) {
        for ($i = 0; $i -lt $string.length; $i++) {
            $string[$i] = p_split $string[$i] $regex
        }
        return $string
    }
    if ($regex -is [System.Array]) {
        foreach ($r in $regex) {
            $string = p_split $string $r
        }
        return $string
    }
    return $string -split $regex
}
function p_null {
    [CmdletBinding()]
    param (
        [Parameter()]
        $nullable
    )
    if ($null -eq $nullable) { return $true }
    if ($nullable -is [System.Array]) {
        foreach ($n in $nullable) {
            if ($null -ne $n) {
                return $false
            }
        }
        return $true
    }
    return $false
}
function p_nullemptystr ($nullable) {
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
function p_nonnull {
    [CmdletBinding()]
    param (
        [Parameter()]
        $nullable
    )
    if ($null -eq $nullable) { return $false }
    if ($nullable -is [System.Array]) {
        foreach ($n in $nullable) {
            if ($null -eq $n) {
                return $false
            }
        }
        return $true
    }
    return $true
}
function p_is ($obj, $class) {
    if ($null -eq $obj) { return $null -eq $class }
    if ($null -eq $class) { return $false }
    if ($class -is [System.Array]) {
        foreach ($c in $class) {
            if ($obj -is $c) { return $true }
        }
        return $false
    }
    return $obj -is [type](p_replace $class @("\[", "]"))
}

function p_between ($val, $min, $max) {
    if ($val -lt $min) { return $false }
    return $val -lt $max
}
function p_match {
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
        $logic = "OR", 
        [Parameter()]
        $index = 0
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
            return $Matches[$index]
        }
        return $logic -ne "NOT"
    }
    if ($logic -eq "NOT") { return $true }
    if ($getMatch) { return $null }
    return $false
}
function p_castString ($stringable) {
    if ($stringable -is [string]) { return $stringable }
    if ($null -eq $stringable) { return "" }
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        return Out-String -InputObject $stringable
    }
    elseif ($stringable -is [System.Array]) {
        return $stringable -join "`n"
    }
    else { return [string]$stringable }
}

function p_castBool ($boolable) {
    if ($boolable -is [boolean]) { return $boolable }
    if ($null -eq $boolable) { return $false }
    if ($boolable -is [string]) {
        return p_match $boolable  @("true", "yes", "y", "1")
    }
    if (p_is $boolable @([int], [long], [float], [double])) {
        return $boolable -gt 0
    }
    return $true
}

function p_castInt ($intable) {
    if ($intable -is [int]) { return $intable }
    if ($null -eq $intable) { return 0 }
    if (p_is $intable @([long], [float], [double], [string])) { return [int]$intable }
    if ($intable -is [boolean]) { if ($intable) { return 1 } else { return 0 } }
    if ($intable -is [System.Array]) { return $intable.length }
    return [int] $intable
}
function p_castFloat ($floatable) {
    if ($floatable -is [float]) { return $floatable }
    if ($null -eq $floatable) { return 0 }
    if (p_is $floatable @([long], [int], [double], [string])) { return [float]$floatable }
    if ($floatable -is [boolean]) { if ($floatable) { return 1 } else { return 0 } }
    if ($floatable -is [System.Array]) { return $intable.length }
    return [float] $floatable
}
function p_castLong ($longable) {
    if ($longable -is [long]) { return $longable }
    if ($null -eq $longable) { return 0 }
    if (p_is $longable @([int], [float], [double], [string])) { return [long]$longable }
    if ($longable -is [boolean]) { if ($longable) { return 1 } else { return 0 } }
    if ($longable -is [System.Array]) { return $intable.length }
    return [long] $longable
}
function p_castDouble ($doubleable) {
    if ($doubleable -is [double]) { return $doubleable }
    if ($null -eq $doubleable) { return 0 }
    if (p_is $doubleable @([long], [float], [int], [string])) { return [double]$doubleable }
    if ($doubleable -is [boolean]) { if ($doubleable) { return 1 } else { return 0 } }
    if ($doubleable -is [System.Array]) { return $intable.length }
    return [double] $doubleable
}
function p_castArray ($arrayAble) {
    if ($arrayAble -is [System.Array]) { return $arrayAble }
    if ($null -eq $arrayAble) { return $null }
    if ($arrayAble -is [string]) { 
        if ($arrayAble -match ":") {
            return $arrayAble -split ":"
        }
    }
    return @($arrayAble)
}

function p_castDateTime($datetimeable) {
    if ($datetimeable -is [datetime]) { return $datetimeable }
    if ($null -eq $datetimeable) { return $null }
    if ($datetimeable -isnot [string]) { 
        return [datetime] $datetimeable
    }
    $formats = @(
        "ddMMMyyyy@HHmm"
    )
    $ErrorActionPreference = 'STOP'
    foreach ($f in $formats) {
        try { $datetime = [datetime]::ParseExact($datetimeable, $f, $null) }
        catch { continue }
    }
    $ErrorActionPreference = 'CONTINUE'
    if ($null -eq $datetime) { $datetime = [datetime] $datetimeable }
    return $datetime
}
function p_cast ($cast, $var) {
    switch (p_replace $cast @("\[", "]")) {
        "boolean" { 
            return p_castBool $var
        }
        { p_match $_ @("int", "integer") } { 
            return p_castInt $var
        }
        "long" { 
            return p_castLong $var
        }
        "float" { 
            return p_castFloat $var
        }
        "double" { 
            return p_castDouble $var
        }
        "string" { 
            return p_castString $var
        }
        "datetime" { 
            return p_castDateTime $var
        }
        "array" { 
            return p_castArray $var
        }
        Default { return Invoke-Expression "$($cast + '"' + $var + '"')" }
    }
}
function p_parseNumber ($numberable) {
    if ($numberable -match "^[0-9]+(\.)?([0-9]+)?$") {
        if ($numberable -match "^[0-9]+$") {
            if ($numberable -le [int]::MaxValue -and $numberable -gt [int]::MinValue ) {
                return [int] $numberable
            }
            else {
                return [long] $numberable
            }
        }
        else {
            if ($numberable -le [float]::MaxValue -and $numberable -gt [float]::MinValue ) {
                return [float] $numberable
            }
            else {
                return [double] $numberable
            }
        }
    }
    return $numberable
}
function p_eq ($a_, $b_) {
    if ($b_ -is [System.Array]) {
        foreach ($b in $b_) {
            if ($a_ -eq $b) { return $true }
        }
        return $false
    }
    else { return $a_ -eq $b_ }
}

function p_getCast ([string]$line) {
    p_debug_function p_getCast darkyellow
    if ($line[0] -ne "[" ) { return }
    for ($i = 0; $i -lt $line.Length; $i++) {
        $cast += $line[$i]
        if ($line[$i] -eq "]") { 
            p_debug "cast: $cast" darkGray
            return $cast 
        }
    }
}

function p_compareVar ([string]$line, [string]$compare) {
    $j = 0;
    for ($i = 0; $i -lt $line.Length; $i++) {
        $letter = $line[$i]
        #p_debug "line[$i]=$letter <> compare[$j]=$($compare[$j]) | await:$await"
        if($letter -eq $await) { $await = $null; continue }
        if($null -ne $await) { continue }
        if($letter -eq "=") { return $compare.length -eq $j }
        if($letter -eq "[") { $await = "]"; continue }
        try {
            if($letter -ne $compare[$j]) { return $false }
        } catch { return $false }
        $j++
    }
    return $true
}

function p_getVal ($line, [switch]$array) {
    p_debug_function p_getVal darkyellow
    $d = -1
    $l = $line.length
    $val = ""
    if ($Null -eq $line) { return $null }
    for ($i = $l - 1; p_between $i -1 $l; $i += $d) {
        if ($d -eq 1) {
            $val += $line[$i]
        }
        elseif ($line[$i] -eq "=") { $d = 1 }
    }
    p_debug "val: $val" darkGray
    if($array){
        return $val -split ":"
    }
    return $val
}

function p_getLine ($content, $var) {
    p_debug_function p_getLine darkyellow
    $c_ = $content -split "`n"
    foreach ($c in $c_) {
        if ($null -eq $c) { continue }
        if ($c.trim() -eq "") { continue }
        if (p_compareVar $c $var) { 
            p_debug "line: $c" darkGray
            return $c 
        }
    }
}

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#   ~ ~      I N I T I A L I Z I N G        ~ ~   #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>


$arguments = $arguments -split ","
if ($arguments -isnot [System.Array]) { $arguments = @($arguments) } # Forcing this to be an array allows simplicity later on, i.e. not having to check

foreach ($arg in $arguments) {
    $split = $arg -split ":"
    switch ($split[0]) {
        Default {}
    }
}
if ($null -eq $global:_persist_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_persist_module_location = $PSScriptRoot
    }
    else {
        $global:_persist_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}

$global:p_error_action = "Continue"

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#               C O N S T A N T S                 #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

$global:SCOPES_PATH = "$global:_persist_module_location\persist.scopes.conf"
$global:INSTANCE_PATH = "$global:_persist_module_location\persist.cfg"
$global:INSTANCE_SCOPE = "INSTANCE::$global:INSTANCE_PATH"

function Invoke-Scopes ([switch]$rebuild){
    if(!(Test-Path $global:SCOPES_PATH) -or $rebuild) {
        p_debug "creating persist scopes file at $global:SCOPES_PATH"
        New-Item $global:SCOPES_PATH -ItemType File -Force
        p_debug "populating persist scopes file with default scopes"
        if(!(test-path "C:\Users\$ENV:USERNAME\contacts" )) { mkdir "C:\Users\$ENV:USERNAME\contacts" }
        if(!(test-path "C:\Users\$ENV:USERNAME\.ssh"  )) { mkdir "C:\Users\$ENV:USERNAME\.ssh" }
        Set-Content -Path $global:SCOPES_PATH -Value 'USER::C:\Users\$ENV:USERNAME\.powershell\persist.cfg
HOST::C:\Windows\System32\WindowsPowerShell\v1.0\persist.cfg
CONTACTS::C:\Users\$ENV:USERNAME\contacts\persist.cfg
SSH::C:\Users\$ENV:USERNAME\.ssh\persist.cfg'
    }
    p_debug 'pushing content to memory in variable $global:SCOPES'
    $global:SCOPES = Get-Content -Path $global:SCOPES_PATH
    $global:SCOPES += $global:INSTANCE_SCOPE
}
Invoke-Scopes

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#           Initializer Functions                 #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

function Set-Scope ([string]$scope="USER") {
    p_debug_function "Set-Scope"
    p_debug "scope:$scope"
    if($scope -eq "NETWORK"){
        $netScope = Invoke-Persist networkLocation
        if($null -eq $netScope) {
            Write-Host "A network location has not been set for $Global:SCOPE. Use the Invoke-Persist setNetworkDir>_ command to set a network location." -ForegroundColor Yellow
            return
        }
        if($netScope -notmatch "persist\.cfg$") {
            if($netScope -notmatch "\\$") { $netScope += "\" }
            $netScope += "persist.cfg"
        }
        $global:SCOPE = "NETWORK::$(persist networkLocation)"
    } else {
        $global:SCOPE = p_match $global:SCOPES "$scope.+" -getMatch
    }
    $spl = $global:SCOPE -split "::"
    $spl[1] = Invoke-Expression "$('"'+$spl[1]+'"')"
    $spl = $spl -join "::"
    $global:SCOPE = $spl
    $spl = $spl -split "::"
    if(!(Test-Path $spl[1])) { $null = New-Item $spl[1] -ItemType File -Force }
    $global:PERSIST = Get-Content $spl[1]
    if($global:PERSIST -is [System.Array]) { $global:PERSIST = $global:PERSIST -join "`n"}
}
p_debug "defaulting scope to user: $ENV:USERNAME"
Set-Scope

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#                   M A N U A L                   #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

if ($null -eq $env:global) {
    $global:man_persist = '
.SYNOPSIS


.DESCRIPTION


.USAGES

    global apiKey = ajf7rj1ml4lfda8s

    global [int] apiKey
    
'
    if (p_elevated) {
        [Environment]::SetEnvironmentVariable("PERSIST", $global:man_persist, [System.EnvironmentVariableTarget]::Machine)
    }
}

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#               F U N C T I O N S                 #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

function p_foo_parse ($parameters) {
    if ($parameters -notmatch ":") {
        write-host 'p_foo_parse ! Expected ":" between arguments' -ForegroundColor Red
        return
    }
    $split = $parameters -split ":"
    $var = $split[0]
    $cast = $split[1]
    $l_ = p_getLine $global:c_ $var
    $val = p_getVal $l_
    switch ($cast) {
        "[datetime]" { return p_castDateTime $val }
        "[int]" { return p_castInt $val }
        "[boolean]" { return p_castBool $val }
        Default {
            write-host 'p_foo_parse ! Invalid cast type, here are the currently supported casts:`n[datetime]     ' -ForegroundColor Red 
        }
    }
}

function p_foo_remove ($parameters) {
    if ($parameters -match ":") { $parameters = $parameters -split ":" }
    if ($parameters -is [System.Array]) {
        foreach ($p in $parameters) {
            p_foo_remove $p
        }
        return
    }
    switch ($parameters) {
            networkLocation { 
            write-host 'p_foo_remove ! Cannot remove networkLocation with remove:: command, use: > Invoke-Persist clearNetworkDir::' -ForegroundColor Yellow
            return
        }
        Default {
            $removeReg = "(^|`n)(\[[a-z]+])?$parameters=.+?(`n|$)"
            $content = $global:c_
            $global:PERSIST = $content -replace $removeReg, ""
        }
    }
}

function p_foo_search ($parameters) {
    $content = ($global:c_) -split "`n"
    if ($global:_debug_) { write-host "p_foo_search:`n  \ Scope:$global:_scope`n   \ var:$parameters" -ForegroundColor Green }
    return $($content | Where-Object { $_ -match $parameters })
}

function p_foo_setNetworkDir ($parameters) {
    p_debug_function "p_foo_setNetworkDir"
    p_debug "params:$parameters"
    $path = $parameters
    if (persist nonnull>_networkLocation) {
        write-host 'p_foo_setNetworkDir ! networkLocation already assigned ! clear with command first: > Invoke-Persist clearNetworkDir>_' -ForegroundColor Yellow
        return
    }
    if (!(test-path $path)) {
        Write-Host "Passed network directory: $path :does not exist" -ForegroundColor Yellow
        return
    }
    if($global:PERSIST -notmatch "`n$") {$global:PERSIST += "`n" }
    $global:PERSIST += "[string]networkLocation=$path"
}

function p_foo_clearNetworkDir {
    $line = p_getLine ($global:c_) networkLocation
    $v_ = p_getVal $line
    Remove-Item $v_ -ErrorAction SilentlyContinue -Force
    $line = p_stringify_regex $line
    $line = "(`n)?$line"
    if ($global:_debug_) { write-host "p_foo_clearNetworkDir:`n  \ Scope:$global:scope`n   \ Line:$line" -ForegroundColor Green }
    $global:PERSIST = $global:PERSIST -replace $line, ""
}

function p_foo_outOfDate ($parameters) {
    p_debug_function "p_foo_outOfDate"
    p_debug "params:$parameters"
    if ($parameters -notmatch ":") {
        write-host 'p_foo_outOfDate ! Expected ":" between arguments' -ForegroundColor Red
        return
    }
    $split = $parameters -split ":"
    $variable = $split[0]
    $DaysWithin = $split[1]
    $l_ = p_getLine $global:c_ $variable
    $v_ = p_getVal $l_
    if ($null -eq $v_) { return $true }
    $date = p_foo_parse "$($variable):[datetime]"
    return (($date.AddDays($DaysWithin)) -lt $(Get-Date))
}
function p_foo_upToDate ($parameters) {
    if ($parameters -notmatch ":") {
        write-host 'p_foo_upToDate ! Expected ":" between arguments' -ForegroundColor Red
        return
    }
    $split = $parameters -split ":"
    $variable = $split[0]
    $DaysWithin = $split[1]
    $l_ = p_getLine $global:c_ $variable
    $v_ = p_getVal $l_
    if ($null -eq $v_) { return $true }
    $date = p_foo_parse "$variable":[datetime]
    return (($date.AddDays($DaysWithin)) -ge $(Get-Date))
}
function p_foo_writeToday ($parameters) {
    $todayString = $((Get-Date).toString('ddMMMyyyy@HHmm'))
    Invoke-Persist [datetime]$parameters='''"'$todayString'"'''
}

function p_foo_writeDate ($parameters) {
    if ($parameters -notmatch ":") {
        write-host 'p_foo_writeToday ! Expected ":" between arguments' -ForegroundColor Red
        return
    }
    $split = $parameters -split ":"
    $variable = $split[0]
    $dateString = $split[1]

    $date = p_castDateTime $dateString
    $dateString = $(($date).toString('ddMMMyyyy@HHmm'))
    Invoke-Persist [datetime]$variable='''"'$dateString'"'''
}

function Get-Scope ([string]$scope, [switch]$exists) {
    $s_ = $global:scopes
    if($s_ -isnot [System.Array]) { $s_ = $s_ -split "`n" }
    if($scope -eq "") {
        return $global:scopes
    }
    foreach ($s in $global:scopes) {
        if($s -match "^$scope") {
            if($exists) {
                return $true       
            } else {
                return $s
            }
        }
    }
    if($exists) {
        return $false
    }
    else {
        return $null
    }
}

function Get-PersistItem ($inputScope){
    if ($null -eq $inputScope) { $inputScope = $global:SCOPE }
    $name = ($inputScope -split "::")[0] 
    $freshScope = p_match $global:SCOPES "$name.+" -getMatch
    $spl = $freshScope -split "::"
    $path = Invoke-Expression "$('"'+$spl[1]+'"')"
    return Get-Item $path
}
New-Alias -name p_item -Value Get-PersistItem -Scope Global -Force

function Get-PersistContent ($inputScope, [switch]$fromItem) {
    if($null -eq $inputScope) {
        if($fromItem)
        {
            return Get-Content (Get-PersistItem).fullname
        }
        else { return $global:PERSIST } 
    } else {
        return Get-Content (Get-PersistItem $inputScope).fullname
    }
}

function Invoke-PullWrapper {
    Invoke-Pull
    $a_ = $args -join " "
    if ($global:_debug_) { Write-Host "pull => args: $a_" -ForegroundColor Green }
    if (p_nullemptystr $a_) { return }
    return Invoke-Expression $a_
}

function Invoke-PushWrapper {
    $a_ = $args -join " "
    if ($global:_debug_) { Write-Host "push => args: $a_" -ForegroundColor Green }
    if (p_nullemptystr $a_) {
        Invoke-Push
        return 
    }
    $res = Invoke-Expression $a_
    Invoke-Push
    return $res
}

function Invoke-Push {
    $spl = $global:SCOPE -split "::"
    try {
        Set-Content -Path $spl[1] -Value $global:PERSIST -ErrorAction Stop
    } catch {
        Write-Host " << Failed to write to $global:SCOPE" -ForegroundColor Red
    }
}

function Invoke-Pull {
    $spl = $global:SCOPE -split "::"
    $global:PERSIST = Get-Content -Path $spl[1]
}
function p_network_wrapper {
    $scope_bak = ("$SCOPE" -split "::")[0]
    Invoke-Persist -> network
    $res = Invoke-Expression "$args"
    Invoke-Persist -> $scope_bak
    return $res
}
New-Alias -Name Use-Network -Value p_network_wrapper -Scope Global -Force
function p_scope_wrapper {
    $wrapper = $args[0]
    $argz = p_truncate $args -FromStart 1
    if(Get-Scope $wrapper -Exists) {
        $scope_bak = ("$SCOPE" -split "::")[0]
        Invoke-Persist -> $wrapper
        $res = Invoke-Expression "$argz"
        Invoke-Persist -> $scope_bak
        return $res
    }
}
New-Alias -Name Use-Scope -Value p_scope_wrapper -Scope Global -Force -ErrorAction SilentlyContinue
function Set-PersistContent ($params) {
    p_debug_function "Set-PersistContent"
    $cast = $params.Cast
    $var = $params.Name
    $val = $params.Value
    p_debug "cast:$cast"
    p_debug "var:$var"
    p_debug "val:$val"
    switch ($var) {
        networkLocation {         
            write-host 'Cannot set networkLocation with Invoke-Persist command directly, use: > persit setNetworkDir>_`"@{scope=$SCOPE;path=$PATH}"`' -ForegroundColor Yellow
        return
 }
        Default {
            $content = $global:c_
            $line = p_getLine $content $var
            $replace = "$cast$var=$val"
            if($null -ne $line) {
                $line = p_stringify_regex $line
                p_debug "replacing: $line => $replace"
                $global:PERSIST = $content -replace $line, $replace
            } else {
                p_debug "adding: $replace"
                if($global:PERSIST.Length -gt 0) { $global:PERSIST += "`n" }
                $global:PERSIST += $replace
            }
        }
    }
    return p_getLine $global:PERSIST $var
}

function p_add {
    [CmdletBinding()]
    param (
        [Parameter()]
        $params
    )
    p_debug_function p_add Blue
    p_debug "params:$(p_hash_to_string $params)" darkGray
    $var = $params.Name
    $n = $params.Value
    $l_ = p_getLine $global:c_ $var
    $cast = p_default $params.Cast $(p_getCast $l_) 
    $val = p_getVal $l_
    switch ($cast) {
        {$_ -match "^array$|^\[array]$"}{ 
            $res = "$($val):$n"
        }
        Default {
            $val = p_parseNumber $val
            $n = p_parseNumber $n
            $res = $val + $n
        }
    }
    p_debug "original value: $val | additive: $n | result:$res | cast:$cast" DarkGray
    p_debug_return
    if ($null -ne $cast) { return p_cast $cast $res } else { return $res }
}

function p_minus {
    [CmdletBinding()]
    param (
        [Parameter()]
        $params
    )
    p_debug_function p_minus Blue
    p_debug "params:$(p_hash_to_string $params)" darkGray
    $var = $params.Name
    $n = $params.Value
    $l_ = p_getLine $global:c_ $var
    $cast = p_default $params.Cast $(p_getCast $l_) 
    $val = p_getVal $l_
    $val = p_parseNumber $val
    $n = p_parseNumber $n
    if($val -match ".+?:.+?") {
        $res = $val -replace $n,""
        $res = $res -replace "::",":"
    } else {
        $res = $val - $n
    }
    p_debug "original value: $val | reductive: $n | result:$res | cast:$cast" DarkGray
    if ($null -ne $cast) { return p_cast $cast $res } else { return $res }
}

function p_multiply {
    [CmdletBinding()]
    param (
        [Parameter()]
        $params
    )
    p_debug_function p_multiply Blue
    p_debug "params:$(p_hash_to_string $params)" darkGray
    $var = $params.Name
    $n = $params.Value
    $l_ = p_getLine $global:c_ $var
    $cast = p_default $params.Cast $(p_getCast $l_) 
    $val = p_getVal $l_
    $val = p_parseNumber $val
    $n = p_parseNumber $n
    $res = $val * $n
    p_debug "original value: $val | multiplier: $n | result:$res | cast:$cast" DarkGray
    if ($null -ne $cast) { return p_cast $cast $res } else { return $res }
}

function p_divide {
    [CmdletBinding()]
    param (
        [Parameter()]
        $params
    )
    p_debug_function p_divide Blue
    p_debug "params:$(p_hash_to_string $params)" darkGray
    $var = $params.Name
    $n = $params.Value
    $l_ = p_getLine $global:c_ $var
    $cast = p_default $params.Cast $(p_getCast $l_) 
    $val = p_getVal $l_
    $val = p_parseNumber $val
    $n = p_parseNumber $n
    $res = $val / $n
    p_debug "original value: $val | dividend: $n | result:$res | cast:$cast" DarkGray
    if ($null -ne $cast) { return p_cast $cast $res } else { return $res }
}

function p_exponentiate {
    [CmdletBinding()]
    param (
        [Parameter()]
        $params
    )
    p_debug_function p_exponentiate Blue
    p_debug "params:$(p_hash_to_string $params)" darkGray
    $var = $params.Name
    $n = $params.Value
    $l_ = p_getLine $global:c_ $var
    $cast = p_default $params.Cast $(p_getCast $l_) 
    $val = p_getVal $l_
    $val = p_parseNumber $val
    $n = p_parseNumber $n
    $res = [Math]::Pow($val, $n)
    p_debug "original value: $val | exponent: $n | result:$res | cast:$cast" DarkGray
    if ($null -ne $cast) { return p_cast $cast $res } else { return $res }
}

function eep ($set) {
    if ($set -eq "stop") {
        $global:ErrorActionPreference = "Stop" 
    }
    elseif ($set -eq "go") {
        $global:ErrorActionPreference = "Continue"
    }
    elseif ($ErrorActionPreference -eq "Continue") {
        $global:ErrorActionPreference = "Stop"
    }
    elseif ($ErrorActionPreference -eq "Stop") {
        $global:ErrorActionPreference = "Continue"
    }
}

function p_not_choice ($msg, $y, $n) {
    return !(p_choice $msg $y $n)
}

function p_choice ($msg, $y, $n) {
    if ($null -eq $y) { $y = "Y" }
    if ($null -eq $n) { $n = "N" }
    if ($null -eq $msg) { $msg = "Continue?" }
    $msg += "($y/$n)"
    $res = Read-Host $msg
    while (($res -ne "Y") -and ($res -ne "N")) {
        Write-Host "Invalid input, submit either $y or $n" -ForegroundColor Yellow
    }
    return $res -eq $y
}

function p_foo ($name, $params) {
    p_debug_function p_foo Magenta
    p_debug "name:$name" darkGray
    p_debug "params:$params" darkGray
    switch ($name) {
        assign { 
            $split = $params -split ":"
            if ($split.length -gt 3) {
                for ($i = 3; $i -lt $split.length; $i++) {
                    $split[2] += "$(':' + $split[$i])"
                }
            }
            return Set-PersistContent @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        add { 
            $split = $params -split ":"
            if ($split.length -gt 3) {
                for ($i = 3; $i -lt $split.length; $i++) {
                    $split[2] += "$(':' + $split[$i])"
                }
            }
            return p_add @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        add_assign { 
            $split = $params -split ":"
            if ($split.length -gt 3) {
                for ($i = 3; $i -lt $split.length; $i++) {
                    $split[2] += "$(':' + $split[$i])"
                }
            }
            $val = p_add @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            if($val -is [System.Array]) { $val = $val -join ":" } 
            return Set-PersistContent @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        minus { 
            $split = $params -split ":"
            if ($split.length -gt 3) {
                for ($i = 3; $i -lt $split.length; $i++) {
                    $split[2] += "$(':' + $split[$i])"
                }
            }
            return p_minus @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        minus_assign { 
            $split = $params -split ":"
            if ($split.length -gt 3) {
                for ($i = 3; $i -lt $split.length; $i++) {
                    $split[2] += "$(':' + $split[$i])"
                }
            }
            $val = p_minus @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return Set-PersistContent @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        multiply { 
            $split = $params -split ":"
            if ($split.length -gt 3) {
                for ($i = 3; $i -lt $split.length; $i++) {
                    $split[2] += "$(':' + $split[$i])"
                }
            }
            return p_multiply @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        multiply_assign { 
            $split = $params -split ":"
            if ($split.length -gt 3) {
                for ($i = 3; $i -lt $split.length; $i++) {
                    $split[2] += "$(':' + $split[$i])"
                }
            }
            $val = p_multiply @{ Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return Set-PersistContent @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        divide { 
            $split = $params -split ":"
            if ($split.length -gt 3) {
                for ($i = 3; $i -lt $split.length; $i++) {
                    $split[2] += "$(':' + $split[$i])"
                }
            }
            return p_divide @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        divide_assign { 
            $split = $params -split ":"
            if ($split.length -gt 3) {
                for ($i = 3; $i -lt $split.length; $i++) {
                    $split[2] += "$(':' + $split[$i])"
                }
            }
            $val = p_divide @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return Set-PersistContent @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        exponentiate { 
            $split = $params -split ":"
            if ($split.length -gt 3) {
                for ($i = 3; $i -lt $split.length; $i++) {
                    $split[2] += "$(':' + $split[$i])"
                }
            }
            return p_exponentiate @{ Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        exponentiate_assign { 
            $split = $params -split ":"
            if ($split.length -gt 3) {
                for ($i = 3; $i -lt $split.length; $i++) {
                    $split[2] += "$(':' + $split[$i])"
                }
            }
            $val = p_exponentiate @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return Set-PersistContent @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        { p_eq $_ @("void", "_") } {
            $null = Invoke-Expression "persist $params"
        }
        insert {
            $split = $params -split ":"
            $l_ = p_getLine $global:c_ $split[0]
            $v_a = p_getVal $l_ -Array
            $v_a[$split[1]] = $split[2]
            $v_a = $v_a -join ":"
            if(p_nullemptystr $v_a){
                Write-Host "!_Value cannot be null_____!`n`n$_`n" -ForegroundColor Red
                return
            }
            return Set-PersistContent @{Cast = "[array]"; Name = $split[0]; Value = $v_a }

        }
        { p_match $_ @("pushinsert","pin") } {
            $split = $params -split "="
            $i_a = p_match $split[0] "\[([0-9]+)" -index 1 -get
            p_debug "i_a:$i_a"
            $a = $split[0] -replace "\[[0-9]+]",""
            p_debug "a:$a"
            $i_b = p_match $split[1] "\[([0-9]+)" -index 1 -get
            p_debug "i_b:$i_b"
            $b = $split[1] -replace "\[[0-9]+]",""
            p_debug "b:$b"
            if(p_nullemptystr @($a,$i_a,$b,$i_b)){
                Write-Host "!_Invalid parameters: $params :_____!`n`n$_`n" -ForegroundColor Red
                return
            }
            $l_ = p_getLine $global:c_ $b
            $v_a = p_getVal $l_ -Array
            p_debug "v_a_b:$v_a"
            return p_foo insert $a':'$i_a':'$($v_a[$i_a])
        }
        nullOrEmpty { 
            $l_ = p_getLine $global:c_ $params
            $v_ = p_getVal $l_
            return $null -eq $v_  
        }
        { p_eq $_ @("nonnull", "nn") } { 
            $l_ = p_getLine $global:c_ $params
            $v_ = p_getVal $l_
            return $null -ne $v_ 
        }
        { p_eq $_ @("remove", "rm") } {
            return p_foo_remove $params 
        }
        { p_eq $_ @("search", "find") } { 
            return p_foo_search $params 
        }
        setNetworkDir { 
            return p_foo_setNetworkDir $params 
        }
        clearNetworkDir { 
            return p_foo_clearNetworkDir $params 
        }
        outOfDate { 
            return p_foo_outOfDate $params 
        }
        upToDate { 
            return p_foo_upToDate $params 
        }
        writeToday { 
            return p_foo_writeToday $params 
        }
        writeDate { 
            return p_foo_writeDate $params 
        }
        parse { 
            return p_foo_parse $params 
        }
        equal { 
            $split = $params -split ":"
            foreach ($s in $split) {
                $l_ = p_getLine $global:c_ $s
                $v_ = p_getVal $l_
                if ($null -ne $last) {
                    if ($v_ -ne $last) { return $false }
                }
                $last = $v_
            }
            return $true
        }
        match { 
            $split = $params -split ":"
            foreach ($s in $split) {
                $l_ = p_getLine $global:c_ $s
                $v_ = p_getVal $l_
                if ($null -ne $last) {
                    if ($v_ -notmatch $last) { return $false }
                }
                $last = $v_
            }
            return $true
        }
        clip { 
            $l_ = p_getLine $global:c_ $params
            $v_ = p_getVal $l_
            Set-Clipboard $v_
        }
        setall { 
            $split = $params -split "="
            $names = $split[0] -split ":"
            $v_ = $split[1]
            foreach ($name in $names) {
                $ct_ = p_getCast $name
                $nm_ = $name -replace $cast, ""
                Set-PersistContent @{Cast = $ct_ ; Name = $nm_; Value = $v_ }
            }
        }
        { p_eq $_ @("sz", "len", "length", "size") } { 
            $l_ = p_getLine $global:c_ $params
            $v_ = p_getVal $l_
            $c_ = p_getCast $l_
            $p_ = p_cast $c_ $v_
            return $p_.length
        }
        { p_eq $_ @("def", "default") } {
            $split = $params -split ":"
            $l_ = p_getLine $global:c_ $split[0]
            $v_ = p_getVal $l_
            if (($null -eq $v_) -or ($v_ -eq "")) {
                $ct_ = p_getCast $split[0]
                $nm_ = $split[0] -replace $ct_, ""
                $v_ = $split[1]
                $l_ = Set-PersistContent @{Cast = $ct_ ; Name = $nm_; Value = $v_ }
            }
            return $v_
        }
        split {
            $split = $params -split "="
            $l_ = p_getLine $global:c_ $split[0]
            $v_ = p_getVal $l_
            if($null -eq $v_) { return $null }
            $split = $v_ -split $split[1]
            return $split
        }
        addScope {
            p_debug_function "addScope"
            if($params -match "vol::") {
                $null = importhks nav
                $appendVol = $true
                $volSyn = p_match $params "(vol::.+?::\\.+?)(::|$)" -getmatch -index 1
                $volPath = Get-Path $volSyn
                $params = $params -replace (p_stringify_regex $volSyn),"vol"
            }
            $spl = $params -split "::"
            if(($spl.count -ne 2) -and ($spl.count -ne 3)) {
                return p_throw IllegalArgumentException "[SCOPE]::[PATH](::[(Y)es])?" $params
            }
            $name = $spl[0]
            $path = $spl[1]
            if($appendVol) { 
                [string]$path = $volPath
            }
            $yesno = p_default $spl[2] "no"
            p_debug "split: [0]$($spl[0]) [1]$($spl[1]) [2]$($yesno)"
            $yesno = if($yesno.toLower() -match "^(y|yes)$") { $true } else { $false }
            if($path -notmatch "persist\.cfg$") {
                if($path -notmatch "\\$") { $path += "\" }
                $path += "persist.cfg"
            }
            p_debug "YesNo:$yesNo"
            if(!(Test-Path $path)) {
                if($yesno)
                { 
                    $null = New-Item -Path $path -Force 
                }
                elseif(p_choice "`n$path doesn't exist, create it?")
                { 
                    $null = New-Item -Path $path -Force 
                }
                else { 
                    Write-Host "$path does not exist" -ForegroundColor Red
                    return
                }
            }
            Add-Content $global:SCOPES_PATH "$name::$path"
            Add-Content $path "[string]scopeInfo=$name::$path`n"
            Invoke-Scopes
            Set-Scope $spl[0]
        }
        { $_ -match "^(cat|content|get-content)$"} {
            $l_ = p_getLine $global:c_ $params
            $v_ = (p_getVal $l_) -replace "(?!^)\\\\","\" -replace "\\$",""
            if($v_ -match "^vol::") {
                try {
                    $null = Import-HKShell nav -ErrorAction Stop
                } catch {
                    Write-Host "!__Failed to import hkshell navigation module___!`n`n$_`n" -ForegroundColor Red
                    return
                }
                $v_ = Get-Path $v_
            }
            try {
                return Get-Content $v_ -Force -ErrorAction Stop
            } catch {
                Write-Host "!___Failed to get content from $($v_)___!`n`n$_`n" -ForegroundColor Red
                return
            }
        }
        pop {
            $s_ = $params -split ":"
            if($s_.Count -eq 3){
                $source = $s_[0]
                $index = $s_[1]
                $destination = $s_[2]
                $l_ = p_getLine $global:c_ $source
                $v_ = p_getVal $l_ -Array
                if($v_ -is [System.Array] -and $v_.Count -gt $index){
                    $pop = $v_[$index]
                    $v_ = p_truncate $v_ -indexAndDepth @($index,1)
                    Invoke-Persist _>_ [array] "$source" = $($v_ -join ":")
                } else {
                    Write-Host "!_$index is invalid for array: $v_ _____!`n`n$_`n" -ForegroundColor Red
                    return
                }
                Invoke-Persist Push>_ "$($destination):$pop"
            } elseif($s_.Count -eq 2) {
                $source = $s_[0]
                $destination = $s_[1]
                $l_ = p_getLine $global:c_ $source
                $v_ = p_getVal $l_ -Array
                if($v_ -is [System.Array] -and $v_.Count -gt 1){
                    $pop = $v_[($v_.count - 1)]
                    $v_ = p_truncate $v_ -fromEnd 1
                    Invoke-Persist _>_ [array] "$source" = $($v_ -join ":")
                } elseif($null -ne $v_) {
                    $pop = $v_
                    Invoke-Persist Remove>_ "$source"
                } else {
                    Write-Host "!_$source is empty/null_____!`n`n$_`n" -ForegroundColor Red
                    return
                }
                Invoke-Persist Push>_ "$($destination):$pop"
            } elseif ($s_.Count -eq 1) {
                $l_ = p_getLine $global:c_ $s_
                $v_ = p_getVal $l_ -Array
                if($v_ -is [System.Array] -and $v_.Count -gt 1){
                    $pop = $v_[($v_.count - 1)]
                    $v_ = p_truncate $v_ -fromEnd 1
                    Invoke-Persist _>_ [array] "$s_" = $($v_ -join ":")
                } elseif ($null -ne $v_) {
                    $pop = $v_
                    Invoke-Persist Remove>_ "$s_"
                } else {
                    Write-Host "!_$s_ is empty/null_____!`n`n$_`n" -ForegroundColor Red
                    return
                }
                return $pop
            } else {
                Write-Host "!_Invalid Argument Format: $params :_____!`n`n$_`n" -ForegroundColor Red
                return
            }
        }
        push {
            $s_ = $params -split ":"
            if($s_.Count -eq 3){
                $destination = $s_[0]
                $in = $s_[1]
                $index = $s_[2]
                if(Invoke-Persist nullOrEmpty>_ "$destination") { 
                    for ($i = 0; $i -lt $index; $i++) {
                        $in = "null:$in"
                    }
                } else {
                    $l_ = p_getLine $global:c_ $destination
                    $v_ = p_getVal $l_
                    $v_a = $v_ -split ":"
                    $c_ = $v_a.Count
                    if($c_ -lt $index) {
                        for ($i = $c_; $i -lt $index; $i++) {
                            $v_ = "$($v_):null"
                        }
                        $in = "$($v_):$in"
                    } elseif ($c_ -eq $index) {
                        $in = "$($v_):$in"
                    } else {
                        $a = $v_a[0..$($index - 1)]
                        $b = $v_a[$index..$($c_ - 1)]
                        $in = $a + $in + $b
                        $in = $in -join ":"
                    }
                }
                Invoke-Persist _>_ [array] $destination = $in
            }
            elseif($s_.Count -eq 2){
                $destination = $s_[0]
                if($destination.toLower -eq "_"){
                    return
                }
                $in = $s_[1]
                if(Invoke-Persist nullOrEmpty>_ "$destination") {
                    Invoke-Persist _>_ [array] $destination = $in
                } else {
                    Invoke-Persist _>_ [array] $destination += $in
                }
            } else {
                Write-Host "!_Invalid Argument Format: $params :_____!`n`n$_`n" -ForegroundColor Red
                return
            }
        }
        pushadd {
            $s_ = $params -split ":"
            if($s_.Count -gt 1){
                Write-Host "!_Invalid Argument Format: $params :_____!`n`n$_`n" -ForegroundColor Red
                return
            }
            [double]$b = Invoke-Persist Pop>_ "$params"
            [double]$a = Invoke-Persist Pop>_ "$params"
            Invoke-Persist Push>_ "$($params):$($a+$b)"
        }
        pushsub {
            $s_ = $params -split ":"
            if($s_.Count -gt 1){
                Write-Host "!_Invalid Argument Format: $params :_____!`n`n$_`n" -ForegroundColor Red
                return
            }
            [double]$b = Invoke-Persist Pop>_ "$params"
            [double]$a = Invoke-Persist Pop>_ "$params"
            Invoke-Persist Push>_ "$($params):$($a-$b)"
        }
        pushcompare {
            $s_ = $params -split ":"
            if($s_.Count -ne 2){
                Write-Host "!_Invalid Argument Format: $params :__Expected_: [name]:[logicalOperator] :_____!`n`n$_`n" -ForegroundColor Red
                return
            }
            $source = $s_[0]
            p_debug "source;$source"
            $op = $s_[1]
            p_debug "op;$op"
            $b = Invoke-Persist Pop>_ "$source"
            p_debug "a;$a"
            $a = Invoke-Persist Pop>_ "$source"
            p_debug "b;$b"
            switch ($op) {
                gt { $res = $(p_castInt $a) -gt $(p_castInt $b) }
                ge { $res = $(p_castInt $a) -ge $(p_castInt $b) }
                eq { $res = $(p_castInt $a) -eq $(p_castInt $b) }
                le { $res = $(p_castInt $a) -le $(p_castInt $b) }
                lt { $res = $(p_castInt $a) -lt $(p_castInt $b) }
                ne { $res = $(p_castInt $a) -ne $(p_castInt $b) }
                or { $res = $(p_castBool $a) -or $(p_castBool $b) }
                and { $res = $(p_castBool $a) -and $(p_castBool $b) }
                Default {
                    Write-Host "!_Invalid Op: $op :_____!`n`n$_`n" -ForegroundColor Red
                    return
                }
            }
            p_debug "res;$res"
            Invoke-Persist Push>_ "$($source):$res"
        }
        Default {}
    }
}

function p_throw ($code, $message, $meta ) {
    if ($global:p_error_action -eq "SilentlyContinue") { return 0 }
    write-host "| persist.psm1 |" -ForegroundColor RED
    switch ($code) {
        { ($_ -eq -1) -or ($_ -eq "SyntaxParseFailure") } { $code = -1; write-host "Syntax parse failed with code ($message)" -ForegroundColor Red }
        { ($_ -eq 01) -or ($_ -eq "ElementAlreadyAssigned") } { $code = 1; write-host "[$message] already assigned" -ForegroundColor Red }
        { ($_ -eq 10) -or ($_ -eq "IllegalValueAssignment") } { $code = 10; write-host "illegal character: $message :when trying to record [$meta]"  -ForegroundColor Red }
        { ($_ -eq 20) -or ($_ -eq "IllegalRecordBefore") } { $code = 20; write-host "Cannot record [$message] before [$meta] has been defined"  -ForegroundColor Red }
        { ($_ -eq 21) -or ($_ -eq "IllegalRecordAfter") } { $code = 21; write-host "Cannot record [$message] after [$meta] has been defined"  -ForegroundColor Red }
        { ($_ -eq 22) -or ($_ -eq "IllegalRecordOrder") } { $code = 22; write-host "Cannot record in the order: $message"  -ForegroundColor Red }
        { ($_ -eq 30) -or ($_ -eq "IllegalArrayRead") } { $code = 30; write-host "Illegal attempt to index array: $message"  -ForegroundColor Red }
        { ($_ -eq 40) -or ($_ -eq "IllegalOperationSyntax") } { $code = 30; write-host "IllegalOperationSyntax: $message"  -ForegroundColor Red }
        { ($_ -eq 50) -or ($_ -eq "IllegalArgumentException") } { $code = 50; write-host "IllegalArgumentException: Expected the format: $message | Received the form: $meta" -ForegroundColor Red }
    }
    if ($global:p_error_action -eq "Stop") {
        if (p_not_choice) { exit }
    }
    return $code
}

function p_parse_syntax ($a_) {
    p_debug_function p_parse_syntax Green
    $symbols = @(
        ">"
        "_"
        "="
        "\+"
        "-"
        "\*"
        "/"
        "\^"
        "!"
        "~"
        "\?"
        "\."
    )
    $aL = $a_.Length
    $cast = $null
    $name = $null
    $operator = $null
    $parameters = $null
    $index = $null 
    $recording = $null
    for ($i = 0; $i -lt $aL; $i++) {
        $a = $a_[$i]
        #if ($global:_debug_) { write-host ":: a_[i]: $a ::" -foregroundcolor darkyellow }
        if ($null -ne $recording) {
            if (($a -eq " ") -and ($recording -ne "STRING")) { continue }
            switch ($recording) {
                "CAST" {
                    if ($a -eq "]") { 
                        $recording = $null
                        p_debug "recording stopped:$cast" DarkRed 
                    } 
                    elseif ($a -notmatch "[a-z]") 
                    { return p_throw IllegalValueAssignment $a "cast" } 
                    $cast += $a 
                }
                "NAME" { 
                    if ($a -notmatch "[0-9a-zA-Z_]") {
                        $recording = $null
                        p_debug "recording stopped:$name" DarkRed
                        $i-- 
                    } 
                    else { $name += $a } 
                }
                "OPERATOR" { 
                    if (p_match $a $symbols -logic NOT) {
                        $recording = $null
                        $i--
                        if ($null -eq $name) { $operator += '|' }
                        p_debug "recording stopped:$operator" DarkRed 
                    } 
                    else { $operator += $a } 
                }
                "PARAMETERS" { 
                    if ($a -notmatch "[a-zA-Z0-9:]") {
                        $recording = $null
                        $i--
                        p_debug "recording stopped:$parameters" DarkRed 
                    } 
                    else { $parameters += $a } 
                }
                "STRING" { 
                    if ($a -eq '"') { 
                        $recording = $null 
                    } 
                    $parameters += $a
                    if ($null -eq $recording) { 
                        $parameters = $parameters -replace '"', ""
                        p_debug "recording stopped:$parameters" DarkRed 
                    } 
                }
                "INDEX" { 
                    if ($a -eq "]") {
                        $recording = $null
                        p_debug "recording stopped:$index" DarkRed 
                    } 
                    elseif ($a -notmatch "[0-9]") { return p_throw IllegalValueAssignment $a "index" } $index += $a 
                }
                "COMMAND" {
                    if ($a -eq '"') { $recording = $null } 
                    $parameters += $a
                    if ($null -eq $recording) { 
                        $parameters = $parameters -replace '"', ""
                        p_debug "recording stopped:$parameters" DarkRed 
                    } 
                }
            }
        }
        else {
            if ($a -eq " ") { 
                continue 
            }
            elseif ($null -ne $operator -and (($operator -eq ">_") -or ($operator -eq "=."))) {
                if ($operator -eq ">_") {
                    $recording = "COMMAND"
                    $parameters = $a
                    p_debug "recording [param] as command arguments" DarkGreen
                }
                if ($operator -eq "=.") {
                    $recording = "STRING"
                    $parameters = $a
                    p_debug "recording [param] as string" DarkGreen
                    $operator = "="
                }
            }
            elseif ($a -eq "[") {
                if ($null -ne $cast) { 
                    #Attempt to record [index]
                    if ($null -eq $name) { 
                        return p_throw IllegalRecordBefore "index" "name" 
                    } 
                    # elseif ($null -ne $operator) { return p_throw IllegalRecordAfter "index" "operator" } 
                    else { 
                        $index = "["
                        $recording = "INDEX"; p_debug "recording [index]" DarkGreen 
                    } 
                }
                elseif ($null -ne $name) {
                    #Attempt to record [index] 
                    if ($null -ne $index) { 
                        return p_throw ElementAlreadyAssigned "index" 
                    }
                    $index = "["
                    $recording = "INDEX" 
                    p_debug "recording [index]" DarkGreen 
                }
                #Attempt to record [cast]
                else {
                    $cast = "["
                    $recording = "CAST"
                    p_debug "recording [cast]" DarkGreen 
                } 
            }
            elseif ($a -match "[a-zA-Z0-9_]") { 
                #Attempt to record [name]
                if ($null -eq $name) {
                    $name = $a
                    $recording = "NAME"
                    p_debug "recording [name]" DarkGreen 
                }  
                
                #Attempt to record [param] 
                elseif ($null -eq $operator) { 
                    return p_throw IllegalRecordBefore "parameter" "operator" 
                }
                elseif (p_nonnull @($operator, $index)) {
                    $oR = p_stringify_regex $operator
                    $iR = p_stringify_regex $index
                    if ($a_ -match "(.+)?$oR(.+)?$iR") {
                        return p_throw IllegalRecordOrder "[op][index][param]"
                    }
                    else {
                        $parameters = $a
                        $recording = "parameters"
                        p_debug "recording [param]" DarkGreen 
                    }
                }
                elseif ($null -eq $parameters) {
                    $parameters = $a
                    $recording = "parameters"
                    p_debug "recording [param]" DarkGreen 
                }
                else { return p_throw 1 "parameters" }
                
            }
            elseif (($a -eq '"') -or ($a -eq ':')) { 
                #Attempt to record [param] as string
                if ($null -eq $name) { 
                    return p_throw IllegalRecordBefore "parameter" "name" 
                } 
                elseif ($null -eq $operator) { 
                    return p_throw IllegalRecordBefore "parameter" "operator" 
                } 
                elseif ($operator -match "\|") { 
                    return p_throw IllegalRecordOrder "[op][name][param]" 
                } 
                elseif ($null -eq $parameters) {
                    $parameters = $a; $recording = "string"
                    p_debug "recording [param] as string" DarkGreen 
                } 
                else {
                    return p_throw ElementAlreadyAssigned "parameters" 
                } 
            }
            elseif (p_match $a $symbols) { 
                #Attempt to record [op] 
                if ($null -ne $operator) { 
                    return p_throw 1 "operator" 
                } 
                else { 
                    $operator = $a
                    $recording = "operator"
                    p_debug "recording [op]" DarkGreen 
                } 
            }
        }
    }
    #Handle Negatives
    if($operator.Length -gt 1 -and $operator[$operator.Length - 1] -eq '-'){
        p_debug "handling negative: op:$operator  parameters:$parameters"
        if($operator.Length -eq 2){
            $operator = "$($operator[0])"
        } elseif ($operator.length -eq 3) {
            $operator = "$($operator[0])$($operator[1])"
        }
        $parameters = "-$parameters"
        p_debug "handling negative: op:$operator  parameters:$parameters"
    }
    return @($cast, $name, $operator, $parameters, $index)
}

function p_index ($indexable, $index) {
    p_debug_function p_foo DarkMagenta
    p_debug "index:$index" darkGray
    $index = p_replace $index @("\[", "]")
    if ($indexable -is [string]) {
        if ($indexable -match ":") {
            $indexable = $indexable -split ":"
        }
        else {
            return $indexable[$index]
        }
    } if ($indexable -is [System.Array]) {
        return $indexable[$index]
    }
    else {
        p_throw IllegalArrayRead "Not an indexable" 
    }
}

function Invoke-Persist {

    p_debug_function Invoke-Persist White
    
    if ($global:_debug_) {
        for ($i = 0; $i -lt $args.length; $i++) {
            $a = $args[$i]
            p_debug "$a" darkgray
        }
    }

    $a_ = $args -join " "

    $s_ = p_parse_syntax $a_

    if ($s_ -isnot [System.Array]) { return p_throw -1 $s_ "line: ~1580" }

    $cast = $s_[0]
    $name = $s_[1]
    $oper = $s_[2]
    $para = $s_[3]
    $inde = $s_[4]


    $prompt = "cast:         $cast
    \\ name:         $name
    \\ operator:     $oper
    \\ parameter:    $para
    \\ index:        $inde"
    p_debug $prompt darkgray
   
    <#
    Based on the available variables [cast][name][op][param][index], the follow up operations are decided

    __________________________________________________________________________________________________
    ////////////// 1 /////////////////////////////////////////////////////////////////////////////////

    [cast]              Get all variables with assigned type of [cast]
    
    [name]              Get variable with name [name]

    [op]                Illegal[post syntax parse], [name] must be defined, cannot apply [op] to null [name]

    [param]             Illegal, cannot record [param] before/without [name]
    
    [index]             Impossible, cannot define [index] if [cast] or [name] are not defined
    
    __________________________________________________________________________________________________
    ////////////// 2 /////////////////////////////////////////////////////////////////////////////////

    [cast]
        [name]          Apply [cast] to [name] ~ return

        [op]            Illegal[post syntax parse], [name] must be defined, cannot apply [op] to null

        [param]         Illegal, cannot record [param] before/without [name]

        [index]         Illegal, cannot record [index] before/without [name]

    [name]
        [cast]          Impossible, cannot define [cast] after [name] has been defined
        
        [op]            applies [op] to [name] ~ return

        [param]         Illegal, do not define [param] before [op]

        [index]         if [name] returns an indexable value, [name][index] ~ return, else Illegal, 
                        variable value is not indexable

    [op]
        [cast]          Illegal[post syntax parse], [name] must be defined, cannot apply [op] to null 

        [name]          if [op] is of the form operation~assign [1|x], [op] is 
                        applied to [name] ~ return
                            - [op] will be formatted like ".|" instead of just "."

        [param]         Illegal, cannot record [param] before/without [name]
        
        [index]         Impossible, cannot define [index] if [cast] or [name] are not defined

    [param]
        [x]             Impossible, cannot define [param] before/without [name]

    [index]
        [x]             Impossible, cannot define [index] before [cast] or [name] are not defined
        
    __________________________________________________________________________________________________
    ////////////// 3 /////////////////////////////////////////////////////////////////////////////////

    [cast]              *Generally [cast] is applied after any operations
        [name]
            [op]        Applies [op] to [name], then attempts to convert to [cast]

            [param]     Illegal, do not define [param] before [op]

            [index]     If [name] returns indexable, indexable[index] is pulled then attempted to be 
                        converted to [cast]

        [op]            
            [name]      Applies [op] to [name], then attempts to convert to [cast]

            [param]     Illegal, cannot record [x] before/without [name]
            [index]     Impossible, cannot define [x] before/without [name]

        [param]         Illegal, cannot record [x] before/without [name]
        [index]         Impossible, cannot define [y] before/without [name]
            [x]         

    [name]
        [cast]
            [x]         Impossible, cannot define [cast] after [name] is defined

        [op]
            [cast]      Impossible, cannot define [cast] after [name] is defined

            [param]     Applies [op][param] to [name] 

            [index]     Illegal, cannot define [index] after [op]

        [param]         
            [x]         Illegal, cannot record [param] before/without [op]

        [index]
            [op]        applies [op] to [name][index], such that the indexing operation
                        is performed first, so long as [name] is assigned an indexable variable. If a return is requested, the unaltered res will be returned
            
            [param]     Illegal, cannot define [param] before/without [op]

            [cast]      Impossible, cannot define [cast] after [name] is defined

    [op]
        [cast]
            [name]      [op] is appleid to [name], then [name] is cast to [cast]

            [param]     Illegal, cannot record [param] before/without [name] 

            [index]     Illegal, cannot record [index] before/without [name]

        [name]
            [cast]      Impossible, cannot record [cast] after [name] is defined

            [param]     Illegal record order [op][name][param]

            [index]     applies [op] to [name][index], such that the indexing operation
                        is performed first, so long as [name] is assigned an indexable variable. If a return is requested, the altered res will be returned

        [param]
        [index]
            [x]         Impossible, cannot record [y] before/without [name]

    [index]
    [param]
        [y]
            [x]         Impossible, cannot record [z] before/without [cast]/[name] 
                        respectively

    
    __________________________________________________________________________________________________
    ////////////// 4 /////////////////////////////////////////////////////////////////////////////////

    [cast]
        [name]
            [op]
                [param] Applies [op][param] to [name] then 
                        applies [cast]

                [index] Illegal, cannot record [index] after 
                        [param] has been defined

            [param]     Illegal, cannot record [param] before
                        /without [op]
                [x]    

            [index]
                [op]    Applies [op] to [name][index] then 
                        applies [cast]
                
                [param] Illegal, cannot record [param] before
                        /without [op]

        [op]
            [name]
                [param] Illegal Order [op][name][param]

                [index] Applies [op] to [name][index] then applies [cast]

            [param]
                [x]     Illegal, Cannot record [parameter] before [name] has been defined

            [index]
                [x]     Illegal, Cannot record [index] before [name] has been defined

        [param]
            [x]         Illegal, Cannot record [parameter] before [name] has been defined
                

        [index]
            [x]         Illegal, Cannot record [index] before [name] has been defined

    [name]
        [cast]
            [x]         Impossible, cannot define [cast] after [name] is defined

        [op]
            [cast]
                [x]     Impossible, cannot define [cast] after [name] is defined

            [param]
                [cast]  Impossible, cannot define [cast] after [name] is defined

                [index] Applies [param][index] via [op] to [name]
            
            [index]
                [cast]  Impossible, cannot define [cast] after [name] is defined

                [param] Illegal, cannot record in the order [op][index][param]

        [param]
            [x]         Illegal, cannot record [param] before/without [op]

        [index]
            [cast]
                [x]     Impossible, cannot define [cast] after [name] is defined

            [op]
                [cast]  Impossible, cannot define [cast] after [name] is defined

                [param] Applies [param] via [op] to [name][index]

            [param]
                [cast]  Impossible, cannot define [cast] after [name] is defined

                [op]    Illegal, cannot record [param] before/without [op]

    [op]
        [cast]
            [name]
                [param] Illegal, Cannot record in the order: [op][name][param]

                [index] Applies [op] to [name][index] to applies [cast]

            [param]
                [x]     Illegal, Cannot record [parameter] before [name] has been defined

            [index]
                [x]     Illegal, Cannot record [index] before [name] has been defined

        [name]  
            [cast]
                [x]     Impossible, cannot define [cast] after [name] is defined

            [param]
                [x]     Illegal, Cannot record in the order: [op][name][param]

            [index]
                [cast]  Impossible, cannot define [cast] after [name] is defined

                [param] Illegal, Cannot record in the order: [op][name][param]

        [param]        
        [index]
            [x]         Illegal, Cannot record [y] before [name] has been defined

    [param]
        [x]             Illegal, cannot record [param] before/without [name]

    [index]
        [x]             Impossible, cannot define [index] before/without [name]



    __________________________________________________________________________________________________
    ////////////// 5 /////////////////////////////////////////////////////////////////////////////////

    [cast]
        [name]
            [op]
                [param]
                    [index]     Applies [param][index] to [name] via [op] then 
                                applies [cast]

                [index]
                    [param]     Illegal, Cannot record in the order: [op][index][param]

            [param]
                [x]             Illegal, Cannot record [parameter] before 
                                [operator] has been defined

            [index]
                [op]
                    [param]     Applies [op][param] to [name][index] then [cast]

                [param]
                    [op]        Illegal, Cannot record [parameter] before 
                                [operator] has been defined

        [op]
            [name]
                [param]
                    [x]         Cannot record in the order: [op][name][param]

                [index]
                    [param]     Cannot record in the order: [op][index][param] 

            [param]
                [x]             Cannot record [parameter] before [name] has been 
                                defined

            [index]
                [x]             Cannot record [index] before [name] has been 
                                defined

        [param]
            [x]                 Cannot record [parameter] before [name] has been 
                                defined

        [index]
            [x]                 Cannot record [index] before [name] has been 
                                defined

    [xxxxx]     ** No further combinations will work, [cast] must always be at the start of the function, and all further combinations include the [cast] in a position other than the start
    #>

    $global:c_ = Get-PersistContent

    if (p_null @($name, $cast)) {
        return $global:c_
    }   

    if ($null -ne $name) {
        p_debug "content | p_getLine $name | p_getVal" darkGray
        $l_ = p_getLine $global:c_ $name
        $v_ = p_getVal $l_
        if (P_null @($oper, $inde, $cast, $para)) {
            $cast = p_getCast $l_
            if ($null -eq $cast) {
                return $v_
            }
            else {
                return p_cast $cast $v_
            }
        }
    }

    if ($Null -ne $inde) {
        p_debug "indexing" darkGray
        if ($null -ne $para) {
            if(p_match $a_ "$para\[[0-9]+]"){
                p_debug "      % param: $para" darkGray
                $para = p_index $para $inde
                p_debug "      \ param: $para" darkGray
            }
        }
        else {
            p_debug "      % val: $val" darkGray
            $v_ = p_index $v_ $inde
            p_debug "      \ val: $val" darkGray
        }
    }

    if ($null -eq $oper) {
        if ($null -eq $cast) {
            $cast = p_getCast $l_
        }
        if ($null -eq $cast) {
            return $v_
        }
        else {
            return p_cast $cast $v_
        }
    }
    else {
        switch ($oper) {
            ">_" { 
                $res = p_foo $name $para 
                if($null -ne $cast){
                    $res = p_cast $cast $res
                }
                } # getthis (command)
            "=" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator assign [n]" } 
                if ($v_ -eq $para) {
                    $c_ = p_getCast $l_
                    if($cast -eq $c_) {
                        if ($global:_debug_) { Write-Host "    \ var.val is already: $para" -ForegroundColor Magenta }
                        $res = $l_
                    } else {
                        $res = p_foo assign $cast':'$name':'$para 
                    }
                }
                else { 
                    if($a_ -match "$name\["){
                        if($null -ne $cast -and $cast.toLower -ne "[array]"){
                            return p_throw IllegalArgumentException "Cannot index array and cast to non-array type"
                        }
                        if($null -eq $inde){
                            return p_throw IllegalArgumentException "Cannot index cannot be null"
                        }
                        $inde = $inde -replace "\[","" -replace "]",""
                        $res = p_foo insert $name':'$inde':'$para
                    } else {
                        $res = p_foo assign $cast':'$name':'$para 
                    }
                } 
            } # assign
            "+" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator add [n]" } 
                $res = p_foo add $cast':'$name':'$para 
            } # add [n]
            "++" {
                if ($null -ne $para) { return p_throw IllegalOperationSyntax "Cannot pass parameters to add~assign [1]" } 
                $n = "1"
                $res = p_foo add_assign $cast':'$name':'$n
            } # add~assign [1]
            "+=" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator add~assign [n]" } 
                $res = p_foo add_assign $cast':'$name':'$para 
            } # add~assign [n] 
            "-" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator minus [n]" } 
                $res = p_foo minus $cast':'$name':'$para 
            } # minus [n]
            "--" {
                if ($null -ne $para) { return p_throw IllegalOperationSyntax "Cannot pass parameters to minus~assign [1]" } 
                $n = "1"
                $res = p_foo minus_assign $cast':'$name':'$n 
            } # minus~assign [1]
            "-=" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator minus_assign [n]" } 
                $res = p_foo minus_assign $cast':'$name':'$para 
            } # minus~assign [n]
            "*" {
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator multiply [n]" } 
                $res = p_foo multiply $cast':'$name':'$para 
            } # multiply [n]
            "**" {
                if ($null -ne $para) { return p_throw IllegalOperationSyntax "Cannot pass parameters to multiply~assign [x]" }
                $res = p_foo multiply_assign $cast':'$name':'$v_
            } # multiply~assign [x]
            "*=" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator multiply-assign [n]" } 
                $res = p_foo multiply_assign $cast':'$name':'$para 
            } # multiply-assign [n]
            "/" {
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator divide [n]" } 
                $res = p_foo divide $cast':'$name':'$para 
            } # divide [n]
            "/=" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator divide~assign [n]" } 
                $res = p_foo divide_assign $cast':'$name':'$para 
            } # divide~assign [n]
            "//" {
                if ($null -ne $para) { return p_throw IllegalOperationSyntax "Cannot pass parameters to divide~assign [x]" } 
                $res = p_foo divide_assign $cast':'$name':'$val
            } # divide~assign [x] (assigns to 1)
            "^" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator exponentiate [n]" } 
                $res = p_foo exponentiate $cast':'$name':'$para 
            } # exponentiate [n]
            "^=" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator exponentiate~assign [n]" } 
                $res = p_foo exponentiate_assign $cast':'$name':'$para 
            } # exponentiate~assign [n]
            "^^" { 
                if ($null -ne $para) { return p_throw IllegalOperationSyntax "Cannot pass parameters to exponentiate~assign [x]" }
                $res = p_foo exponentiate_assign $cast':'$name':'$v_ 
            } # exponentiate~assign [x]
            "==" {
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator compare~equal [n]" } 
                $res = $v_ -eq $para
            } # compare~equal [n]
            "!=" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator compare~equal~not [n]" } 
                $res = $v_ -ne $para
            } # compare~equal~not [n]
            "~=" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator compare~match [n]" } 
                $res = $v_ -match $para
            } # compare~match [n]
            "!~" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator compare~match~not [n]" } 
                $res = $v_ -notmatch $para
            } # compare~match~not [n]
            "~>" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator compare~match~get [n]" } 
                $res = p_match $v_ $para -getMatch
            } # compare~match~get [n]
            "?" { 
                if ($null -ne $para) { return p_throw IllegalOperationSyntax "Cannot pass parameters to compare~true [x]" } 
                $res = $v_ -eq "True"
            } # compare~true [x]
            "!?" { 
                if ($null -ne $para) { return p_throw IllegalOperationSyntax "Cannot pass parameters to compare~not~true [x]" } 
                $res = ($null -eq $v_) -or ($v_ -eq "False")
            } # compare~not~true [x]
            "->|" { 
                if ($null -eq $name) { return p_throw IllegalOperationSyntax "Expected argument for operator push [n]" } 
                $res = Set-Scope $name
            } # push [n]
        }
        return $res
    }
  

}
New-Alias -Name persist -Value Invoke-Persist -Scope Global -Force
New-Alias -Name Get-PersistentVariable -Value Invoke-Persist -Scope Global -Force
