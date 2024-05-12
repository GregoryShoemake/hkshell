$global:_module_location_modhandler = $(Split-Path -Parent $MyInvocation.MyCommand.Definition) -replace "\\","/"

if(!(Test-Path "~/.hkshell")) { mkdir "~/.hkshell" }
if(!(Test-Path "~/.hkshell/hkshell.conf")) { New-Item "~/.hkshell/hkshell.conf" | Set-Content "enablehints=true" }

$global:_enable_hints_ = "$(Get-Item "~/.hkshell/hkshell.conf" -Force -ErrorAction SilentlyContinue | Get-Content)" -match "enablehints=true"

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
	$global:moduleDirectory = $(Split-Path $global:_module_location_modhandler) -replace "\\","/"
    }

    $path_ = "$global:moduleDirectory/$module"

    try {
	$DebugPreference = 'Stop'
	___debug "path:$path_"
    }
    catch {
	if($global:_debug_) {
	    Write-Host "path:$path_"
	}
    }
    $DebugPreference = 'SilentlyContinue'

    if($global:_debug_) { Write-Host "    \\ module:$path_" -ForegroundColor DarkMagenta }

    if($(Get-Item "$pwd").PSProvider.Name -eq "Registry") {
	Push-Location C:\
	$pop_location = $true
    }
    
    if (test-path $path_) {
        
        $moduleLoaded = ($global:loadedModules -contains $path_) -or ($null -ne (Get-Module | Where-Object { $_.name -eq $module }))

        if($moduleLoaded -and !$force) { 

            if($global:_debug_) { 
		Write-Host "    \\ module:$path_ -- already imported" -ForegroundColor Red 
		if($pop_location){ Pop-Location }
		return
	    }
	    else {
		if($pop_location){ Pop-Location }
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
     
    if($pop_location){ Pop-Location }

}
New-Alias -Name importhks -Value Import-HKShell -Scope Global -Force

$global:loadedModules = @("$moduleDirectory/modhandler")


$null = Import-HKShell _ -ErrorAction SilentlyContinue
