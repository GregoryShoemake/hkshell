if ($null -eq $global:_backup_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_backup_module_location = $PSScriptRoot
    }
    else {
        $global:_backup_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}
function bk_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "DarkYellow" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function bk_debug_function ($function, $messageColor, $meta) {
    if (!$global:bk_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Yellow" }
    Write-Host ">_ $function" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function bk_debug_return {
    if (!$global:_debug_) { return }
    Write-Host "#return# $($args -join " ")" -ForegroundColor Black -BackgroundColor DarkGray
    return
}

function bk_prolix ($message, $messageColor) {
    if (!$global:prolix) { return }
    if ($null -eq $messageColor) { $messageColor = "Cyan" }
    Write-Host $message -ForegroundColor $messageColor
}
function bk_choice ($prompt) {
    while((Read-Host $prompt) -notmatch "[Yy]([EeSs])?|[Nn]([Oo])?") {
            $prompt = ""
            Write-Host "Please input a [Y]es or [N]o answer" -ForegroundColor yellow
        }
    if($MATCHES[0] -match "[Yy]"){ return $true }
    return $false
}
function bk_int_equal {
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
function bk_truncate {
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
    bk_debug_function "_truncate"
    bk_debug "array:
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
        bk_debug_return empty array
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
        if (($i -gt $fromStart) -and !(bk_int_equal $i $middle ) -and ($i -lt $fromEnd)) {
            $res += $array[$i]
        }
    }
    bk_debug_return $(Out-String -inputObject $res)
    return $res
}
function bk_search_args
{
    bk_debug_function "_search_args"    
    $c_ = $a_.Count
    bk_debug "args:$a_ | len:$c_"
    bk_debug "param:$param"
    bk_debug "switch:$switch"
    if($switch) { 
        for ($i = 0; $i -lt $c_; $i++) {
            $a = $a_[$i]
            bk_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if($null -eq $res) { 
                $res = $true 
                $a_ = _truncate $a_ -indexAndDepth @($i,1)
            }
            else {
                throw [System.ArgumentException] "Duplicate argument passed: $param"
            }
        }
        $res = $res -and $true
        bk_debug_return
        return @{
            RES = $res
            ARGS = $a_
        }
    } else {
        for ($i = 0; $i -lt $abk_.length; $i++) {
            $a = $a_[$i]
            bk_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if(($null -eq $res) -and ($i -lt ($c_ - 1))) { 
                $res = $a_[$i + 1]
                $a_ = _truncate $a_ -indexAndDepth @($i,2)
            }
            elseif ($i -ge ($c_ - 1)) {
                 throw [System.ArgumentOutOfRangeException] "Argument value at position $($i + 1) out of $c_ does not exist for param $param"
            }
            elseif ($null -ne $res) {
                throw [System.ArgumentException] "Duplicate argument passed: $param"
            }
        }
        bk_debug_return
        return @{
            RES = $res
            ARGS = $a_
        }
    }
}
function bk_default ($variable, $value) {
    bk_debug_function "e_default"
    if ($null -eq $variable) { 
        bk_debug_return variable is null
        return $value 
    }
    switch ($variable.GetType().name) {
        String { 
            if($variable -eq "") {
                bk_debug_return
                return $value
            } else {
                bk_debug_return
                return $variable
            }
        }
    }
}
function bk_match {
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
    bk_debug_function "__match"
    if ($null -eq $string) {
        bk_debug_return string is null
        if ($getMatch) { return $null }
        return $false
    }
    if ($null -eq $regex) {
        bk_debug_return regex is null
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
        bk_debug_return
        return ($logic -eq "AND") -or ($logic -eq "NOT")
    }
    $found = $string -match $regex
    if ($found) {
        if ($getMatch) {
            bk_debug_return
            return $Matches[0]
        }
        bk_debug_return
        return $logic -ne "NOT"
    }
    bk_debug_return
    if ($logic -eq "NOT") { return $true }
    if ($getMatch) { return $null }
    return $false
}
$null = importhks Invoke-Persist
function Format-BackupConfiguration {
    if($global:scopes.ToLower() -notmatch "^backup") {
        $backupPath = "C:\users\$ENV:USERNAME\.powershell\scopes\backup"
        if(!(Test-Path $backupPath)) { mkdir $backupPath } 
        Invoke-Persist addScope>_backup::$backupPath\persist.cfg::yes
    }
    Invoke-Persist -> backup
    
    if(Invoke-Persist backupDirectory!?) {
        $location = Read-Host "Input the desired directory to direct your backup targets to"
        while(!(Test-Path $location)) {
            if($location -notmatch "^(\\\\.+?\|[a-zA-Z]:\\).+$") {
                $location = Read-Host "Input a valid directory syntax"
            }
            elseif(bk_choice "$location does not exist, attempt to create?"){
                mkdir $location
            }
            else {
                $location = Read-Host "$location does not exist, input an existing directory"
            }
        }
        Invoke-Persist backupDirectory=.$location
    } elseif (bk_choice "Modify backup directory: $(Invoke-Persist backupDirectory)?") {
        $location = Read-Host "Input the desired directory to direct your backup targets to"
        while(!(Test-Path $location)) {
            if($location -notmatch "^(\\\\.+?\|[a-zA-Z]:\\).+$") {
                $location = Read-Host "Input a valid directory syntax"
            }
            elseif(bk_choice "$location does not exist, attempt to create?"){
                mkdir $location
            }
            else {
                $location = Read-Host "$location does not exist, input an existing directory"
            }
        }
        Invoke-Persist backupDirectory=.$location
    }


    if(persist nullOrEmpty>_bareMetalBackup) {  
        if(bk_choice "Authorize full image recoveries?") {
            Invoke-Persist _>_[boolean]bareMetalBackup=true
            bk_prolix "Input the drive letter or volume name of the desired backup volume. NOTE: Do not make this on the same DISK that contains the C: drive" Cyan
            Write-Host "$(Get-AllVolumes -Expand Volumes | Out-String -width 100)"
            $volLet = Read-Host " "
            while(($volLet -notmatch "^([a-zA-Z]:\\)$") -or !(Test-Path $volLet)) {
                $volLet = Read-Host "Drive letter must match the format [A-Z]:\ and be accessible"
            }
            Invoke-Persist bareMetalBackupVolume=.$volLet
        } else {
            Invoke-Persist _>_[boolean]bareMetalBackup=false
            Invoke-Persist remove>_bareMetalBackupVolume
        }
    } else { 
        if(bk_choice "Modify full image backup settings?") {
            push Invoke-Persist remove>_bareMetalBackup
            return Format-BackupConfiguration
        }
    }
}


