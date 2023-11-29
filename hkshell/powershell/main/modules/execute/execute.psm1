function e_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "DarkYellow" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function e_debug_function ($function, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Yellow" }
    Write-Host ">_ $function" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function e_debug_return {
    if (!$global:_debug_) { return }
    Write-Host "#return# $($args -join " ")" -ForegroundColor Black -BackgroundColor DarkGray
    return
}
function e_prolix ($message, $messageColor) {
    if (!$global:prolix) { return }
    if ($null -eq $messageColor) { $messageColor = "Cyan" }
    Write-Host $message -ForegroundColor $messageColor
}

function e_eq ($a_, $b_) {
    e_debug_function "e_eq"
    if ($b_ -is [System.Array]) {
        foreach ($b in $b_) {
            if ($a_ -eq $b) { 
            e_debug_return
            return $true 
            }
        }
        e_debug_return
        return $false
    }
    else {
        e_debug_return
        return $a_ -eq $b_ 
    }
}
function e_match {
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
    e_debug_function "e_match"
    if ($null -eq $string) {
        e_debug_return string is null
        if ($getMatch) { return $null }
        return $false
    }
    if ($null -eq $regex) {
        e_debug_return regex is null
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
        e_debug_return
        return ($logic -eq "AND") -or ($logic -eq "NOT")
    }
    $found = $string -match $regex
    if ($found) {
        if ($getMatch) {
            e_debug_return
            return $Matches[0]
        }
        e_debug_return
        return $logic -ne "NOT"
    }
    e_debug_return
    if ($logic -eq "NOT") { return $true }
    if ($getMatch) { return $null }
    return $false
}
function e_int_equal {
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
function e_truncate {
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
    e_debug_function "e_truncate"
    e_debug "array:
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
        e_debug_return empty array
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
        if (($i -gt $fromStart) -and !(e_int_equal $i $middle ) -and ($i -lt $fromEnd)) {
            $res += $array[$i]
        }
    }
    e_debug_return $(Out-String -inputObject $res)
    return $res
}
function e_default ($variable, $value) {
    e_debug_function "e_default"
    if ($null -eq $variable) { 
        e_debug_return variable is null
        return $value 
    }
    switch ($variable.GetType().name) {
        String { 
            if($variable -eq "") {
                e_debug_return
                return $value
            } else {
                e_debug_return
                return $variable
            }
        }
    }
}
function e_array_tostring ($a_) {
    if (!$global:_debug_) { return }
    e_debug_function "e_array_tostring"
    $i = 0
    foreach ($a in $a_) {
        Write-Host -NoNewline " [$i]$a" -ForegroundColor DarkYellow
        $i++
    }
    write-host ""
}
function e_search_args ($a_, $param, [switch]$switch) {
    e_debug_function "e_search_args"    
    $c_ = $a_.Count
    e_debug "args:$a_ | len:$c_"
    e_debug "param:$param"
    e_debug "switch:$switch"
    if($switch) { 
        for ($i = 0; $i -lt $c_; $i++) {
            $a = $a_[$i]
            e_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if($null -eq $res) { 
                $res = $true 
                $a_ = e_truncate $a_ -indexAndDepth @($i,1)
            }
            else {
                throw [System.ArgumentException] "Duplicate argument passed: $param"
            }
        }
        $res = $res -and $true
        e_debug_return
        return @{
            RES = $res
            ARGS = $a_
        }
    } else {
        for ($i = 0; $i -lt $a_.length; $i++) {
            $a = $a_[$i]
            e_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if(($null -eq $res) -and ($i -lt ($c_ - 1))) { 
                $res = $a_[$i + 1]
                $a_ = e_truncate $a_ -indexAndDepth @($i,2)
            }
            elseif ($i -ge ($c_ - 1)) {
                 throw [System.ArgumentOutOfRangeException] "Argument value at position $($i + 1) out of $c_ does not exist for param $param"
            }
            elseif ($null -ne $res) {
                throw [System.ArgumentException] "Duplicate argument passed: $param"
            }
        }
        e_debug_return
        return @{
            RES = $res
            ARGS = $a_
        }
    }
}

function e_get_ext ([string]$name="") {
    e_debug_function "e_get_ext"
    $l_ = $name.length
    $dir = -1
    for($i = $l_ - 1; $i -lt $l_; $i += $dir) {
        if($name[$i] -eq ".") { $dir = 0; $i++; continue }
        if($dir -lt 0) { continue }
        if($dir -eq 0) { $res = $name[$i]; $dir = 1; continue }
        if($dir -eq 1) { $res += $name[$i] }
    }
    e_debug_return
    return $res
}

$methods = @{
    RUN = "RUN"
}

function execute ()
{
    e_debug_function "execute"
    $hash = e_search_args $args "-method"
    $method = $hash.RES
    $method = e_default $method $methods.RUN
    e_debug "args:$(e_array_tostring $hash.ARGS)"
    e_debug "method:$method"
    

    switch ($method) {
        $methods.RUN { 
            run $hash.ARGS
        }
        Default {}
    }
}
New-Alias -name ex -value execute -scope Global -Force

function run ($params) {
    e_debug_function "run"
    $c_ = $params.Count
    e_debug "args:$params | count:$c_"
    if(($null -eq $params) -or ($c_ -eq 0) -or (($c_ -eq 1)-and($null -eq $params[0]))){
        throw [System.ArgumentNullException] "No arguments passed to execute.run"
    } 
    $target = $params[0]
    if ($target -is [string]) { 
        if($target -match "^[0-9]+$"){
            $target = (Get-ChildItem $(Get-Location))[$target]
        } else {
            $target = Get-Item $target -Force -ErrorAction Stop
        }
    } elseif ($target -is [int]) {
         $target = (Get-ChildItem $(Get-Location))[$target]       
    }
    if ($target -isnot [System.IO.FileInfo]) {
        throw [System.ArgumentException] "Invalid target type $($target.GetType()), expected [string] (as path) or [System.IO.FileInfo]"
    }
    $ext = e_get_ext $target.name
    $hash = e_search_args $params "-runas" -switch
    $verb = if($hash.RES) { "RunAs" } else { "Open" }
    $hash = e_search_args $hash.ARGS "-wait" -switch
    $wait = $hash.RES
    $hash = e_search_args $hash.ARGS "-passthru" -switch
    $passthru = $hash.RES
    $hash = e_search_args $hash.ARGS "-style" 
    $style = e_default $hash.RES "Normal"
    $hash = e_search_args $hash.ARGS "-argumentList"
    $arguments = $hash.RES

    e_debug "target:$($target.fullname)"
    e_debug "ext:$ext"
    e_debug "verb:$verb"
    e_debug "style:$style"
    e_debug "wait:$wait"
    e_debug "passthru:$passthru"

    switch($ext) {
        ps1 {
            $noExit = if($style -ne "hidden") { "-noexit" } else { "" }
            return Start-Process powershell -Verb $verb -WindowStyle $style -ArgumentList " -executionPolicy Bypass $noexit -file $($target.fullname) $arguments" -Wait:$wait -PassThru:$passthru
        }
        bat {
            if($null -eq $arguments) {
                return Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru
            }
            return Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru -ArgumentList $arguments
        }
    }
}
