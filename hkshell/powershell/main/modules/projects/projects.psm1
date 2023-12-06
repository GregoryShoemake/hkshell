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
    while((Read-Host $prompt) -notmatch "[Yy]([EeSs])?|[Nn]([Oo])?") {
            $prompt = ""
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
$global:projectsPath = (((Get-Content "$global:_projects_module_location\projects.cfg") | Select-String "projects-root") -split "=")[1]
$global:projectsPath = Get-Path $global:projectsPath
pr_debug "Populating user PROJECTS global projects path variable ->
    global:projectsPath=$global:projectsPath"
$global:originalPath = $ENV:PATH

function New-Project ($name) {
    pr_debug_function "New-Project"
    pr_debug "args:$args"
    $null = importhks nav
    pr_debug "pwd:$pwd"
    Set-Location $global:projectsPath
    pr_debug "pwd:$pwd"
    if($null -eq $name) { $name = Read-Host "Project Name" }
    mkdir "$global:projectsPath\$name" 
    Set-Location ".\$name"
    pr_debug "pwd:$pwd"
    Set-Content -Path $(New-Item "$global:projectsPath\$name\project.cfg" -ItemType File -Force).FullName -Value "@{ Name='$name'; Path='$global:projectsPath\$name'; Description='a new project'; LastDirectory='$global:projectsPath\$name'; LastFile='$global:projectsPath\$name\project.cfg' }"
    if($global:_debug_){Write-Host "$(Get-Content "$global:projectsPath\$name\project.cfg")"}
    Copy-Item "$global:_projects_module_location\project.ps1" "$global:projectsPath\$name"
    if(Invoke-Git -Path "$global:projectsPath\$name" -Action Initialize) {
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
    pr_debug_function "Start-Project"
    pr_debug "args:$args"
    pr_debug "name:$name"
    persist -> user
    if($name -match "\\") {
        pr_debug "Split project '\\' requested"
        $split = $name -split "\\"
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
            $found = $true;
            if($null -ne $subName) { $name = "$name\$subName" }
            $null = importhks nav
            $null = importhks query
            $null = importhks persist
            $script:projectLoop = Start-Process powershell -WindowStyle Minimized -ArgumentList "-file $global:projectsPath\$name\project.ps1" -Passthru
            $global:project = Invoke-Expression (Get-Content "$global:projectsPath\$name\project.cfg")
            pull; Start-Sleep -Milliseconds 100; push persist _>_project=.$name; 
            if($null -eq $subName) {
                $ENV:PATH += ";$($_.fullname)"
                $startDir = if($null -ne $global:project.LastDirectory){"$($global:project.LastDirectory)"} else {"$global:projectsPath\$name"}
                Invoke-Go $startDir
                If(pr_choice "Open last file?: $($global:project.LastFile)") {
                    nvim.exe -n $global:project.LastFile
                }
            } 
            else { 
                $ENV:PATH += ";$($_.fullname)\$subname"
                $startDir = if($null -ne $global:project.LastDirectory){"$($global:project.LastDirectory)"} else {"$global:projectsPath\$name"}
                Invoke-Go $startDir
            }
            return
        }
    }
    if($found) { return }
    pr_debug "Project $name not found"
    $prompt =  "Project $name not found, create project in $global:projectsPath?"
    if(pr_choice $prompt) {
        mkdir "$global:projectsPath\$name"
        Set-Content -Path $(New-Item "$global:projectsPath\$name\project.cfg" -ItemType File -Force).FullName -Value "@{ Name='$name'; Path='$global:projectsPath\$name'; Description='a new project'; LastDirectory='$global:projectsPath\$name'; LastFile='$global:projectsPath\$name\project.cfg' }"
        Copy-Item "$global:_projects_module_location\project.ps1" "$global:projectsPath\$name"
        if(pr_choice "Start project $name now?") {
            Start-Project $name
        }
    } else {
        Write-Host "Project $name does not exist" -ForegroundColor Yellow
    }
}
New-Alias -name sprj -value Start-Project -Scope Global -Force

function Exit-Project {
    if($null -eq $global:project) {
        Write-Host "
No project is currently loaded
" -ForegroundColor Yellow
        return
    }
    $Script:projectLoop | Stop-Process
    $name = $project.Name
    Set-Content -Path $(Get-Item "$global:projectsPath\$name\project.cfg" -Force).FullName -Value "@{ Name='$($global:project.Name)'; Path='$($global:project.Path)'; Description='$($global:project.Description)'; LastDirectory='$($global:project.LastDirectory)'; LastFile='$($global:project.LastFile)' }"
    $global:project = $null
    $ENV:PATH = $global:originalPath
    if(pr_choice "Commit changes?") {
        Invoke-Git -Action Save
    }
    Invoke-Go "C:\Users\$ENV:USERNAME"
}
New-Alias -name eprj -value Exit-Project -Scope Global -Force
function Invoke-Git ([string]$path,[string]$action = "status") {
    pr_debug_function Invoke-Git
    $path = pr_default $path "$pwd"    
    switch ($action.ToLower()) {
        {$_ -match "^e$|^exists$"} {
            $p_ = $path
            pr_debug "Testing: $p_"
            while(($p_ -ne "") -and (!(Test-Path "$p_\.git"))){
                pr_debug "Testing: $p_"
                $p_ = Split-Path $p_
            }
            return Test-Path "$p_\.git"
        }
        {$_ -match "^ne$|^notexists$"} {
            return !$(Invoke-Git -Path $path -Action $action)
        }
        {$_ -eq "REMOTE-TEST"} {
            $exists = $(Invoke-Git -Path $path -Action Exists)   
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
            $bak = "$pwd"
            Set-Location $path
            if(Invoke-Git -Action Exists) { 
                Write-Host "Existing git repository already exists!" -ForegroundColor Red; return $false
            }
            pr_prolix "Initializing Git"
            git init
            pr_prolix "Adding $(Get-Location) to safe directories"
            git config --global --add safe.directory .\
            pr_prolix "Adding all files in project directory"
            git add .
            pr_prolix "Commiting"
            git commit -a -m "Initial Commit $(Get-Date)"
            If(pr_choice "Push to a remote repository?") {
                git remote add origin "$(Read-Host "Input URL to remote repository")"
                git push -u origin master
            }
            Set-Location $bak
            return $true
        }
        {$_ -match "^sa$|^save$"} { if(Invoke-Git -Action NotExists) { 
                pr_debug "Git repository at $path doesn't exist!" -ForegroundColor Red; git-status; return 
            }
            $msg = pr_default "$(Read-Host 'Input message (Default: ${current date} ${git status})')" "$(Get-Date) - $(git status)"

            git commit -a -m $msg
            If(Invoke-Git -Action Remote) {
                git push
            }
        }
        Default { git status }
    }
}
New-Alias -name igit -Value Invoke-Git -Scope Global -Force


















