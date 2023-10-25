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

function g_npath ($path) { return !(test-path $path) }
function g_elevated { return (new-object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
function g_instance_root {  }
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
function g_replace($string, $regex, [string] $replace) {
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
function g_for ([int]$iMax, [int]$jMax, [int]$kmax, [string] $startCommand, [string] $loopCommand, [string] $endCommand) {
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
function g_split ($string, $regex) {
    if ($null -eq $string) {
        return $string
    }
    if ($null -eq $regex) {
        return $string
    }
    if ($string -is [System.Array]) {
        for ($i = 0; $i -lt $string.length; $i++) {
            $string[$i] = g_split $string[$i] $regex
        }
        return $string
    }
    if ($regex -is [System.Array]) {
        foreach ($r in $regex) {
            $string = g_split $string $r
        }
        return $string
    }
    return $string -split $regex
}
function g_null {
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
function g_nullemptystr ($nullable) {
    if ($null -eq $nullable) { return $true }
    if ($nullable -isnot [string]) { return $false }
    if ($nullable.length -eq 0) { return $true }
    return g_for $nullable.length 1 1 '$result = $true' 'if(($nullable[$i] -ne " ") -and ($nullable[$i] -ne "`n")){ $result = $false}' 'return $result'
}
function g_nonnull {
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
function g_is ($obj, $class) {
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

function g_between ($val, $min, $max) {
    if ($val -lt $min) { return $false }
    return $val -lt $max
}
function g_match {
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
function g_parseString ($stringable) {
    if ($stringable -is [string]) { return $stringable }
    if ($null -eq $stringable) { return "" }upper
    if (g_is $stringable @([int], [long], [float], [double], [boolean])) { return [string]$stringable }
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        return Out-String -InputObject $stringable
    }
    else { return [string]$stringable }
}

function g_parseBool ($boolable) {
    if ($boolable -is [boolean]) { return $boolable }
    if ($null -eq $boolable) { return $false }
    if ($boolable -is [string]) {
        return g_match $boolable  @("true", "yes", "y", "1")
    }
    if (g_is $boolable @([int], [long], [float], [double])) {
        return $boolable -gt 0
    }
    return $true
}

function g_parseInt ($intable) {
    if ($intable -is [int]) { return $intable }
    if ($null -eq $intable) { return 0 }
    if (g_is $intable @([long], [float], [double], [string])) { return [int]$intable }
    if ($intable -is [boolean]) { if ($intable) { return 1 } else { return 0 } }
    if ($intable -is [System.Array]) { return $intable.length }
    return [int] $intable
}
function g_parseFloat ($floatable) {
    if ($floatable -is [float]) { return $floatable }
    if ($null -eq $floatable) { return 0 }
    if (g_is $floatable @([long], [int], [double], [string])) { return [float]$floatable }
    if ($floatable -is [boolean]) { if ($floatable) { return 1 } else { return 0 } }
    if ($floatable -is [System.Array]) { return $intable.length }
    return [float] $floatable
}
function g_parseLong ($longable) {
    if ($longable -is [long]) { return $longable }
    if ($null -eq $longable) { return 0 }
    if (g_is $longable @([int], [float], [double], [string])) { return [long]$longable }
    if ($longable -is [boolean]) { if ($longable) { return 1 } else { return 0 } }
    if ($longable -is [System.Array]) { return $intable.length }
    return [long] $longable
}
function g_parseDouble ($doubleable) {
    if ($doubleable -is [double]) { return $doubleable }
    if ($null -eq $doubleable) { return 0 }
    if (g_is $doubleable @([long], [float], [int], [string])) { return [double]$doubleable }
    if ($doubleable -is [boolean]) { if ($doubleable) { return 1 } else { return 0 } }
    if ($doubleable -is [System.Array]) { return $intable.length }
    return [double] $doubleable
}
function g_parseArray ($arrayAble) {
    if ($arrayAble -is [System.Array]) { return $arrayAble }
    if ($null -eq $arrayAble) { return $null }
    if ($arrayAble -is [string]) { return $arrayAble -split "," }
    return @($arrayAble)
}

function g_cast ($cast, $var) {
    switch (g_replace $cast @("\[", "]")) {
        "boolean" { 
            return g_parseBool $var
        }
        { g_match $_ @("int", "integer") } { 
            return g_parseInt $var
        }
        "long" { 
            return g_parseLong $var
        }
        "float" { 
            return g_parseFloat $var
        }
        "double" { 
            return g_parseDouble $var
        }
        "string" { 
            return g_parseString $var
        }
        Default { return Invoke-Expression "$($cast + '"' + $var + '"')" }
    }
}
function g_eq ($a_, $b_) {
    if ($b_ -is [System.Array]) {
        foreach ($b in $b_) {
            if ($a_ -eq $b) { return $true }
        }
        return $false
    }
    else { return $a_ -eq $b_ }
}

function g_ehe {
    Write-Error 'administrative rights required to access host global cfg'
}

function g_getCast ([string]$line) {
    if ($line[0] -ne "[" ) { return }
    for ($i = 0; $i -lt $line.Length; $i++) {
        $cast += $line[$i]
        if ($line[$i] -eq "]") { return $cast }
    }
}

function g_getLine ($content, $var) {
    $c_ = $content -split "`n"
    foreach ($c in $c_) {
        if ($c -match $var) { return $c }
    }
}

function g_getVal ($line) {
    $d = -1
    $l = $line.length
    $val = ""
    for ($i = $l - 1; g_between $i -1 $l; $i += $d) {
        if ($d -eq 1) {
            $val += $line[$i]
        }
        elseif ($line[$i] -eq "=") { $d = 1 }
    }
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
if ($null -eq $global:_global_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_global_module_location = $PSScriptRoot
    }
    else {
        $global:_global_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#               C O N S T A N T S                 #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
$global:_user_global_cfg = "C:\users\$ENV:USERNAME\.powershell\global.cfg"
$global:_host_global_cfg = "C:\Windows\System32\WindowsPowerShell\v1.0\global.cfg"
$global:_instance_global_cfg = "$global:_global_module_location\global.cfg"

$global:_scope_user = "USER"
$global:_scope_instance = "INSTANCE"
$global:_scope_host = "HOST"
$global:_scope_network = "NET"


<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#               I N I T I A L I Z E               #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

if (g_npath $global:_user_global_cfg) { $null = new-item $global:_user_global_cfg -Force }
if ((g_npath $global:_host_global_cfg) -and (g_elevated)) { $null = new-item $global:_host_global_cfg -Force }
if (g_npath $global:_instance_global_cfg) { $null = new-item $global:_instance_global_cfg -Force }

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#                   M A N U A L                   #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

if ($null -eq $env:global) {
    $global:man_global = '
.SYNOPSIS


.DESCRIPTION


.USAGES

    global apiKey = ajf7rj1ml4lfda8s

    global [int] apiKey
    
'
    if (g_elevated) {
        [Environment]::SetEnvironmentVariable("GLOBAL", $global:man_global, [System.EnvironmentVariableTarget]::Machine)
    }
}

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#               V A R I A B L E S                 #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

$global:_scope = $global:_scope_user
$global:_network_scope_parent = $global:_scope

<# USER CONTENT #>
$global:_content_user = (Get-Item $global:_user_global_cfg -Force | Get-Content -Force) -join "`n"
if ($null -eq $global:_content_user ) { $global:_content_user = "" }

<# INSTANCE CONTENT #>
$global:_content_instance = (Get-Item $global:_instance_global_cfg -Force | Get-Content -Force) -join "`n"
if ($null -eq $global:_content_instance ) { $global:_content_instance = "" }

<# HOST CONTENT [ADMIN CONSOLE REQUIRED]#>
if (g_elevated) {
    $global:_content_host = (Get-Item $global:_host_global_cfg -Force | Get-Content -Force) -join "`n"
}
if ($null -eq $global:_content_host ) { $global:_content_host = "" }

<#~~~~~~~ NETWORK CONTENTS ~~~~~~~~#>

<# USER NETWORK CONTENTS#>
function init_user_network {
    $global:_network_global_cfg_user = g_getVal (g_getLine $global:_content_user networkLocation)
    if ($null -ne $global:_network_global_cfg_user) {
        $global:_network_global_cfg_user = "$global:_network_global_cfg_user\global.cfg"
        if (g_npath $global:_network_global_cfg_user) { $null = new-item $global:_network_global_cfg_user -Force }
        $global:_content_user_network = (Get-Item $global:_network_global_cfg_user -force | Get-Content -Force) -join "`n"
        if ($null -eq $global:_content_user_network ) { $global:_content_user_network = "" }
        try { g_push } catch [System.Management.Automation.CommandNotFoundException] {}
    }
}
init_user_network

<# INSTANCE NETWORK CONTENTS#>
function init_instance_network {
    $global:_network_global_cfg_instance = (g_match "$($global:_content_instance | select-string networkLocation)" "(?![\\w]+)(?:=)(.+)" -getMatch) -replace "=", ""
    if ($null -ne $global:_network_global_cfg_instance) {
        $global:_network_global_cfg_instance = "$global:_network_global_cfg_instance\global.cfg"
        if (g_npath $global:_network_global_cfg_instance) { $null = new-item $global:_network_global_cfg_instance -Force }
        $global:_content_instance_network = (Get-Item $global:_network_global_cfg_instance -force | Get-Content -Force) -join "`n"
        if ($null -eq $global:_content_instance_network ) { $global:_content_instance_network = "" }
        try { g_push } catch [System.Management.Automation.CommandNotFoundException] {}
    }
}
init_instance_network

<# USER NETWORK CONTENTS#>
function init_host_network {
    if (g_elevated) {
        $global:_network_global_cfg_host = (g_match "$($global:_content_host | select-string networkLocation)" "(?![\\w]+)(?:=)(.+)" -getMatch) -replace "=", ""
        if ($null -ne $global:_network_global_cfg_host) {
            $global:_network_global_cfg_host = "$global:_network_global_cfg_host\global.cfg"
            if (g_npath $global:_network_global_cfg_host) { $null = new-item $global:_network_global_cfg_host -Force }
            $global:_content_host_network = (Get-Item $global:_network_global_cfg_host -force | Get-Content -Force) -join "`n"
            if ($null -eq $global:_content_host_network ) { $global:_content_host_network = "" }
            try { g_push } catch [System.Management.Automation.CommandNotFoundException] {}
        }
    }
}
init_host_network

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#               F U N C T I O N S                 #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

function g_set_scope_user {
    g_push
    $global:_scope = $global:_scope_user
    $a_ = $args -join " "
    if ($global:prolix) { Write-Host "g_set_scope_user => args: $a_" -ForegroundColor Green }
    if (g_nullemptystr $a_) { return }
    return Invoke-Expression $a_
}
Set-Alias -Name user -Value g_set_scope_user -Scope Global -Force

function g_set_scope_instance {
    g_push
    $global:_scope = $global:_scope_instance
    $a_ = $args -join " "
    if ($global:prolix) { Write-Host "g_set_scope_instance => args: $a_" -ForegroundColor Green }
    if (g_nullemptystr $a_) { return }
    return Invoke-Expression $a_
}
Set-Alias -Name instance -Value g_set_scope_instance -Scope Global -Force

function g_set_scope_host {
    g_push
    $global:_scope = $global:_scope_host
    $a_ = $args -join " "
    if ($global:prolix) { Write-Host "g_set_scope_host => args: $a_" -ForegroundColor Green }
    if (g_nullemptystr $a_) { return }
    return Invoke-Expression $a_
}
Set-Alias -Name host -Value g_set_scope_host -Scope Global -Force

function g_set_scope_network {
    g_push
    if ($global:_scope -ne $global:_scope_network) {
        g
        $global:_network_scope_parent = $global:_scope
    }
    $global:_scope = $global:_scope_network
    $a_ = $args -join " "
    if ($global:prolix) { Write-Host "g_set_scope_network => args: $a_" -ForegroundColor Green }
    if (g_nullemptystr $a_) { return }
    return Invoke-Expression $a_
}
Set-Alias -Name network -Value g_set_scope_network -Scope Global -Force

function g_foo_remove ($parameters) {
    if ($parameters -match "~") { $parameters = $parameters -split "~" }
    if ($parameters -is [System.Array]) {
        foreach ($p in $parameters) {
            g_foo_remove $p
        }
        return
    }
    $removeReg = "(`n)?(\[[a-z]+])?$parameters=.+"
    $content = g_content
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
                    if ($null -eq $global:_network_global_cfg_user) { Write-Error 'user network location has not been initialized. Call > g_set_scope_user global networkLocation = \\network\share to initialize' } else {                    
                        $global:_content_user_network = $content -replace $removeReg, ""
                    } 
                }
                $global:_scope_instance {
                    if ($null -eq $global:_network_global_cfg_instance) { Write-Error 'instance network location has not been initialized. Call > g_set_scope_instance global networkLocation = \\network\share to initialize' } else {                    
                        $global:_content_instance_network = $content -replace $removeReg, ""
                    } 
                }
                $global:_scope_host {
                    if (g_elevated) {
                        if ($null -eq $global:_network_global_cfg_host) { Write-Error 'host network location has not been initialized. Call > g_set_scope_host global networkLocation = \\network\share to initialize' } else {                    
                            $global:_content_host_network = $content -replace $removeReg, ""
                        }  
                    }
                    else { g_ehe } 
                }
                Default {}
            } 
        }
        Default {}
    }
}

function g_foo_search ($parameters) {
    $content = (g_content) -split "`n"
    return $($content | Where-Object { $_ -match $parameters })
}

function g_foo ($function, $parameters) {
    if ($global:prolix) { Write-Host "g_foo : $function :: $parameters" -ForegroundColor DarkRed -BackgroundColor Black }
    switch ($function) {
        "remove" { g_foo_remove $parameters }
        "search" { return g_foo_search $parameters }
    }
}

function g_item {
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
        $global:_scope_user { return get-Item $global:_user_global_cfg -Force }
        $global:_scope_instance { return get-Item $global:_instance_global_cfg -Force }
        $global:_scope_host { if (g_elevated) { return get-Item $global:_host_global_cfg -Force } else {  } }
        $global:_scope_network {
            switch ($networkScopeParent) {
                $global:_scope_user { if ($null -eq $global:_network_global_cfg_user) { Write-Error 'user network location has not been initialized. Call > g_set_scope_user global networkLocation = \\network\share to initialize' } else { return get-Item $global:_network_global_cfg_user -Force } }
                $global:_scope_instance { if ($null -eq $global:_network_global_cfg_instance) { Write-Error 'instance network location has not been initialized. Call > g_set_scope_instance global networkLocation = \\network\share to initialize' } else { return get-Item $global:_network_global_cfg_instance -Force } }
                $global:_scope_host { if (g_elevated) { if ($null -eq $global:_network_global_cfg_host) { Write-Error 'host network location has not been initialized. Call > g_set_scope_host global networkLocation = \\network\share to initialize' } else { return get-Item $global:_network_global_cfg_host -Force } } else { g_ehe } }
                Default {}
            } 
        }
    }
}

function g_content {
    [CmdletBinding()]
    param (
        [Parameter()]
        $scope,
        [Parameter()]
        $networkScopeParent
    )
    if ($null -eq $scope) { $scope = $global:_scope }
    if ($null -eq $networkScopeParent) { $networkScopeParent = $global:_network_scope_parent }
    if ($global:prolix) { Write-Host "g_content:" -ForegroundColor DarkCyan }
    switch ($scope) {
        $global:_scope_user { 
            if ($global:prolix) { Write-Host "    \ user:$global:_content_user" -ForegroundColor DarkCyan }; return $global:_content_user 
        }
        $global:_scope_instance {
            if ($global:prolix) { Write-Host "    \ instance:$global:_content_instance" -ForegroundColor DarkCyan }; return $global:_content_instance 
        }
        $global:_scope_host { 
            if (g_elevated) { if ($global:prolix) { Write-Host "    \ host:$global:_content_host" -ForegroundColor DarkCyan }; return $global:_content_host } else { g_ehe } 
        }
        $global:_scope_network {
            switch ($networkScopeParent) {
                $global:_scope_user { if ($null -eq $global:_network_global_cfg_user) { Write-Error 'user network location has not been initialized. Call > g_set_scope_user global networkLocation = \\network\share to initialize' } else { return $global:_content_user_network } }
                $global:_scope_instance { if ($null -eq $global:_network_global_cfg_instance) { Write-Error 'instance network location has not been initialized. Call > g_set_scope_instance global networkLocation = \\network\share to initialize' } else { return $global:_content_instance_network } }
                $global:_scope_host { if (g_elevated) { if ($null -eq $global:_network_global_cfg_host) { Write-Error 'host network location has not been initialized. Call > g_set_scope_host global networkLocation = \\network\share to initialize' } else { return $global:_content_host_network } } else { g_ehe } }
                Default {}
            } 
        }
    }
}

function g_push {
    [CmdletBinding()]
    param (
        [Parameter()]
        $scope,
        [Parameter()]
        $networkScopeParent
    )
    if ($null -eq $scope) { $scope = $global:_scope }
    if ($null -eq $networkScopeParent) { $networkScopeParent = $global:_network_scope_parent }
    if ($global:prolix) { Write-Host "g_push `n  \ scope: $scope ~ netScopeParent: $networkScopeParent" -ForegroundColor Yellow }
    $c_ = g_content $scope $networkScopeParent
    $i_ = g_item $scope $networkScopeParent
    if ($global:prolix) { Write-Host "     \ item: $i_" -ForegroundColor Yellow }
    try {
        Set-Content $i_.fullname $c_ -ErrorAction Stop
    }
    catch {
        Write-Host " << Failed to write to cfg file" -ForegroundColor Red
        if ($global:prolix) { Write-Host "    $_" -ForegroundColor Red }
    }
}

function g_get {
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
    $content = if ($null -eq $content) { g_content } else { $content }
    $match = g_getLine $content $var
    if ($null -ne $match) {

        if (g_match $flags "_SEARCH_") {
            $c_ = $content -split "`n"
            $g_ = @()
            foreach ($c in $c_) {
                $m = g_getLine $c $var
                if ($null -ne $m) { $g_ += $m }
            }
            if ($global:prolix) { Write-Host "g_get : _SEARCH_ : $cast `n$($g_)" -ForegroundColor DarkYellow }
            if (g_match $flags "_NOT_") { return $g_.length -eq 0 }
            if (g_match $flags "_BOOL_") { return $g_.length -gt 0 }
            if ($null -ne $cast) { $g_ = g_cast $cast $g_ }
            return $g_
        }
        else {
            $get = g_getVal $match
            $cast = if ($null -eq $cast) { g_getCast $match } else { $cast }
            if ($global:prolix) { Write-Host "g_get : $cast $get" -ForegroundColor DarkYellow }
            if (g_match $flags "_NOT_") { if ($null -eq $get) { $get = $true } else { $get = !(g_parseBool $get) } }
            if (g_match $flags "_BOOL_") { if ($null -eq $get) { $get = $false } else { $get = g_parseBool $get } }
            if ($null -ne $cast) { $get = g_cast $cast $get }
            return $get
        }
    }
    else {
        
    }
}

function g_assign {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $cast,
        [Parameter(Mandatory = $false, Position = 0)]
        [string]
        $var,
        [Parameter(Mandatory = $false, Position = 1)]
        [string]
        $val
    )
    if (($global:_scope -eq $global:_scope_host) -and !(g_elevated)) {
        g_ehe
        return
    }
    if ($global:prolix) { Write-Host "g_assign: $val => $var" -ForegroundColor Magenta }
    $content = g_content
    $line = g_getLine $content $var
    $replace = "$cast$var=$val"
    if ($global:prolix) { Write-Host "  \ $line => $replace" -ForegroundColor Magenta }
    if ($null -ne $line) {
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
                        if ($null -eq $global:_network_global_cfg_user) { Write-Error 'user network location has not been initialized. Call > g_set_scope_user global networkLocation = \\network\share to initialize' } else {                    
                            $global:_content_user_network = $content -replace "$line", $replace 
                        } 
                    }
                    $global:_scope_instance {
                        if ($null -eq $global:_network_global_cfg_instance) { Write-Error 'instance network location has not been initialized. Call > g_set_scope_instance global networkLocation = \\network\share to initialize' } else {                    
                            $global:_content_instance_network = $content -replace "$line", $replace 
                        } 
                    }
                    $global:_scope_host {
                        if (g_elevated) {
                            if ($null -eq $global:_network_global_cfg_host) { Write-Error 'host network location has not been initialized. Call > g_set_scope_host global networkLocation = \\network\share to initialize' } else {                    
                                $global:_content_host_network = $content -replace "$line", $replace 
                            }  
                        }
                        else { g_ehe } 
                    }
                    Default {}
                } 
            }
            Default {}
        }
    }
    else {
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
                        if ($null -eq $global:_network_global_cfg_user) { Write-Error 'user network location has not been initialized. Call > g_set_scope_user global networkLocation = \\network\share to initialize' } else {    
                            if ($global:_content_user_network[$global:_content_user_network.length - 1] -ne "`n") { $global:_content_user_network += "`n" }                
                            $global:_content_user_network += "$replace" 
                        } 
                    }
                    $global:_scope_instance {
                        if ($null -eq $global:_network_global_cfg_instance) { Write-Error 'instance network location has not been initialized. Call > g_set_scope_instance global networkLocation = \\network\share to initialize' } else {                    
                            if ($global:_content_instance_network[$global:_content_instance_network.length - 1] -ne "`n") { $global:_content_instance_network += "`n" }
                            $global:_content_instance_network += "$replace" 
                        } 
                    }
                    $global:_scope_host {
                        if (g_elevated) {
                            if ($null -eq $global:_network_global_cfg_host) { Write-Error 'host network location has not been initialized. Call > g_set_scope_host global networkLocation = \\network\share to initialize' } else {  
                                if ($global:_content_host_network[$global:_content_host_network.length - 1] -ne "`n") { $global:_content_host_network += "`n" }                  
                                $global:_content_host_network += "$replace" 
                            }  
                        }
                        else { g_ehe } 
                    }
                    Default {}
                } 
            }
            Default {}
        }
    }
    if ($var -eq "networkLocation") {
        switch ($global:_scope) {
            $global:_scope_user {
                init_user_network
            }
            $global:_scope_instance {
                init_instance_network
            }
            $global:_scope_host {
                init_host_network
            }
        }
    }
}

function global {
    
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
            "user" { g_set_scope_user }
            "instance" { g_set_scope_instance }
            "host" { g_set_scope_host }
            "network" { g_set_scope_network }
            "" { g_push }
            Default { Write-Error "Invalid Scope [ $scope ]" }
        }
        return
    }
    # Regex for functions
    if ($a_ -match "[a-z]+::.+") {
        $m_ = $matches
        $f_ = g_match $m_[0] "[a-z]+(?<!:)" -getMatch
        $p_ = g_match $m_[0] "(?<=::).+(?=)" -getMatch
        return g_foo $f_ $p_
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
        $prop = (g_match $prop "\.\w+" -getMatch) -replace "\.", ""
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
            { g_match $_ "\[([0-9]+)?]" } {
                $script:i = g_match $act "[0-9]+" -getMatch
                $act = "ARRAY" 
            }
            Default { Write-Error "Invalid operator [ $act ]"; $null = Read-Host 'Press enter to continue'; return }
        }
    }

    if ($global:prolix) { Write-Host "cast:$cast`nvar:$var`nproperty:$prop`naction:$act`nvalue:$val`nflags:$flags`nscope:$global:_scope" -ForegroundColor Cyan }

    if (g_null @($var, $cast, $act)) {
        if ($global:prolix) { Write-Host "retrieving global content ~`n  network_scope_parent:$global:_network_scope_parent" -ForegroundColor Cyan }
        return g_content
    }
    if (g_nonnull @($var, $act, $val)) {
        $g = g_get $var $cast $flags 
        if ($act -eq "ASSIGN") { g_assign $var $val -cast $cast; return }
        if (g_eq $act @("PLUS_PLUS", "MINUS_MINUS")) {
            Write-Error "increment operators cannot be applied with values [ $val ]"; $null = Read-Host 'Press enter to continue'
            return
        }
        if ($null -eq $g) {
            Write-Error "$var has not been initiated"; $null = Read-Host 'Press enter to continue'
            return
        }
        switch ($act) {
            "PLUS" {
                if (g_is $g @([byte], [int], [long], [float], [double], [string], [boolean])) {
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
                if (g_is $g @([byte], [int], [long], [float], [double], [string], [boolean])) {
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
                g_assign $var $g -cast $cast
            }
            "MINUS" {
                if (g_is $g @([byte], [int], [long], [float], [double], [boolean])) {
                    try {
                        $g -= $val
                    }
                    catch [System.Management.Automation.RuntimeException] {
                        Write-Error $_
                        return
                    }
                }
                elseif ($g -is [string]) {
                    if (g_is $val  @([byte], [int], [long], [float], [double], [string], [boolean])) {
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
                if (g_is $g @([byte], [int], [long], [float], [double], [boolean])) {
                    try {
                        $g -= $val
                    }
                    catch [System.Management.Automation.RuntimeException] {
                        Write-Error $_
                        return
                    }
                }
                elseif ($g -is [string]) {
                    if (g_is $val  @([byte], [int], [long], [float], [double], [string], [boolean])) {
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
                g_assign $var $g -cast $cast
            }
            "TIMES" {
                if (g_is $g @([byte], [int], [long], [float], [double], [boolean])) {
                    try {
                        $g *= $val
                    }
                    catch [System.Management.Automation.RuntimeException] {
                        Write-Error $_
                        return
                    }
                }
                elseif ($g -is [string]) {
                    if (g_is $val  @([byte], [int], [long], [float], [double], [string], [boolean])) {
                        try {
                            $v_ = [Math]::Round($val) - 1
                            $g = g_for $v_ 1 1 '$a_ = @($g)' '$a_ += $g' 'return $a_ -join ""'
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
                if (g_is $g @([byte], [int], [long], [float], [double], [boolean])) {
                    try {
                        $g *= $val
                    }
                    catch [System.Management.Automation.RuntimeException] {
                        Write-Error $_
                        return
                    }
                }
                elseif ($g -is [string]) {
                    if (g_is $val  @([byte], [int], [long], [float], [double], [string], [boolean])) {
                        try {
                            $v_ = [Math]::Round($val) - 1
                            $g = g_for $v_ 1 1 '$a_ = @($g)' '$a_ += $g' 'return $a_ -join ""'
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
                g_assign $var $g -cast $cast
            }
            "DIV" {
                if (g_is $g @([byte], [int], [long], [float], [double], [boolean])) {
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
                if (g_is $g @([byte], [int], [long], [float], [double], [boolean])) {
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
                g_assign $var $g -cast $cast
            }
            "EQUALS" {
                return $g -eq $val
            }
            "MATCH" {
                return g_match $val $g
            }
            "POW" { g_pow $var $val -cast $cast }
            "TERTIARY" { g_plus_eq $var $val -cast $cast }
            "SPECIAL" { g_plus_eq $var $val -cast $cast }
            Default {}
        }
        return
    }
    if (g_nonnull @($var, $act)) {
        switch ($act) {
            "ASSIGN" { Write-Error "Assignment operator without any assignment value"; $null = Read-Host 'Press enter to continue' }
            "PLUS_PLUS" {
                $g = g_get $var $cast $flags 
                if (g_is $g @([byte], [int], [long], [float], [double])) {
                    $g++
                }
                else {
                    Write-Error "Cannot increment type $($g.GetType().Name) for variable $var"
                }
                g_assign $var $g -cast $cast
            }
            "MINUS_MINUS" {
                $g = g_get $var $cast $flags 
                if (g_is $g @([byte], [int], [long], [float], [double])) {
                    $g--
                }
                else {
                    Write-Error "Cannot increment type $($g.GetType().Name) for variable $var"
                }
                g_assign $var $g -cast $cast
            }
            "ARRAY" {
                $val = g_get $var "[string]"
                $arr = $val -split ","
                if ($null -ne $script:i) { return $arr[$script:i] } 
                return $arr
            }
            "TERTIARY" {
                if ($flags -match "_BOOL_") {
                    return g_get $var $cast -flags $flags
                }
            }
            Default {}
        }
        return
    }
    if (g_nonnull @($var, $prop)) {
        if ($global:prolix) { Write-Host "Executioning property: $prop on $v_" -ForegroundColor Cyan }
        $g = g_get $var
        if (($flags -match "_PSVAR_") -and ($g -is [string])) {
            $g = g_for $g.length 1 1 '$g = $g -replace "\$","#$"; $g = $g -split "#"' 'if($g[$i] -match "\$"){$g[$i] = $g[$i] -replace "\$",""; $g[$i] = (get-variable "$($g[$i])").value }' 'return $($g) -join ""'
        }
        $p = Invoke-Expression "$('(' + $g + ').' + $prop)"
        if ($null -ne $cast) { return g_cast $cast $p }
        return $p
    }
    if ($null -ne $var) {
        $g = g_get $var $cast -flags $flags
        if (($flags -match "_PSVARS_") -and ($g -is [string])) {
            $g = g_for $g.length 1 1 '$g = $g -replace "\$","#$"; $g = $g -split "#"' 'if($g[$i] -match "\$"){$g[$i] = $g[$i] -replace "\$",""; $g[$i] = (get-variable "$($g[$i])").value }' 'return $($g) -join ""'
        }
        return $g
    }
    
    Write-Error "Invalid format: $args"

}