if ($null -eq $global:_PRJ_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_PRJ_module_location = $PSScriptRoot
    }
    else {
        $global:_PRJ_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}

$null = Import-HKShell _
$null = Import-HKShell persist

Invoke-Persist -> Instance

function Start-ProjectActions {
    
<#
.TODO
#>


<#
.TODO
#>

    Start-ProjectLoop
}

function Start-ProjectLoop {
    
<#
.TODO
#>


<#
.TODO
#>

    if(Invoke-Persist EndProject?) {
        Stop-ProjectActions
    } else {
        Start-Sleep 1
        Start-ProjectLoop
    }
}

function Stop-ProjectActions {

<#
.TODO
#>


<#
.TODO
#>

}

Invoke-Persist [boolean] EndProject = False

Start-ProjectActions

