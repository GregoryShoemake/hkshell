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
    if($null -eq $apiKey) { $apiKey = Use-Scope Contacts Get-PersistentVariable pushBulletAPIKey }
    if($null -eq $apiKey) { Write-Host "No API Key" -ForegroundColor Red; return }
    $res = https "GET /v2/devices" "api.pushbullet.com" "Access-Token: $apiKey"
    $jsonString = __match $res "{.+}" -g
    $json = (ConvertFrom-Json $jsonString)
    return $json.devices
}

function New-PushBulletPush ([string]$message = "testing...") {

    ___start New-PushBulletPush 

    ___debug "initial:message:$message"
        
    $headers = @{
        "Access-Token" = "$(Use-Scope Contacts Get-PersistentVariable pushBulletAPIKey)"
        "Content-Type" = "application/json"
    }

    ___debug "headers:$headers"    

    $data = @{
        body = "$message"
        title  = 'Push from Clank'
        type = 'note'
    } | ConvertTo-Json

    ___debug "body:$body"    

    $url = "https://api.pushbullet.com/v2/pushes"

    ___debug "url:$url"    

    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $data

    ___debug "response:$response"
    ___end
} 

New-Alias -Name pbp -Value New-PushBulletPush -Scope Global -Force

function Send-PushbulletSMS ([string]$message = "testing...", $contact) {
    Invoke-PushScope Contacts

    pb_debug_function Send-PushbulletSMS DarkCyan
    pb_debug "Contact: $contact" DarkGray
    pb_debug "Message: $message" DarkGray
    if($null -eq $contact) {
        $contact = Get-PersistentVariable lastRecipient
    }
    if($null -eq $contact) {
        Write-Host "Contact is null" -ForegroundColor Yellow
        return
    }
    $target = Get-PersistentVariable myPhone
    if($null -eq $target) {
        Write-Host "`n$(Get-Devices)`n"
        $target = Get-PersistentVariable Default>_ myPhone:$(Read-Host "`nInput GUID:")
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
        
        $headers = @{
            "Access-Token" = "$(Use-Scope Contacts Get-PersistentVariable pushBulletAPIKey)"
            "Content-Type" = "application/json"
        }

        $body = @{
            data = @{
                addresses = @($contactNumber)
                guid = "$(Get-FileHash -InputStream $([IO.MemoryStream]::new([byte[]][char[]]$message)) -Algorithm SHA256 | Select-Object -ExpandProperty Hash)"
                message = $message
                target_device_iden = $target
            }
        } | ConvertTo-Json

        $url = "https://api.pushbullet.com/v2/texts"

        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body

        ___debug "response:$response"
        
        Invoke-PushWrapper Invoke-Persist _>_lastRecipient=.$contact
    }
    Invoke-PopScope
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
    ___start Get-Text

    ___debug "initial:who:$who"
    ___debug "initial:expand:$expand"

    ___debug "Currently this function only supports returning the last text of the thread. Trying to resolve this issue."
    Invoke-PushScope Contacts
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
    ___debug "res:$res"
    $jsonString = __match $res "{.+}" -g
    ___debug "jsonString:$jsonString"
    try {
        $json = (ConvertFrom-Json $jsonString -ErrorAction Stop )
        ___debug "json:$json"
        if($json.encrypted) {
            return ___return "$(Invoke-Decrypt $json.ciphertext)"
        }
    }
    catch {
        return ___return $res
    }
    try {
        $threads = $json.threads 
        ___debug "threads:$threads"
    }
    catch {
        return ___return $json
    }
    if($null -ne $who){
        $thread = $threads | Foreach-Object {
            if($_.recipients.count -gt 1){ return }
            if($_.recipients[0] -match $who){ return $_ }
        }
        if($null -eq $thread){
            Write-Host "No thread was found for $who. Returning all message threads"
            return ___return $threads
        }
        elseif($thread -is [System.Array]){}
        else {
            switch ($expand) {
                {$_ -match "^b$|^body$"} { return ___return "$($thread.latest.body)" }
                Default {return ___return "$($thread.latest)"}
            }
        }
    } else {
        return ___return $threads
    }
    ___end
}

function Invoke-Decrypt {
    param (
        $message
    )
    Invoke-PushScope Contacts
    $message = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($message))
    $key = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("$(Get-PersistentVariable pushBulletEncryptionKey)"))

    $version = $message.Substring(0,1)
    if($version -ne "1") {
        Write-Host "!_Invalid Version:$($version)____!`n`n$_`n" -ForegroundColor Red
        return
    }
    $iv = $message.Substring(17,12)
    $iv = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($iv))
    $encrypted = $message.Substring(29)
    $encrypted = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($encrypted))

    return Start-DecryptPushbulletMessage $encrypted $key $iv
}

function Start-DecryptPushbulletMessage {
    param (
        [string]$encryptedMessage,
        [string]$aesKey,
        [string]$iv
    )

    # Convert key and IV from Base64 to byte array
    $keyBytes = [Convert]::FromBase64String($aesKey)
    $ivBytes = [Convert]::FromBase64String($iv)

    # Convert encrypted message from Base64 to byte array
    $encryptedBytes = [Convert]::FromBase64String($encryptedMessage)

    # Create AES decryptor
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $keyBytes
    $aes.IV = $ivBytes

    $decryptor = $aes.CreateDecryptor($aes.Key, $aes.IV)

    # Decrypt the message
    $memoryStream = New-Object System.IO.MemoryStream
    $cryptoStream = New-Object System.Security.Cryptography.CryptoStream($memoryStream, $decryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
    $cryptoStream.Write($encryptedBytes, 0, $encryptedBytes.Length)
    $cryptoStream.FlushFinalBlock()

    # Get the decrypted message
    $decryptedBytes = $memoryStream.ToArray()
    $cryptoStream.Close()
    $memoryStream.Close()

    return [System.Text.Encoding]::UTF8.GetString($decryptedBytes)
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













