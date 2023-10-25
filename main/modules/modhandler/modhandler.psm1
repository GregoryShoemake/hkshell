
$global:_module_location_modhandler = Split-Path -Parent $MyInvocation.MyCommand.Definition

function import {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $module,
        [Parameter()]
        $moduleDirectory
    )
    if ($null -eq $moduleDirectory) {
        $moduleDirectory = Split-Path $global:_module_location_modhandler
    }
    $path = "$moduleDirectory\$module"
    if (test-path $path) {
        try {
            Import-Module $path -Force -Scope GLobal -ErrorAction Stop
            $script:loadedModules += $path
        }
        catch {
            Write-Host "Exception thrown while importing module: $_" -ForegroundColor Red
        }
    }
    else {
        Write-Host Path to module: $path :does not exist -ForegroundColor Red
    }
}

$script:loadedModules = @("$moduleDirectory\modhandler")

function reimport {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $module
    )
    foreach ($m in $script:loadedModules) {
        if ($m -notmatch $module) { if ($module -ne "all") { continue } }

        if (test-path $m) {
            try {
                Import-Module $m -Force -Scope GLobal -ErrorAction Stop
                $script:loadedModules += $m
            }
            catch {
            
            }
        }
        else {
            Write-Host Path to module: $m :does not exist -ForegroundColor Red
        }
    }
} 