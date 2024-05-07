if ($null -eq $global:_io_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_io_module_location = $PSScriptRoot
    }
    else {
        $global:_io_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}

<#
.PREFERENCES
#>


<#
.PREFERENCES
#>

$userDir = "~/.hkshell/io"
if(!(Test-Path $userDir)) { mkdir $userDir }


function Write-HostLoading {
    ___start Write-HostLoading 

    $hash = __search_args $args "-seconds"
    [int]$seconds = __default $hash.RES 0
    $hash = __search_args $hash.ARGS "-milliseconds"
    [int]$milliseconds = __default $hash.RES 0

    ___debug "seconds:$seconds"
    ___debug "milliseconds:$milliseconds"

    $hash = __search_args $hash.ARGS "-foregroundcolor"
    $foregroundcolor = __default $hash.RES "Gray"
    $hash = __search_args $hash.ARGS "-backgroundcolor"
    $backgroundcolor = __default $hash.RES "Black"

    ___debug "foregroundcolor:$foregroundcolor"
    ___debug "backgroundcolor:$backgroundcolor"

    if(($seconds + $milliseconds) -eq 0) { $seconds = 5 } else { $seconds += $milliseconds / 1000 }

    ___debug "final seconds:$seconds"

    $msg = $hash.ARGS

    ___debug "msg:$msg"

    foreach($i in @(0..$($seconds / 2))) {
	Write-Host -NoNewline "`r | $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds 125
	Write-Host -NoNewline "`r / $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds 125
	Write-Host -NoNewline "`r - $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds 125
	Write-Host -NoNewline "`r \ $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds 125
	Write-Host -NoNewline "`r | $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds 125
	Write-Host -NoNewline "`r / $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds 125
	Write-Host -NoNewline "`r - $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds 125
	Write-Host -NoNewline "`r \ $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds 125
    }
    Write-Host -NoNewline "`r * $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor

    ___end

}

	

