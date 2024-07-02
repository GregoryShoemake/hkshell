function e_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "DarkYellow" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function e_debug_function ($function, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Yellow" }
    Write-Host ">_ $function" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function e_debug_return {
    if (!$global:_debug_) { return }
    Write-Host "#return# $($args -join " ")" -ForegroundColor Black -BackgroundColor DarkGray
    return
}

function e_array_tostring ($a_) {
    if (!$global:_debug_) { return }
    e_debug_function "e_array_tostring"
    $i = 0
    foreach ($a in $a_) {
        Write-Host -NoNewline " [$i]$a" -ForegroundColor DarkYellow
        $i++
    }
    write-host ""
}

function e_get_ext ([string]$name="") {
    e_debug_function "e_get_ext"
    $l_ = $name.length
    $dir = -1
    for($i = $l_ - 1; $i -lt $l_; $i += $dir) {
        if($name[$i] -eq ".") { $dir = 0; $i++; continue }
        if($dir -lt 0) { continue }
        if($dir -eq 0) { $res = $name[$i]; $dir = 1; continue }
        if($dir -eq 1) { $res += $name[$i] }
    }
    e_debug_return
    return $res
}

$methods = @{
    e_run = "RUN";
    e_install = "INSTALL"
}

function Start-Execute ()
{
    e_debug_function "execute"
    $hash = __search_args $args "-method"
    $method = $hash.RES
    $method = __default $method $methods.e_run
    e_debug "args:$(e_array_tostring $hash.ARGS)"
    e_debug "method:$method"
    

    switch ($method) {
        $methods.e_run { 
            e_run $hash.ARGS
        }
        $methods.e_install { 
            e_install $hash.ARGS
        }
        Default {}
    }
}
New-Alias -name ex -value "Start-Execute" -scope Global -Force

function e_run ($params) {
    e_debug_function "e_run"
    $c_ = $params.Count
    e_debug "args:$params | count:$c_"
    if(($null -eq $params) -or ($c_ -eq 0) -or (($c_ -eq 1)-and($null -eq $params[0]))){
        throw [System.ArgumentNullException] "No arguments passed to execute.e_run"
    } 
    $target = Get-Path $params[0] | Get-Item
    $ext = e_get_ext $target.name
    $hash = __search_args $params "-runas" -switch
    $verb = if($hash.RES) { "RunAs" } else { "Open" }
    $hash = __search_args $hash.ARGS "-wait" -switch
    $wait = $hash.RES
    $hash = __search_args $hash.ARGS "-passthru" -switch
    $passthru = $hash.RES
    $hash = __search_args $hash.ARGS "-style" 
    $style = __default $hash.RES "Normal"
    $hash = __search_args $hash.ARGS "-argumentList" -all
    $arguments = $hash.RES

    e_debug "target:$($target.fullname)"
    e_debug "ext:$ext"
    e_debug "verb:$verb"
    e_debug "style:$style"
    e_debug "wait:$wait"
    e_debug "passthru:$passthru"
    e_debug "arguments:$passthru"

    switch($ext) {
        ps1 {
            $noExit = if($style -ne "hidden") { "-noexit" } else { "" }
            try {
                return Start-Process pwsh.exe -Verb $verb -WindowStyle $style -ArgumentList "$arguments -executionPolicy Bypass $noexit -file $($target.fullname)" -Wait:$wait -PassThru:$passthru -ErrorAction Stop
            } catch {
                return Start-Process powershell.exe -Verb $verb -WindowStyle $style -ArgumentList " $arguments -executionPolicy Bypass $noexit -file $($target.fullname)" -Wait:$wait -PassThru:$passthru
            }
        }
        sh  {
            return Start-Process bash -Verb $verb -WindowStyle $style -ArgumentList "$($target.fullname)" -Wait:$wait -PassThru:$passthru -ErrorAction Stop
        }
        bat {
            if($null -eq $arguments) {
                return Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru
            }
            return Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru -ArgumentList $arguments
        }
        default {
            if($null -eq $arguments) {
                return Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru
            }
            return Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru -ArgumentList $arguments
        }
    }
}
function e_install ($params) {
    e_debug_function "e_install"
    $c_ = $params.Count
    e_debug "args:$params | count:$c_"
    if(($null -eq $params) -or ($c_ -eq 0) -or (($c_ -eq 1)-and($null -eq $params[0]))){
        throw [System.ArgumentNullException] "No arguments passed to execute.e_install"
    } 
    $target = $params[0]
    if ($target -is [string]) { 
        e_debug "target is string"
        if($target -match "^[0-9]+$"){
            $target = (Get-ChildItem $(Get-Location))[$target]
        } else {
            $target = Get-Item $target -Force -ErrorAction Stop
        }
    } elseif ($target -is [int]) {
         $target = (Get-ChildItem $(Get-Location))[$target]       
    }
    if ($target -isnot [System.IO.FileInfo]) {
        throw [System.ArgumentException] "Invalid target type $($target.GetType()), expected [string] (as path) or [System.IO.FileInfo]"
    }
    $ext = e_get_ext $target.name
    $hash = __search_args $params "-runas" -switch
    $verb = if($hash.RES) { "RunAs" } else { "Open" }
    $hash = __search_args $hash.ARGS "-wait" -switch
    $wait = $hash.RES
    $wait = __default $wait (Invoke-PushWrapper Invoke-Persist [boolean]default>_installWaitDefault:true)
    $hash = __search_args $hash.ARGS "-passthru" -switch
    $passthru = $hash.RES
    $passthru = __default $passthru (Invoke-PushWrapper Invoke-Persist [boolean]default>_installPassthruDefault:true)
    $hash = __search_args $hash.ARGS "-style" 
    $style = __default $hash.RES "Normal"
    $hash = __search_args $hash.ARGS "-argumentList" -all -untilswitch
    $arguments = $hash.RES

    if($global:_debug_) { 
        e_debug "target:$($target.fullname)"
        e_debug "ext:$ext"
        e_debug "verb:$verb"
        e_debug "style:$style"
        e_debug "wait:$wait"
        e_debug "passthru:$passthru"
        e_debug "arguments:$arguments"
    }    
    
    switch($ext) {
        exe {
            e_debug "Running [exe] install"
            if($null -eq $arguments) {
                return Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru
            }
            return Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru -ArgumentList $arguments
        }
    }
}
function Test-Credential {
<#
	.SYNOPSIS
		Takes a PSCredential object and validates it against the domain (or local machine, or ADAM instance).

	.PARAMETER cred
		A PScredential object with the username/password you wish to test. Typically this is generated using the Get-Credential cmdlet. Accepts pipeline input.
		
	.PARAMETER context
		An optional parameter specifying what type of credential this is. Possible values are 'Domain' for Active Directory accounts, and 'Machine' for local machine accounts. The default is 'Domain.'
	
	.OUTPUTS
		A boolean, indicating whether the credentials were successfully validated.

	.NOTES
		Created by Jeffrey B Smith, 6/30/2010
#>
	param(
		[parameter(Mandatory=$true,ValueFromPipeline=$true)]
		[System.Management.Automation.PSCredential]$credential,
		[parameter()][validateset('Domain','Machine')]
		[string]$context = 'Machine'
	)
	begin {
		Add-Type -AssemblyName System.DirectoryServices.AccountManagement
		$DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::$context) 
	}
	process {
		$DS.ValidateCredentials($credential.GetNetworkCredential().UserName, $credential.GetNetworkCredential().password)
	}
}

function Invoke-Do ([int]$repetitions,$block) {
    for ($i = 0; $i -lt $repetitions; $i++) {
    	& $block
    }
}
New-Alias -Name ido -Value Invoke-Do -Scope Global -Force -ErrorAction SilentlyContinue
