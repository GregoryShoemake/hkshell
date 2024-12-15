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
function __int_equal {
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




function New-Project ([string]$name) {
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
        if(__choice "Start project now?"){
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

    if($name -eq ""){
        $projects = Get-ChildItem $projectsPath
        $name = $projects[$(__choose_item $projects)].Name
    }

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
            $global:project.LastedUpdated = "$(Get-Date)"
            Invoke-PushWrapper Invoke-Persist default>_project:$name; 
            if($null -eq $subName) {
                $ENV:PATH += ";$($_.fullname)"
                $startDir = if($null -ne $global:project.LastDirectory){"$($global:project.LastDirectory)"} else {"$global:projectsPath/$name"}
                if(!(Test-Path $startDir)) { $startDir = $global:project.Path }
                Invoke-Go $startDir
                If(__choice "Open last file [$($global:project.LastFile)]") {
                    Invoke-Expression $("$global:editor" + ' $global:project.LastFile')
                }
            } 
            else { 
                pr_debug "adding project directory to env:path"
                $ENV:PATH += ";$($_.fullname)/$subname"
                $startDir = if($null -ne $global:project.LastDirectory){"$($global:project.LastDirectory)"} else {"$global:projectsPath/$name"}
                ___debug "initial:startDir:$startDir"
                if(!(Test-Path $startDir)) { $startDir = $global:project.Path }
                ___debug "startDir:$startDir"
                try {
                    Invoke-Go $startDir -ErrorAction Stop
                } catch {
                    Write-Host "!!Failed to enter project directory`n`n$_`n" -ForegroundColor Red -BackgroundColor DarkGray
                    return
                }
            }
            $prjpth = $global:project.Path -replace "(?!^)\\\\","\" -replace "\\$","" -replace "\\","/"
            if((Test-Path $prjpth/project.ps1) -and ($Project.RunLoop -eq "True")) {
                pr_debug "running project loop script"
                $script:projectLoop = Start-Process powershell -WindowStyle Minimized -ArgumentList "-noprofile -file $prjpth/project.ps1" -Passthru
            }
            Import-Shortcuts -confPath $(Get-Path "$($global:project.Path)/shortcuts.conf")
            return
        }
    }
    if($found) { return }
    pr_debug "Project $name not found"
    $prompt =  "Project $name not found, create project in $global:projectsPath?"
    if(__choice $prompt) {
        mkdir "$global:projectsPath/$name"
        Set-Content -Path $(New-Item "$global:projectsPath/$name/project.cfg" -ItemType File -Force).FullName -Value "@{ Name='$name'; Path='$global:projectsPath/$name'; Description='a new project'; LastDirectory='$global:projectsPath/$name'; LastFile='$global:projectsPath/$name/project.cfg' }"
        Copy-Item "$global:_projects_module_location/project.ps1" "$global:projectsPath/$name"
        if(__choice "Start project $name now?") {
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
    Use-Scope Instance Invoke-Persist [boolean] EndProject = True
    $name = $project.Name
    Set-Location $(Get-Path $global:project.Path)
    $global:project.GitExitAction = __default $global:project.GitExitAction "prompt"
    $global:project.LastedUpdated = "$(Get-Date)"
    Set-Content -Path $(Get-Item "$global:projectsPath/$name/project.cfg" -Force).FullName -Value "$(Format-ProjectConfigurationString)"
    git diff
    switch ($global:project.GitExitAction) {
        {$_.toLower() -match "^(prompt|ask|request)$" }{ 
            if(__choice "Add, Commit, and Push changes to Master?") {
                Invoke-Git -Action Save
            }
        }
        { $_.toLower() -match "^add$" } { Invoke-Git -Action Add }
        { $_.toLower() -match "^commit$" } { Invoke-Git -Action Commit }
        { $_.toLower() -match "^push$" } { Invoke-Git -Action Push }
        { $_.toLower() -match "^savedefault$" } { Invoke-Git -Action Save -DefaultMessage }
        { $_.toLower() -match "^save$" } { Invoke-Git -Action Save }
    }
    $global:project = $null
    $ENV:PATH = $global:originalPath
    Import-Shortcuts
}
New-Alias -name eprj -value Exit-Project -Scope Global -Force

function Invoke-Git ([string]$path,[string]$action = "status",[switch]$defaultMessage) {
    ___start Invoke-Git
    ___debug "path:$path"
    ___debug "action:$action"
    ___debug "defaultMessage:$defaultMessage"
    if($path -eq "") {
	$path = __default $(Get-Path $global:project.Path) "$pwd"
    } else {
	$path = Get-Path $path
    }
    if(!(Test-Path $path)){
	Write-Host "!_Path does not exist: $path_____!`n`n$_`n" -ForegroundColor Red
	return ___return
    }
    switch ($action.ToLower()) {
        {$_ -match "^exists$"} {
            $p_ = $path
            pr_debug "Testing: $p_"
            while(($p_ -ne "") -and (!(Test-Path "$p_/.git"))){
                pr_debug "Testing: $p_"
                $p_ = Split-Path $p_
            }
            return ___return $(Test-Path "$p_/.git")
        }
        {$_ -match "^notexists$"} {
            return ___return $(!$(Invoke-Git -Path $path -Action Exists))
        }
        {$_ -eq "REMOTE-TEST"} {
            $p_ = $path
            pr_debug "Testing: $p_"
            while(($p_ -ne "") -and (!(Test-Path "$p_/.git"))){
                pr_debug "Testing: $p_"
                $p_ = Split-Path $p_
            }
            $exists = Test-Path "$p_/.git"   
            if(!$exists) { return ___return $false }
            $res = $(git ls-remote)
            return ___return $($res -notmatch "No remote configured")
        }
        {$_ -match "^remote$"} {
            return ___return $(!$(!$(Invoke-Git -Path $path -Action REMOTE-TEST)))
        }
        {$_ -match "^notremote$"} {
            return ___return $(!$(Invoke-Git -Path $path -Action REMOTE-TEST))
        }
        {$_ -match "^initialize$"} {
            pr_debug "initializing git"
            pr_debug "pwd:$pwd"
            pr_debug "path:$path"
	    Push-Location $path
            if(Invoke-Git -Path $path -Action Exists) { 
                Write-Host "Existing git repository already exists!" -ForegroundColor Red; return ___return $false
            }
            pr_debug "Initializing Git"
            git init
            pr_debug "Adding $(Get-Location) to safe directories"
            git config --global --add safe.directory ./
            pr_debug "Adding all files in project directory"
            git add .
            pr_debug "Commiting"
            git commit -a -m "Initial Commit $(Get-Date)"
            If(__choice "Push to a remote repository?") {
                git remote add origin "$(Read-Host "Input URL to remote repository")"
                git push -u origin master
            }
	    Pop-Location
            return ___return $true
        }
        {$_ -match "^save$"} { 
	    Push-Location $path
	    if(Invoke-Git -Path $path -Action NotExists) { 
                Write-Host "Git repository at $path doesn't exist!" -ForegroundColor Red; git status; return ___return 
            }
            $msg = if($defaultMessage) { "$(Get-Date) - $(git status)" }  else { $(__default "$(Read-Host 'Input message (Default: ${current date} ${git status})')" "$(Get-Date) - $(git status)") }
	    if($defaultMessage) {
                $null = git rm -rf --cached .
		$null = git add .
		$null = git commit -a -m $msg
	    } else {
                git rm -rf --cached .
		git add .
		git commit -a -m $msg
	    }
            If(Invoke-Git -Path $path -Action Remote) {
		if($defaultMessage) {
		    $null = git push
		} else {
		    git push
		}
            }
	    Pop-Location
        }
        {$_ -match "^(add)$"} { 
	    Push-Location $path
            if(Invoke-Git -Path $path -Action NotExists) { 
                Write-Host "Git repository at $path doesn't exist!" -ForegroundColor Red; git status; return ___return
            }
            git add .
	    Pop-Location
        }
        {$_ -match "^(commit)$"} { 
	    Push-Location $path
            if(Invoke-Git -Path $path -Action NotExists) { 
                Write-Host "Git repository at $path doesn't exist!" -ForegroundColor Red; git status; return ___return
            }
            $msg = if($defaultMessage) { "$(Get-Date) - $(git status)" }  else { $(__default "$(Read-Host 'Input message (Default: ${current date} ${git status})')" "$(Get-Date) - $(git status)") }
            git commit -a -m $msg
	    Pop-Location
        }
        {$_ -match "^(push)$"} { 
	    Push-Location $path
            if(Invoke-Git -Path $path -Action NotExists) { 
                Write-Host "Git repository at $path doesn't exist!" -ForegroundColor Red; git status; return ___return
            }
            if(Invoke-Git -Path $path -Action NotRemote) { 
                Write-Host "Git repository at $path does not have a remote repository!" -ForegroundColor Red; git status; return ___return
            }
            git push
	    Pop-Location
        }
        {$_ -match "^(pull)$"} { 
	    Push-Location $path
            if(Invoke-Git -Path $path -Action NotExists) { 
                Write-Host "Git repository at $path doesn't exist!" -ForegroundColor Red; git status; return ___return
            }
            if(Invoke-Git -Path $path -Action NotRemote) { 
                Write-Host "Git repository at $path does not have a remote repository!" -ForegroundColor Red; git status; return ___return
            }
            git pull
	    Pop-Location
        }
        Default { git status }
    }
    ___end
}
New-Alias -name igit -Value Invoke-Git -Scope Global -Force

function Start-Edit ($item,[switch]$find, [switch]$quick, [switch]$last, [switch]$leftSplit, [switch]$rightSplit) {
    ___start Start-Edit
    ___debug "item:$item"
    ___debug "last:$last"
    ___debug "initial:leftSplit:$leftSplit"
    ___debug "initial:rightSplit:$rightSplit"

    if($leftSplit) {
        $pop = $true
        Push-Location $global:PWDLeftSplit
    } elseif ($rightSplit) {
        $pop = $true
        Push-Location $global:PWDRightSplit
    }

    if($find) {
	$path = Get-ChildItem "$pwd" -Recurse | Where-Object { !$_.PsIsContainer -and $_.name -match $item }
        if($path.Count -gt 1) {
            if($quick) {
                $path = $path[0]
            } else {
                $path = $path[$(__choose_item $path -property fullname -substringLeft)]            
            }
        }
        $path = Get-Path $path
    } else {
        $path = Get-Path $item
    }

    ___debug "path(after find):$path"

    if($null -ne $global:project){

        if($last) {
	    ___end
            return Start-Edit $global:project.LastFile
        }

        if($path -notmatch "([a-zA-Z]:/|//.+?/|^/)") { $p = "$(Get-Location)/$path" } else { $p = $path }

        if($global:project.keys -notcontains "LastFile") {
            $global:project.add("LastFile",$p)
        } else {
            $global:project.LastFile = $p
        }

    } else {

	if($last) {
	    ___end
	    return Start-Edit $global:_last_edit_
	}

        if($path -notmatch "([a-zA-Z]:/|//.+?/|^/)") { $p = "$(Get-Location)/$path" } else { $p = $path }

	$global:_last_edit_ = $p
    }

    if($pop) {
        Pop-Location
    }

    Invoke-Expression "$global:editor $path"
    ___end
}
New-Alias -Name ed -Value Start-Edit -Scope Global -Force -ErrorAction SilentlyContinue
function edl { Start-Edit -last }
















