if ($null -eq $global:_MODNAME_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_MODNAME_module_location = $PSScriptRoot
    }
    else {
        $global:_MODNAME_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}

<#
.GLOBAL VARIABLES
#>

$global:PATH_DELIMITER = if ($IsWindows) { "\" } elseif ($IsLinux) { "/" }
$global:PATH_DELIMITER_REGEX = if ($IsWindows) { "\\" } elseif ($IsLinux) { "/" }
<#
.GLOBAL VARIABLES
#>


<#
.GLOBAL FUNCTIONS
#>

function ___reset {
    $global:_fns_ = $null
}

function ___start {
	if($null -eq $global:_fns_) { $global:_fns_ = @() } 
	$global:_fns_ += "$args"
	if($global:_debug_) {
	    Write-Host ""
	    Write-Host -NoNewLine "START >_ $args  |  nested functions - " -ForegroundColor Green -BackgroundColor Black
	    Write-Host -NoNewLine "$($global:_fns_ -join " { ")" -ForegroundColor White -BackgroundColor Black
	    Write-Host " |  depth[$($global:_fns_.Count)]" -ForegroundColor Green -BackgroundColor Black

	}
}

function ___pop ($array) {
    $array_LENGTH = $array.Count
    $array_NEW = @()
    for ($i = 0; $i -lt $array_LENGTH - 1; $i++) {
	$array_NEW += $array[$i]
    }
    return $array_NEW
}

function ___end {
	if($global:_debug_) {
	    Write-Host ""
	    Write-Host "END >_ $($global:_fns_[($global:_fns_.Count - 1)])  |  depth[$($global:_fns_.Count - 1)]" -ForegroundColor Magenta -BackgroundColor Black
	}
	$global:_fns_ = ___pop $global:_fns_
	if($global:_fns_ -isnot [System.Array]) { 
	    if($null -ne $global:_fns_) {
		$global:_fns_ = @($global:_fns_) 
	    }
	}
}

function ___return  {
    if($global:_debug_) {
	Write-Host ""
	Write-Host "return ___return >_ $($global:_fns_[($global:_fns_.Count - 1)]) -> $(Out-String -InputObject $args)" -ForegroundColor Yellow -BackgroundColor Black
    }
    ___end
    return $args
} 
 
function ___debug ([string]$message, [string]$color = "Cyan") {
    if($global:_debug_) { 
	$fn = if($null -eq $global:_fns_) { "___" } else { $($global:_fns_[($global:_fns_.Count - 1)]) }
	Write-Host "" 
	Write-Host "DEBUG >_ $fn \\ $message" -ForegroundColor $color
    }
}



<#
.GLOBAL FUNCTIONS
#>

function __pad ([string]$string, $length, $padChar = " " ,[switch]$left, [switch]$substringLeft) {
    ___start __pad
    ___debug "string:[$string]"
    $tmp___pad = $global:_debug_
    $global:_debug_ = $false
    ___debug "length:$length"
    ___debug "left:$left"
    if($string.Trim() -eq "") {
        $global:_debug_ = $tmp___pad
        ___debug "return: [$(" "*$length)]"
        ___end
        return " "*$length
    }
    if($null -eq $length) { $length = $string.length }
    $diff = $length - $string.length
    ___debug "difference:$diff"
    $pad = ""
    foreach ($i in $(1..$diff)) { $pad += $padChar }
    ___debug "pad:$pad | pad length: $($pad.length)"
    if($left) { $string = $pad + $string } else { $string = $string + $pad }
    if($substringLeft) {
        if($string.Length -gt $length) {
            $res = $string.substring($($string.Length - $length), $length)
        }
    } else {
        $res = $string.substring(0,$length)
    }
    $global:_debug_ = $tmp___pad
    ___debug "return: $res"
    ___end
    return $res
}

function __choose_item ($items, $property = "name", [switch]$substringLeft) {
    ___start __choise_item
    ___debug "items:$items"
    ___debug "property:$property"
    Write-Host "│  INDEX  │ ITEM" -ForegroundColor DarkGray
    Write-Host "├─────────┼───────────────────────────────────────────────────" -ForegroundColor DarkGray
    for ($i = 0; $i -lt $items.Count; $i++) {
        $item = $items[$i]
        ___debug "item:$item"
        $item = if($property) { (Select-Object -InputObject $item -Property $property).$property } else { $item }
        ___debug "item.$($property):$item"
        if($i -eq 0) {
            $index = "0 or 'f'"
        } else {
            $index = "$i"
        }
        Write-Host "│" -NoNewline -ForegroundColor DarkGray
        Write-Host "$(__pad "$index" 9)" -NoNewline
        Write-Host "│" -NoNewline -ForegroundColor DarkGray
        Write-Host "$(__pad "$item" 50 -substringLeft:$substringLeft)"
    }
    $return = Read-Host "`n`n    Enter index of desired item"
    while($return -notmatch "(f|[0-9]+)") {
        Write-Host "Please input a valid answer ('f' or [0-9]+)" -ForegroundColor yellow
        $return = Read-Host "?"
    }
    if($return -eq "f") {
        $return = 0
    }
    ___end
    return $return
}

function __stringify_regex ($regex) {
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

function __prolix ($message, $messageColor) {
    if (!$global:prolix) { return ___return }
    if ($null -eq $messageColor) { $messageColor = "Cyan" }
    Write-Host $message -ForegroundColor $messageColor
}

function __choice ([string]$prompt = "yes or no?") {
    ___start __choice
    ___debug "prompt:$prompt"
    while((Read-Host $prompt) -notmatch "^(y|Y|yes|Yes|YES|n|N|no|No|NO)$") {
            $prompt = "?"
            Write-Host "Please input a [Y]es or [N]o answer" -ForegroundColor yellow
    }
    if($MATCHES[0] -match "[Yy]"){ return ___return $true }
    return ___return $false
}
function __eq ($a_, $b_, $logic = "OR") {
    #___start __eq
    #___debug "a_:$a_"
    #___debug "b_:$b_"
    #___debug "logic:$logic"
    if ($b_ -is [System.Array]) {
        foreach ($b in $b_) {
	    switch ($logic) {
    	    	OR {  if ($a_ -eq $b) { return $true } }
		AND { if ($a_ -ne $b) { return $false } }
	    	Default {}
	    }
        }
        return $($logic -eq "AND")
    }
    else { return $($a_ -eq $b_) }
}
function __nullemptystr ($nullable) {
    ___start __nullemptystr
    ___debug "initial:nullable:$nullable"
    if ($null -eq $nullable) { return ___return $true }
    if ($nullable -isnot [string]) { return ___return $false }
    if ($nullable.length -eq 0) { return ___return $true }

    for ($i = 0; $i -lt $nullable.length; $i++) {
        if (($nullable[$i] -ne " ") -and ($nullable[$i] -ne "`n")) {
            return ___return $false
        }
    }
    return ___return $true
}

function __replace($string, $regex, [string] $replace) {
    ___start __replace
    ___debug "string:$string"
    ___debug "regex:$regex"
    ___debug "replace:$replace"
    if (__eq $null @($string, $regex)) {
        return ___return $string
    }
    foreach ($r in $regex) {
        $string = $string -replace $r, $replace
    }
    return ___return $string
}
function __is ($obj, $class) {
    ___start __is
    ___debug "obj:$obj"
    ___debug "class:$class"
    if ($null -eq $obj) { return ___return $($null -eq $class) }
    if ($null -eq $class) { return ___return $false }
    if ($class -is [System.Array]) {
        foreach ($c in $class) {
            if ($obj -is $c) { return ___return $true }
        }
        return ___return $false
    }
    return ___return $($obj -is [type](__replace $class @("\[", "]") ""))
}
function __between ($val, $min, $max) {
    #___start __between
    #___debug "initial:val:$val"
    #___debug "initial:min:$min"
    #___debug "initial:max:$max"
    if ($val -lt $min) { return $false }
    return $($val -lt $max)
}

function __int_equal {
    [CmdletBinding()]
    param (
        [int]
        $int,
        # single int or array of ints to compare
        $ints
    )
    if(!$SkipDebug) { 
	___start __int_equal 
	___Debug "int:$int"
	___Debug "ints:$ints"
    }

    if ($null -eq $ints) { 
	return ___return $false 
    }
    foreach ($i in $ints) {
        if ($int -eq $i) { 
	    return ___return $true 
	}
    }
    return ___return $false
}
function __truncate {
    [CmdletBinding()]
    param (
        # Array object passed to truncate
        [Parameter(Mandatory = $false, Position = 0)]
        [System.Array]
        $array,
        [int]
        $fromStart = 0,
        [int]
        $fromEnd = 0,
        [int[]]
        $indexAndDepth
    )

    ___start __truncate 
    ___debug "array:$array"
    ___debug "fromStart:$fromStart"
    ___debug "fromEnd:$fromEnd"
    ___debug "indexAndDepth:$indexAndDepth"

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
        return ___return @()
    }
    $res = @()
    $fromStart--
    if ($null -ne $indexAndDepth) {
        $middleStart = $indexAndDepth[0]
        $middleEnd = $indexAndDepth[0] + $indexAndDepth[1] - 1
        $middleVoid = $middleStart..$middleEnd
    }
    for ($i = 0; $i -lt $array.Length; $i ++) {
        if (($i -gt $fromStart) -and ($middleVoid -notcontains $i) -and ($i -lt $fromEnd)) {
            $res += $array[$i]
        }
    }
    return ___return $res
}
function __search_args ($a_, $param, [switch]$switch, [switch]$all, [switch]$untilSwitch) {
    ___start __search_args

    $c_ = $a_.Count
    ___debug "args:$a_ | len:$c_"
    ___debug "param:$param"
    ___debug "switch:$switch"
    if($switch) { 
        for ($i = 0; $i -lt $c_; $i++) {
            $a = $a_[$i]
            ___debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if($null -eq $res) { 
                $res = $true 
                $a_ = __truncate $a_ -indexAndDepth @($i,1)
            }
            else {
                throw [System.ArgumentException] "Duplicate argument passed: $param"
            }
        }
        $res = $res -and $true
        return ___return $(@{
            RES = $res
            ARGS = $a_
        })
    } else {
        for ($i = 0; $i -lt $a_.length; $i++) {
            $a = $a_[$i]
            ___debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if(($null -eq $res) -and ($i -lt ($c_ - 1))) {
                if($all) {
                    $ibak = $i
                    $res = @()
                    $remove = 1
                    for ($i = $i + 1; $i -lt ($c_); $i++) {
                        if($untilSwitch -and ($a_[$i] -match "^-")) {
                            ___debug "[-untilSwitch] next switch found"
                            break
                        }
                        $res += $a_[$i]
                        $remove++
                    }
                    $res = $res -join " "
                    $a_ = __truncate $a_ -indexAndDepth @($ibak, $remove)
                } else {
                    $res = $a_[$i + 1]
                    if($res -match "^-") { 
                        $res = $null 
                        ___debug "switch argument expected, not found" Red
                    } else {
                        $a_ = __truncate $a_ -indexAndDepth @($i,2)
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
        return ___return $(@{
            RES = $res
            ARGS = $a_
        })
    }
}
function __default ($variable, $value) {
    ___start __default
    ___debug "variable:$variable"
    ___debug "value:$value"
    if ($null -eq $variable) { 
        return ___return $value 
    }
    switch ($variable.GetType().name) {
        String { 
            if($variable -eq "") {
                return ___return $value
            } else {
                return ___return $variable
            }
        }
	default {
	    if($null -eq $variable){
		return ___return $value
	    } else {
		return ___return $variable
	    }
	}
    }
}
function __match {
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
        [string]$logic = "OR",
        [Parameter()]
        $index = 0
    )
    <#
    ___start __match
    ___debug "string:$string"
    ___debug "regex:$regex"
    ___debug "getMatch:$getMatch"
    ___debug "logic:$logic"
    ___debug "index:$index"
    #>

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
            $f = __match $string $r
            if (($logic -eq "OR") -and $f) { return $true }
            if (($logic -eq "AND") -and !$f) { return $false }
            if (($logic -eq "NOT") -and $f) { return $false }
        }
        return $(($logic -eq "AND") -or ($logic -eq "NOT"))
    }
    $found = $string -match $regex
    if ($found) {
        if ($getMatch) {
            if($index -eq "all") {
                return $Matches
            }
            return $($Matches[$index])
        }
        return $($logic -ne "NOT")
    }
    if ($logic -eq "NOT") { return $true }
    if ($getMatch) { return $null }
    return $false
}

function __isLinux {
    return Test-Path '/home'
}

function __isWindows {
    return Test-Path 'C:\'
}
