
function Invoke-CastString ($stringable) {
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

function Invoke-CastBool ($boolable) {
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

function Invoke-CastInt ($intable) {
    if ($intable -is [int]) { return $intable }
    if ($null -eq $intable) { return 0 }
    if (__is $intable @([long], [float], [double], [string])) { return [int]$intable }
    if ($intable -is [boolean]) { if ($intable) { return 1 } else { return 0 } }
    if ($intable -is [System.Array]) { return $intable.length }
    return [int] $intable
}
function Invoke-CastFloat ($floatable) {
    if ($floatable -is [float]) { return $floatable }
    if ($null -eq $floatable) { return 0 }
    if (__is $floatable @([long], [int], [double], [string])) { return [float]$floatable }
    if ($floatable -is [boolean]) { if ($floatable) { return 1 } else { return 0 } }
    if ($floatable -is [System.Array]) { return $intable.length }
    return [float] $floatable
}
function Invoke-CastLong ($longable) {
    if ($longable -is [long]) { return $longable }
    if ($null -eq $longable) { return 0 }
    if (__is $longable @([int], [float], [double], [string])) { return [long]$longable }
    if ($longable -is [boolean]) { if ($longable) { return 1 } else { return 0 } }
    if ($longable -is [System.Array]) { return $intable.length }
    return [long] $longable
}
function Invoke-CastDouble ($doubleable) {
    if ($doubleable -is [double]) { return $doubleable }
    if ($null -eq $doubleable) { return 0 }
    if (__is $doubleable @([long], [float], [int], [string])) { return [double]$doubleable }
    if ($doubleable -is [boolean]) { if ($doubleable) { return 1 } else { return 0 } }
    if ($doubleable -is [System.Array]) { return $intable.length }
    return [double] $doubleable
}
function Invoke-CastArray ($arrayAble) {
    if ($arrayAble -is [System.Array]) { return $arrayAble }
    if ($null -eq $arrayAble) { return $null }
    if ($arrayAble -is [string]) { 
        if ($arrayAble -match ":") {
            return $arrayAble -split ":"
        }
    }
    return @($arrayAble)
}

function Invoke-CastDateTime($datetimeable) {
    ___start Invoke-CastDateTime
    ___debug "datetimeable:$datetimeable"
    if ($datetimeable -is [datetime]) { return ___return $datetimeable }
    if ($null -eq $datetimeable) { return ___return $null }
    if ($datetimeable -isnot [string]) { 
        return ___return $([datetime] $datetimeable)
    }
    $null = Import-HKShell conf
    $formats = Get-ConfigurationItem datetime_formats.conf | Get-Content
    ___debug "formats`n$formats`n"
    $ErrorActionPreference = 'STOP'
    foreach ($f in $formats) {
        try { $datetime = [datetime]::ParseExact($datetimeable, $f, $null) }
        catch { continue }
    }
    $ErrorActionPreference = 'CONTINUE'
    if ($null -eq $datetime) { $datetime = [datetime] $datetimeable }
    return ___return $datetime
}

function Invoke-Cast ($cast, $var) {
    switch (__replace $Cast @("\[", "]")) {
        { __match $_ @("i1", "bool", "boolean") }{ 
            return Invoke-CastBool $var
        }
        { __match $_ @("int", "integer", "i32") } { 
            return Invoke-CastInt $var
        }
        { __match $_ @("long", "i64") } { 
            return Invoke-CastLong $var
        }
        "float" { 
            return Invoke-CastFloat $var
        }
        "double" { 
            return Invoke-CastDouble $var
        }
        { __match $_ @("u8[]", "str", "string") }{ 
            return Invoke-CastString $var
        }
        "datetime" { 
            return Invoke-CastDateTime $var
        }
        "array" { 
            return Invoke-CastArray $var
        }
        Default { return Invoke-Expression "$($Cast + '"' + $var + '"')" }
    }
}
New-Alias -Name cast -Value Invoke-Cast -Scope Global -Force -ErrorAction SilentlyContinue
