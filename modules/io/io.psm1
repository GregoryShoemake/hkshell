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

    if(($seconds + $milliseconds) -eq 0) { $milliseconds = 5000 } else { $milliseconds += $seconds * 1000 }

    ___debug "final milliseconds:$milliseconds"

    $msg = $hash.ARGS

    ___debug "msg:$msg"

    [int]$repetitions = [Math]::Sqrt($milliseconds / 1000) * 2

    $duration = ($milliseconds) / ($repetitions * 8)


    foreach($i in @(1..$repetitions)) {
	Write-Host -NoNewline "`r | $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds $duration
	Write-Host -NoNewline "`r / $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds $duration
	Write-Host -NoNewline "`r - $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds $duration
	Write-Host -NoNewline "`r \ $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds $duration
	Write-Host -NoNewline "`r | $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds $duration
	Write-Host -NoNewline "`r / $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds $duration
	Write-Host -NoNewline "`r - $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds $duration
	Write-Host -NoNewline "`r \ $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor; Start-Sleep -Milliseconds $duration
    }
    Write-Host -NoNewline "`r * $msg" -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor

    ___end

}

function Write-HostColor ($message, [switch]$help) {

    if($help) {
        return "
NAME
    Write-HostColor

SYNOPSIS
    Writes colored text to the console output based on the specified message format.

SYNTAX
    Write-HostColor [-message] <String> [[-help] <SwitchParameter>]

DESCRIPTION
    The Write-HostColor function is designed to output text to the console with color formatting.
    The text message can contain color tags in the format \[Color\] (the exact format includes the slashes) which specify the foreground color
    for the subsequent text. If no color is specified, the text will default to Gray.

PARAMETERS
    -message <String>
        The message string to be output. The string can include segments enclosed in square brackets
        to specify colors, e.g., '\[Red\]This is red text \[Green\]and this is green.'

NOTES
    - The function splits the input message using square brackets to determine color segments.
    - If a specified color is not recognized, or if no color is defined within brackets, the function
      defaults to using Gray as the foreground color.
    - The implementation currently does not handle nested or overlapping color tags.

AUTHOR
    GregoryShoemake a.k.a. HomeyKrogerSage

COPYRIGHT
    © 2025 Your Company. All rights reserved.

SEE ALSO
    Write-Host
```

### Additional Insights:

- **Color Handling:** The function relies on the '-ForegroundColor' parameter of the 'Write-Host' cmdlet, which supports a predefined set of colors. It's a good idea to document which colors are supported explicitly if you intend users to utilize specific colors.

- **Default Behavior:** As per your function, if no color is specified or if the color is the same as the section identified, it defaults to 'Gray'. This is important for users to know in case they see unexpected results.

- **Error Handling:** Consider adding error handling for unsupported colors or malformed input. Right now, it assumes the input is well-formed.
        "
    }

    $message -split "\\\[" | ForEach-Object {
        $split = $_ -split "\\]"
        $section = __default $split[1] $split[0]
        $color = $split[0]
        if($color -eq $section) {
            $color = "Gray"
        }
        Write-Host -Object $section -ForegroundColor $color -NoNewline
    }
    Write-Host ""
}

