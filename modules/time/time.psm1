$global:millisecond = 1
$global:second = $global:millisecond * 1000
$global:minute = $global:second * 60
$global:hour = $global:minute * 60
$global:day = $global:hour * 24
$global:week = $global:day * 7

function t_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Gray" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function t_debug_function ($function, $functionColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Gray" }
    Write-Host ">_ $function" -ForegroundColor $functionColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}

function ConvertTo-TimeInterval ($quantity = 0, [string]$from = "milliseconds") {

    $millis = ConvertTo-Milliseconds $quantity $from

    [long]$daysInterval = [Math]::Floor([long]$millis / [long]$day)
    [long]$millis = $millis - ($daysInterval * $day)
  
    [long]$hoursInterval = [Math]::Floor([long]$millis / [long]$hour)
    [long]$millis = $millis - ($hoursInterval * $hour)
  
    [long]$minutesInterval = [Math]::Floor([long]$millis / [long]$minute)
    [long]$millis = $millis - ($minutesInterval * $minute)
  
    [long]$secondsInterval = [Math]::Floor([long]$millis / [long]$second)
    [long]$millis = $millis - ($secondsInterval * $second)

    return "$daysInterval days: $hoursInterval hrs: $minutesInterval mins: $secondsInterval secs: $millis ms"
}
New-Alias -Name convert2TimeInt -Value ConvertTo-TimeInterval -Scope Global -Force
function ConvertTo-Milliseconds ($quantity = 0, [string]$from = "milliseconds") {
    switch ($from) {
        { __eq $_ @("millis", "ms", "milliseconds", "millisecond") } { return $quantity }
        { __eq $_ @("secs", "s", "seconds", "second", "sec") } { return $quantity * $global:second }
        { __eq $_ @("mins", "min", "minutes", "minute") } { return $quantity * $global:minute }
        { __eq $_ @("hrs", "hr", "hours", "hour") } { return $quantity * $global:hour }
        { __eq $_ @("days", "day") } { return $quantity * $global:day }
        { __eq $_ @("wks", "wk", "weeks", "week") } { return $quantity * $global:week }
    }
}
New-Alias -Name convertToMS -Value ConvertTo-Milliseconds -Scope Global -Force
function ConvertFrom-Milliseconds ($quantity = 0, [string]$to = "milliseconds") {
    switch ($to) {
        { __eq $_ @("millis", "ms", "milliseconds", "millisecond") } { return $quantity }
        { __eq $_ @("secs", "s", "seconds", "second", "sec") } { return $quantity / $global:second }
        { __eq $_ @("mins", "min", "minutes", "minute") } { return $quantity / $global:minute }
        { __eq $_ @("hrs", "hr", "hours", "hour") } { return $quantity / $global:hour }
        { __eq $_ @("days", "day") } { return $quantity / $global:day }
        { __eq $_ @("wks", "wk", "weeks", "week") } { return $quantity / $global:week }
    }
}
New-Alias -Name convertFrMS -Value ConvertFrom-Milliseconds -Scope Global -Force
function ConvertTo-Time ($quantity = 0, [string]$from = "milliseconds" , [string]$to = "milliseconds") {
    $fromMS = ConvertTo-Milliseconds $quantity $from
    return ConvertFrom-Milliseconds $fromMS $to
}
New-Alias -Name convert2Time -Value ConvertTo-Time -Scope Global -Force
function Get-MillisecondsUntil ([datetime]$datetime) {
    $difference = $datetime - $(Get-Date)
    return $difference.TotalMilliseconds
}
New-Alias -Name millisUntil -Value ConvertTo-Time -Scope Global -Force
function ConvertTo-DateTime ($dateHash = @{ Parse = "01JAN1970@0000" }) {
    t_debug_function "ConvertTo-DateTime" DarkCyan
    if ($null -ne $dateHash.Parse) {
        $formats = @(
            "ddMMMyyyy@HHmm"
        )
        $ErrorActionPreference = 'STOP'
        foreach ($f in $formats) {
            try { $datetime = [datetime]::ParseExact($dateHash.Parse, $f, $null) }
            catch { continue }
        }
        $ErrorActionPreference = 'CONTINUE'
        if ($null -eq $datetime) { $datetime = [datetime] $dateHash.Parse }
    }
    elseif ($null -ne $dateHash.Date -and $null -ne $dateHash.Time) {
        t_debug "dateHash.Date: $($dateHash.Date)"
        switch ($dateHash.Date) {
            Today {
                $date = (Get-Date)
                $year = $date.Year
                $month = $date.Month
                $day = $date.Day 
            }
            Tomorrow {
                $date = (Get-Date).AddDays(1)
                $year = $date.Year
                $month = $date.Month
                $day = $date.Day 
            }
            Yesterday {
                $date = (Get-Date).AddDays(-1)
                $year = $date.Year
                $month = $date.Month
                $day = $date.Day 
            }
            { __eq $_ @("monday", "mon", "m", "lunes") } {
                $date = (Get-Date)
                while ($date.DayOfWeek -ne "Monday" ) {
                    $date = $date.AddDays(1)
                }
                $year = $date.Year
                $month = $date.Month
                $day = $date.Day 
            }
            { __eq $_ @("tueday", "tue", "t", "martes") } {
                $date = (Get-Date)
                while ($date.DayOfWeek -ne "Tuesday" ) {
                    $date = $date.AddDays(1)
                }
                $year = $date.Year
                $month = $date.Month
                $day = $date.Day 
            }
            { __eq $_ @("wednesday", "wed", "w", "miercoles") } {
                $date = (Get-Date)
                while ($date.DayOfWeek -ne "Wednesday" ) {
                    $date = $date.AddDays(1)
                }
                $year = $date.Year
                $month = $date.Month
                $day = $date.Day 
            }
            { __eq $_ @("thursday", "thu", "th", "jueves") } {
                $date = (Get-Date)
                while ($date.DayOfWeek -ne "Thursday" ) {
                    $date = $date.AddDays(1)
                }
                $year = $date.Year
                $month = $date.Month
                $day = $date.Day 
            }
            { __eq $_ @("friday", "fri", "f", "viernes") } {
                $date = (Get-Date)
                while ($date.DayOfWeek -ne "Friday" ) {
                    $date = $date.AddDays(1)
                }
                $year = $date.Year
                $month = $date.Month
                $day = $date.Day 
            }
            { __eq $_ @("saturday", "sat", "s", "sabado") } {
                $date = (Get-Date)
                while ($date.DayOfWeek -ne "Saturday" ) {
                    $date = $date.AddDays(1)
                }
                $year = $date.Year
                $month = $date.Month
                $day = $date.Day 
            }
            { __eq $_ @("sunday", "sun", "s", "domingo") } {
                $date = (Get-Date)
                while ($date.DayOfWeek -ne "Sunday" ) {
                    $date = $date.AddDays(1)
                }
                $year = $date.Year
                $month = $date.Month
                $day = $date.Day 
            }
        }
        t_debug "dateHash.Date - year: $year" darkGray
        t_debug "dateHash.Date - month: $month" darkGray
        t_debug "dateHash.Date - day: $day" darkGray
        t_debug "dateHash.Time: $($dateHash.Time)"
        switch ($dateHash.Time) {
            { $_ -match "^([0-9]{1,2}|[0-9]{4})(:)?([0-9]{2})?(am|pm)?$" } {
                $hour = __match $dateHash.Time "^[0-9]{1,2}" -getMatch
                t_debug "dateHash.Time - hour: $hour" darkGray
                $ampm = __match $dateHash.Time "(am|pm)" -getMatch
                t_debug "dateHash.Time - ampm: $ampm" darkGray
                if ($null -ne $ampm) {
                    if ($hour -eq 12) { $hour -= 12 }
                    $hour = if ($ampm -eq "pm") { ([int]$hour) + 12 } else { $hour }
                }
                if ($dateHash.Time -match ":[0-9]{2}") {
                    $split = $Matches[0] -split ":"
                    $minute = $split[1]
                }
                elseif ($dateHash.Time -match "^[0-9]{4}") {
                    $minute = $dateHash.Time.substring(2, 2)
                }
                else {
                    $minute = 0
                }
                t_debug "dateHash.Time - minute: $minute" darkGray
            }
            Default {}
        }
        $datetime = Get-Date -Year $year -Month $month -Day $day -Hour $hour -Minute $minute -Second 0
    }
    return $datetime
}
New-Alias -Name 2dt -Value ConvertTo-DateTime -Scope Global -Force
