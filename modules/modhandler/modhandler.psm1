$global:_module_location_modhandler = Split-Path -Parent $MyInvocation.MyCommand.Definition



if(!(Test-Path "~\.hkshell")) { mkdir "~\.hkshell" }

function Import-HKShell {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $module,
        [Parameter()]
        $moduleDirectory,
        [Parameter()]
        [switch]
        $force
    )

    if ($null -eq $moduleDirectory) {
        $global:moduleDirectory = Split-Path $global:_module_location_modhandler
    }

    $path_ = "$global:moduleDirectory\$module"

    if($global:_debug_) { Write-Host "    \\ module:$path_" -ForegroundColor DarkMagenta }
    
    if (test-path $path_) {
        
        $moduleLoaded = ($global:loadedModules -contains $path_) -or ($null -ne (Get-Module | Where-Object { $_.name -eq $module }))

        if($moduleLoaded -and !$force) { 

            if($global:_debug_) { 
		Write-Host "    \\ module:$path_ -- already imported" -ForegroundColor Red 
		return
	    }
	    else {
		return "module $module is already imported" 
	    } 

	}

        try {
            Import-Module $path_ -Force -Scope GLobal
            $global:loadedModules += $path_
        }
        catch {
            Write-Error $_
            Write-Host "Exception thrown while importing module: $_" -ForegroundColor Red
        }

    }

    else {
        Write-Host Path to module: $path_ :does not exist -ForegroundColor Red
    }

}
New-Alias -Name importhks -Value Import-HKShell -Scope Global -Force

$global:loadedModules = @("$moduleDirectory\modhandler")


$null = Import-HKShell _ -ErrorAction SilentlyContinue
