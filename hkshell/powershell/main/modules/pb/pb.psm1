importhks persist
importhks net
if ($null -eq $global:_pb_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_pb_module_location = $PSScriptRoot
    }
    else {
        $global:_pb_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}
function pb_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "DarkYellow" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function pb_debug_function ($function, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Yellow" }
    Write-Host ">_ $function" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function pb_debug_return {
    if (!$global:_debug_) { return }
    Write-Host "#return# $($args -join " ")" -ForegroundColor Black -BackgroundColor DarkGray
    return
}
function pb_prolix ($message, $messageColor) {
    if (!$global:prolix) { return }
    if ($null -eq $messageColor) { $messageColor = "Cyan" }
    Write-Host $message -ForegroundColor $messageColor
}
function pb_choice ($prompt) {
    while((Read-Host $prompt) -notmatch "[Yy]([EeSs])?|[Nn]([Oo])?") {
            $prompt = ""
            Write-Host "Please input a [Y]es or [N]o answer" -ForegroundColor yellow
        }
    if($MATCHES[0] -match "[Yy]"){ return $true }
    return $false
}
function pb_int_equal {
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
function pb_truncate {
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
    pb_debug_function "_truncate"
    pb_debug "array:
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
        pb_debug_return empty array
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
        if (($i -gt $fromStart) -and !(pb_int_equal $i $middle ) -and ($i -lt $fromEnd)) {
            $res += $array[$i]
        }
    }
    pb_debug_return $(Out-String -inputObject $res)
    return $res
}
function pb_search_args
{
    pb_debug_function "_search_args"    
    $c_ = $a_.Count
    pb_debug "args:$a_ | len:$c_"
    pb_debug "param:$param"
    pb_debug "switch:$switch"
    if($switch) { 
        for ($i = 0; $i -lt $c_; $i++) {
            $a = $a_[$i]
            pb_debug "a[$i]:$a"
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
        pb_debug_return
        return @{
            RES = $res
            ARGS = $a_
        }
    } else {
        for ($i = 0; $i -lt $apb_.length; $i++) {
            $a = $a_[$i]
            pb_debug "a[$i]:$a"
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
        pb_debug_return
        return @{
            RES = $res
            ARGS = $a_
        }
    }
}
function pb_default ($variable, $value) {
    pb_debug_function "e_default"
    if ($null -eq $variable) { 
        pb_debug_return variable is null
        return $value 
    }
    switch ($variable.GetType().name) {
        String { 
            if($variable -eq "") {
                pb_debug_return
                return $value
            } else {
                pb_debug_return
                return $variable
            }
        }
    }
}
function pb_match {
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
    pb_debug_function "__match"
    if ($null -eq $string) {
        pb_debug_return string is null
        if ($getMatch) { return $null }
        return $false
    }
    if ($null -eq $regex) {
        pb_debug_return regex is null
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
        pb_debug_return
        return ($logic -eq "AND") -or ($logic -eq "NOT")
    }
    $found = $string -match $regex
    if ($found) {
        if ($getMatch) {
            pb_debug_return
            return $Matches[0]
        }
        pb_debug_return
        return $logic -ne "NOT"
    }
    pb_debug_return
    if ($logic -eq "NOT") { return $true }
    if ($getMatch) { return $null }
    return $false
}
function pb_replace($string, $regex, [string] $replace) {
    if ($null -eq $string) {
        return $string
    }
    if ($null -eq $regex) {
        return $string
    }
    if ($string -is [System.Array]) {
        $string = $string -join "`n"
    }
    if ($regex -is [System.Array]) {
        foreach ($r in $regex) {
            $string = $string -replace $r, $replace
        }
    }
    return $string -replace $regex, $replace
}
function Get-Devices ($apiKey) {
    if($null -eq $apiKey) { $apiKey = persist pushBulletAPIKey }
    if($null -eq $apiKey) { Write-Host "No API Key" -ForegroundColor Red; return }
    $res = https "GET /v2/devices" "api.pushbullet.com" "Access-Token: $apiKey"
    $jsonString = pb_match $res "{.+}" -g
    $json = (ConvertFrom-Json $jsonString)
    return $json.devices
}
function Send-PushbulletSMS ([string]$message = "testing...", $contact) {
    $SCOPEbak = ($global:SCOPE -split "::")[0]
    persist -> contacts
    pb_debug_function Send-PushbulletSMS DarkCyan
    pb_debug "Contact: $contact" DarkGray
    pb_debug "Message: $message" DarkGray
    if($null -eq $contact) {
        $contact = Use-Scope contacts Get-PersistentVariable lastRecipient
    }
    if($null -eq $contact) {
        Write-Host "Contact is null" -ForegroundColor Yellow
        return
    }
    if ($contact -is [System.Array]) {
        foreach ($c in $contact) {
            Send-PushbulletSMS $c $message
        }
        return
    }
    switch ($contact) {
        { $_ -match "(\+)?(\()?[0-9]{3}(\)|\-)?[0-9]{3}(\-)?[0-9]{4}" } { 
            pb_replace $contact @("\(", "\)", "\-")
            $contactNumber = $contact
        }
        Default {
            $contactNumber = persist $contact
            pb_replace $contactNumber @("\(", "\)", "\-")
            persist _>_ $contact = $contactNumber
        }
    }
    if (($null -ne $contactNumber) -and ($contactNumber -match "(\+)?(\()?[0-9]{3}(\)|\-)?[0-9]{3}(\-)?[0-9]{4}")) {
        pb_prolix "Sending message to contact: $contact" Blue 
        pb_prolix "    \ Message contents: $message" 
        pb sms -d 0 -n $contactNumber $message

        Invoke-PushWrapper Invoke-Persist _>_lastRecipient=.$contact
    }
    persist -> $SCOPEbak
} 
New-Alias -Name text -Value Send-PushbulletSMS
function pb_log {
    [CmdletBinding()]
    param (
        [Parameter()]
        $variable,
        [Parameter()]
        [int]
        $columns = 1,
        [Parameter()]
        $ForegroundColor = 1
    )
    if ($variable -is [System.Array]) {
        for ($i = 1; $i -le $variable.length; $i++) {
            [int]$width = 130 / $columns
            $item = "$($variable[$i - 1])"
            while ($item.Length -lt $width) {
                $item += " "
            }
            $item = $item.Substring(0, $width)
            if ($i % $columns -eq 0) {
                Write-Host $item -ForegroundColor $ForegroundColor
            }
            else {
                Write-Host -NoNewline $item -ForegroundColor $ForegroundColor
            }
        }
    }
}

function Get-Text ($who,$expand) {
    pb_prolix "Currently this function only supports returning the last text of the thread. Trying to resolve this issue."
    persist -> contacts
    $apiKey = persist pushBulletApiKey
    
    while($null -eq $apiKey) {
        $push = $true
        if (pb_choice "You don't appear to have setup an api key. Input one now? ") {
               $apiKey = Read-Host "Input Pushbullet API key"
               if($null -ne $apiKey) { persist pushBulletApiKey=.$apiKey }
        } else {
            return
        }
    }
    if($push) { push; $push = $false }
    $deviceID = persist MyPhone
    while($null -eq $deviceID) {
        $push = $true
        Write-Host "You don't appear to have setup a deviceID to request texts from. Pulling device list..."
        $hash = Get-Devices -apiKey $apiKey | Where-Object {"$($_.nickname)" -ne ""} | Select-Object nickname, iden
        $str = @("|__Name_______","|__IDEN_______")
        foreach($h in $hash) {
            $str += $h.nickname
            $str += $h.iden
        }
        pb_log $str -c 2
        $userInput = Read-Host "Input the name or the IDEN of the desired device"
        $device = $hash | Where-Object {($_.nickname -eq $userInput)-or($_.iden -eq $userInput)}
        $deviceID = $device.iden
        persist myPhone=.$deviceID
    }
    if($push) { push; $push = $false }
    $res = https "GET /v2/permanents/$($deviceID)_threads" "api.pushbullet.com" "Access-Token: $apiKey"
    $jsonString = p_match $res "{.+}" -g
    try {
        $json = (ConvertFrom-Json $jsonString -ErrorAction Stop )
    }
    catch {
        return $res
    }
    try {
        $threads = $json.threads 
    }
    catch {
        return $json
    }
    if($null -ne $who){
        $thread = $threads | Foreach-Object {
            if($_.recipients.count -gt 1){return}
            if($_.recipients[0] -match $who){return $_}
        }
        if($null -eq $thread){
            Write-Host "No thread was found for $who. Returning all message threads"
            return $threads
        }
        elseif($thread -is [System.Array]){}
        else {
            switch ($expand) {
                {$_ -match "^b$|^body$"} { return $thread.latest.body }
                Default {return $thread.latest}
            }
        }
    } else {
        return $threads
    }
}
function Watch-Thread ($who,[switch]$skipSent,[int]$frequency = 750) {
    $frequency = [Math]::Max(750,$frequency)
    $new = Get-Text $who
    $direction = if($new.direction -eq "incoming"){"from"}else{"to"}
    $last = $new.body
    Write-Host "Last message $direction $who - $last"
    While($true){
        Start-Sleep -Milliseconds $frequency
        $new = Get-Text $who
        if("$($new.body)" -eq ""){ continue }
        if($new.body -ne $last){
            $last = $new.body
            $direction = if($new.direction -eq "incoming"){"from"}else{"to"}
            if(($direction -eq "to") -and $skipSent){continue} 
            Write-Host "New message $direction $who - $last"
        }
    }
}















