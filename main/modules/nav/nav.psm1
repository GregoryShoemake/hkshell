$global:shortcuts = @(
    "C:\HKS"
    "P:\My files\Proton"
    "F:\Google\Gregory"
    "F:\Google\Gregory\.Coding"
    "F:\Google\Gregory\.Documents"
)

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

function .. {
    [CmdletBinding()]
    param (
        [Parameter()]
        $path
    )
    if (n_nullemptystr $path) {
        $path = Get-Location
    }
    if (n_is $path  @([System.IO.FileInfo], [System.IO.DirectoryInfo])) {
        $path = $path.fullname
    }
    return split-path $path
}

function DisplayDirectory {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $path,
        [Parameter()]
        [switch]
        $D
    )
    if (n_nullemptystr $path) {
        $path = "$(Get-Location)"
    }
    $depth = Get-PathDepth $path
    if ($depth -eq 1) {
        <#
        
        
        #>
        $curPrompt = "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
ChildItems of $path
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        Write-Host $curPrompt -ForegroundColor Blue
        return Get-ChildItem $path | Where-Object { ($_.psiscontainer -and $D) -or !$D }
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
        return Get-ChildItem $path | Where-Object { ($_.psiscontainer -and $D) -or !$D }
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
        return Get-ChildItem $path | Where-Object { ($_.psiscontainer -and $D) -or !$D }
        <#
        
        
        #>
    }
}
New-Alias -Name 'D' -Value 'DisplayDirectory' -Scope Global -Force

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

function Go {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $path,
        [Parameter()]
        [switch]
        $C,
        [Parameter()]
        [switch]
        $A
    )
    $D = !$A
    if ($path -eq "..") {
        $path = ..
    }
    else {
        foreach ($s in $global:shortcuts) {
            if ($s -match $path) {
                if ($null -eq $arr) { $arr = @($s) }
                else { $arr += $s }
            }
        }
        if (($null -ne $arr) -and ($arr.length -gt 1)) {
            Write-Host `nMultiple matches found:
            $i = 0
            foreach ($p in $arr) {
                Write-Host "'[$i] $p"
                $i++
            }
            $i = [int](Read-Host "Pick index of desired path")
            $path = $arr[$i]
        }
    }
    if (n_nullemptystr $path) {
        $path = "$(Get-Location)"
    }
    if (Test-Path $path) {
        Set-Location $path
        D -D:$D
    }
    elseif ($C) {
        New-Item $path -ItemType Directory -force
    }
    else {
        Write-Host Path: $path :does not exist -ForegroundColor Red
    }
}
New-Alias -Name 'G' -Value 'Go' -Scope Global -Force