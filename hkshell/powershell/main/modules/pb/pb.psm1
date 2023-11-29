importhks persist

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
function pb_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Gray" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function pb_debug_function ($function, $functionColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Gray" }
    Write-Host ">_ $function" -ForegroundColor $functionColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function pb_prolix ($message, $messageColor) {
    if (!$global:prolix) { return }
    if ($null -eq $messageColor) { $messageColor = "Gray" }
    Write-Host $msg -ForegroundColor $messageColor
}

function Send-PushbulletSMS ($contact = "7574703149", [string]$message = "testing...") {
    $SCOPEbak = ($global:SCOPE -split "::")[0]
    persist -> contacts
    pb_debug_function Send-PushbulletSMS DarkCyan
    pb_debug "Contact: $contact" DarkGray
    pb_debug "Message: $message" DarkGray
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
    }
    persist -> $SCOPEbak
} 
New-Alias -Name text -Value Send-PushbulletSMS
