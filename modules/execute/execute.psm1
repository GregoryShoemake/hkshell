function e_array_tostring ($a_) {
    if (!$global:_debug_) { return }
    ___start "e_array_tostring"
    $i = 0
    foreach ($a in $a_) {
        Write-Host -NoNewline " [$i]$a" -ForegroundColor DarkYellow
        $i++
    }
    write-host ""
}

function e_get_ext ([string]$name="") {
    ___start "e_get_ext"
    $l_ = $name.length
    $dir = -1
    for($i = $l_ - 1; $i -lt $l_; $i += $dir) {
        if($name[$i] -eq ".") { $dir = 0; $i++; continue }
        if($dir -lt 0) { continue }
        if($dir -eq 0) { $res = $name[$i]; $dir = 1; continue }
        if($dir -eq 1) { $res += $name[$i] }
    }
    return ___return $res
}

$methods = @{
    e_run = "RUN";
    e_install = "INSTALL"
}

function Start-Execute ()
{
    if("$args" -eq "help") {
        return '
## NAME
**Start-Execute** - A function to execute tasks with specified methods and arguments.

## SYNOPSIS
`Start-Execute [-method <method>] [-arguments <arguments>] [-style <style>] [-runas] [-wait] [-passthru]`

## DESCRIPTION
The `Start-Execute` function is designed to handle execution of tasks by invoking different methods like `run` or `install`. The function parses the command-line arguments to determine the method and the respective parameters to execute. It supports handling of various file types and can run them with different execution policies and window styles.

## PARAMETERS

- **-method** (Optional)

  Specifies the method to be used for execution. It can be either `RUN` or `INSTALL`. If no method is specified, the default is `RUN`.

- **-arguments** (Optional)

  A list of arguments to pass to the method being executed. Each method can interpret these arguments differently.

- **-style** (Optional)

  Specifies the window style for the process that will be started. Defaults to `Normal`.

- **-runas** (Switch)

  If specified, the process will be started with elevated privileges (as an administrator).

- **-wait** (Switch)

  If specified, the function will wait for the process to exit before returning.

- **-passthru** (Switch)

  If specified, the function will pass the output of the process back to the calling environment.

## USAGE

1. **Running a Script or Executable:**

   To run a script or executable, specify the file path as part of the arguments. You can specify additional options like window style or run as administrator.

   ```powershell
   Start-Execute "C\path\to\file.ps1" -method RUN -argument "-noprofile" -style Hidden -runas -wait
   ```

2. **Installing an Application:**

   To install an application, specify the method as `INSTALL` and provide the path to the installer.

   ```powershell
   Start-Execute "C:\path\to\installer.exe" -method INSTALL -wait -passthru
   ```

## DEBUGGING

If the global variable `_debug_` is set, the function will output debug information to the console, detailing each step of the execution process, including method selection, arguments parsing, and execution results.

## RETURN VALUE

The function does not return any value unless the `-passthru` switch is used, in which case it returns the process object for further inspection.

## NOTES

- The `Start-Execute` function utilizes helper functions like `___start`, `e_array_tostring`, and `e_get_ext` to handle debugging, argument processing, and file extension extraction respectively.
- Aliased as `ex` for convenience, allowing for quick execution calls in the shell.

## EXAMPLES

- **Run a PowerShell script with default settings:**

  ```powershell
  ex "C:\scripts\myscript.ps1"
  ```

- **Install an application with elevated privileges:**

  ```powershell
  ex -method INSTALL "C:\installers\myapp.exe" -runas
  ```

- **Install an MSI application with elevated privileges:**

  ```powershell
  ex -method INSTALL "C:\installers\winapp.msi" -runas -argumentList "/norestart /qn /a"
  ```

This man page should give you a comprehensive overview of the `Start-Execute` function`s design and usage. It`s all about making your code execution versatile and adaptable to different needs. Keep it cool and code on!
'
    }
    ___start "execute"
    $hash = __search_args $args "-method"
    $method = $hash.RES
    $method = __default $method $methods.e_run
    ___debug "args:$(e_array_tostring $hash.ARGS)"
    ___debug "method:$method"
    

    switch ($method) {
        $methods.e_run { 
            e_run $hash.ARGS
        }
        $methods.e_install { 
            e_install $hash.ARGS
        }
        Default {}
    }
    ___end
}
New-Alias -name ex -value "Start-Execute" -scope Global -Force

function e_run ($params) {
    ___start "e_run"
    $c_ = $params.Count
    ___debug "args:$params | count:$c_"
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

    ___debug "target:$($target.fullname)"
    ___debug "ext:$ext"
    ___debug "verb:$verb"
    ___debug "style:$style"
    ___debug "wait:$wait"
    ___debug "passthru:$passthru"
    ___debug "arguments:$passthru"

    switch($ext) {
        ps1 {
            $noExit = if($style -ne "hidden") { "-noexit" } else { "" }
            try {
                $res = Start-Process pwsh.exe -Verb $verb -WindowStyle $style -ArgumentList "$arguments -executionPolicy Bypass $noexit -file $($target.fullname)" -Wait:$wait -PassThru:$passthru -ErrorAction Stop
                return ___return $res
            } catch {
                $res = Start-Process powershell.exe -Verb $verb -WindowStyle $style -ArgumentList " $arguments -executionPolicy Bypass $noexit -file $($target.fullname)" -Wait:$wait -PassThru:$passthru
                return ___return $res
            }
        }
        sh  {
            $res = Start-Process bash -Verb $verb -WindowStyle $style -ArgumentList "$($target.fullname)" -Wait:$wait -PassThru:$passthru -ErrorAction Stop
            return ___return $res
        }
        bat {
            if($null -eq $arguments) {
                return ___return $(Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru)
            }
            return ___return $(Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru -ArgumentList $arguments)
        }
        default {
            if($null -eq $arguments) {
                return ___return $(Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru)
            }
            return ___return $(Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru -ArgumentList $arguments)
        }
    }
}
function e_install ($params) {
    ___start "e_install"
    $c_ = $params.Count
    ___debug "args:$params | count:$c_"
    if(($null -eq $params) -or ($c_ -eq 0) -or (($c_ -eq 1)-and($null -eq $params[0]))){
        ___end
        throw [System.ArgumentNullException] "No arguments passed to execute.e_install"
    } 
    $target = $params[0]
    if ($target -is [string]) { 
        ___debug "target is string"
        if($target -match "^[0-9]+$"){
            $target = (Get-ChildItem $(Get-Location))[$target]
        } else {
            $target = Get-Item $target -Force -ErrorAction Stop
        }
    } elseif ($target -is [int]) {
         $target = (Get-ChildItem $(Get-Location))[$target]       
    }
    if ($target -isnot [System.IO.FileInfo]) {
        ___end
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

    ___debug "target:$($target.fullname)"
    ___debug "ext:$ext"
    ___debug "verb:$verb"
    ___debug "style:$style"
    ___debug "wait:$wait"
    ___debug "passthru:$passthru"
    ___debug "arguments:$arguments"
    
    switch($ext) {
        exe {
            ___debug "Running [exe] install"
            if($null -eq $arguments) {
                return ___return $(Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru)
            }
            return ___return $(Start-Process $target.fullname -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru -ArgumentList $arguments)
        }
        msi {
            if($verb -eq "Open") {
                Write-Host "!_MSI INSTALL REQUIRES RUNAS VERB_ (ex /path/to/app.exe -runas)____!`n`n$_`n" -ForegroundColor Red
                return ___return
            }
            $arguments = __default $arguments "/norestart /qn"
            ___debug "Running [msi] install"
            return ___return $(Start-Process msiexec -Verb $verb -WindowStyle $style -Wait:$wait -PassThru:$passthru -ArgumentList "/i $($target.FullName) $arguments")
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
