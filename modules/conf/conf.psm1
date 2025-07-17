if ($null -eq $global:_MODNAME_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_conf_module_location = $PSScriptRoot
    }
    else {
        $global:_conf_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}

$null = importhks fs

$global:hks_conf_dir = "~\.hkshell\confs"
Invoke-NewDir $global:hks_conf_dir

function Get-ConfigurationItem ([string]$path, [switch]$content) {

    Push-Location $Global:hks_conf_dir

    If(Get-Path $path -NotExists) {
        $conf = Invoke-NewItem $path -PassThru
    } 

    $conf = Get-Item $path

    Pop-Location

    if($content) {
        $path = $conf.FullName
        return Get-Content $path -Force
    }

    return $conf
}

function Get-ConfigurationLine ([string]$path, [string]$key) {
    $content = Get-ConfigurationItem $path -Content
    if($content -isnot [System.Array]) {
        $content = $content -split "\n"
    }
    foreach($line in $content) {
        $lineKey = __match $line "(.+?)=" -Get -Index 1
        if($lineKey -eq $key) {
            return $line
        }
    }
}

function Get-ConfigurationValue ([string]$path, [string]$key) {
    $line = Get-ConfigurationLine $path $key
    return __match $line "=(.+?)$" -Get -Index 1
}

function Set-ConfigurationLine ([string]$path, [string]$key, [string]$value) {
    $item = Get-ConfigurationItem $path
    $content = Get-Content $item.FullName -Force
    $content = $content -replace "$key=.+", "$key=$value"
    Set-Content $item.FullName -Value $content
}
