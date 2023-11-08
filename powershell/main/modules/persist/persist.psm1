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

function p_prolix ($message, $messageColor, $meta) {
    if (!$global:prolix) { return }
    if ($null -eq $messageColor) { $messageColor = "Gray" }
    Write-Host $message -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function p_prolix_function ($function, $functionColor, $meta) {
    if (!$global:prolix) { return }
    if ($null -eq $messageColor) { $messageColor = "Gray" }
    Write-Host ">_ $function" -ForegroundColor $functionColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
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
function p_instance_root {  }
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
    if (($string -is [System.Array])) {
        $string = $string -join "`n"
    }
    if ($regex -is [System.Array]) {
        foreach ($r in $regex) {
            $string = $string -replace $r, $replace
        }
    }
    return $string -replace $regex, $replace
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
    return p_for $nullable.length 1 1 '$result = $true' 'if(($nullable[$i] -ne " ") -and ($nullable[$i] -ne "`n")){ $result = $false}' 'return $result'
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
    if ($line[0] -ne "[" ) { return }
    for ($i = 0; $i -lt $line.Length; $i++) {
        $cast += $line[$i]
        if ($line[$i] -eq "]") { return $cast }
    }
}

function p_getLine ($content, $var) {
    p_prolix_function p_getLine darkyellow
    $c_ = $content -split "`n"
    foreach ($c in $c_) {
        if ($c -match $var) { 
            p_prolix "    \ line: $c" darkGray
            return $c 
        }
    }
}

function p_getVal ($line) {
    p_prolix_function p_getVal darkyellow
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
    p_prolix "    \ val: $val" darkGray
    return $val
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

$global:p_error_action = "Stop"

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#               C O N S T A N T S                 #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
$global:_user_persist_cfg = "C:\users\$ENV:USERNAME\.powershell\persist.cfg"
$global:_host_persist_cfg = "C:\Windows\System32\WindowsPowerShell\v1.0\persist.cfg"
$global:_instance_persist_cfg = "$global:_persist_module_location\persist.cfg"

$global:_scope_user = "USER"
$global:_scope_instance = "INSTANCE"
$global:_scope_host = "HOST"
$global:_scope_network = "NET"


<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#               I N I T I A L I Z E               #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

if (p_npath $global:_user_persist_cfg) { $null = new-item $global:_user_persist_cfg -Force }
if ((p_npath $global:_host_persist_cfg) -and (p_elevated)) { $null = new-item $global:_host_persist_cfg -Force }
if (p_npath $global:_instance_persist_cfg) { $null = new-item $global:_instance_persist_cfg -Force }

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
        [Environment]::SetEnvironmentVariable("GLOBAL", $global:man_persist, [System.EnvironmentVariableTarget]::Machine)
    }
}

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#               V A R I A B L E S                 #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

$global:_scope = $global:_scope_user
$global:_network_scope_parent = $global:_scope

<#~~~~~~~ NETWORK CONTENTS ~~~~~~~~#>

<# USER NETWORK CONTENTS#>
function init_user_network ([boolean]$pull) {
    p_prolix_function init_user_network DarkRed
    $global:_network_persist_cfg_user = p_getVal (p_getLine $global:_content_user networkLocation)
    if ($null -ne $global:_network_persist_cfg_user) {
        $global:_network_persist_cfg_user = "$global:_network_persist_cfg_user\persist.cfg"
        if (p_npath $global:_network_persist_cfg_user) { $null = new-item $global:_network_persist_cfg_user -Force }
        $global:_content_user_network = (Get-Item $global:_network_persist_cfg_user -force | Get-Content -Force) -join "`n"
        if ($null -eq $global:_content_user_network ) { $global:_content_user_network = "" }
        try { if (!$pull) { p_push } } catch [System.Management.Automation.CommandNotFoundException] {}
    }
}

<# INSTANCE NETWORK CONTENTS#>
function init_instance_network([boolean]$pull) {
    p_prolix_function init_instance_network DarkRed
    $global:_network_persist_cfg_instance = (p_match "$($global:_content_instance | select-string networkLocation)" "(?![\\w]+)(?:=)(.+)" -getMatch) -replace "=", ""
    if ($null -ne $global:_network_persist_cfg_instance) {
        $global:_network_persist_cfg_instance = "$global:_network_persist_cfg_instance\persist.cfg"
        if (p_npath $global:_network_persist_cfg_instance) { $null = new-item $global:_network_persist_cfg_instance -Force }
        $global:_content_instance_network = (Get-Item $global:_network_persist_cfg_instance -force | Get-Content -Force) -join "`n"
        if ($null -eq $global:_content_instance_network ) { $global:_content_instance_network = "" }
        try { if (!$pull) { p_push } } catch [System.Management.Automation.CommandNotFoundException] {}
    }
}

<# USER NETWORK CONTENTS#>
function init_host_network([boolean]$pull) {
    p_prolix_function init_host_network DarkRed
    if (p_elevated) {
        $global:_network_persist_cfg_host = (p_match "$($global:_content_host | select-string networkLocation)" "(?![\\w]+)(?:=)(.+)" -getMatch) -replace "=", ""
        if ($null -ne $global:_network_persist_cfg_host) {
            $global:_network_persist_cfg_host = "$global:_network_persist_cfg_host\persist.cfg"
            if (p_npath $global:_network_persist_cfg_host) { $null = new-item $global:_network_persist_cfg_host -Force }
            $global:_content_host_network = (Get-Item $global:_network_persist_cfg_host -force | Get-Content -Force) -join "`n"
            if ($null -eq $global:_content_host_network ) { $global:_content_host_network = "" }
            try { if (!$pull) { p_push } } catch [System.Management.Automation.CommandNotFoundException] {}
        }
    }
}

function p_init_scope ($scope, [boolean] $pull) {

    $scopes = @(
        "instance"
        "user"
        "host"
        "network_instance"
        "network_user"
        "network_host"
    )

    if ($null -eq $scope) {
        foreach ($s in $scopes) {
            p_init_scope $s -pull $pull
        }
    }

    switch ($scope) {
        instance { 
            p_prolix_function "p_init_scope : instance" DarkRed
            <# INSTANCE CONTENT #>
            $global:_content_instance = (Get-Item $global:_instance_persist_cfg -Force | Get-Content -Force) -join "`n"
            if ($null -eq $global:_content_instance ) { $global:_content_instance = "" } 
        }
        user {
            p_prolix_function "p_init_scope : user" DarkRed
            <# USER CONTENT #>
            $global:_content_user = (Get-Item $global:_user_persist_cfg -Force | Get-Content -Force) -join "`n"
            if ($null -eq $global:_content_user ) { $global:_content_user = "" } 
        }
        host { 
            p_prolix_function "p_init_scope : host" DarkRed
            <# HOST CONTENT [ADMIN CONSOLE REQUIRED]#>
            if (p_elevated) {
                $global:_content_host = (Get-Item $global:_host_persist_cfg -Force | Get-Content -Force) -join "`n"
            }
            if ($null -eq $global:_content_host ) { $global:_content_host = "" }
        }
        network_instance { init_instance_network -pull $pull }
        network_user { init_user_network -pull $pull }
        network_host { init_host_network -pull $pull }
        Default {}
    }
}

p_init_scope

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#               F U N C T I O N S                 #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

function p_set_scope_user {
    p_push
    $global:_scope = $global:_scope_user
    $a_ = $args -join " "
    if ($global:prolix) { Write-Host "g_set_scope_user => args: $a_" -ForegroundColor Green }
    if (p_nullemptystr $a_) { return }
    return Invoke-Expression $a_
}
Set-Alias -Name user -Value p_set_scope_user -Scope Global -Force

function p_set_scope_instance {
    p_push
    $global:_scope = $global:_scope_instance
    $a_ = $args -join " "
    if ($global:prolix) { Write-Host "g_set_scope_instance => args: $a_" -ForegroundColor Green }
    if (p_nullemptystr $a_) { return }
    return Invoke-Expression $a_
}
Set-Alias -Name instance -Value p_set_scope_instance -Scope Global -Force

function p_set_scope_host {
    p_push
    $global:_scope = $global:_scope_host
    $a_ = $args -join " "
    if ($global:prolix) { Write-Host "g_set_scope_host => args: $a_" -ForegroundColor Green }
    if (p_nullemptystr $a_) { return }
    return Invoke-Expression $a_
}
Set-Alias -Name host -Value p_set_scope_host -Scope Global -Force

function p_set_scope_network {
    p_push
    if ($global:_scope -ne $global:_scope_network) {
        g
        $global:_network_scope_parent = $global:_scope
    }
    $global:_scope = $global:_scope_network
    $a_ = $args -join " "
    if ($global:prolix) { Write-Host "g_set_scope_network => args: $a_" -ForegroundColor Green }
    if (p_nullemptystr $a_) { return }
    return Invoke-Expression $a_
}
Set-Alias -Name network -Value p_set_scope_network -Scope Global -Force

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
    if ($parameters -eq "networkLocation") {
        write-host 'p_foo_remove ! Cannot remove networkLocation with remove:: command, use: > persist clearNetworkDir::' -ForegroundColor Yellow
        return
    }
    $removeReg = "(`n)?(\[[a-z]+])?$parameters=.+"
    $content = $global:c_
    if ($global:prolix) { Write-Host "  \ content: $content`n   \ regex : $removeReg" -ForegroundColor DarkRed -BackgroundColor Black }
    switch ($global:_scope) {
        $global:_scope_user { 
            $global:_content_user = $content -replace $removeReg, ""
        }
        $global:_scope_instance { 
            $global:_content_instance = $content -replace $removeReg, ""
        }
        $global:_scope_host { 
            $global:_content_host = $content -replace $removeReg, ""
        }
        $global:_scope_network { 
            switch ($global:_network_scope_parent) {
                $global:_scope_user {
                    if ($null -eq $global:_network_persist_cfg_user) { Write-Error 'user network location has not been initialized. Call > p_set_scope_user global networkLocation = \\network\share to initialize' } else {                    
                        $global:_content_user_network = $content -replace $removeReg, ""
                    } 
                }
                $global:_scope_instance {
                    if ($null -eq $global:_network_persist_cfg_instance) { Write-Error 'instance network location has not been initialized. Call > p_set_scope_instance global networkLocation = \\network\share to initialize' } else {                    
                        $global:_content_instance_network = $content -replace $removeReg, ""
                    } 
                }
                $global:_scope_host {
                    if (p_elevated) {
                        if ($null -eq $global:_network_persist_cfg_host) { Write-Error 'host network location has not been initialized. Call > p_set_scope_host global networkLocation = \\network\share to initialize' } else {                    
                            $global:_content_host_network = $content -replace $removeReg, ""
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

function p_foo_search ($parameters) {
    $content = ($global:c_) -split "`n"
    if ($global:prolix) { write-host "p_foo_search:`n  \ Scope:$global:_scope`n   \ var:$parameters" -ForegroundColor Green }
    return $($content | Where-Object { $_ -match $parameters })
}

function p_foo_setNetworkDir ($parameters) {
    $path = $parameters
    if ($global:prolix) { write-host "p_foo_setNetworkDir:`n  \ Scope:$global:scope`n   \ Path:$path" -ForegroundColor Green }
    if (persist nonnull::networkLocation) {
        write-host 'p_foo_setNetworkDir ! networkLocation already assigned ! clear with command first: > persist clearNetworkDir::' -ForegroundColor Yellow
        return
    }
    if (!(test-path $path) ) {
        Write-Host "Passed network directory: $path :does not exist"
        return
    }
    switch ($global:scope) {
        $global:_scope_user {
            $global:_content_user += "`n[string]networkLocation=$path"
            init_user_network
        }
        $global:_scope_instance {
            $global:_content_instance += "`n[string]networkLocation=$path"
            init_instance_network
        }
        $global:_scope_host {
            $global:_content_host += "`n[string]networkLocation=$path"
            init_host_network
        }
    }
}

function p_foo_clearNetworkDir {
    $line = p_getLine ($global:c_) networkLocation
    $line = "(`n)?$line"
    if ($global:prolix) { write-host "p_foo_clearNetworkDir:`n  \ Scope:$global:scope`n   \ Line:$line" -ForegroundColor Green }
    switch ($global:scope) {
        $global:_scope_user {
            $global:_content_user = $global:_content_user -replace $line, ""
            init_user_network
        }
        $global:_scope_instance {
            $global:_content_instance = $global:_content_instance -replace $line, ""
            init_instance_network
        }
        $global:_scope_host {
            $global:_content_host = $global:_content_host -replace $line, ""
            init_host_network
        }
    }
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
    if ($global:prolix) { Write-Host "g_foo : $function :: $parameters" -ForegroundColor DarkRed -BackgroundColor Black }
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

function p_item {
    [CmdletBinding()]
    param (
        [Parameter()]
        $scope,
        [Parameter()]
        $networkScopeParent
    )
    if ($null -eq $scope) { $scope = $global:_scope }
    if ($null -eq $networkScopeParent) { $networkScopeParent = $global:_network_scope_parent }
    switch ($scope) {
        $global:_scope_user { return get-Item $global:_user_persist_cfg -Force }
        $global:_scope_instance { return get-Item $global:_instance_persist_cfg -Force }
        $global:_scope_host { if (p_elevated) { return get-Item $global:_host_persist_cfg -Force } else {  } }
        $global:_scope_network {
            switch ($networkScopeParent) {
                $global:_scope_user { if ($null -eq $global:_network_persist_cfg_user) { Write-Error 'user network location has not been initialized. Call > p_set_scope_user global networkLocation = \\network\share to initialize' } else { return get-Item $global:_network_persist_cfg_user -Force } }
                $global:_scope_instance { if ($null -eq $global:_network_persist_cfg_instance) { Write-Error 'instance network location has not been initialized. Call > p_set_scope_instance global networkLocation = \\network\share to initialize' } else { return get-Item $global:_network_persist_cfg_instance -Force } }
                $global:_scope_host { if (p_elevated) { if ($null -eq $global:_network_persist_cfg_host) { Write-Error 'host network location has not been initialized. Call > p_set_scope_host global networkLocation = \\network\share to initialize' } else { return get-Item $global:_network_persist_cfg_host -Force } } else { p_ehe } }
                Default {}
            } 
        }
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
    if ($global:prolix) { Write-Host "p_content:" -ForegroundColor Cyan }
    switch ($scope) {
        $global:_scope_user { 
            if ($global:prolix) { Write-Host "    \ user:$global:_content_user" -ForegroundColor DarkCyan }; return $global:_content_user 
        }
        $global:_scope_instance {
            if ($global:prolix) { Write-Host "    \ instance:$global:_content_instance" -ForegroundColor DarkCyan }; return $global:_content_instance 
        }
        $global:_scope_host { 
            if (p_elevated) { if ($global:prolix) { Write-Host "    \ host:$global:_content_host" -ForegroundColor DarkCyan }; return $global:_content_host } else { p_ehe } 
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
    if ($global:prolix) { Write-Host "p_push `n  \ scope: $scope ~ netScopeParent: $networkScopeParent" -ForegroundColor Yellow }
    $c_ = p_content $scope $networkScopeParent
    $i_ = p_item $scope $networkScopeParent
    if ($global:prolix) { Write-Host "     \ item: $i_" -ForegroundColor Yellow }
    try {
        Set-Content $i_.fullname $c_ -ErrorAction Stop
    }
    catch {
        Write-Host " << Failed to write to cfg file" -ForegroundColor Red
        if ($global:prolix) { Write-Host "    $_" -ForegroundColor Red }
    }
}

function p_pull {
    [CmdletBinding()]
    param (
        [Parameter()]
        $scope,
        [Parameter()]
        $networkScopeParent
    )
    p_prolix_function p_pull yellow
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
            if ($global:prolix) { Write-Host "g_get : _SEARCH_ : $cast `n$($g_)" -ForegroundColor DarkYellow }
            if (p_match $flags "_NOT_") { return $g_.length -eq 0 }
            if (p_match $flags "_BOOL_") { return $g_.length -gt 0 }
            if ($null -ne $cast) { $g_ = p_cast $cast $g_ }
            return $g_
        }
        else {
            $get = p_getVal $match
            $cast = if ($null -eq $cast) { p_getCast $match } else { $cast }
            if ($global:prolix) { Write-Host "g_get : $cast $get" -ForegroundColor DarkYellow }
            if (p_match $flags "_NOT_") { if ($null -eq $get) { $get = $true } else { $get = !(p_castBool $get) } }
            if (p_match $flags "_BOOL_") { if ($null -eq $get) { $get = $false } else { $get = p_castBool $get } }
            if ($null -ne $cast) { $get = p_cast $cast $get }
            return $get
        }
    }
    else {
        
    }
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
    p_prolix "p_assign: $val => $var" Magenta
    if ($var -eq "networkLocation") {
        write-host 'Cannot set networkLocation with persist command directly, use: > persit setNetworkDir>_`"@{scope=$SCOPE;path=$PATH}"`' -ForegroundColor Yellow
        return
    }
    $content = $global:c_
    $line = p_getLine $content $var
    $replace = "$cast$var=$val"
    if ($null -ne $line) {
        $line = p_stringify_regex $line
        if ($global:prolix) { Write-Host "  \ $line => $replace" -ForegroundColor Magenta }
        if ($global:prolix) { Write-Host "    ~ replacing" -ForegroundColor Magenta }
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
        if ($global:prolix) { Write-Host "  \ $line => $replace" -ForegroundColor Magenta }
        if ($global:prolix) { Write-Host "    ~ adding" -ForegroundColor Magenta }
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

function persist_v1 {
    
    if ($global:prolix) { Write-Host "global: $args" -ForegroundColor White }

    $flags = ""
    $a_ = $args -join ""
    $valReg = '.+'

    $cast = $null
    $var = $null
    $act = $null
    $val = $null
    $prop = $null

    # Regex for scope changes
    if ($a_ -match "->( )?(\w+)?") {
        $scope = $matches[0] -replace "->", ""
        switch ($scope) {
            "user" { p_set_scope_user }
            "instance" { p_set_scope_instance }
            "host" { p_set_scope_host }
            "network" { p_set_scope_network }
            "" { p_push }
            Default { Write-Error "Invalid Scope [ $scope ]" }
        }
        return
    }
    # Regex for functions
    if ($a_ -match "[a-z]+::.+") {
        $m_ = $matches
        $f_ = p_match $m_[0] "[a-z]+(?<!:)" -getMatch
        $p_ = p_match $m_[0] "(?<=::).+(?=)" -getMatch
        return p_foo $f_ $p_
    }
    
    # Regex for casts
    if ($a_ -match "^\[[a-z]+]") {
        $cast = $matches[0] 
        switch ($cast) {
            '[int]' { $valReg = '(-)?[0-9]+' }
            '[double]' { $valReg = '(-)?[0-9]+(.)?([0-9]+)?' }
        }
    }
    # Regex for variable
    if ($a_ -match "(^\[[a-z]+])?(!)?[a-z]<([A-Z](<)?)+([\$])?") {
        $flags += '_SEARCH_'
        $var = $matches[0]
        if ($cast) {
            $var = $var -replace "\$cast", ''
        }
        if ($var -match '!') {
            $flags += '_NOT_'
            $var = $var -replace '!', ''
            $a_ = $a_ -replace '!', ''
        }
        if ($var -match '\$') {
            $flags += '_PSVARS_'
            $var = $var -replace '\$', ''
            $a_ = $a_ -replace '\$', ''
        }
        $split = $var -split "<"
        $var = ""
        foreach ($s in $split) {
            $var += "$s\w+"
        }
    }
    elseif ($a_ -match "((^\[[a-z]+])?(!)?\w+)([\$])?") {
        $var = $matches[0]
        if ($cast) {
            $var = $var -replace "\$cast", ''
        }
        if ($var -match '^!') {
            $flags += '_NOT_'
            $var = $var -replace '^!', ''
            $a_ = $a_ -replace '(?!\[)!', ''
        }
        if ($var -match '\$') {
            $flags += '_PSVARS_'
            $var = $var -replace '\$', ''
            $a_ = $a_ -replace '\$', ''
        }
    }
    # Regex for property
    if ($a_ -match "(^\[[a-z]+])?(!)?\w+\.\w+") {
        $prop = $matches[0]
        $prop = (p_match $prop "\.\w+" -getMatch) -replace "\.", ""
    }
    # Regex for value
    if (($a_ -match '[!~=+\-*\/?^]+') -or ($a_ -match "\[([0-9]+)?]")) {
        $act = $matches[0]
        switch ($act) {
            '=' {
                $act = "ASSIGN"
                if ($a_ -match "(?<==)$valReg") {
                    $val = $matches[0]
                }
            }
            "+" {
                $act = "PLUS" 
                if ($a_ -match "(?<=\+)$valReg") {
                    $val = $matches[0]
                } 
            }
            "-" {
                $act = "MINUS" 
                if ($a_ -match "(?<=-)$valReg") {
                    $val = $matches[0]
                } 
            }
            "*" {
                $act = "TIMES" 
                if ($a_ -match "(?<=\*)$valReg") {
                    $val = $matches[0]
                } 
            }
            "/" {
                $act = "DIV" 
                if ($a_ -match "(?<=/)$valReg") {
                    $val = $matches[0]
                } 
            }
            "++" {
                $act = "PLUS_PLUS" 
                if ($a_ -match "(?<=\+\+)$valReg") {
                    $val = $matches[0]
                } 
            }
            "--" {
                $act = "MINUS_MINUS" 
                if ($a_ -match "(?<=--)$valReg") {
                    $val = $matches[0]
                } 
            }
            "+=" {
                $act = "PLUS_EQ" 
                if ($a_ -match "(?<=\+=)$valReg") {
                    $val = $matches[0]
                } 
            }
            "-=" {
                $act = "MINUS_EQ" 
                if ($a_ -match "(?<=-=)$valReg") {
                    $val = $matches[0]
                } 
            }
            "*=" {
                $act = "TIMES_EQ" 
                if ($a_ -match "(?<=\*=)$valReg") {
                    $val = $matches[0]
                } 
            }
            "/=" {
                $act = "DIV_EQ" 
                if ($a_ -match "(?<=\/=)$valReg") {
                    $val = $matches[0]
                } 
            }
            "==" {
                $act = "EQUALS" 
                if ($a_ -match "(?<===)$valReg") {
                    $val = $matches[0]
                } 
            }
            "~=" {
                $act = "MATCH" 
                if ($a_ -match "(?<=~=)$valReg") {
                    $val = $matches[0]
                } 
            }
            "^" {
                $act = "POW" 
                if ($a_ -match "(?<=\^)$valReg") {
                    $val = $matches[0]
                } 
            }
            "?" {
                $act = "TERTIARY" 
                if ($a_ -match "(?<=\?)$valReg") {
                    $val = $matches[0]
                }
                else {
                    $flags += "_BOOL_"
                }
            }
            "~" {
                $act = "SPECIAL"
                if ($flags -match "_PSVARS_") {
                    
                }

            }
            { p_match $_ "\[([0-9]+)?]" } {
                $script:i = p_match $act "[0-9]+" -getMatch
                $act = "ARRAY" 
            }
            Default { Write-Error "Invalid operator [ $act ]"; $null = Read-Host 'Press enter to continue'; return }
        }
    }

    if ($global:prolix) { Write-Host "cast:$cast`nvar:$var`nproperty:$prop`naction:$act`nvalue:$val`nflags:$flags`nscope:$global:_scope" -ForegroundColor Cyan }

    if (p_null @($var, $cast, $act)) {
        if ($global:prolix) { Write-Host "retrieving global content ~`n  network_scope_parent:$global:_network_scope_parent" -ForegroundColor Cyan }
        return p_content
    }
    if (p_nonnull @($var, $act, $val)) {
        $g = p_get $var $cast $flags 
        if ($act -eq "ASSIGN") { p_assign $var $val -cast $cast; return }
        if (p_eq $act @("PLUS_PLUS", "MINUS_MINUS")) {
            Write-Error "increment operators cannot be applied with values [ $val ]"; $null = Read-Host 'Press enter to continue'
            return
        }
        if ($null -eq $g) {
            Write-Error "$var has not been initiated"; $null = Read-Host 'Press enter to continue'
            return
        }
        switch ($act) {
            "PLUS" {
                if (p_is $g @([byte], [int], [long], [float], [double], [string], [boolean])) {
                    try {
                        $g += $val
                    }
                    catch [System.Management.Automation.RuntimeException] {
                        Write-Error $_
                        return
                    }
                }
                else {
                    Write-Error "Cannot increment type $($g.GetType().Name) for variable $var"
                    return
                }
                return $g
            }
            "PLUS_EQ" {
                if (p_is $g @([byte], [int], [long], [float], [double], [string], [boolean])) {
                    try {
                        $g += $val
                    }
                    catch [System.Management.Automation.RuntimeException] {
                        Write-Error $_
                        return
                    }
                }
                else {
                    Write-Error "Cannot increment type $($g.GetType().Name) for variable $var"
                    return
                }
                p_assign $var $g -cast $cast
            }
            "MINUS" {
                if (p_is $g @([byte], [int], [long], [float], [double], [boolean])) {
                    try {
                        $g -= $val
                    }
                    catch [System.Management.Automation.RuntimeException] {
                        Write-Error $_
                        return
                    }
                }
                elseif ($g -is [string]) {
                    if (p_is $val  @([byte], [int], [long], [float], [double], [string], [boolean])) {
                        try {
                            $g = $g -replace $val, ""
                        }
                        catch [System.Management.Automation.RuntimeException] {
                            Write-Error $_
                            return
                        }
                    }
                    else {
                        Write-Error "Cannot decrement with type $($val.GetType().Name) of value $val"
                        return
                    }
                }
                else {
                    Write-Error "Cannot decrement type $($g.GetType().Name) for variable $var"
                    return
                }
                return $g
            }
            "MINUS_EQ" {
                if (p_is $g @([byte], [int], [long], [float], [double], [boolean])) {
                    try {
                        $g -= $val
                    }
                    catch [System.Management.Automation.RuntimeException] {
                        Write-Error $_
                        return
                    }
                }
                elseif ($g -is [string]) {
                    if (p_is $val  @([byte], [int], [long], [float], [double], [string], [boolean])) {
                        try {
                            $g = $g -replace $val, ""
                        }
                        catch [System.Management.Automation.RuntimeException] {
                            Write-Error $_
                            return
                        }
                    }
                    else {
                        Write-Error "Cannot decrement with type $($val.GetType().Name) of value $val"
                        return
                    }
                }
                else {
                    Write-Error "Cannot decrement type $($g.GetType().Name) for variable $var"
                    return
                }
                p_assign $var $g -cast $cast
            }
            "TIMES" {
                if (p_is $g @([byte], [int], [long], [float], [double], [boolean])) {
                    try {
                        $g *= $val
                    }
                    catch [System.Management.Automation.RuntimeException] {
                        Write-Error $_
                        return
                    }
                }
                elseif ($g -is [string]) {
                    if (p_is $val  @([byte], [int], [long], [float], [double], [string], [boolean])) {
                        try {
                            $v_ = [Math]::Round($val) - 1
                            $g = p_for $v_ 1 1 '$a_ = @($g)' '$a_ += $g' 'return $a_ -join ""'
                        }
                        catch [System.Management.Automation.RuntimeException] {
                            Write-Error $_
                            return
                        }
                    }
                    else {
                        Write-Error "Cannot apply multiply operator with type $($val.GetType().Name) of value $val"
                        return
                    }
                }
                else {
                    Write-Error "Cannot apply multiply operator type $($g.GetType().Name) for variable $var"
                    return
                }
                return $g
            }
            "TIMES_EQ" {
                if (p_is $g @([byte], [int], [long], [float], [double], [boolean])) {
                    try {
                        $g *= $val
                    }
                    catch [System.Management.Automation.RuntimeException] {
                        Write-Error $_
                        return
                    }
                }
                elseif ($g -is [string]) {
                    if (p_is $val  @([byte], [int], [long], [float], [double], [string], [boolean])) {
                        try {
                            $v_ = [Math]::Round($val) - 1
                            $g = p_for $v_ 1 1 '$a_ = @($g)' '$a_ += $g' 'return $a_ -join ""'
                        }
                        catch [System.Management.Automation.RuntimeException] {
                            Write-Error $_
                            return
                        }
                    }
                    else {
                        Write-Error "Cannot apply multiply operator with type $($val.GetType().Name) of value $val"
                        return
                    }
                }
                else {
                    Write-Error "Cannot apply multiply operator type $($g.GetType().Name) for variable $var"
                    return
                }
                p_assign $var $g -cast $cast
            }
            "DIV" {
                if (p_is $g @([byte], [int], [long], [float], [double], [boolean])) {
                    try {
                        $g /= $val
                    }
                    catch [System.Management.Automation.RuntimeException] {
                        Write-Error $_
                        return
                    }
                }
                else {
                    Write-Error "Cannot apply divide operator to type $($g.GetType().Name) for variable $var"
                    return
                }
                return $g
            }
            "DIV_EQ" {
                if (p_is $g @([byte], [int], [long], [float], [double], [boolean])) {
                    try {
                        $g /= $val
                    }
                    catch [System.Management.Automation.RuntimeException] {
                        Write-Error $_
                        return
                    }
                }
                else {
                    Write-Error "Cannot apply divide operator to type $($g.GetType().Name) for variable $var"
                    return
                }
                p_assign $var $g -cast $cast
            }
            "EQUALS" {
                return $g -eq $val
            }
            "MATCH" {
                return p_match $val $g
            }
            "POW" { p_pow $var $val -cast $cast }
            "TERTIARY" { p_plus_eq $var $val -cast $cast }
            "SPECIAL" { p_plus_eq $var $val -cast $cast }
            Default {}
        }
        return
    }
    if (p_nonnull @($var, $act)) {
        switch ($act) {
            "ASSIGN" { Write-Error "Assignment operator without any assignment value"; $null = Read-Host 'Press enter to continue' }
            "PLUS_PLUS" {
                $g = p_get $var $cast $flags 
                if (p_is $g @([byte], [int], [long], [float], [double])) {
                    $g++
                }
                else {
                    Write-Error "Cannot increment type $($g.GetType().Name) for variable $var"
                }
                p_assign $var $g -cast $cast
            }
            "MINUS_MINUS" {
                $g = p_get $var $cast $flags 
                if (p_is $g @([byte], [int], [long], [float], [double])) {
                    $g--
                }
                else {
                    Write-Error "Cannot increment type $($g.GetType().Name) for variable $var"
                }
                p_assign $var $g -cast $cast
            }
            "ARRAY" {
                $arr = p_get $var "[array]"
                if ($null -ne $script:i) {
                    if ($script:i -ge $arr.length) {
                        Write-Host "Out of range index [ $script:i ] of array $var that has length: $($arr.length)" -ForegroundColor Red
                    }
                    return $arr[$script:i] 
                } 
                return $arr
            }
            "TERTIARY" {
                if ($flags -match "_BOOL_") {
                    return p_get $var $cast -flags $flags
                }
            }
            Default {}
        }
        return
    }
    if (p_nonnull @($var, $prop)) {
        if ($global:prolix) { Write-Host "Executioning property: $prop on $v_" -ForegroundColor Cyan }
        $g = p_get $var
        if (($flags -match "_PSVAR_") -and ($g -is [string])) {
            $g = p_for $g.length 1 1 '$g = $g -replace "\$","#$"; $g = $g -split "#"' 'if($g[$i] -match "\$"){$g[$i] = $g[$i] -replace "\$",""; $g[$i] = (get-variable "$($g[$i])").value }' 'return $($g) -join ""'
        }
        $p = Invoke-Expression "$('(' + $g + ').' + $prop)"
        if ($null -ne $cast) { return p_cast $cast $p }
        return $p
    }
    if ($null -ne $var) {
        $g = p_get $var $cast -flags $flags
        if (($flags -match "_PSVARS_") -and ($g -is [string])) {
            $g = p_for $g.length 1 1 '$g = $g -replace "\$","#$"; $g = $g -split "#"' 'if($g[$i] -match "\$"){$g[$i] = $g[$i] -replace "\$",""; $g[$i] = (get-variable "$($g[$i])").value }' 'return $($g) -join ""'
        }
        return $g
    }
    
    Write-Error "Invalid format: $args"

}

function p_add {
    [CmdletBinding()]
    param (
        [Parameter()]
        $params
    )
    p_prolix_function p_add Blue
    p_prolix "    \ params:$(p_hash_to_string $params)" darkGray
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
    p_prolix_function p_minus Blue
    p_prolix "    \ params:$(p_hash_to_string $params)" darkGray
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
    p_prolix_function p_multiply Blue
    p_prolix "    \ params:$(p_hash_to_string $params)" darkGray
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
    p_prolix_function p_divide Blue
    p_prolix "    \ params:$(p_hash_to_string $params)" darkGray
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
    p_prolix_function p_exponentiate Blue
    p_prolix "    \ params:$(p_hash_to_string $params)" darkGray
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
    }
    if ($global:p_error_action -eq "Stop") {
        if (p_not_choice) { exit }
    }
    return $code
}

function p_parse_syntax ($a_) {
    p_prolix_function p_parse_syntax Green
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
    )
    $aL = $a_.Length
    $cast = $null
    $name = $null
    $operator = $null
    $parameters = $null
    $index = $null 
    $recording = $nullz
    for ($i = 0; $i -lt $aL; $i++) {
        $a = $a_[$i]
        if ($global:_debug_) { write-host ":: a_[i]: $a ::" -foregroundcolor darkyellow }
        if ($null -ne $recording) {
            if (($a -eq " ") -and ($recording -ne "STRING")) { continue }
            switch ($recording) {
                "CAST" {
                    if ($a -eq "]") { 
                        $recording = $null
                        p_prolix "    \recording stopped:$cast" DarkRed 
                    } 
                    elseif ($a -notmatch "[a-z]") 
                    { return p_throw IllegalValueAssignment $a "cast" } 
                    $cast += $a 
                }
                "NAME" { 
                    if ($a -notmatch "[a-zA-Z]") {
                        $recording = $null
                        p_prolix "    \recording stopped:$name" DarkRed
                        $i-- 
                    } 
                    else { $name += $a } 
                }
                "OPERATOR" { 
                    if (p_match $a $symbols -logic NOT) {
                        $recording = $null
                        $i--
                        if ($null -eq $name) { $operator += '|' }
                        p_prolix "    \recording stopped:$operator" DarkRed 
                    } 
                    else { $operator += $a } 
                }
                "PARAMETERS" { 
                    if ($a -notmatch "[a-zA-Z0-9:]") {
                        $recording = $null
                        $i--
                        p_prolix "    \recording stopped:$parameters" DarkRed 
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
                        p_prolix "    \recording stopped:$parameters" DarkRed 
                    } 
                }
                "INDEX" { 
                    if ($a -eq "]") {
                        $recording = $null
                        p_prolix "    \recording stopped:$index" DarkRed 
                    } 
                    elseif ($a -notmatch "[0-9]") { return p_throw IllegalValueAssignment $a "index" } $index += $a 
                }
                "COMMAND" {
                    if ($a -eq '"') { $recording = $null } 
                    $parameters += $a
                    if ($null -eq $recording) { 
                        $parameters = $parameters -replace '"', ""
                        p_prolix "    \recording stopped:$parameters" DarkRed 
                    } 
                }
            }
        }
        else {
            if ($a -eq " ") { 
                continue 
            }
            elseif (($null -ne $operator) -and ($operator -eq ">_")) {
                $recording = "COMMAND"
                $parameters = $a
                p_prolix "    \recording [param] as command arguments" DarkGreen
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
                        $recording = "INDEX"; p_prolix "    \recording [index]" DarkGreen 
                    } 
                }
                elseif ($null -ne $name) {
                    #Attempt to record [index] 
                    if ($null -ne $index) { 
                        return p_throw ElementAlreadyAssigned "index" 
                    }
                    $index = "["
                    $recording = "INDEX" 
                    p_prolix "    \recording [index]" DarkGreen 
                }
                #Attempt to record [cast]
                else {
                    $cast = "["
                    $recording = "CAST"
                    p_prolix "    \recording [cast]" DarkGreen 
                } 
            }
            elseif ($a -match "[a-zA-Z0-9_]") { 
                #Attempt to record [name]
                if ($null -eq $name) {
                    $name = $a
                    $recording = "NAME"
                    p_prolix "    \recording [name]" DarkGreen 
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
                        p_prolix "    \recording [param]" DarkGreen 
                    }
                }
                elseif ($null -eq $parameters) {
                    $parameters = $a
                    $recording = "parameters"
                    p_prolix "    \recording [param]" DarkGreen 
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
                    p_prolix "    \recording [param] as string" DarkGreen 
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
                    p_prolix "    \recording [op]" DarkGreen 
                } 
            }
        }
    }
    return @($cast, $name, $operator, $parameters, $index)
}

function p_index ($indexable, $index) {
    p_prolix_function p_foo DarkMagenta
    p_prolix "    \ index:$index" darkGray
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
    p_prolix_function p_foo Magenta
    p_prolix "    \ name:$name" darkGray
    p_prolix "    \ params:$params" darkGray
    switch ($name) {
        assign { 
            $split = $params -split ":"
            return p_assign @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        add { 
            $split = $params -split ":"
            return p_add @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        add_assign { 
            $split = $params -split ":"
            $val = p_add @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return p_assign @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        minus { 
            $split = $params -split ":"
            return p_minus @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        minus_assign { 
            $split = $params -split ":"
            $val = p_minus @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return p_assign @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        multiply { 
            $split = $params -split ":"
            return p_multiply @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        multiply_assign { 
            $split = $params -split ":"
            $val = p_multiply @{ Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return p_assign @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        divide { 
            $split = $params -split ":"
            return p_divide @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        divide_assign { 
            $split = $params -split ":"
            $val = p_divide @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return p_assign @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        exponentiate { 
            $split = $params -split ":"
            return p_exponentiate @{ Cast = $split[0]; Name = $split[1]; Value = $split[2] }
        }
        exponentiate_assign { 
            $split = $params -split ":"
            $val = p_exponentiate @{Cast = $split[0]; Name = $split[1]; Value = $split[2] }
            return p_assign @{Cast = $split[0]; Name = $split[1]; Value = $val }
        }
        void {
            $null = Invoke-Expression "persist $params"
        }
        nullOrEmpty { 
            $l_ = p_getLine $global:c_ $params
            $v_ = p_getVal $l_
            return $null -eq $v_  
        }
        NonNull { 
            $l_ = p_getLine $global:c_ $params
            $v_ = p_getVal $l_
            return $null -ne $v_ 
        }
        Remove {
            return p_foo_remove $params 
        }
        Search { 
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
        Default {}
    }
}

function persist {

    p_prolix_function persist White
    
    if ($global:prolix) {
        for ($i = 0; $i -lt $args.length; $i++) {
            $a = $args[$i]
            p_prolix "    \$a" darkgray
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
    p_prolix $prompt darkgray
   
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

    $global:c_ = p_content

    if (p_null @($name, $cast)) {
        if ($oper -eq "->") {
            p_push
            return
        }
        if ($oper -eq ">-") {
            p_pull
            return
        }
        else {
            return $global:c_
        }
    }
    

    if ($null -ne $name) {
        p_prolix "    \ content | p_getLine $name | p_getVal" darkGray
        $l_ = p_getLine $global:c_ $name
        $v_ = p_getVal $l_
        if (P_null @($oper, $inde, $cast, $para)) {
            return $v_
        }
    }

    if ($Null -ne $inde) {
        p_prolix "    \ indexing" darkGray
        if (($null -ne $para) -and (p_match $a_ "$para\[[0-9]+]")) {
            p_prolix "      % param: $para" darkGray
            $para = p_index $para $inde
            p_prolix "      \ param: $para" darkGray
        }
        else {
            p_prolix "      % val: $val" darkGray
            $v_ = p_index $v_ $inde
            p_prolix "      \ val: $val" darkGray
        }
    }

    if ($null -eq $oper) {
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
                $res = p_foo assign $cast':'$name':'$para 
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
                $res = p_push $name
            } # push [n]
            ">-|" { 
                if ($null -eq $name) { return p_throw IllegalOperationSyntax "Expected argument for operator pull [n]" } 
                $res = p_pull $name
            } # pull [n]
        }
        return $res
    }
  

}