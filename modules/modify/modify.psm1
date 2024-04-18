if ($null -eq $global:_modify_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_modify_module_location = $PSScriptRoot
    }
    else {
        $global:_modify_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}
function mod_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "DarkYellow" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function mod_debug_function ($function, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Yellow" }
    Write-Host ">_ $function" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function mod_debug_return {
    if (!$global:_debug_) { return }
    Write-Host "#return# $($args -join " ")" -ForegroundColor Black -BackgroundColor DarkGray
    return
}

function mod_prolix ($message, $messageColor) {
    if (!$global:prolix) { return }
    if ($null -eq $messageColor) { $messageColor = "Cyan" }
    Write-Host $message -ForegroundColor $messageColor
}
function mod_choice ($prompt) {
    while((Read-Host $prompt) -notmatch "[Yy]([EeSs])?|[Nn]([Oo])?") {
            $prompt = ""
            Write-Host "Please input a [Y]es or [N]o answer" -ForegroundColor yellow
        }
    if($MATCHES[0] -match "[Yy]"){ return $true }
    return $false
}
function mod_int_equal {
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
function mod_truncate {
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
    mod_debug_function "_truncate"
    mod_debug "array:
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
        mod_debug_return empty array
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
        if (($i -gt $fromStart) -and !(mod_int_equal $i $middle ) -and ($i -lt $fromEnd)) {
            $res += $array[$i]
        }
    }
    mod_debug_return $(Out-String -inputObject $res)
    return $res
}
function mod_search_args ($a_, $param, [switch]$switch, [switch]$all, [switch]$untilSwitch) {
    mod_debug_function "mod_search_args"    
    $c_ = $a_.Count
    mod_debug "args:$a_ | len:$c_"
    mod_debug "param:$param"
    mod_debug "switch:$switch"
    if($switch) { 
        for ($i = 0; $i -lt $c_; $i++) {
            $a = $a_[$i]
            mod_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if($null -eq $res) { 
                $res = $true 
                $a_ = mod_truncate $a_ -indexAndDepth @($i,1)
            }
            else {
                throw [System.ArgumentException] "Duplicate argument passed: $param"
            }
        }
        $res = $res -and $true
        mod_debug_return "@{ RES=$res ; ARGS=$a_ }"
        return @{
            RES = $res
            ARGS = $a_
        }
    } else {
        for ($i = 0; $i -lt $a_.length; $i++) {
            $a = $a_[$i]
            mod_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if(($null -eq $res) -and ($i -lt ($c_ - 1))) {
                if($all) {
                    $ibak = $i
                    $res = @()
                    $remove = 1
                    for ($i = $i + 1; $i -lt ($c_); $i++) {
                        if($untilSwitch -and ($a_[$i] -match "^-")) {
                            mod_debug "[-untilSwitch] next switch found"
                            break
                        }
                        $res += $a_[$i]
                        $remove++
                    }
                    $res = $res -join " "
                    $a_ = mod_truncate $a_ -indexAndDepth @($ibak, $remove)
                } else {
                    $res = $a_[$i + 1]
                    if($res -match "^-") { 
                        $res = $null 
                        mod_debug "switch argument expected, not found" Red
                    } else {
                        $a_ = mod_truncate $a_ -indexAndDepth @($i,2)
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
        mod_debug_return "@{ RES=$res ; ARGS=$a_ }"
        return @{
            RES = $res
            ARGS = $a_
        }
    }
}
function mod_default ($variable, $value) {
    mod_debug_function "e_default"
    if ($null -eq $variable) { 
        mod_debug_return variable is null
        return $value 
    }
    switch ($variable.GetType().name) {
        String { 
            if($variable -eq "") {
                mod_debug_return
                return $value
            } else {
                mod_debug_return
                return $variable
            }
        }
    }
}
function mod_match {
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
    mod_debug_function "mod_match"
    if ($null -eq $string) {
        mod_debug_return string is null
        if ($getMatch) { return $null }
        return $false
    }
    if ($null -eq $regex) {
        mod_debug_return regex is null
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
        mod_debug_return
        return ($logic -eq "AND") -or ($logic -eq "NOT")
    }
    $found = $string -match $regex
    if ($found) {
        if ($getMatch) {
            mod_debug_return
            return $Matches[0]
        }
        mod_debug_return
        return $logic -ne "NOT"
    }
    mod_debug_return
    if ($logic -eq "NOT") { return $true }
    if ($getMatch) { return $null }
    return $false
}

$null = importhks nav

function New-Symlink ($RealTarget, [string]$NewSymPath){
    mod_debug_function "New-Symlink"
    mod_debug "realTarget:$RealTarget"
    mod_debug "newSymPath:$NewSymPath"
    $RealTarget = Get-Path $RealTarget
    if($NewSymPath -eq "") {
        $name = Get-Item $RealTarget | Select-Object -ExpandProperty Name
        $NewSymPath = "$pwd\$name"
    }
    if($RealTarget -eq $NewSymPath) {
        Write-Host "The real target:$RealTarget `nexists at the path provided:$NewSymPath" -ForegroundColor Yellow
        mod_debug_return
        return
    }
    New-Item -ItemType SymbolicLink -Path $NewSymPath -Value $RealTarget -Force
}

function New-Tunnel ($targetDirectory){
    if($targetDirectory -is [System.IO.DirectoryInfo]){
        $targetDirectory = $targetDirectory.FullName
    }
    if($targetDirectory -is [String]) {
        try {
            $current = Get-Item "$pwd" -ErrorAction Stop
            $target = Get-Item $targetDirectory -ErrorAction Stop
            $a = "$($current.FullName)\$($target.Name)"
            $b = "$($target.FullName)\$($current.Name)"
            New-Item -ItemType SymbolicLink -Path $a -Value $target.Fullname -Force -ErrorAction Stop
            New-Item -ItemType SymbolicLink -Path $b -Value $current.FullName -Force -ErrorAction Stop
        }
        catch {
            Write-Host "!_Failed to create tunnel_____!`n`n$_`n" -ForegroundColor Red
            return
        }
    } else {
        Write-Host "!_target_directory_type_: $($targetDirectory.GetType) :_is_invalid_____!`n`n$_`n" -ForegroundColor Red
        return
    }
}

function m_copy ($path, $destination, [switch] $mirror, [switch] $passthru) {
    try {
	$i = Get-Item $path -Force -ErrorAction Stop
	if($i.psIsContainer) {
	    if($mirror) {
		Robocopy $i.FullName $destination /MT /MIR /NFL /NDL /NJH /NJS /NC /NS > NUL 
	    } else {
		Robocopy $i.FullName $destination /MT /E /NFL /NDL /NJH /NJS /NC /NS > NUL 
	    }
	    if($passthru) { return $(Get-Item $destination -Force) }
	} else {
	    Robocopy $(Split-Path $i.FullName) $destination $i.name /MT /E /NFL /NDL /NJH /NJS /NC /NS > NUL 
	    if($passthru) { return $(Get-Item "$destination\$($i.name)" -Force) }
	}
    } catch {
	Write-Error $_
    }
}

function Invoke-GetItem ($item, [switch]$all) {
    if($null -eq $global:clip) { $global:clip = @() }
    if($all){
        return Get-ChildItem "$PWD" | ForEach-Object {
            Invoke-GetItem $_.FullName
        }
    }
    if($item -is [System.Array]) {
        return $item | ForEach-Object {
            Invoke-GetItem $_
        }
    }
    $global:clip += Get-Path $item
    $null = $global:clip ## To remove debug message
}

function Invoke-MoveItem ([string]$path, [int]$index = -1, [switch]$force, [switch] $all,[switch] $removeItemFromClip) {
    if ($all) {
        $n = $clip.count
        for ($i = $n - 1; $i -ge 1; $i--) {
            Invoke-MoveItem -index $i -force:$force -removeItemFromClip:$removeItemFromClip -path $path
        }
        Invoke-MoveItem -index 0 -force:$force -removeItemFromClip:$removeItemFromClip -path $path
        return
    }
    if($index -eq -1) { $index = $global:clip.Count - 1 }
    if($path -eq "") {
        $path = "$pwd"
    }
    $path = Get-Path $path
    m_copy $global:clip[$index] $path
    Remove-Item $global:clip[$index] -Force
    if($removeItemFromClip){
        if($global:clip.count -eq 1) {
            $global:clip = $null
            return
        }
        if($global:clip.count -eq 2) {
            $global:clip = @($global:clip[1-$index])
            return
        }
        $global:clip = mod_truncate -array $global:clip -indexAndDepth @($index, 1)
    } else {
	$global:clip[$index] = $path
    }
}

function Invoke-CopyItem ([string]$path, [int]$index = -1, [switch]$force, [switch]$all, [switch] $removeItemFromClip) {
    if ($all) {
        $n = $clip.count
        for ($i = $n - 1; $i -ge 1; $i--) {
            Invoke-CopyItem -index $i -force:$force -removeItemFromClip:$removeItemFromClip -path $path
        }
        Invoke-CopyItem -index 0 -force:$force -removeItemFromClip:$removeItemFromClip -path $path
        return
    }
    if($index -eq -1) { $index = $global:clip.Count - 1 }
    if($path -eq "") {
        $path = "$pwd"
    }
    $path = Get-Path $path
    m_copy $global:clip[$index] $path
    if($removeItemFromClip){
        if($global:clip.count -eq 1) {
            $global:clip = $null
            return
        }
        if($global:clip.count -eq 2) {
            $global:clip = @($global:clip[1-$index])
            return
        }
        $global:clip = mod_truncate -array $global:clip -indexAndDepth @($index, 1)
    }
}

function Invoke-Extract([string]$archive,[string]$destination,[string]$extractor){
    if($extractor -eq ""){
        $7z = "D:\Program Files\7-Zip\7z.exe"
        $7za = "D:\Program Files\7-Zip\7za.exe"
        if(Test-Path $7z){
            $extractor = $7z
        } elseif (Test-Path $7za) {
            $extractor = $7za
        } else {
            Write-Host "failed - could not find valid executable 7z or 7za: $extractor" -ForegroundColor Red
            return 1
        }
    }
    while(!( Test-Path $archive )){
        $archive = Read-Host "Input full or relative path to a valid target archive file, or press <Ctrl-c> to cancel"
    }
    if($extractor -match "7za") {
        $argument = "e"
    } elseif ($extractor -match "7z") {
        $argument = "x"
    } else {
        Write-Host "failed - invalid extraction executable: $extractor" -ForegroundColor Red
        return 2
    }
     
    $destination = if($destination -ne "") { " -o'$destination'" } else { "" }
    Start-Process -NoNewWindow -Wait -FilePath $extractor -ArgumentList "$argument $('"')$archive$('"')$destination"
}
