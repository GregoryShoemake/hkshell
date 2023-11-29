
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
function pr_prolix ($message, $messageColor) {
    if (!$global:prolix) { return }
    if ($null -eq $messageColor) { $messageColor = "Cyan" }
    Write-Host $message -ForegroundColor $messageColor
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




$global:projectsPath = (((Get-Content "$global:_projects_module_location\projects.cfg") | Select-String "projects-root") -split "=")[1]
pr_debug "Populating user PROJECTS global projects path variable ->
    global:projectsPath=$global:projectsPath"
$global:originalPath = $ENV:PATH

function Get-Project ($get = "all"){
    if($null -ne $global:project) {
        switch ($get) {
            all { return $global:project }
            { $_.tolower() -match "desc"} { return $global:project.description }
            Default { return Invoke-Expression $('$global:project.' + $get) }
        }
    }
    $null = import nav
    n_dir $(Get-ChildItem $projectsPath -depth 1 -force -ErrorAction SilentlyContinue)
}
New-Alias -name gprj -value Get-Project -Scope Global -Force

function Start-Project ($name, [switch]$loadlast) {
    pr_debug_function "Start-Project"
    pr_debug "args:$args"
    pr_debug "name:$name"
    pr_debug "loadLast:$loadlast"
    if($name -match "\\") {
        pr_debug "Split project '\\' requested"
        $split = $name -split "\\"
        $name = $split[0]
        $subName = $split[1]
        pr_debug "name:$name | subname:$subName"
    }
    if($name -eq "last"){
        $null = import persist
        Start-Project $(persist project) -loadlast
    }
    $found = $false
    Get-ChildItem $projectsPath | Foreach-Object {
        pr_debug "Comparing $($_.name) -> $name"
        if ($_.name -eq $name) {
            pr_debug "Project $name found. Starting ~"
            $found = $true;
            if($null -ne $subName) { $name = "$name\$subName" }
            $null = import nav
            $null = import query
            $null = import persist
            $script:projectLoop = Start-Process powershell -WindowStyle Minimized -ArgumentList "-file $global:projectsPath\$name\project.ps1" -Passthru
            $global:project = Invoke-Expression (Get-Content "$global:projectsPath\$name\project.cfg")
            pull; Start-Sleep -Milliseconds 100; push persist _>_project=.$name; 
            if(!$loadLast) { push persist rm>_last }

            if($null -eq $subName) {
                $ENV:PATH += ";$($_.fullname)"
                Go $_.fullname 
            } 
            else { 
                $ENV:PATH += ";$($_.fullname)\$subname"
                Go "$($_.fullname)\$subname" 
            }
            if ($loadLast) { vi $(persist last) }
            return
        }
    }
    if($found) { return }
    pr_debug "Project $name not found"
    $prompt =  "Project $name not found, create project in $global:projectsPath?"
    if(pr_choice $prompt) {
        mkdir "$global:projectsPath\$name"
        New-Item "$global:projectsPath\$name\project.cfg" | Set-Content "@{ Name='$name'; Path='$global:projectsPath\$name';Description='a new project' }"
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
    $global:project = $null
    $ENV:PATH = $global:originalPath
    Go "C:\Users\$ENV:USERNAME"
}
New-Alias -name eprj -value Exit-Project -Scope Global -Force
