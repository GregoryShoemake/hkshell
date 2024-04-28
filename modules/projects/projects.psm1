<#
Stop-Process: Cannot bind argument to parameter 'InputObject' because it is null.
Set-Location: Cannot find path 'K:\nand2tetris\projects\03\:\nand2tetris' because it does not exist.

#>

$userDir = "~/.hkshell/projects"
if(!(Test-Path $userDir)) { mkdir $userDir }




$null = importhks nav
function pr_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "DarkYellow" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function pr_debug_function ($function, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Yellow" }
    Write-Host ">_ $function" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function pr_debug_return {
    if (!$global:_debug_) { return }
    Write-Host "#return# $($args -join " ")" -ForegroundColor Black -BackgroundColor DarkGray
    return
}
function pr_prolix ($message, $messageColor) {
    if (!$global:prolix) { return }
    if ($null -eq $messageColor) { $messageColor = "Cyan" }
    Write-Host $message -ForegroundColor $messageColor
}
function pr_choice ($prompt) {
    while((Read-Host $prompt) -notmatch "^(y|Y|yes|Yes|YES|n|N|no|No|NO)$") {
            $prompt = "?"
            Write-Host "Please input a [Y]es or [N]o answer" -ForegroundColor yellow
        }
    if($MATCHES[0] -match "[Yy]"){ return $true }
    return $false
}
function pr_default ($variable, $value) {
    pr_debug_function "e_default"
    if ($null -eq $variable) { 
        pr_debug_return variable is null
        return $value 
    }
    switch ($variable.GetType().name) {
        String { 
            if($variable -eq "") {
                pr_debug_return
                return $value
            } else {
                pr_debug_return
                return $variable
            }

        }
    }
}

if ($null -eq $global:_projects_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_projects_module_location = $PSScriptRoot
    }
    else {
        $global:_projects_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}
pr_debug "Populating module PROJECTS global path variable ->
    global:_projects_module_location=$global:_projects_module_location"
function pr_choice ($prompt) {
    while((Read-Host $prompt) -notmatch "[Yy]([EeSs])?|[Nn]([Oo])?") {
            $prompt = ""
            Write-Host "Please input a [Y]es or [N]o answer" -ForegroundColor yellow
        }
    if($MATCHES[0] -match "[Yy]"){ return $true }
    return $false
}
function pr_match {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        $string,
        [Parameter(Mandatory = $false, Position = 1)]
        $regex,
        [Parameter()]
        [switch]
        $getMatch = $false,
        [Parameter()]
        $logic = "OR"
    )
    pr_debug_function "pr_match"
    if ($null -eq $string) {
        pr_debug_return string is null
        if ($getMatch) { return $null }
        return $false
    }
    if ($null -eq $regex) {
        pr_debug_return regex is null
        if ($getMatch) { return $null }
        return $false
    }
    if (($string -is [System.Array])) {
        $string = $string -join "`n"
    }
    if ($regex -is [System.Array]) {
        foreach ($r in $regex) {
            $f = p_match $string $r
            if (($logic -eq "OR") -and $f) { return $true }
            if (($logic -eq "AND") -and !$f) { return $false }
            if (($logic -eq "NOT") -and $f) { return $false }
        }
        pr_debug_return
        return ($logic -eq "AND") -or ($logic -eq "NOT")
    }
    $found = $string -match $regex
    if ($found) {
        if ($getMatch) {
            pr_debug_return
            return $Matches[0]
        }
        pr_debug_return
        return $logic -ne "NOT"
    }
    pr_debug_return
    if ($logic -eq "NOT") { return $true }
    if ($getMatch) { return $null }
    return $false
}
function pr_int_equal {
    [CmdletBinding()]
    param (
        [Parameter()]
        [int]
        $int,
        # single int or array of ints to compare
        [Parameter()]
        $ints
    )
    if ($null -eq $ints) { return $false }
    foreach ($i in $ints) {
        if ($int -eq $i) { return $true }
    }
    return $false
}
function pr_truncate {
    [CmdletBinding()]
    param (
        # Array object passed to truncate
        [Parameter(Mandatory = $false, Position = 0)]
        [System.Array]
        $array,
        [Parameter()]
        [int]
        $fromStart = 0,
        [Parameter()]
        [int]
        $fromEnd = 0,
        [int[]]
        $indexAndDepth
    )
    pr_debug_function "_truncate"
    pr_debug "array:
$(Out-String -inputObject $array)//"

    $l = $array.Length
    if ($fromStart -gt 0) {
        $l = $l - $fromStart
    }
    if ($fromEnd -gt 0) {
        $l = $l - $fromEnd
    }
    elseif(($fromStart -eq 0) -and ($null -eq $indexAndDepth)) {
        $fromEnd = 1
    }
    $fromEnd = $array.Length - $fromEnd
    if (($null -ne $indexAndDepth) -and ($indexAndDepth[1] -gt 0)) {
        $l = $l - $indexAndDepth[1]
    }
    if ($l -le 0) {
        pr_debug_return empty array
        return @()
    }
    $res = @()
    $fromStart--
    if ($null -ne $indexAndDepth) {
        $middleStart = $indexAndDepth[0]
        $middleEnd = $indexAndDepth[0] + $indexAndDepth[1] - 1
        $middle = $middleStart..$middleEnd
    }
    for ($i = 0; $i -lt $array.Length; $i ++) {
        if (($i -gt $fromStart) -and !(pr_int_equal $i $middle ) -and ($i -lt $fromEnd)) {
            $res += $array[$i]
        }
    }
    pr_debug_return $(Out-String -inputObject $res)
    return $res
}
function pr_search_args ($a_, $param, [switch]$switch, [switch]$all, [switch]$untilSwitch) {
    pr_debug_function "pr_search_args"    
    $c_ = $a_.Count
    pr_debug "args:$a_ | len:$c_"
    pr_debug "param:$param"
    pr_debug "switch:$switch"
    if($switch) { 
        for ($i = 0; $i -lt $c_; $i++) {
            $a = $a_[$i]
            pr_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if($null -eq $res) { 
                $res = $true 
                $a_ = pr_truncate $a_ -indexAndDepth @($i,1)
            }
            else {
                throw [System.ArgumentException] "Duplicate argument passed: $param"
            }
        }
        $res = $res -and $true
        pr_debug_return "@{ RES=$res ; ARGS=$a_ }"
        return @{
            RES = $res
            ARGS = $a_
        }
    } else {
        for ($i = 0; $i -lt $a_.length; $i++) {
            $a = $a_[$i]
            pr_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if(($null -eq $res) -and ($i -lt ($c_ - 1))) {
                if($all) {
                    $ibak = $i
                    $res = @()
                    $remove = 1
                    for ($i = $i + 1; $i -lt ($c_); $i++) {
                        if($untilSwitch -and ($a_[$i] -match "^-")) {
                            pr_debug "[-untilSwitch] next switch found"
                            break
                        }
                        $res += $a_[$i]
                        $remove++
                    }
                    $res = $res -join " "
                    $a_ = pr_truncate $a_ -indexAndDepth @($ibak, $remove)
                } else {
                    $res = $a_[$i + 1]
                    if($res -match "^-") { 
                        $res = $null 
                        pr_debug "switch argument expected, not found" Red
                    } else {
                        $a_ = pr_truncate $a_ -indexAndDepth @($i,2)
                    }
                }
            }
            elseif ($i -ge ($c_ - 1)) {
                 throw [System.ArgumentOutOfRangeException] "Argument value at position $($i + 1) out of $c_ does not exist for param $param"
            }
            elseif ($null -ne $res) {
                throw [System.ArgumentException] "Duplicate argument passed: $param"
            }
        }
        pr_debug_return "@{ RES=$res ; ARGS=$a_ }"
        return @{
            RES = $res
            ARGS = $a_
        }
    }
}




$conf_path = "$userDir/projects.conf"
if(!(Test-Path $conf_path)) { New-Item $conf_path -ItemType File -Force }
$global:projectsPath = (((Get-Content $conf_path ) | Select-String "projects-root") -split "=")[1]
$global:projectsPath = Get-Path $global:projectsPath
pr_debug "Populating user PROJECTS global projects path variable ->
    global:projectsPath=$global:projectsPath"
$global:originalPath = $ENV:PATH

$global:editor = (((Get-Content "$userDir/projects.conf") | Select-String "default-editor") -split "=")[1]
pr_debug "Populated user defined preferred editor ->
    global:editor=$global:editor"




function New-Project ($name) {
    pr_debug_function "New-Project"
    if($null -ne $global:project){
        Write-Host "$($global:project.name) is currently active. Run Exit-Project (eprj) to start a new project" -ForegroundColor Yellow
        return
    }
    pr_debug "args:$args"
    $null = importhks nav
    pr_debug "pwd:$pwd"
    Set-Location $global:projectsPath
    pr_debug "pwd:$pwd"
    if($null -eq $name) { $name = Read-Host "Project Name" }
    mkdir "$global:projectsPath/$name" 
    Set-Location "./$name"
    pr_debug "pwd:$pwd"
    Set-Content -Path $(New-Item "$global:projectsPath/$name/project.cfg" -ItemType File -Force).FullName -Value "@{ Name='$name'; Path='$global:projectsPath/$name'; Description='a new project'; LastDirectory='$global:projectsPath/$name'; LastFile='$global:projectsPath/$name/project.cfg'; RunLoop='True' }"
    if($global:_debug_){Write-Host "$(Get-Content "$global:projectsPath/$name/project.cfg")"}
    Copy-Item "$global:_projects_module_location/project.ps1" "$global:projectsPath/$name"
    if(Invoke-Git -Path "$global:projectsPath/$name" -Action Initialize) { 
        if(pr_choice "Start project now?"){
            Start-Project $name
        }
    }
}

function Get-Project ($get = "all"){
    if($null -ne $global:project) {
        switch ($get) {
            all { return $global:project }
            { $_.tolower() -match "desc"} { return $global:project.description }
            Default { return Invoke-Expression $('$global:project.' + $get) }
        }
    }
    $null = importhks nav
    n_dir $(Get-ChildItem $projectsPath -depth 1 -force -ErrorAction SilentlyContinue)
}
New-Alias -name gprj -value Get-Project -Scope Global -Force

function Start-Project ($name) {
    $name = $name -replace "\\","/"
    pr_debug_function "Start-Project"
    pr_debug "args:$args"
    pr_debug "name:$name"
    Invoke-Persist -> user
    if($name -match "/") {
        pr_debug "Split project '/' requested"
        $split = $name -split "/"
        $name = $split[0]
        $subName = $split[1]
        pr_debug "name:$name | subname:$subName"
    }
    if($name -eq "last"){
        $null = importhks persist
        Start-Project $(persist project)
    }
    $found = $false
    Get-ChildItem $projectsPath | Foreach-Object {
        pr_debug "Comparing $($_.name) -> $name"
        if ($_.name -eq $name) {
            pr_debug "Project $name found. Starting ~"
            $found = $true
            $null = $found  #Keep getting powershell lint errors saying I don't use it
            if($null -ne $subName) { $name = "$name/$subName" }
            $null = importhks nav
            $null = importhks query
            $null = importhks persist
	    $prj_cfg_path = "$global:projectsPath/$name/project.cfg"
	    if(!(Test-Path $prj_cfg_path)) { return New-Project $name }
            $global:project = Invoke-Expression (Get-Content "$global:projectsPath/$name/project.cfg")
            Invoke-PushWrapper Invoke-Persist default>_project:$name; 
            if($null -eq $subName) {
                $ENV:PATH += ";$($_.fullname)"
                $startDir = if($null -ne $global:project.LastDirectory){"$($global:project.LastDirectory)"} else {"$global:projectsPath/$name"}
                if(!(Test-Path $startDir)) { $startDir = $global:project.Path }
                Invoke-Go $startDir
                If(pr_choice "Open last file [$($global:project.LastFile)]") {
                    Invoke-Expression $("$global:editor" + ' $global:project.LastFile')
                }
            } 
            else { 
                pr_debug "adding project directory to env:path"
                $ENV:PATH += ";$($_.fullname)/$subname"
                $startDir = if($null -ne $global:project.LastDirectory){"$($global:project.LastDirectory)"} else {"$global:projectsPath/$name"}
                if(!(Test-Path $startDir)) { $startDir = $global:project.Path }
                try {
                    Invoke-Go $startDir -ErrorAction Stop
                } catch {
                    Write-Host "pr_!!pr_Failed to enter project directorypr__`n`n$_`n" -ForegroundColor Red -BackgroundColor DarkGray
                    return
                }
            }
            $prjpth = $global:project.Path -replace "(?!^)\\\\","\" -replace "\\$","" -replace "\\","/"
            if((Test-Path $prjpth/project.ps1) -and ($Project.RunLoop -eq "True")) {
                pr_debug "running project loop script"
                $script:projectLoop = Start-Process powershell -WindowStyle Minimized -ArgumentList "-noprofile -file $prjpth/project.ps1" -Passthru
            }
            return
        }
    }
    if($found) { return }
    pr_debug "Project $name not found"
    $prompt =  "Project $name not found, create project in $global:projectsPath?"
    if(pr_choice $prompt) {
        mkdir "$global:projectsPath/$name"
        Set-Content -Path $(New-Item "$global:projectsPath/$name/project.cfg" -ItemType File -Force).FullName -Value "@{ Name='$name'; Path='$global:projectsPath/$name'; Description='a new project'; LastDirectory='$global:projectsPath/$name'; LastFile='$global:projectsPath/$name/project.cfg' }"
        Copy-Item "$global:_projects_module_location/project.ps1" "$global:projectsPath/$name"
        if(pr_choice "Start project $name now?") {
            Start-Project $name
        }
    } else {
        Write-Host "Project $name does not exist" -ForegroundColor Yellow
    }
}
New-Alias -name sprj -value Start-Project -Scope Global -Force
function Format-ProjectConfigurationString {
    $stringBuilder = @()
    foreach ($k in $global:project.keys){
        $val = Invoke-Expression ('$global:project.' + $k)
        $stringBuilder += " $k='$val'"
    }
    return '@{' + ($stringBuilder -join ";") + ' }'
}
function Exit-Project {
    $null = importhks nav
    if($null -eq $global:project) {
        Write-Host "
No project is currently loaded
" -ForegroundColor Yellow
        return
    }
    $Script:projectLoop | Stop-Process
    $name = $project.Name
    Set-Location $(Get-Path $global:project.Path)
    $global:project.GitExitAction = pr_default $global:project.GitExitAction "prompt"
    Set-Content -Path $(Get-Item "$global:projectsPath/$name/project.cfg" -Force).FullName -Value "$(Format-ProjectConfigurationString)"
    git diff
    switch ($global:project.GitExitAction) {
        {$_.toLower() -match "^(prompt|ask|request)$" }{ 
            if(pr_choice "Add, Commit, and Push changes to Master?") {
                Invoke-Git -Action Save
            }
        }
        { $_.toLower() -match "add" } { Invoke-Git -Action Add }
        { $_.toLower() -match "commit" } { Invoke-Git -Action Commit }
        { $_.toLower() -match "push" } { Invoke-Git -Action Push }
        { $_.toLower() -match "savedefault" } { Invoke-Git -Action Save -DefaultMessage }
        { $_.toLower() -match "save" } { Invoke-Git -Action Save }
    }
    $global:project = $null
    $ENV:PATH = $global:originalPath
}
New-Alias -name eprj -value Exit-Project -Scope Global -Force
function Invoke-Git ([string]$path,[string]$action = "status",[switch]$defaultMessage) {
    pr_debug_function Invoke-Git
    if($null -eq $path) {
	$path = pr_default $(Get-Path $global:project.Path) "$pwd"
    } else {
	$path = Get-Path $path
    }
    if(!(Test-Path $path)){
	Write-Host "!_Path does not exist: $path_____!`n`n$_`n" -ForegroundColor Red
	return
    }
    switch ($action.ToLower()) {
        {$_ -match "^e$|^exists$"} {
            $p_ = $path
            pr_debug "Testing: $p_"
            while(($p_ -ne "") -and (!(Test-Path "$p_/.git"))){
                pr_debug "Testing: $p_"
                $p_ = Split-Path $p_
            }
            return Test-Path "$p_/.git"
        }
        {$_ -match "^ne$|^notexists$"} {
            return !$(Invoke-Git -Path $path -Action Exists)
        }
        {$_ -eq "REMOTE-TEST"} {
            $p_ = $path
            pr_debug "Testing: $p_"
            while(($p_ -ne "") -and (!(Test-Path "$p_/.git"))){
                pr_debug "Testing: $p_"
                $p_ = Split-Path $p_
            }
            $exists = Test-Path "$p_/.git"   
            if(!$exists) { return $false }
            $res = $(git ls-remote)
            return $res -notmatch "No remote configured"
        }
        {$_ -match "^r$|^remote$"} {
            return !$(!$(Invoke-Git -Path $path -Action REMOTE-TEST))
        }
        {$_ -match "^nr$|^notremote$"} {
            return !$(Invoke-Git -Path $path -Action REMOTE-TEST)
        }
        {$_ -match "^i$|^init$|^initialize$"} {
            pr_debug "initializing git"
            pr_debug "pwd:$pwd"
            pr_debug "path:$path"
	    Push-Location $path
            if(Invoke-Git -Path $path -Action Exists) { 
                Write-Host "Existing git repository already exists!" -ForegroundColor Red; return $false
            }
            pr_prolix "Initializing Git"
            git init
            pr_prolix "Adding $(Get-Location) to safe directories"
            git config --global --add safe.directory ./
            pr_prolix "Adding all files in project directory"
            git add .
            pr_prolix "Commiting"
            git commit -a -m "Initial Commit $(Get-Date)"
            If(pr_choice "Push to a remote repository?") {
                git remote add origin "$(Read-Host "Input URL to remote repository")"
                git push -u origin master
            }
	    Pop-Location
            return $true
        }
        {$_ -match "^sa$|^save$"} { 
	    Push-Location $path
	    if(Invoke-Git -Path $path -Action NotExists) { 
                Write-Host "Git repository at $path doesn't exist!" -ForegroundColor Red; git status; return 
            }
            $msg = if($defaultMessage) { "$(Get-Date) - $(git status)" }  else { $(pr_default "$(Read-Host 'Input message (Default: ${current date} ${git status})')" "$(Get-Date) - $(git status)") }
            git add .
            git commit -a -m $msg
            If(Invoke-Git -Path $path -Action Remote) {
                git push
            }
	    Pop-Location
        }
        {$_ -match "^(add)$"} { 
	    Push-Location $path
            if(Invoke-Git -Path $path -Action NotExists) { 
                Write-Host "Git repository at $path doesn't exist!" -ForegroundColor Red; git status; return 
            }
            git add .
	    Pop-Location
        }
        {$_ -match "^(commit)$"} { 
	    Push-Location $path
            if(Invoke-Git -Path $path -Action NotExists) { 
                Write-Host "Git repository at $path doesn't exist!" -ForegroundColor Red; git status; return 
            }
            $msg = if($defaultMessage) { "$(Get-Date) - $(git status)" }  else { $(pr_default "$(Read-Host 'Input message (Default: ${current date} ${git status})')" "$(Get-Date) - $(git status)") }
            git commit -a -m $msg
	    Pop-Location
        }
        {$_ -match "^(push)$"} { 
	    Push-Location $path
            if(Invoke-Git -Path $path -Action NotExists) { 
                Write-Host "Git repository at $path doesn't exist!" -ForegroundColor Red; git status; return 
            }
            if(Invoke-Git -Path $path -Action NotRemote) { 
                Write-Host "Git repository at $path does not have a remote repository!" -ForegroundColor Red; git status; return 
            }
            git push
	    Pop-Location
        }
        {$_ -match "^(pull)$"} { 
	    Push-Location $path
            if(Invoke-Git -Path $path -Action NotExists) { 
                Write-Host "Git repository at $path doesn't exist!" -ForegroundColor Red; git status; return 
            }
            if(Invoke-Git -Path $path -Action NotRemote) { 
                Write-Host "Git repository at $path does not have a remote repository!" -ForegroundColor Red; git status; return 
            }
            git pull
	    Pop-Location
        }
        Default { git status }
    }
}
New-Alias -name igit -Value Invoke-Git -Scope Global -Force
function Start-Edit ($item, [switch]$last) {
    ___start Start-Edit
    ___debug "item:$item"
    ___debug "last:$last"
    $path = Get-Path $item
    ___debug "path:$path"
    if($null -ne $global:project){
        if($last) {
            return Start-Edit $global:project.LastFile
        }
        if($path -notmatch "([a-zA-Z]:/|//.+?/|^/)") { $p = "$(Get-Location)/$path" } else { $p = $path }
        if($null -eq $global:project.LastFile) {
            $global:project.add("LastFile",$p)
        } else {
            $global:project.LastFile = $p
        }
    }
    Invoke-Expression "$global:editor $path"
}
New-Alias -Name ed -Value Start-Edit -Scope Global -Force -ErrorAction SilentlyContinue
function edl { Start-Edit -last }
















