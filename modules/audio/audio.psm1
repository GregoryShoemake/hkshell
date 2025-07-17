if ($null -eq $global:_audio_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_audio_module_location = $PSScriptRoot
    }
    else {
        $global:_audio_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}

<#
.PREFERENCES
#>


<#
.PREFERENCES
#>

$userDir = "~/.hkshell/audio"
if(!(Test-Path $userDir)) { mkdir $userDir }

Import-HkShell audio | Out-Null

Add-Type -AssemblyName presentationCore

function Get-Audio ([string]$nameRegex,[switch]$start) {
    $audios = Get-ChildItem -Force -Path $userDir | Where-Object { __match $_.Name $nameRegex }
    
    if(($audios -is [System.Array]) -and ($audios.Length -gt 1)) {
        $i = __choose_item $audios -Property $NULL
        $audio = $audios[$i]
    } else {
        if($audios -is [System.Array]) {
            $audio = $audios[0]
        } else {
            $audio = $audios
        }
    }

    if($start) {
        Start-Audio $audio.FullName
    } else {
        return $audio
    }
}
New-Alias -Name aud -Value Get-Audio -Scope Global -Force -ErrorAction SilentlyContinue

function _windows_start_audio($path) {
        $mediaPlayer = New-Object system.windows.media.mediaplayer
        $mediaPlayer.open($Path)
        $mediaPlayer.Play()
}

function _linux_start_audio($path) {
    Write-Host "!_LINUX MEDIA ACCESS NOT IMPLEMENTED_____!`n`n$_`n" -ForegroundColor Red
    return
}

function Start-Audio ($Path) {
    ___start Start-Audio
    ___debug "init:Path:$Path"
    $Path = Get-Path $Path -ErrorAction SilentlyContinue
    ___debug "Path:$Path"
    $checkFavorites = Get-Audio $Path
    if($NULL -ne $checkFavorites) {
        Start-Audio $checkFavorites.FullName
    } elseif (Test-Path $Path) {
        if(__IsWindows) {
            _windows_start_audio $path
        } elseif (__IsLinux) {
            _linux_start_audio $path
        }
    } elseif(!$(__match "$Path".ToLower() @("\.mp3", "\.wav", "\.flac", "\.aiff", "\.aac", "\.wma"))) {
        $string = ""
        Write-Host "!_Invalid extension: --> $(__match $Path "(\..+?$)" -Get -Index 1 ) <-- _____!`n`n$_`n" -ForegroundColor Red
        return
    } else {
        Write-Host "!_No Audio File Found at $($Path)_____!`n`n$_`n" -ForegroundColor Red

    }
   ___end
}
New-Alias -Name play -Value Start-Audio -Scope Global -Force -ErrorAction SilentlyContinue

