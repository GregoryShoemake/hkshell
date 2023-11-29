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
            p_debug "    \ cast: $cast" darkGray
            return $cast 
        }
    }
}

function p_compareVar ([string]$line, [string]$compare) {
    $j = 0;
    for ($i = 0; $i -lt $line.Length; $i++) {
        $letter = $line[$i]
        p_debug "line[$i]=$letter <> compare[$j]=$($compare[$j]) | await:$await"
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

function p_getVal ($line) {
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
    p_debug "    \ val: $val" darkGray
    return $val
}

function p_getLine ($content, $var) {
    p_debug_function p_getLine darkyellow
    $c_ = $content -split "`n"
    foreach ($c in $c_) {
        if ($null -eq $c) { continue }
        if ($c.trim() -eq "") { continue }
        if (p_compareVar $c $var) { 
            p_debug "    \ line: $c" darkGray
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

function Start-Scopes ([switch]$rebuild){
    if(!(Test-Path $global:SCOPES_PATH) -or $rebuild) {
        p_debug "creating persist scopes file at $global:SCOPES_PATH"
        New-Item $global:SCOPES_PATH -ItemType File -Force
        p_debug "populating persist scopes file with default scopes"
        if(!(test-path "C:\Users\$ENV:USERNAME\contacts" )) { mkdir "C:\Users\$ENV:USERNAME\contacts" }
        if(!(test-path "C:\Users\$ENV:USERNAME\.ssh"  )) { mkdir "C:\Users\$ENV:USERNAME\.ssh" }
        Set-Content -Path $global:SCOPES_PATH -Value "USER::C:\Users\$ENV:USERNAME\.powershell\persist.cfg"
        Set-Content -Path $global:SCOPES_PATH -Value "USER::C:\Users\$ENV:USERNAME\.powershell\persist.cfg
    INSTANCE::$global:_persist_module_location\persist.cfg
    HOST::C:\Windows\System32\WindowsPowerShell\v1.0\persist.cfg
    CONTACTS::C:\Users\$ENV:USERNAME\contacts\persist.cfg
    SSH::C:\Users\$ENV:USERNAME\.ssh\persist.cfg"
        p_debug 'pushing content to memory in variable $global:SCOPES'
        $global:SCOPES = Get-Content -Path $global:SCOPES_PATH
    } else { 
        $global:SCOPES = Get-Content -Path $global:SCOPES_PATH
        $global:SCOPES += $global:INSTANCE_SCOPE
    }
}
Start-Scopes

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#           Initializer Functions                 #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

function Set-Scope ([string]$scope="USER") {
    p_debug_function "Set-Scope"
    p_debug "scope:$scope"
    if($scope -eq "NETWORK"){
        $netScope = persist networkLocation
        if($null -eq $netScope) {
            Write-Host "A network location has not been set for $Global:SCOPE. Use the persist setNetworkDir>_ command to set a network location." -ForegroundColor Yellow
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
    if(!(Test-Path $spl[1])) { $null = New-Item $spl[1] -ItemType File -Force }
    $global:PERSIST = Get-Content $spl[1]
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
            write-host 'p_foo_remove ! Cannot remove networkLocation with remove:: command, use: > persist clearNetworkDir::' -ForegroundColor Yellow
            return
        }
        Default {
            $removeReg = "(`n)?(\[[a-z]+])?$parameters=.+"
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
        write-host 'p_foo_setNetworkDir ! networkLocation already assigned ! clear with command first: > persist clearNetworkDir>_' -ForegroundColor Yellow
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
    $date = p_foo_parse "$variable":[datetime]
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
    persist [datetime]$parameters='''"'$todayString'"'''
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
    persist [datetime]$variable='''"'$dateString'"'''
}

function p_foo.old ($function, $parameters) {
    if ($global:_debug_) { Write-Host "g_foo : $function :: $parameters" -ForegroundColor DarkRed -BackgroundColor Black }
    switch ($function) {
        "remove" { p_foo_remove $parameters }
        "search" { return p_foo_search $parameters }
        "nullOrEmpty" { return $null -eq (persist $parameters) }
        "nonnull" { return $null -ne (persist $parameters) }
        "setNetworkDir" { p_foo_setNetworkDir $parameters }
        "clearNetworkDir" { p_foo_clearNetworkDir $parameters }
        "outOfDate" { p_foo_outOfDate $parameters }
        "upToDate" { p_foo_upToDate $parameters }
        "writeToday" { p_foo_writeToday $parameters }
        "writeDate" { p_foo_writeDate $parameters }
        "parse" { p_foo_parse $parameters }
        Default { Write-Host "Function: $function :is not a recognized command" }
    }
}

function Get-PersistItem ($sc){
    if ($null -eq $sc) { $sc = $global:SCOPE }
    $sc = ($sc -split "::")[0] 
    $scope_ = p_match $global:SCOPES "$sc.+" -getMatch
    $spl_ = $scope_ -split "::"
    return Get-Item $spl_[1]
}
New-Alias -name p_item -Value Get-PersistItem -Scope Global -Force

function Get-PersistContent ($sc) {
    if($null -eq $sc) {
        return $global:PERSIST
    } else {
        $sc = ($sc -split "::")[0] 
        $scope_ = p_match $global:SCOPES "$sc.+" -getMatch
        $spl_ = $scope_ -split "::"
        return Get-Content $spl_[1]
    }
}

function p_content {
    [CmdletBinding()]
    param (
        [Parameter()]
        $scope,
        [Parameter()]
        $networkScopeParent
    )
    if ($null -eq $scope) { $scope = $global:_scope }
    if ($null -eq $networkScopeParent) { $networkScopeParent = $global:_network_scope_parent }
    if ($global:_debug_) { Write-Host "p_content:" -ForegroundColor Cyan }
    switch ($scope) {
        $global:_scope_user { 
            if ($global:_debug_) { Write-Host "    \ user:$global:_content_user" -ForegroundColor DarkCyan }; return $global:_content_user 
        }
        $global:_scope_instance {
            if ($global:_debug_) { Write-Host "    \ instance:$global:_content_instance" -ForegroundColor DarkCyan }; return $global:_content_instance 
        }
        $global:_scope_host { 
            if (p_elevated) { if ($global:_debug_) { Write-Host "    \ host:$global:_content_host" -ForegroundColor DarkCyan }; return $global:_content_host } else { p_ehe } 
        }
        $global:_scope_network {
            switch ($networkScopeParent) {
                $global:_scope_user { if ($null -eq $global:_network_persist_cfg_user) { Write-Error 'user network location has not been initialized. Call > p_set_scope_user global networkLocation = \\network\share to initialize' } else { return $global:_content_user_network } }
                $global:_scope_instance { if ($null -eq $global:_network_persist_cfg_instance) { Write-Error 'instance network location has not been initialized. Call > p_set_scope_instance global networkLocation = \\network\share to initialize' } else { return $global:_content_instance_network } }
                $global:_scope_host { if (p_elevated) { if ($null -eq $global:_network_persist_cfg_host) { Write-Error 'host network location has not been initialized. Call > p_set_scope_host global networkLocation = \\network\share to initialize' } else { return $global:_content_host_network } } else { p_ehe } }
                Default {}
            } 
        }
    }
}

function pull {
    Invoke-Pull
    $a_ = $args -join " "
    if ($global:_debug_) { Write-Host "pull => args: $a_" -ForegroundColor Green }
    if (p_nullemptystr $a_) { return }
    return Invoke-Expression $a_
}

function push {
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

function p_push {
    [CmdletBinding()]
    param (
        [Parameter()]
        $scope,
        [Parameter()]
        $networkScopeParent
    )
    if ($null -eq $scope) { $scope = $global:_scope }
    if ($null -eq $networkScopeParent) { $networkScopeParent = $global:_network_scope_parent }
    if ($global:_debug_) { Write-Host "p_push `n  \ scope: $scope ~ netScopeParent: $networkScopeParent" -ForegroundColor Yellow }
    $c_ = p_content $scope $networkScopeParent
    $i_ = p_item $scope $networkScopeParent
    if ($global:_debug_) { Write-Host "     \ item: $i_" -ForegroundColor Yellow }
    try {
        Set-Content $i_.fullname $c_ -ErrorAction Stop
    }
    catch {
        Write-Host " << Failed to write to cfg file" -ForegroundColor Red
        if ($global:_debug_) { Write-Host "    $_" -ForegroundColor Red }
    }
}

function Invoke-Pull {
    $spl = $global:SCOPE -split "::"
    $global:PERSIST = Get-Content -Path $spl[1]
}

function p_pull {
    [CmdletBinding()]
    param (
        [Parameter()]
        $scope,
        [Parameter()]
        $networkScopeParent
    )
    p_debug_function p_pull yellow
    if ($null -eq $scope) {
        p_init_scope -pull $true
    }
    else {
        switch ($scope) {
            instance { p_init_scope instance -pull $true }
            user { p_init_scope user -pull $true }
            host { p_init_scope host -pull $true }
            network { 
                if ($null -eq $networkScopeParent) {
                    p_init_scope network_instance -pull $true
                    p_init_scope network_user -pull $true
                    p_init_scope network_host -pull $true
                }
                else {
                    switch ($networkScopeParent) {
                        instance {  
                            p_init_scope network_instance -pull $true
                        }
                        user { 
                            p_init_scope network_user -pull $true
                        }
                        host { 
                            p_init_scope network_host -pull $true
                        }
                        Default {}
                    } 
                }
            }
            Default {}
        }
    }
}

function p_get {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $var,
        [Parameter()]
        $cast,
        [Parameter()]
        $flags,
        [Parameter()]
        $content
    )
    $content = if ($null -eq $content) { if ($null -ne $global:c_) { $global:c_ } else { p_content } } else { $content }
    $match = p_getLine $content $var
    if ($null -ne $match) {

        if (p_match $flags "_SEARCH_") {
            $c_ = $content -split "`n"
            $g_ = @()
            foreach ($c in $c_) {
                $m = p_getLine $c $var
                if ($null -ne $m) { $g_ += $m }
            }
            if ($global:_debug_) { Write-Host "g_get : _SEARCH_ : $cast `n$($g_)" -ForegroundColor DarkYellow }
            if (p_match $flags "_NOT_") { return $g_.length -eq 0 }
            if (p_match $flags "_BOOL_") { return $g_.length -gt 0 }
            if ($null -ne $cast) { $g_ = p_cast $cast $g_ }
            return $g_
        }
        else {
            $get = p_getVal $match
            $cast = if ($null -eq $cast) { p_getCast $match } else { $cast }
            if ($global:_debug_) { Write-Host "g_get : $cast $get" -ForegroundColor DarkYellow }
            if (p_match $flags "_NOT_") { if ($null -eq $get) { $get = $true } else { $get = !(p_castBool $get) } }
            if (p_match $flags "_BOOL_") { if ($null -eq $get) { $get = $false } else { $get = p_castBool $get } }
            if ($null -ne $cast) { $get = p_cast $cast $get }
            return $get
        }
    }
    else {
        
    }
}

function p_network_wrapper {
    $scope_bak = ("$SCOPE" -split "::")[0]
    persist -> network
    $res = Invoke-Expression "$args"
    persist -> $scope_bak
    return $res
}
New-Alias -Name network -Value p_network_wrapper -Scope Global -Force

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
            write-host 'Cannot set networkLocation with persist command directly, use: > persit setNetworkDir>_`"@{scope=$SCOPE;path=$PATH}"`' -ForegroundColor Yellow
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
                $global:PERSIST += $replace
            }
        }
    }
    return p_getLine (p_content) $var
}

function p_assign {
    [CmdletBinding()]
    param (
        [Parameter()]
        $params
    )
    $cast = $params.Cast
    $var = $params.Name
    $val = $params.Value
    if (($global:_scope -eq $global:_scope_host) -and !(p_elevated)) {
        p_ehe
        return
    }
    p_debug "p_assign: $val => $var" Magenta
    if ($var -eq "networkLocation") {
        write-host 'Cannot set networkLocation with persist command directly, use: > persit setNetworkDir>_`"@{scope=$SCOPE;path=$PATH}"`' -ForegroundColor Yellow
        return
    }
    $content = $global:c_
    $line = p_getLine $content $var
    $replace = "$cast$var=$val"
    if ($null -ne $line) {
        $line = p_stringify_regex $line
        if ($global:_debug_) { Write-Host "  \ $line => $replace" -ForegroundColor Magenta }
        if ($global:_debug_) { Write-Host "    ~ replacing" -ForegroundColor Magenta }
        switch ($global:_scope) {
            $global:_scope_user { 
                $global:_content_user = $content -replace "$line", $replace
            }
            $global:_scope_instance { 
                $global:_content_instance = $content -replace "$line", $replace 
            }
            $global:_scope_host { 
                $global:_content_host = $content -replace "$line", $replace 
            }
            $global:_scope_network { 
                switch ($global:_network_scope_parent) {
                    $global:_scope_user {
                        if ($null -eq $global:_network_persist_cfg_user) { Write-Error 'user network location has not been initialized. Call > p_set_scope_user global networkLocation = \\network\share to initialize' } else {                    
                            $global:_content_user_network = $content -replace "$line", $replace 
                        } 
                    }
                    $global:_scope_instance {
                        if ($null -eq $global:_network_persist_cfg_instance) { Write-Error 'instance network location has not been initialized. Call > p_set_scope_instance global networkLocation = \\network\share to initialize' } else {                    
                            $global:_content_instance_network = $content -replace "$line", $replace 
                        } 
                    }
                    $global:_scope_host {
                        if (p_elevated) {
                            if ($null -eq $global:_network_persist_cfg_host) { Write-Error 'host network location has not been initialized. Call > p_set_scope_host global networkLocation = \\network\share to initialize' } else {                    
                                $global:_content_host_network = $content -replace "$line", $replace 
                            }  
                        }
                        else { p_ehe } 
                    }
                    Default {}
                } 
            }
            Default {}
        }
    }
    else {
        if ($global:_debug_) { Write-Host "  \ $line => $replace" -ForegroundColor Magenta }
        if ($global:_debug_) { Write-Host "    ~ adding" -ForegroundColor Magenta }
        switch ($global:_scope) {
            $global:_scope_user { 
                if ($global:_content_user[$global:_content_user.length - 1] -ne "`n") { $global:_content_user += "`n" }
                $global:_content_user += "$replace" 
            }
            $global:_scope_instance { 
                if ($global:_content_instance[$global:_content_instance.length - 1] -ne "`n") { $global:_content_instance += "`n" }
                $global:_content_instance += "$replace" 
            }
            $global:_scope_host { 
                if ($global:_content_host[$global:_content_host.length - 1] -ne "`n") { $global:_content_host += "`n" }
                $global:_content_host += "$replace" 
            }
            $global:_scope_network { 
                switch ($global:_network_scope_parent) {
                    $global:_scope_user {
                        if ($null -eq $global:_network_persist_cfg_user) { Write-Error 'user network location has not been initialized. Call > p_set_scope_user global networkLocation = \\network\share to initialize' } else {    
                            if ($global:_content_user_network[$global:_content_user_network.length - 1] -ne "`n") { $global:_content_user_network += "`n" }                
                            $global:_content_user_network += "$replace" 
                        } 
                    }
                    $global:_scope_instance {
                        if ($null -eq $global:_network_persist_cfg_instance) { Write-Error 'instance network location has not been initialized. Call > p_set_scope_instance global networkLocation = \\network\share to initialize' } else {                    
                            if ($global:_content_instance_network[$global:_content_instance_network.length - 1] -ne "`n") { $global:_content_instance_network += "`n" }
                            $global:_content_instance_network += "$replace" 
                        } 
                    }
                    $global:_scope_host {
                        if (p_elevated) {
                            if ($null -eq $global:_network_persist_cfg_host) { Write-Error 'host network location has not been initialized. Call > p_set_scope_host global networkLocation = \\network\share to initialize' } else {  
                                if ($global:_content_host_network[$global:_content_host_network.length - 1] -ne "`n") { $global:_content_host_network += "`n" }                  
                                $global:_content_host_network += "$replace" 
                            }  
                        }
                        else { p_ehe } 
                    }
                    Default {}
                } 
            }
            Default {}
        }
    }
    return p_getLine (p_content) $var
}
function p_add {
    [CmdletBinding()]
    param (
        [Parameter()]
        $params
    )
    p_debug_function p_add Blue
    p_debug "    \ params:$(p_hash_to_string $params)" darkGray
    $cast = $params.Cast
    $var = $params.Name
    $n = $params.Value
    $l_ = p_getLine $global:c_ $var
    $val = p_getVal $l_
    $val = p_parseNumber $val
    $n = p_parseNumber $n
    $res = $val + $n
    if ($null -ne $cast) { return p_cast $cast $res } else { return $res }
}

function p_minus {
    [CmdletBinding()]
    param (
        [Parameter()]
        $params
    )
    p_debug_function p_minus Blue
    p_debug "    \ params:$(p_hash_to_string $params)" darkGray
    $cast = $params.Cast
    $var = $params.Name
    $n = $params.Value
    $l_ = p_getLine $global:c_ $var
    $val = p_getVal $l_
    $val = p_parseNumber $val
    $n = p_parseNumber $n
    $res = $val - $n
    if ($null -ne $cast) { return p_cast $cast $res } else { return $res }
}

function p_multiply {
    [CmdletBinding()]
    param (
        [Parameter()]
        $params
    )
    p_debug_function p_multiply Blue
    p_debug "    \ params:$(p_hash_to_string $params)" darkGray
    $cast = $params.Cast
    $var = $params.Name
    $n = $params.Value
    $l_ = p_getLine $global:c_ $var
    $val = p_getVal $l_
    $val = p_parseNumber $val
    $n = p_parseNumber $n
    $res = $val * $n
    if ($null -ne $cast) { return p_cast $cast $res } else { return $res }
}

function p_divide {
    [CmdletBinding()]
    param (
        [Parameter()]
        $params
    )
    p_debug_function p_divide Blue
    p_debug "    \ params:$(p_hash_to_string $params)" darkGray
    $cast = $params.Cast
    $var = $params.Name
    $n = $params.Value
    $l_ = p_getLine $global:c_ $var
    $val = p_getVal $l_
    $val = p_parseNumber $val
    $n = p_parseNumber $n
    $res = $val / $n
    if ($null -ne $cast) { return p_cast $cast $res } else { return $res }
}

function p_exponentiate {
    [CmdletBinding()]
    param (
        [Parameter()]
        $params
    )
    p_debug_function p_exponentiate Blue
    p_debug "    \ params:$(p_hash_to_string $params)" darkGray
    $cast = $params.Cast
    $var = $params.Name
    $n = $params.Value
    $l_ = p_getLine $global:c_ $var
    $val = p_getVal $l_
    $val = p_parseNumber $val
    $n = p_parseNumber $n
    $res = [Math]::Pow($val, $n)
    if ($null -ne $cast) { return p_cast $cast $res } else { return $res }
}

function eept ($set) {
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

function p_throw ($code, $message, $meta ) {
    if ($global:p_error_action -eq "SilentlyContinue") { return 0 }
    write-host "| persist.psm1 |" -ForegroundColor RED
    switch ($code) {
        { ($_ -eq -1) -or ($_ -eq "SyntaxParseFailure") } { $code = -1; write-host "Syntax parse failed with code ($message)" -ForegroundColor Red }
        { ($_ -eq 1) -or ($_ -eq "ElementAlreadyAssigned") } { $code = 1; write-host "[$message] already assigned" -ForegroundColor Red }
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
        if ($global:_debug_) { write-host ":: a_[i]: $a ::" -foregroundcolor darkyellow }
        if ($null -ne $recording) {
            if (($a -eq " ") -and ($recording -ne "STRING")) { continue }
            switch ($recording) {
                "CAST" {
                    if ($a -eq "]") { 
                        $recording = $null
                        p_debug "    \recording stopped:$cast" DarkRed 
                    } 
                    elseif ($a -notmatch "[a-z]") 
                    { return p_throw IllegalValueAssignment $a "cast" } 
                    $cast += $a 
                }
                "NAME" { 
                    if ($a -notmatch "[0-9a-zA-Z_]") {
                        $recording = $null
                        p_debug "    \recording stopped:$name" DarkRed
                        $i-- 
                    } 
                    else { $name += $a } 
                }
                "OPERATOR" { 
                    if (p_match $a $symbols -logic NOT) {
                        $recording = $null
                        $i--
                        if ($null -eq $name) { $operator += '|' }
                        p_debug "    \recording stopped:$operator" DarkRed 
                    } 
                    else { $operator += $a } 
                }
                "PARAMETERS" { 
                    if ($a -notmatch "[a-zA-Z0-9:]") {
                        $recording = $null
                        $i--
                        p_debug "    \recording stopped:$parameters" DarkRed 
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
                        p_debug "    \recording stopped:$parameters" DarkRed 
                    } 
                }
                "INDEX" { 
                    if ($a -eq "]") {
                        $recording = $null
                        p_debug "    \recording stopped:$index" DarkRed 
                    } 
                    elseif ($a -notmatch "[0-9]") { return p_throw IllegalValueAssignment $a "index" } $index += $a 
                }
                "COMMAND" {
                    if ($a -eq '"') { $recording = $null } 
                    $parameters += $a
                    if ($null -eq $recording) { 
                        $parameters = $parameters -replace '"', ""
                        p_debug "    \recording stopped:$parameters" DarkRed 
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
                    p_debug "    \recording [param] as command arguments" DarkGreen
                }
                if ($operator -eq "=.") {
                    $recording = "STRING"
                    $parameters = $a
                    p_debug "    \recording [param] as string" DarkGreen
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
                        $recording = "INDEX"; p_debug "    \recording [index]" DarkGreen 
                    } 
                }
                elseif ($null -ne $name) {
                    #Attempt to record [index] 
                    if ($null -ne $index) { 
                        return p_throw ElementAlreadyAssigned "index" 
                    }
                    $index = "["
                    $recording = "INDEX" 
                    p_debug "    \recording [index]" DarkGreen 
                }
                #Attempt to record [cast]
                else {
                    $cast = "["
                    $recording = "CAST"
                    p_debug "    \recording [cast]" DarkGreen 
                } 
            }
            elseif ($a -match "[a-zA-Z0-9_]") { 
                #Attempt to record [name]
                if ($null -eq $name) {
                    $name = $a
                    $recording = "NAME"
                    p_debug "    \recording [name]" DarkGreen 
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
                        p_debug "    \recording [param]" DarkGreen 
                    }
                }
                elseif ($null -eq $parameters) {
                    $parameters = $a
                    $recording = "parameters"
                    p_debug "    \recording [param]" DarkGreen 
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
                    p_debug "    \recording [param] as string" DarkGreen 
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
                    p_debug "    \recording [op]" DarkGreen 
                } 
            }
        }
    }
    return @($cast, $name, $operator, $parameters, $index)
}

function p_index ($indexable, $index) {
    p_debug_function p_foo DarkMagenta
    p_debug "    \ index:$index" darkGray
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

function p_foo ($name, $params) {
    p_debug_function p_foo Magenta
    p_debug "    \ name:$name" darkGray
    p_debug "    \ params:$params" darkGray
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
            return p_add @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        add_assign { 
            $split = $params -split ":"
            $val = p_add @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return Set-PersistContent @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        minus { 
            $split = $params -split ":"
            return p_minus @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        minus_assign { 
            $split = $params -split ":"
            $val = p_minus @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return Set-PersistContent @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        multiply { 
            $split = $params -split ":"
            return p_multiply @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        multiply_assign { 
            $split = $params -split ":"
            $val = p_multiply @{ Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return Set-PersistContent @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        divide { 
            $split = $params -split ":"
            return p_divide @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        divide_assign { 
            $split = $params -split ":"
            $val = p_divide @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return Set-PersistContent @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        exponentiate { 
            $split = $params -split ":"
            return p_exponentiate @{ Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        exponentiate_assign { 
            $split = $params -split ":"
            $val = p_exponentiate @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return Set-PersistContent @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        { p_eq $_ @("void", "_") } {
            $null = Invoke-Expression "persist $params"
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
            if ($null -eq $v_) {
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
            $spl = $params -split "::"
            if($spl.count -ne 2) {
                return p_throw IllegalArgumentException "[SCOPE]::[PATH]" $params
            }
            $name = $spl[0]
            $path = $spl[1]
            if($path -notmatch "persist\.cfg$") {
                if($path -notmatch "\\$") { $path += "\" }
                $path += "persist.cfg"
            }
            if(!(Test-Path $path)) {
                $prompt = "`n$path doesn't exist, create it?"
                while("$(Read-Host $prompt)"  -notmatch "([Yy]|[Yy][Ee][Ss])|([Nn]|[Nn][Oo])"
) { Write-Host "Please provide a [y]es or [n]o answer"; $prompt = "`n" } 
                if($matches[0] -match "[Yy]|[Yy][Ee][Ss]") {
                    $null = New-Item -Path $path -Force
                }
                else {
                    Write-Host "$path does not exist" -ForegroundColor Red
                    return
                }
            }
            Add-Content $global:SCOPES_PATH "$name::$path"
            Add-Content $path "[string]scopeInfo=$name::$path`n"
            Start-Scopes
            Set-Scope $spl[0]
        }
        Default {}
    }
}

function persist {

    p_debug_function persist White
    
    if ($global:_debug_) {
        for ($i = 0; $i -lt $args.length; $i++) {
            $a = $args[$i]
            p_debug "    \$a" darkgray
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


    $prompt = "    \ cast:         $cast
    \ name:         $name
    \ operator:     $oper
    \ parameter:    $para
    \ index:        $inde"
    p_debug $prompt darkgray
   
    <#
    Based on the available variables [cast][name][op][param], the follow up operations are decided

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

                [param] Applies [param] via [op] to [cast][index]

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
        p_debug "    \ content | p_getLine $name | p_getVal" darkGray
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
        p_debug "    \ indexing" darkGray
        if (($null -ne $para) -and (p_match $a_ "$para\[[0-9]+]")) {
            p_debug "      % param: $para" darkGray
            $para = p_index $para $inde
            p_debug "      \ param: $para" darkGray
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
            ">_" { $res = p_foo $name $para } # getthis (command)
            "=" { 
                if ($null -eq $para) { return p_throw IllegalOperationSyntax "Expected argument for operator assign [n]" } 
                if ($v_ -eq $para) {
                    if ($global:_debug_) { Write-Host "    \ var.val is already: $para" -ForegroundColor Magenta }
                    $res = $l_
                }
                else { $res = p_foo assign $cast':'$name':'$para } 
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
