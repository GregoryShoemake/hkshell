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

$global:userRoot = if($IsWindows) {
    "C:/Users/$ENV:USERNAME"
} elseif($IsLinux) {
    "/home/$(whoami)"
}

___debug "$userRoot"

$userDir = "$userRoot/.hkshell/persist"

___debug "$userDir"

if(!(Test-Path $userDir)) { mkdir $userDir }

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

function p_elevated { 
    if($IsLinux) {
	return "$(whoami)" -eq "root"
    } elseif ($IsWindows) {
	return (new-object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) 
    }
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
        return __match $boolable  @("true", "yes", "y", "1")
    }
    if (__is $boolable @([int], [long], [float], [double])) {
        return $boolable -gt 0
    }
    return $true
}

function p_castInt ($intable) {
    if ($intable -is [int]) { return $intable }
    if ($null -eq $intable) { return 0 }
    if (__is $intable @([long], [float], [double], [string])) { return [int]$intable }
    if ($intable -is [boolean]) { if ($intable) { return 1 } else { return 0 } }
    if ($intable -is [System.Array]) { return $intable.length }
    return [int] $intable
}
function p_castFloat ($floatable) {
    if ($floatable -is [float]) { return $floatable }
    if ($null -eq $floatable) { return 0 }
    if (__is $floatable @([long], [int], [double], [string])) { return [float]$floatable }
    if ($floatable -is [boolean]) { if ($floatable) { return 1 } else { return 0 } }
    if ($floatable -is [System.Array]) { return $intable.length }
    return [float] $floatable
}
function p_castLong ($longable) {
    if ($longable -is [long]) { return $longable }
    if ($null -eq $longable) { return 0 }
    if (__is $longable @([int], [float], [double], [string])) { return [long]$longable }
    if ($longable -is [boolean]) { if ($longable) { return 1 } else { return 0 } }
    if ($longable -is [System.Array]) { return $intable.length }
    return [long] $longable
}
function p_castDouble ($doubleable) {
    if ($doubleable -is [double]) { return $doubleable }
    if ($null -eq $doubleable) { return 0 }
    if (__is $doubleable @([long], [float], [int], [string])) { return [double]$doubleable }
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
    switch (__replace $cast @("\[", "]")) {
        "boolean" { 
            return p_castBool $var
        }
        { __match $_ @("int", "integer") } { 
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
    ___start p_getVal
    ___debug "initial:line:$line"
    ___debug "switch:array:$array"
    $d = -1
    ___debug "walking back from end of line"
    $l = $line.length
    $val = ""
    if ($Null -eq $line) { return ___return $null }
    for ($i = $l - 1; __between $i -1 $l; $i += $d) {
        if ($d -eq 1) {
            $val += $line[$i]
        }
        elseif ($line[$i] -eq "=") { $d = 1; ___debug "start of value reached, recording forward" }
    }
    if($array){
        return ___return $($val -split ":")
    }
    return ___return $val
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

$global:SCOPES_PATH = "$userDir/persist.scopes.conf"
$global:INSTANCE_PATH = "$global:_persist_module_location/persist.cfg"
$global:INSTANCE_SCOPE = "INSTANCE::$global:INSTANCE_PATH"
$global:HOST_PERSIST_PATH = if($IsWindows) {
    "C:/Windows/System32/WindowsPowerShell/v1.0"
} elseif($IsLinux) {
    "/root/powershell/hkshell"
}

function Invoke-Scopes ([switch]$rebuild){
    if(!(Test-Path $global:SCOPES_PATH) -or $rebuild) {
        p_debug "creating persist scopes file at $global:SCOPES_PATH"
        New-Item $global:SCOPES_PATH -ItemType File -Force
        p_debug "populating persist scopes file with default scopes"
        if(!(test-path "$userRoot/contacts" )) { mkdir "$userRoot/contacts" }
        if(!(test-path "$userRoot/.ssh"  )) { mkdir "$userRoot/.ssh" }
        Set-Content -Path $global:SCOPES_PATH -Value "USER::$userRoot/.powershell/persist.cfg
HOST::$global:HOST_PERSIST_PATH/persist.cfg
CONTACTS::$userRoot/contacts/persist.cfg
SSH::$userRoot/.ssh/persist.cfg"
    }
    p_debug 'pushing content to memory in variable $global:SCOPES'
    $global:SCOPES = Get-Content -Path $global:SCOPES_PATH
    $global:SCOPES += $global:INSTANCE_SCOPE
}
Invoke-Scopes

<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>
#           Initializer Functions                 #
<#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~#>

function Set-Scope ([string]$scope="USER", [boolean]$save) {
    p_debug_function "Set-Scope"
    p_debug "scope:$scope"  

    if($save) {
	Invoke-Push
    }

    if($scope -eq "NETWORK"){
        $netScope = Invoke-Persist networkLocation
        if($null -eq $netScope) {
            Write-Host "A network location has not been set for $Global:SCOPE. Use the Invoke-Persist setNetworkDir>_ command to set a network location." -ForegroundColor Yellow
            return
        }
        if($netScope -notmatch "persist\.cfg$") {
            if($netScope -notmatch "/$") { $netScope += "/" }
            $netScope += "persist.cfg"
        }
        $global:SCOPE = "NETWORK::$(persist networkLocation)"
    } else {
        $global:SCOPE = __match $global:SCOPES "$scope.+" -getMatch
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
            $removeReg = "(^|`n)(\[[a-z]+])?$parameters=.+"
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
    $line = __stringify_regex $line
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
    ___start Get-Scope
    ___debug "initial:scope:$scope"
    ___debug "switch:exists:$exists"
    $s_ = $global:scopes
    if($s_ -isnot [System.Array]) { $s_ = $s_ -split "`n" }
    ___debug "scopes:$s_"
    if($scope -eq "") {
        return ___return $global:scopes
    }
    foreach ($s in $global:scopes) {
        if($s -match "^$scope") {
            if($exists) {
                return ___return $true       
            } else {
                return ___return $s
            }
        }
    }
    if($exists) {
        return ___return $false
    }
    else {
        return ___return $null
    }
}

function Get-PersistItem ($inputScope){
    if ($null -eq $inputScope) { $inputScope = $global:SCOPE }
    $name = ($inputScope -split "::")[0] 
    $freshScope = __match $global:SCOPES "$name.+" -getMatch
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
    if (__nullemptystr $a_) { return }
    return Invoke-Expression $a_
}

function Invoke-PushWrapper {
    $a_ = $args -join " "
    if ($global:_debug_) { Write-Host "push => args: $a_" -ForegroundColor Green }
    if (__nullemptystr $a_) {
        Invoke-Push
        return 
    }
    $res = Invoke-Expression $a_
    Invoke-Push
    return $res
}

function Invoke-PopScope {
	Invoke-Persist -> $Script:S_BK
}

function Invoke-PushScope ([string]$TemporaryScope) {
	if($scope -eq "") {
		Write-Host "Invalid scope: $TemporaryScope" -ForegroundColor Red
		return
	}
	$Script:S_BK = __match $Scope "(.+?)::" -GetMatch -Index 1
	Invoke-Persist -> $TemporaryScope
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
    ___start p_scope_wrapper
    ___debug "args:$args"
    $wrapper = $args[0]
    ___debug "scope:$wrapper"
    $argz = __truncate $args -FromStart 1
    if(Get-Scope $wrapper -Exists) {
        $scope_bak = ("$SCOPE" -split "::")[0]
        Invoke-Persist -> $wrapper
        $res = Invoke-Expression "$argz"
        Invoke-Persist -> $scope_bak
        return ___return $res
    }
    ___end
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
                $line = __stringify_regex $line
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
	commands {
	    Write-Host "$(@("assign","add","add_assign","minus","minus_assign","multiply","multiply_assign","divide","divide_assign","exponentiate","exponentiate_assign","void","insert","pushinsert","nullOrEmpty","nonnull","remove","search","setNetworkDir","clearNetworkDir","outOfDate","upToDate","writeToday","writeDate","parse","equal","match","clip","setall","length","default","split","addScope","get-content","add-content","pop","push","pushadd","pushsub","pushcompare"))"
	}
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
        { __eq $_ @("void", "_") } {
            $null = Invoke-Expression "persist $params"
        }
        insert {
            $split = $params -split ":"
            $l_ = p_getLine $global:c_ $split[0]
            $v_a = p_getVal $l_ -Array
            $v_a[$split[1]] = $split[2]
            $v_a = $v_a -join ":"
            if(__nullemptystr $v_a){
                Write-Host "!_Value cannot be null_____!`n`n$_`n" -ForegroundColor Red
                return
            }
            return Set-PersistContent @{Cast = "[array]"; Name = $split[0]; Value = $v_a }

        }
        { __match $_ @("pushinsert","pin") } {
            $split = $params -split "="
            $i_a = __match $split[0] "\[([0-9]+)" -index 1 -get
            p_debug "i_a:$i_a"
            $a = $split[0] -replace "\[[0-9]+]",""
            p_debug "a:$a"
            $i_b = __match $split[1] "\[([0-9]+)" -index 1 -get
            p_debug "i_b:$i_b"
            $b = $split[1] -replace "\[[0-9]+]",""
            p_debug "b:$b"
            if(__nullemptystr @($a,$i_a,$b,$i_b)){
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
        { __eq $_ @("nonnull", "nn") } { 
            $l_ = p_getLine $global:c_ $params
            $v_ = p_getVal $l_
            return $null -ne $v_ 
        }
        { __eq $_ @("remove", "rm") } {
            return p_foo_remove $params 
        }
        { __eq $_ @("search", "find") } { 
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
        { __eq $_ @("sz", "len", "length", "size") } { 
            $l_ = p_getLine $global:c_ $params
            $v_ = p_getVal $l_
            $c_ = p_getCast $l_
            $p_ = p_cast $c_ $v_
            return $p_.length
        }
        { __eq $_ @("def", "default") } {
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
                $volSyn = __match $params "(vol::.+?::/.+?)(::|$)" -getmatch -index 1
                $volPath = Get-Path $volSyn
                $params = $params -replace (__stringify_regex $volSyn),"vol"
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
                if($path -notmatch "/$") { $path += "/" }
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
            $v_ = (p_getVal $l_) -replace "(?!^)//","/" -replace "/$",""
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
	{ $_ -match "^(append|add-content)$" } {
	    $split = $params -split ":"
	    $path = $split[0]
            $l_ = p_getLine $global:c_ $path
            $v_ = (p_getVal $l_) -replace "(?!^)//","/" -replace "/$",""
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
		for ($i = 1; $i -lt $split.Count; $i++) {
		    Add-Content -Path $v_ -Value $split[$i] -Force -ErrorAction Stop
		}
            } catch {
                Write-Host "!___Failed to add item {$($split[$i]) @ $i} to $($v_)___!`n`n$_`n" -ForegroundColor Red
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
                    $v_ = __truncate $v_ -indexAndDepth @($index,1)
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
                    $v_ = __truncate $v_ -fromEnd 1
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
                    $v_ = __truncate $v_ -fromEnd 1
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
        scopes {
            return $global:SCOPES
        }
        Default {}
    }
}

function p_throw ($code, $message, $meta ) {
    if ($global:p_error_action -eq "SilentlyContinue") { return 0 }
    write-host "| persist.psm1 |" -ForegroundColor RED
    switch ($code) {
        { ($_ -eq -1) -or ($_ -eq "SyntaxParseFailure") } { $code = -1; write-host "Syntax parse failed with code ($message)" -ForegroundColor Red }
        { ($_ -eq 01) -or ($_ -eq "ElementAlreadyAssigned") } { $code = 1; write-host "[$message] already assigned as '$meta'" -ForegroundColor Red }
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
                    if ($a -notmatch "[0-9a-zA-Z_\-]") {
                        $recording = $null
                        p_debug "recording stopped:$name" DarkRed
                        $i-- 
                    } 
                    else { $name += $a } 
                }
                "OPERATOR" { 
                    if (__match $a $symbols -logic NOT) {
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
                        return p_throw ElementAlreadyAssigned "index" $index
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
                elseif ($($null -ne $operator) -and $($null -ne $index)) {
                    $oR = __stringify_regex $operator
                    $iR = __stringify_regex $index
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
                else { return p_throw 1 "parameters" $parameters }
                
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
                    return p_throw ElementAlreadyAssigned "parameters" $parameters
                } 
            }
            elseif (__match $a $symbols) { 
                #Attempt to record [op] 
                if ($null -ne $operator) { 
                    return p_throw 1 "operator" $operator
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
    $index = __replace $index @("\[", "]")
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

    ___start Invoke-Persist
    ___debug "initial:args:$args"

    if("$args" -eq "help") {
        return ___return '
---

## NAME

**Invoke-Persist** - A function to manage persistent variables across different scopes in PowerShell.

## SYNOPSIS

**Invoke-Persist** [<CAST>] <NAME> [<OPERATOR>] [<PARAMETER>] [<INDEX>]

## DESCRIPTION

The **Invoke-Persist** function in PowerShell is designed to manage persistent variables and their values across different scopes. It allows for setting, retrieving, modifying, and manipulating variables with various operations such as addition, subtraction, multiplication, division, and more.

## SYNTAX

```powershell
Invoke-Persist [<CAST>] <NAME> [<OPERATOR>] [<PARAMETER>] [<INDEX>]
```

## PARAMETERS

- **CAST** : The type to cast the variable to. Examples include `[string]`, `[int]`, `[boolean]`, `[array]`, `[datetime]`, etc.
- **NAME** : The name of the variable to be managed.
- **OPERATOR** : The operation to be performed. Supported operators include:
  - `=` : Assign a value.
  - `+` : Add a value.
  - `-` : Subtract a value.
  - `*` : Multiply by a value.
  - `/` : Divide by a value.
  - `^` : Exponentiate by a value.
  - `>` : Perform a command.
  - `==` : Compare equality.
  - `!=` : Compare inequality.
  - `~=` : Match a pattern.
  - `!~` : Not match a pattern.
  - `~>` : Get matched value.
  - `?` : Check if true.
  - `!?` : Check if false.
- **PARAMETER** : The value or argument for the operation.
- **INDEX** : The index for accessing array elements.

## EXAMPLES

### Retrieving a Variable`s Value

```powershell
Invoke-Persist [string]variableName
```
This retrieves the value of `variableName` cast to a string.

### Assigning a Value

```powershell
Invoke-Persist [int]variableName = 42
```
This assigns the integer value `42` to `variableName`.

### Adding a Value

```powershell
Invoke-Persist [int]variableName + 10
```
This adds `10` to the current value of `variableName`.

### Subtracting a Value

```powershell
Invoke-Persist [int]variableName - 5
```
This subtracts `5` from the current value of `variableName`.

### Multiplying a Value

```powershell
Invoke-Persist [int]variableName * 2
```
This multiplies the current value of `variableName` by `2`.

### Dividing a Value

```powershell
Invoke-Persist [int]variableName / 3
```
This divides the current value of `variableName` by `3`.

### Exponentiating a Value

```powershell
Invoke-Persist [int]variableName ^ 3
```
This raises the current value of `variableName` to the power of `3`.

### Conditional Checks

```powershell
Invoke-Persist variableName == 42
```
This checks if `variableName` is equal to `42`.

### Array Indexing

```powershell
Invoke-Persist [array]variableName[0]
```
This retrieves the first element of the array `variableName`.



The `>_` operator is used to execute specific commands within this context.

### EXAMPLES

#### Example 1: Default Assignment
##### SYNOPSIS
Assign a default value to a possibly unassigned variable.
##### USAGE
```powershell
Invoke-Persist default >_ aPossiblyUnassignedValue:10
```
##### DESCRIPTION
This command checks if the variable `aPossiblyUnassignedValue` is already assigned a value. If it is, the current value is returned. If it is not, the value `10` is assigned to it and returned.

#### Example 2: Set Network Directory
##### SYNOPSIS
Set a network directory for the persistent module.
##### USAGE
```powershell
Invoke-Persist setNetworkDir >_ "\\Network\Config"
```
##### DESCRIPTION
Assigns the path `"\\Network\Config"` as the network directory where persistent configurations will be stored.

#### Example 3: Clear Network Directory
##### SYNOPSIS
Clear the previously set network directory.
##### USAGE
```powershell
Invoke-Persist clearNetworkDir >_
```
##### DESCRIPTION
Removes the network directory configuration, effectively clearing the set path for storing network-based persistent configurations.

#### Example 4: Check if a Variable is Non-null
##### SYNOPSIS
Check if a persistent variable is non-null.
##### USAGE
```powershell
Invoke-Persist nonnull >_ myVariable
```
##### DESCRIPTION
Returns `True` if `myVariable` has been assigned a value, otherwise returns `False`.

#### Example 5: Push and Pop Values
##### SYNOPSIS
Push and pop values to/from a persistent variable stack.
##### USAGE - PUSH
```powershell
Invoke-Persist push >_ myStack:42

Invoke-Persist push >_ myStack:12
```
##### USAGE - POP
```powershell
Invoke-Persist pop >_ myStack

Invoke-Persist pop >_ myStack:Temp
```
##### DESCRIPTION
- **Push**: Adds `42` to the stack `myStack` as an array element.
- **Push**: Adds `12` to the stack `myStack` as an array element.
- **Pop**: Removes the value `12` from `myStack` and returns it.
- **Pop**: Removes the value `42` from `myStack` and pushes it the `Temp` variable as an array element.

#### Example 8: Write Today`s Date
##### SYNOPSIS
Write the current date and time to a persistent variable.
##### USAGE
```powershell
Invoke-Persist writeToday >_ currentDate
```
##### DESCRIPTION
Stores the current date and time in the `currentDate` variable in the format `ddMMMyyyy@HHmm`.


### Comprehensive List of `foo` Commands

1. **assign**
   - **Usage:** `Invoke-Persist assign >_ [CAST]:[NAME]:[VALUE]`
   - **Description:** Assigns a value to a persistent variable.

2. **add**
   - **Usage:** `Invoke-Persist add >_ [CAST]:[NAME]:[VALUE]`
   - **Description:** Adds a specified value to a persistent variable.

3. **add_assign**
   - **Usage:** `Invoke-Persist add_assign >_ [CAST]:[NAME]:[VALUE]`
   - **Description:** Adds a specified value to a persistent variable and assigns the result back to the variable.

4. **minus**
   - **Usage:** `Invoke-Persist minus >_ [CAST]:[NAME]:[VALUE]`
   - **Description:** Subtracts a specified value from a persistent variable.

5. **minus_assign**
   - **Usage:** `Invoke-Persist minus_assign >_ [CAST]:[NAME]:[VALUE]`
   - **Description:** Subtracts a specified value from a persistent variable and assigns the result back to the variable.

6. **multiply**
   - **Usage:** `Invoke-Persist multiply >_ [CAST]:[NAME]:[VALUE]`
   - **Description:** Multiplies a persistent variable by a specified value.

7. **multiply_assign**
   - **Usage:** `Invoke-Persist multiply_assign >_ [CAST]:[NAME]:[VALUE]`
   - **Description:** Multiplies a persistent variable by a specified value and assigns the result back to the variable.

8. **divide**
   - **Usage:** `Invoke-Persist divide >_ [CAST]:[NAME]:[VALUE]`
   - **Description:** Divides a persistent variable by a specified value.

9. **divide_assign**
   - **Usage:** `Invoke-Persist divide_assign >_ [CAST]:[NAME]:[VALUE]`
   - **Description:** Divides a persistent variable by a specified value and assigns the result back to the variable.

10. **exponentiate**
    - **Usage:** `Invoke-Persist exponentiate >_ [CAST]:[NAME]:[VALUE]`
    - **Description:** Raises a persistent variable to the power of a specified value.

11. **exponentiate_assign**
    - **Usage:** `Invoke-Persist exponentiate_assign >_ [CAST]:[NAME]:[VALUE]`
    - **Description:** Raises a persistent variable to the power of a specified value and assigns the result back to the variable.

12. **void**
    - **Usage:** `Invoke-Persist void >_ parameters`
    - **Description:** Executes a command without returning a value.

13. **insert**
    - **Usage:** `Invoke-Persist insert >_ [NAME]:[INDEX]:[VALUE]`
    - **Description:** Inserts a value into an array at the specified index.

14. **pushinsert**
    - **Usage:** `Invoke-Persist pushinsert >_ [ARRAY_NAME][INDEX]=[OTHER_ARRAY_NAME][INDEX]`
    - **Description:** Inserts values from one array into another at specified indices.

15. **nullOrEmpty**
    - **Usage:** `Invoke-Persist nullOrEmpty >_ [NAME]`
    - **Description:** Checks if a persistent variable is null or empty.

16. **nonnull**
    - **Usage:** `Invoke-Persist nonnull >_ [NAME]`
    - **Description:** Checks if a persistent variable is non-null.

17. **remove**
    - **Usage:** `Invoke-Persist remove >_ [NAME]`
    - **Description:** Removes a persistent variable.

18. **search**
    - **Usage:** `Invoke-Persist search >_ [PATTERN]`
    - **Description:** Searches for a pattern in persistent variables.

19. **setNetworkDir**
    - **Usage:** `Invoke-Persist setNetworkDir >_ [PATH]`
    - **Description:** Sets the network directory for persistent storage.

20. **clearNetworkDir**
    - **Usage:** `Invoke-Persist clearNetworkDir >_`
    - **Description:** Clears the network directory configuration.

21. **outOfDate**
    - **Usage:** `Invoke-Persist outOfDate >_ [VARIABLE]:[DAYS]`
    - **Description:** Checks if the date stored in a variable is older than the specified number of days.

22. **upToDate**
    - **Usage:** `Invoke-Persist upToDate >_ [VARIABLE]:[DAYS]`
    - **Description:** Checks if the date stored in a variable is within the specified number of days.

23. **writeToday**
    - **Usage:** `Invoke-Persist writeToday >_ [VARIABLE]`
    - **Description:** Writes the current date and time to a persistent variable.

24. **writeDate**
    - **Usage:** `Invoke-Persist writeDate >_ [VARIABLE]:[DATE]`
    - **Description:** Writes a specified date and time to a persistent variable.

25. **parse**
    - **Usage:** `Invoke-Persist parse >_ [VARIABLE]:[CAST]`
    - **Description:** Parses the value of a persistent variable to the specified type.

26. **equal**
    - **Usage:** `Invoke-Persist equal >_ [VAR1]:[VAR2]`
    - **Description:** Checks if two persistent variables are equal.

27. **match**
    - **Usage:** `Invoke-Persist match >_ [VAR1]:[PATTERN]`
    - **Description:** Checks if the value of a persistent variable matches a specified pattern.

28. **clip**
    - **Usage:** `Invoke-Persist clip >_ [VARIABLE]`
    - **Description:** Copies the value of a persistent variable to the clipboard.

29. **setall**
    - **Usage:** `Invoke-Persist setall >_ [VAR1:VAR2:VAR3]=[VALUE]`
    - **Description:** Sets multiple persistent variables to the same value.

30. **length**
    - **Usage:** `Invoke-Persist length >_ [VARIABLE]`
    - **Description:** Returns the length of the value of a persistent variable.

31. **default**
    - **Usage:** `Invoke-Persist default >_ [NAME]:[DEFAULT_VALUE]`
    - **Description:** Returns the value of a persistent variable or assigns and returns the default value if it is unassigned.

32. **split**
    - **Usage:** `Invoke-Persist split >_ [VARIABLE]=[DELIMITER]`
    - **Description:** Splits the value of a persistent variable by the specified delimiter.

33. **addScope**
    - **Usage:** `Invoke-Persist addScope >_ [SCOPE]::[PATH]`
    - **Description:** Adds a new scope to the persistent configuration.

34. **get-content**
    - **Usage:** `Invoke-Persist get-content >_ [VARIABLE]`
    - **Description:** Retrieves the content at the path assigned to a persistent variable.

35. **add-content**
    - **Usage:** `Invoke-Persist add-content >_ [VARIABLE]:[CONTENT]`
    - **Description:** Appends content at the path assigned to a persistent variable.

36. **pop**
    - **Usage:** `Invoke-Persist pop >_ [SOURCE]:[INDEX]:[DESTINATION]`
    - **Description:** Pops a value from the source array and pushes it, either a return value, or optionally to a destination variable.

37. **push**
    - **Usage:** `Invoke-Persist push >_ [DESTINATION]:[VALUE]`
    - **Description:** Pushes a value to the destination array.

38. **pushadd**
    - **Usage:** `Invoke-Persist pushadd >_ [STACK_NAME]`
    - **Description:** Pops two values from the stack, adds them, and pushes the result back to the stack.

39. **pushsub**
    - **Usage:** `Invoke-Persist pushsub >_ [STACK_NAME]`
    - **Description:** Pops two values from the stack, subtracts the second from the first, and pushes the result back to the stack.

40. **pushcompare**
    - **Usage:** `Invoke-Persist pushcompare >_ [STACK_NAME]:[LOGICAL_OPERATOR]`
    - **Description:** Pops two values from the stack, compares them using the specified logical operator, and pushes the result back to the stack.

41. **scopes**
    - **Usage:** `Invoke-Persist scopes >__
    - **Description** Returns all existing scopes, including default and user added scopes

### Additional Insights
These commands offer a wide range of functionalities to manage persistent variables effectively. From basic assignments and arithmetic operations to more complex stack manipulations and scope management, the `foo` commands provide a robust toolkit for handling persistent data in PowerShell.


### Scopes and Scope Selection Functionalities

#### 1. **Set-Scope**
##### SYNOPSIS
Sets and switches between different scopes.
##### USAGE
```powershell
Set-Scope -scope "USER" -save $true
```
##### DESCRIPTION
This function sets the current scope to the specified scope (e.g., USER, NETWORK, SSH). If the `-save` parameter is provided and set to `$true`, it saves the current persistent variables to the configuration file before switching scopes.

#### 2. **Invoke-Persist -> SCOPE**
##### SYNOPSIS
Changes the current scope and pulls the persistent variables from the scope`s configuration file into memory.
##### USAGE
```powershell
Invoke-Persist -> SSH
```
##### DESCRIPTION
Changes the current scope to the specified scope (e.g., SSH). This operation pulls the persistent variables from the SSH scope`s configuration file into memory, making them available for use.

#### 3. **Invoke-Pull**
##### SYNOPSIS
Pulls the persistent variables from the current scope`s configuration file into memory.
##### USAGE
```powershell
Invoke-Pull
```
##### DESCRIPTION
Synchronizes the in-memory persistent variables with the values from the current scope`s configuration file. This ensures that the latest values from the file are loaded into memory.

#### 4. **Invoke-Push**
##### SYNOPSIS
Pushes all in-memory persistent variables to the current scope`s configuration file.
##### USAGE
```powershell
Invoke-Push
```
##### DESCRIPTION
Writes all the persistent variables that are currently in memory to the configuration file of the current scope. This ensures that any changes made to the variables are saved to the file.

#### 5. **Invoke-Scopes**
##### SYNOPSIS
Initializes and populates the scopes from a configuration file.
##### USAGE
```powershell
Invoke-Scopes -rebuild
```
##### DESCRIPTION
Creates the scopes file if it doesn`t exist and populates it with default scopes. The `-rebuild` switch forces the re-creation of the scopes file.

#### 6. **Get-Scope**
##### SYNOPSIS
Retrieves the path or existence of a specified scope.
##### USAGE
```powershell
Get-Scope -scope "SSH" -exists
```
##### DESCRIPTION
Checks if the specified scope exists in the scopes configuration and returns `true` or `false`. Without the `-exists` switch, it returns the path of the scope.

#### 7. **Use-Scope**
##### SYNOPSIS
Temporarily switches to a specified scope for the duration of a command.
##### USAGE
```powershell
Use-Scope SSH { <command> }
```
##### DESCRIPTION
Executes the specified command within the context of the specified scope without permanently changing the current scope. After executing the command, it switches back to the original scope.

### Example Scenarios

#### Example 1: Switching to SSH Scope
```powershell
Invoke-Persist -> SSH
```
- **Operation:** Changes the current scope to SSH.
- **Result:** Pulls the persistent variables from the SSH configuration file into memory.

#### Example 2: Pulling Variables from the Current Scope
```powershell
Invoke-Pull
```
- **Operation:** Synchronizes in-memory variables with those from the current scope`s configuration file.
- **Result:** Ensures the latest values from the file are loaded into memory.

#### Example 3: Pushing Variables to the Current Scope
```powershell
Invoke-Push
```
- **Operation:** Writes all in-memory persistent variables to the configuration file of the current scope.
- **Result:** Saves any changes made to the variables to the scope`s configuration file.

#### Example 4: Using a Different Scope Temporarily
```powershell
Use-Scope SSH { Invoke-Persist }
```
- **Operation:** Executes the `Invoke-Persist` command within the context of the SSH scope.
- **Result:** Returns all persistent variables assigned to the SSH scope without permanently changing the current scope.

### Insights

- **Scope Management:** The script provides robust functionalities for managing different scopes, allowing you to organize persistent variables by context or use case.
- **Synchronization:** `Invoke-Pull` and `Invoke-Push` ensure that the in-memory state is synchronized with the persistent storage, providing consistency.
- **Flexibility:** Temporary scope changes (`Use-Scope`) allow for context-specific operations without altering the global state.

These functionalities make the `Invoke-Persist` tool quite powerful for managing persistent configurations in a modular and organized manner.


## NOTES

- **Invoke-Persist** works with multiple data types and supports complex operations.
- It is crucial to understand the type casting and array indexing to use this function effectively.
- The function also supports debug messages that can be enabled via the global `_debug_` variable.

For more detailed information and additional command options, refer to the source code and comments within the script.

## AUTHOR

Atypic, your friendly hipster coder master.

---        
'
    }

    
    if ($global:_debug_) {
        for ($i = 0; $i -lt $args.length; $i++) {
            $a = $args[$i]
            ___debug "args[$i] >>> $a"
        }
    }

    $a_ = $args -join " "

    $s_ = p_parse_syntax $a_

    if ($s_ -isnot [System.Array]) { return ___return $( p_throw -1 $s_ "line: ~1580" ) }

    $cast = $s_[0]
    $name = $s_[1]
    $oper = $s_[2]
    $para = $s_[3]
    $inde = $s_[4]


    ___debug "cast:$cast"
    ___debug "name:$name"
    ___debug "operator:$oper"
    ___debug "parameter:$para"
    ___debug "index:$inde"




   $global:c_ = Get-PersistContent

    if ($($null -eq $name) -and $($null -eq $cast)) {
        return ___return $global:c_
    }   

    if ($null -ne $name) {
        ___debug "content | p_getLine $name | p_getVal" 
        $l_ = p_getLine $global:c_ $name
        $v_ = p_getVal $l_
        if ($($null -eq $oper) -and $($null -eq $para) -and $($null -eq $cast) -and $($null -eq $inde)) {
            $cast = p_getCast $l_
            if ($null -eq $cast) {
                return ___return $v_
            }
            else {
                return ___return $(p_cast $cast $v_)
            }
        }
    }

    if ($Null -ne $inde) {
        ___debug "indexing" 
        if ($null -ne $para) {
            if(__match $a_ "$para\[[0-9]+]"){
                ___debug "      % param: $para" 
                $para = p_index $para $inde
                ___debug "      \ param: $para"
            }
        }
        else {
            ___debug "      % val: $val"
            $v_ = p_index $v_ $inde
            ___debug "      \ val: $val"
        }
    }

    if ($null -eq $oper) {
        if ($null -eq $cast) {
            $cast = p_getCast $l_
        }
        if ($null -eq $cast) {
            return ___return $v_
        }
        else {
            return ___return $(p_cast $cast $v_)
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
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator assign [n]") } 
                if ($v_ -eq $para) {
                    $c_ = p_getCast $l_
                    if($cast -eq $c_) {
                        ___debug "    \ var.val is already: $para"
                        $res = $l_
                    } else {
                        $res = p_foo assign $cast':'$name':'$para 
                    }
                }
                else { 
                    if($a_ -match "$name\["){
                        if($null -ne $cast -and $cast.toLower -ne "[array]"){
                            return ___return $(p_throw IllegalArgumentException "Cannot index array and cast to non-array type")
                        }
                        if($null -eq $inde){
                            return ___return $(p_throw IllegalArgumentException "Cannot index cannot be null")
                        }
                        $inde = $inde -replace "\[","" -replace "]",""
                        $res = p_foo insert $name':'$inde':'$para
                    } else {
                        $res = p_foo assign $cast':'$name':'$para 
                    }
                } 
            } # assign
            "+" { 
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator add [n]") } 
                $res = p_foo add $cast':'$name':'$para 
            } # add [n]
            "++" {
                if ($null -ne $para) { return ___return $(p_throw IllegalOperationSyntax "Cannot pass parameters to add~assign [1]") } 
                $n = "1"
                $res = p_foo add_assign $cast':'$name':'$n
            } # add~assign [1]
            "+=" { 
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator add~assign [n]") } 
                $res = p_foo add_assign $cast':'$name':'$para 
            } # add~assign [n] 
            "-" { 
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator minus [n]") } 
                $res = p_foo minus $cast':'$name':'$para 
            } # minus [n]
            "--" {
                if ($null -ne $para) { return ___return $(p_throw IllegalOperationSyntax "Cannot pass parameters to minus~assign [1]") } 
                $n = "1"
                $res = p_foo minus_assign $cast':'$name':'$n 
            } # minus~assign [1]
            "-=" { 
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator minus_assign [n]") } 
                $res = p_foo minus_assign $cast':'$name':'$para 
            } # minus~assign [n]
            "*" {
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator multiply [n]") } 
                $res = p_foo multiply $cast':'$name':'$para 
            } # multiply [n]
            "**" {
                if ($null -ne $para) { return ___return $(p_throw IllegalOperationSyntax "Cannot pass parameters to multiply~assign [x]") }
                $res = p_foo multiply_assign $cast':'$name':'$v_
            } # multiply~assign [x]
            "*=" { 
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator multiply-assign [n]") } 
                $res = p_foo multiply_assign $cast':'$name':'$para 
            } # multiply-assign [n]
            "/" {
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator divide [n]") } 
                $res = p_foo divide $cast':'$name':'$para 
            } # divide [n]
            "/=" { 
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator divide~assign [n]") } 
                $res = p_foo divide_assign $cast':'$name':'$para 
            } # divide~assign [n]
            "//" {
                if ($null -ne $para) { return ___return $(p_throw IllegalOperationSyntax "Cannot pass parameters to divide~assign [x]") } 
                $res = p_foo divide_assign $cast':'$name':'$val
            } # divide~assign [x] (assigns to 1)
            "^" { 
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator exponentiate [n]") } 
                $res = p_foo exponentiate $cast':'$name':'$para 
            } # exponentiate [n]
            "^=" { 
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator exponentiate~assign [n]") } 
                $res = p_foo exponentiate_assign $cast':'$name':'$para 
            } # exponentiate~assign [n]
            "^^" { 
                if ($null -ne $para) { return ___return $(p_throw IllegalOperationSyntax "Cannot pass parameters to exponentiate~assign [x]") }
                $res = p_foo exponentiate_assign $cast':'$name':'$v_ 
            } # exponentiate~assign [x]
            "==" {
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator compare~equal [n]") } 
                $res = $v_ -eq $para
            } # compare~equal [n]
            "!=" { 
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator compare~equal~not [n]") } 
                $res = $v_ -ne $para
            } # compare~equal~not [n]
            "~=" { 
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator compare~match [n]") } 
                $res = $v_ -match $para
            } # compare~match [n]
            "!~" { 
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator compare~match~not [n]") } 
                $res = $v_ -notmatch $para
            } # compare~match~not [n]
            "~>" { 
                if ($null -eq $para) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator compare~match~get [n]") } 
                $res = __match $v_ $para -getMatch
            } # compare~match~get [n]
            "?" { 
                if ($null -ne $para) { return ___return $(p_throw IllegalOperationSyntax "Cannot pass parameters to compare~true [x]") } 
                $res = $v_ -eq "True"
            } # compare~true [x]
            "!?" { 
                if ($null -ne $para) { return ___return $(p_throw IllegalOperationSyntax "Cannot pass parameters to compare~not~true [x]") } 
                $res = ($null -eq $v_) -or ($v_ -eq "False")
            } # compare~not~true [x]
            "->|" { 
                if ($null -eq $name) { return ___return $(p_throw IllegalOperationSyntax "Expected argument for operator push [n]") } 
                $res = Set-Scope $name
            } # push [n]
        }
        return ___return $res
    }
  

}
New-Alias -Name persist -Value Invoke-Persist -Scope Global -Force
New-Alias -Name Get-PersistentVariable -Value Invoke-Persist -Scope Global -Force
