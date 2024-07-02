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

function Get-Devices ($apiKey) {
    if($null -eq $apiKey) { $apiKey = persist pushBulletAPIKey }
    if($null -eq $apiKey) { Write-Host "No API Key" -ForegroundColor Red; return }
    $res = https "GET /v2/devices" "api.pushbullet.com" "Access-Token: $apiKey"
    $jsonString = __match $res "{.+}" -g
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
            __replace $contact @("\(", "\)", "\-")
            $contactNumber = $contact
        }
        Default {
            $contactNumber = persist $contact
            __replace $contactNumber @("\(", "\)", "\-")
            persist _>_ $contact = $contactNumber
        }
    }
    if (($null -ne $contactNumber) -and ($contactNumber -match "(\+)?(\()?[0-9]{3}(\)|\-)?[0-9]{3}(\-)?[0-9]{4}")) {
        pb_debug "Sending message to contact: $contact" Blue 
        pb_debug "    \ Message contents: $message" 
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
    pb_debug "Currently this function only supports returning the last text of the thread. Trying to resolve this issue."
    persist -> contacts
    $apiKey = persist pushBulletApiKey
    
    while($null -eq $apiKey) {
        $push = $true
        if (__choice "You don't appear to have setup an api key. Input one now? ") {
               $apiKey = Read-Host "Input Pushbullet API key"
               if($null -ne $apiKey) { persist pushBulletApiKey=.$apiKey }
        } else {
            return
        }
    }
    if($push) { pushw; $push = $false }
    $deviceID = persist MyPhone
    while($null -eq $deviceID -or $deviceID -eq "") {
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
    if($push) { pushw; $push = $false }
    $res = https "GET /v2/permanents/$($deviceID)_threads" "api.pushbullet.com" "Access-Token: $apiKey"
    $jsonString = __match $res "{.+}" -g
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
function Watch-Thread ($who,[switch]$skipSent,[int]$frequency = 750,[switch]$clear) {
    if( $clear ){ Clear-Host }
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

function ConvertTo-PushBulletDecryption ($encryptedData, $key) {

}













