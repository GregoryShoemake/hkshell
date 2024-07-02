
if ($null -eq $global:_nav_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_nav_module_location = $PSScriptRoot
    }
    else {
        $global:_nav_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}

<#
.PREFERENCES
#>


<#
.PREFERENCES
#>

$userDir = "~/.hkshell/nav"
if(!(Test-Path $userDir)) { mkdir $userDir }



function Import-Shortcuts {
    $conf_path = "$userDir/nav.shortcuts.conf" 
    if(!(Test-Path $conf_path)) { New-Item $conf_path -ItemType File -Force }
    $global:shortcuts = Get-Content "$userDir/nav.shortcuts.conf" 
    $null = $global:shortcuts
}
Import-Shortcuts

function Add-Shortcut ([string]$shortcut) {
    if($shortcut -eq ""){
        $shortcut = Read-Host "Input new shortcut"
    } elseif ($shortcut -eq ".") {
	$shortcut = "$pwd"
    }
    $test = Get-Path $shortcut

    if(!(Test-Path $test)){
        Write-Host "!_Shortcut Path Is Invalid: $shortcut :_____!`n`n$_`n" -ForegroundColor Red
        return
    }
    Add-Content -Path "$userDir/nav.shortcuts.conf" -Value $shortcut
    Import-Shortcuts
    Get-Shortcuts
}

function Get-Shortcuts ([switch]$Tree) {
    foreach ($s in $global:shortcuts) {
        if(($null -eq $s) -or ($s -eq "")) { continue }
        if($null -eq $items) { $items = @(Get-Item $s -Force -ErrorAction SilentlyContinue) }
        else { $items += Get-item $s -Force -ErrorAction SilentlyContinue }
    }
    Format-ChildItem $items -Tree:$Tree
}

$global:hidden_or_system = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System
function n_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "DarkYellow" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function n_debug_function ($function, $functionColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $functionColor) { $functionColor = "Yellow" }
    Write-Host ">_ $function" -ForegroundColor $functionColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}

function Test-IsSymLink ($InputObject) {
    ___start Test-IsSymLink
    if(__is $InputObject @("System.IO.FileInfo","System.IO.DirectoryInfo")) {
	$input_PATH = $InputObject.FullName
    } elseif($InputObject -isnot [string]) {
	Write-Host "!_Expected type System.IO or string, Found: $($InputObject.GetType())_____!`n`n$_`n" -ForegroundColor Red
	return ___return
    } else {
	$input_PATH = $InputObject
    }
    
    try {
    	$input_ITEM = Get-Item $input_PATH -Force -ErrorAction Stop
    }
    catch {
	Write-Host "!_Failed to get item: $_ _____!`n`n$_`n" -ForegroundColor Red
	return ___return
    }

    return ___return $($input_ITEM.FullName -ne $input_ITEM.ResolvedTarget -and "$($input_ITEM.ResolvedTarget)" -ne "")

}

function Test-Access($Path)
{
    try
    {
        $null = Get-ChildItem $path -ErrorAction Stop
        return $true
    }
    catch
    {
        return $false
    }
}
function Get-PathDepth ($path) {
    $split = $path -split "/"
    for ($i = 0; $i -lt $split.length; $i++) {
        if (__nullemptystr $split[$i]) {
            $split = __truncate $split -indexAndDepth @($i, 1)
        }
    }
    return $split.length
}
function __is ($obj, $class) {
    if ($null -eq $obj) { return $null -eq $class }
    if ($null -eq $class) { return $false }
    if ($class -is [System.Array]) {
        foreach ($c in $class) {
            if ($obj -is $c) { return $true }
        }
        return $false
    }
    return $obj -is [type](g_replace $class @("\[", "]"))
}

function Get-ParentDirectory {
    [CmdletBinding()]
    param (
        [Parameter()]
        $path,
        [Parameter()]
        $until,
        [Parameter()]
        [int]$count = 0
    )
    if (__nullemptystr $path) {
        $path = Get-Location
    }
    if (__is $path  @([System.IO.FileInfo], [System.IO.DirectoryInfo])) {
        $path = $path.fullname
    }
    if ($count -gt 0){
        $path = Split-Path $path
        $count--
        return Get-ParentDirectory $path $count
    }
    return split-path $path
}
New-Alias -Name ".." -Value Get-ParentDirectory -Scope Global -Force
New-Alias -Name n_pad -Value __pad -Scope Global -Force -ErrorAction SilentlyContinue

Function Get-RegistryKeyPropertiesAndValues
{
  <#
    Get-RegistryKeyPropertiesAndValues -path 'HKCU:\Volatile Environment'
    Http://www.ScriptingGuys.com/blog
  #>

 Param(

    [Parameter(Mandatory=$true)]
    [string]$path)

    Push-Location
    Set-Location -Path $path
    Get-Item . | Select-Object -ExpandProperty property | ForEach-Object {
        $value = (Get-ItemProperty -Path .).$_
        $hash = @{Value="$value"; Name="$_"}
        return $hash
    }
    Pop-Location
} #end function Get-RegistryKeyPropertiesAndValues

function n_write_virtual_dirs ([int]$columns = 1, $nameLength) {
    try {
	$last = Get-Item $global:history[$global:history.Count -1] -Force -ErrorAction Stop
	write-host -nonewline "│" -ForegroundColor DarkBlue
	$index = n_pad "[.<]" 7 " "
	write-host -nonewline $index
	write-host -nonewline "│" -ForegroundColor DarkGray
        if($columns -lt 4) {
            $type = n_pad "[last]" 9 " "
            write-host -nonewline $type -ForegroundColor Cyan
            write-host -nonewline "│" -ForegroundColor DarkGray
            if($columns -lt 2) {
                $lastWrite = n_pad "$($last.lastwritetime)" 25 " " 
                write-host -nonewline $lastWrite
                write-host -nonewline "│" -ForegroundColor DarkGray
            }
        }
	$name = n_pad $last.FullName $nameLength " "
	write-host -NoNewline:$($columns -gt 1) $name -ForegroundColor $("Gray")
    }
    catch {
    	<#Do this if a terminating exception happens#>
    }

    try {
	$current = Get-Item "$pwd" -Force -ErrorAction Stop     
	$parent = Get-Item $current.Parent.FullName -Force -ErrorAction Stop
        write-host -nonewline "│" -ForegroundColor DarkBlue 
        $index = n_pad "[..]" 7 " "
        write-host -nonewline $index
        write-host -nonewline "│" -ForegroundColor DarkGray
        if($columns -lt 4){
            $type = n_pad "[parent]" 9 " "
            write-host -nonewline $type -ForegroundColor Cyan
            write-host -nonewline "│" -ForegroundColor DarkGray
            if($columns -lt 2){
                $lastWrite = n_pad "$($parent.LastWriteTime)" 25 " " 
                write-host -nonewline $lastWrite
                write-host -nonewline "│" -ForegroundColor DarkGray
            }
        }
        $name = n_pad $parent.Name $nameLength " "
        write-host -NoNewline:$($columns -gt 2) $name -ForegroundColor $("Gray")
    }
    catch {
	<#Do this if a terminating exception happens#>
    }

    try {
	write-host -nonewline "│" -ForegroundColor DarkBlue 
	$index = n_pad "[.]" 7 " "
	write-host -nonewline $index
	write-host -nonewline "│" -ForegroundColor DarkGray
        if($columns -lt 4) {
            $type = n_pad "[current]" 9 " "
            write-host -nonewline $type -ForegroundColor Cyan
            write-host -nonewline "│" -ForegroundColor DarkGray
            if ($columns -lt 2) {
                $lastWrite = n_pad "$($current.lastwritetime)" 25 " " 
                write-host -nonewline $lastWrite
                write-host -nonewline "│" -ForegroundColor DarkGray
                }
        }
        $name = n_pad $current.Name $nameLength " "
	write-host $name -ForegroundColor $("Gray")
    }
    catch {
    	<#Do this if a terminating exception happens#>
    }

}

function n_convert_index ($index) {
    ___start n_convert_index
    ___debug "index:$index"
    $index_NEW = ""
    if("$index" -match "[0-9]+") {
	foreach ($number in [char[]]"$index") {
	    switch($number) {
		1 { $index_NEW += "a" }
		2 { $index_NEW += "b" }
		3 { $index_NEW += "c" }
		4 { $index_NEW += "d" }
		5 { $index_NEW += "e" }
		6 { $index_NEW += "f" }
		7 { $index_NEW += "g" }
		8 { $index_NEW += "h" }
		9 { $index_NEW += "i" }
		0 { $index_NEW += "z" }
	    }
	}
    } else {
	foreach ($letter in [char[]]"$index") {
	    switch ($letter) {
	    	a { $index_NEW += "1" }
	    	b { $index_NEW += "2" }
	    	c { $index_NEW += "3" }
	    	d { $index_NEW += "4" }
	    	e { $index_NEW += "5" }
	    	f { $index_NEW += "6" }
	    	g { $index_NEW += "7" }
	    	h { $index_NEW += "8" }
	    	i { $index_NEW += "9" }
	    	z { $index_NEW += "0" }
	    }
	}
    }
    return ___return $index_NEW
}

function Format-ChildItem ($items, [switch]$cache, [switch]$clearCache, [switch]$tree, [int]$columns = -1) {
    if($cache) {
        $items = $global:QueryResult 
        if($clearCache){
            $global:QueryResult = $null
        }
    }
    $i = 0
    if($args -notcontains "-force") { $args += " -force" }
    if($items.Count -gt 0) {
    
        if($columns -eq -1) {
            $columns = [System.Math]::Clamp($items.Count / 35, 1, 4)
        }
        if($columns -gt 4) {
            Write-Host "Column count must be between 1 and 4, defaulting to 1" -ForegroundColor Yellow
            $columns = 1
        }

        ___debug "columns:$columns"

	$Script:lastParent = $null
        $items | Foreach-Object {

	    if($_ -is [string] -and (Test-Path $_)) {
		try {
		    $_ = Get-Item -Force -ErrorAction Stop
		}
		catch {
		    return
		}
	    }

            $isReg = "$($_.PSProvider.Name)" -eq "Registry"
            $isDir = $_.psiscontainer
            $isSym = Test-IsSymLink $_
            if($isSym) { $resolved = $_.ResolvedTarget }
            $parent = if( $isReg ){ $_ | Select-Object -ExpandProperty Name | Split-Path | Split-Path -leaf }elseif($isDir) { $_.parent.fullname } else { $_.directory.fullname }
            if($script:lastParent -ne $parent) {
                Write-Host "
                $parent
    " -ForegroundColor DarkYellow
                $script:lastParent = $parent
                
                switch ($columns) {
                    2 { 
                        $nameLength = 52
write-host "│ INDEX │  TYPE   │  NAME                                              │ INDEX │  TYPE   │  NAME" -ForegroundColor DarkGray
                        write-host "├───────┼─────────┼─────────────────────────────────────────────────── ├───────┼─────────┼──────" -ForegroundColor DarkGray
                    }
                    3 { 
                        $nameLength = 39
write-host "│ INDEX │  TYPE   │  NAME                                 │ INDEX │  TYPE   │  NAME                                 │ INDEX │  TYPE   │  NAME" -ForegroundColor DarkGray #34
                        write-host "├───────┼─────────┼────────────────────────────────────── ├───────┼─────────┼────────────────────────────────────── ├───────┼─────────┼──────" -ForegroundColor DarkGray
                    }
                    4 { 
                        $nameLength = 34
write-host "│ INDEX │  NAME                            │ INDEX │  NAME                            │ INDEX │  NAME                            │ INDEX │  NAME" -ForegroundColor DarkGray #29
                        write-host "├───────┼───────────────────────────────── ├───────┼───────────────────────────────── ├───────┼───────────────────────────────── ├───────┼──────" -ForegroundColor DarkGray
                    }
                    default {
                        $nameLength = 80
write-host "│ INDEX │  TYPE   │     LAST WRITE TIME     │  NAME" -ForegroundColor DarkGray
                        write-host "├───────┼─────────┼─────────────────────────┼──────" -ForegroundColor DarkGray
                    }
                }
            }


            if(!$WrittenVirtuals){
                n_write_virtual_dirs $columns $nameLength
                    $WrittenVirtuals = $true
            }


            $index = n_pad "[$i]" 7 " "
            $type = n_pad $(if( $isReg ){ "[reg]" }elseif($isSym) { if($isDir) {"[tun]"} else {"[link]"} }elseif($isDir){"[dir]"}else{"[file]"}) 9 " "
            $lastWrite = n_pad "$($_.lastwritetime)" 25 " " 
            $name = $_.name
            if($isSym) {
                $name += " -> $resolved"
            } elseif($isReg){
                $name = $name | Split-Path -Leaf
            }
            $name = n_pad $name $nameLength " "
            if($isDir) {
                $canAccess = Test-Access $_.fullname
            } else {
                try { [IO.File]::OpenWrite($_.fullname).close();$canAccess = $true }
                catch { $canAccess = $false }
            }
            $sysOrHid = $_.Attributes -band $global:hidden_or_system
            write-host -nonewline "│" -ForegroundColor DarkBlue
            write-host -nonewline $index
            write-host -nonewline "│" -ForegroundColor DarkGray
            if($columns -lt 4) {
                write-host -nonewline $type -ForegroundColor $(if( $isReg ){ "Red" }elseif($isSym){ if($isDir) {"Magenta"} else {"DarkMagenta"} }elseif($isDir){"Cyan"}else{"DarkCyan"})
                write-host -nonewline "│" -ForegroundColor DarkGray
                if($columns -lt 2) {
                    write-host -nonewline $lastWrite
                    write-host -nonewline "│" -ForegroundColor DarkGray
                }
            }
            write-host -nonewline:$(($i+1)%$columns -ne 0) $name -ForegroundColor $(if($canAccess -and !$sysOrHid) { "Gray" } elseif ($canAccess -and $sysOrHidden) { "DarkGray" } elseif (!$sysOrHidden -and !$canAccess) { "Red" } else { "DarkRed" })
            $i++

            if($isDir -and $tree -and $columns -eq 1) {
                $children = Get-ChildItem $_.FullName -Force -ErrorAction SilentlyContinue
                    $children_COUNT = $children.Count
                    $j = 0
                    foreach ($child in $children){
                        if($child.name -eq "...break"){ break }
                        if($j -eq $children_COUNT - 1) {
                            write-host -nonewline $(n_pad "[$(n_convert_index $j)]└── " 47 " " -Left) -ForegroundColor DarkGray
                        } else {
                            write-host -nonewline $(n_pad "[$(n_convert_index $j)]├── " 47 " " -Left) -ForegroundColor DarkGray
                        }

                        $child_SYSORHID = $_.Attributes -band $global:hidden_or_system
                            if($child.PSIsContainer) {
                                $child_CANACCESS = Test-Access $child.fullname
                            } else {
                                try { [IO.File]::OpenWrite($child.fullname).close();$child_CANACCESS = $true }
                                catch { $child_CANACCESS = $false }
                            }
                        $c_ISDIR = $child.PSIsContainer
                            $c_ISSYM = Test-IsSymLink $child
                            write-host "$(if($c_ISSYM){"l"} elseif($c_ISDIR) {"d"} else {"f"}) .. $($child.Name) $(if($c_ISSYM){"-> $($child.ResolvedTarget)"} else {''} )" -ForegroundColor $(if($child_CANACCESS -and !$child_SYSORHID) { "Gray" } elseif ($child_CANACCESS -and $child_SYSORHID) { "DarkGray" } elseif (!$child_SYSORHID -and !$child_CANACCESS) { "Red" } else { "DarkRed" })
                            $j++
                    }
            }
        }  
    }
    try {
        $t = Get-Item "$pwd" -Force -ErrorAction Stop
        if("$($t.PSProvider)" -eq "Microsoft.PowerShell.Core\Registry") {
            $subkeys = Get-RegistryKeyPropertiesAndValues -Path "$pwd"
        }
    } catch {
        Write-Error $_
        return
    }
    if($null -ne $subkeys) {
        [bool]$b_index = $subkeys.name.Count -gt 1
        for ($i = 0; $i -lt $subKeys.name.Count; $i++) {
            $index = n_pad " n/a" 7 " "
            $type = n_pad "[subkey]" 8 " "
            $lastWrite = n_pad " n/a" 25 " " 
            $name = $(if($b_index) {$subkeys.name[$i]} else {$subkeys.name})
            $name += $(if($b_index) { " -> $($subkeys.value[$i])"} else { " -> $($subkeys.value)"})
            $name = n_pad $name 80 " "
            write-host -nonewline "|" -ForegroundColor DarkGray
            write-host -nonewline $index
            write-host -nonewline "|" -ForegroundColor DarkGray
            write-host -nonewline $type -ForegroundColor DarkRed
            write-host -nonewline "|" -ForegroundColor DarkGray
            write-host -nonewline $lastWrite
            write-host -nonewline "|" -ForegroundColor DarkGray
            write-host $name -ForegroundColor DarkGray
        }
    }
    
}
New-Alias -Name n_dir -Value Format-ChildItem -Scope Global -Force
New-Alias -Name fchi -Value Format-ChildItem -Scope Global -Force
function Show-Directories {
    [CmdletBinding()]
    param (
        [Parameter()]
        $path,
        [Parameter()]
        [switch]
        $D,
        [Parameter()]
        [switch]
        $Tree,
        [Parameter()]
        [int]
        $dep = 0

    )
    ___start Show-Directories
    ___debug "D:$D"
    ___debug "Tree:$Tree"
    ___debug "dep:$dep"
    if ($null -eq $path) {
        $path = "$(Get-Location)"
    }
    ___debug "path:$path as $($path.GetType())"
    if($path -is [System.Array] -or $path.Count -gt 1) {
	foreach ($p in $path) {
	    if($null -eq $p) { continue }
	    Show-Directories $p -D:$D -Tree:$Tree
	}
	return ___return
    }
    $path = Get-Path $path

    $res = Get-ChildItem -Force -Path $path -depth $dep -ErrorAction SilentlyContinue | Where-Object { ($_.psiscontainer -and $D) -or !$D }

    if($null -eq $res) { $res = Get-ChildItem -Force -Path $path -Depth $dep -ErrorAction SilentlyContinue }

    if($null -eq $res) {
        Write-Host "
            $path   is Empty!" -ForegroundColor Red
    } else {
        Format-ChildItem $res -Tree:$Tree
    }

    write-host "
    "
    ___end
}
New-Alias -Name 'sdir' -Value 'Show-Directories' -Scope Global -Force

function n_match {
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
        $logic = "OR",
        [Parameter()]
        [int]$index = 0
    )
    if ($null -eq $string) {
        if ($getMatch) { return $null }
        return $false
    }
    if ($null -eq $regex) {
        if ($getMatch) { return $null }
        return $false
    }
    if (($string -is [System.Array])) {
        $string = $string -join "`n"
    }
    if ($regex -is [System.Array]) {
        foreach ($r in $regex) {
            $f = g_match $string $r
            if (($logic -eq "OR") -and $f) { return $true }
            if (($logic -eq "AND") -and !$f) { return $false }
        }
        return ($logic -eq "AND")
    }
    $found = $string -match $regex
    if ($found) {
        if ($getMatch) {
            return $Matches[$index]
        }
        return $true
    }
    if ($getMatch) { return $null }
    return $false
}

function n_log {
    [CmdletBinding()]
    param (
        [Parameter()]
        $variable,
        [Parameter()]
        [int]
        $columns = 1,
        [Parameter()]
        $ForegroundColor = "Gray"
    )
    if ($variable -is [System.Array]) {
        for ($i = 1; $i -le $variable.length; $i++) {
            [int]$width = 130 / $columns
            $item = "$($variable[$i - 1])"
            while ($item.Length -lt $width) {
                $item += " "
            }
            $item = $item.Substring(0, $width)
            if ($i % $columns -eq 0) {
                Write-Host $item -ForegroundColor $ForegroundColor
            }
            else {
                Write-Host -NoNewline $item -ForegroundColor $ForegroundColor
            }
        }
    }
}

function Invoke-Go {
    [CmdletBinding()]
    param (
        [Parameter()]
        $in,
        [Parameter()]
        [switch]
        $C,
        [Parameter()]
        [switch]
        $A,
        [Parameter()]
        [switch]
        $tree,
        [Parameter()]
        [switch]
        $passthru,
        [Parameter()]
        $Until
    )
    ___start "Invoke-Go"
    ___debug "in:$in"
    ___debug "C:$C"
    ___debug "A:$A"
    ___debug "tree:$tree"
    ___debug "passthru:$passthru"
    ___debug "until:$until"

    if($null -ne (Get-Module persist)) {
	if(Invoke-Persist clearHostOnInvokeGo?) {
	    Clear-Host
	}
    }
    
    if ($null -ne $Until) {

        $res = Get-ChildItem -Force -Recurse $(Get-Location) | Where-Object { $_.psiscontainer } | Where-Object { $_.name -eq $Until }
        if ($null -eq $res) {
            $res = Get-ChildItem -Force -Recurse $(Get-Location) | Where-Object { $_.psiscontainer } | Where-Object { $_.name -match $Until }
        }
        if ($null -eq $res) {
            Write-Host "Directory matching $Until not found" -ForegroundColor Yellow; return
        }
        if ($res.Count -gt 1) {
            Write-Host "Multiple matches for $Until" -ForegroundColor Yellow
            Format-ChildItem $res
            $index = Read-Host "Input index of desired directory: "
            $res = $res[$index]
        }
	___debug " -> $($res.FullName)"
	Invoke-Go $res.FullName -A:$A -C:$C -Tree:$Tree
	if($passthru) {
	    return ___return $($res.FullName)
	}
        return ___return 

    }

    if($null -eq $in){$in = "$(Get-Location)"}

    if($in -match "\.<") {
	$num = $in.replace(".","").split("<").Count - 1
	$in = $global:history[($global:history.Count - $num)]
	$global:history = __truncate $global:history -FromEnd ($num)
	$backTracking = $true
    } elseif($in -match "\.\^") {
	$num = $in.replace(".","").split("^").Count - 1
	$in = "$pwd"
	for($i = 0; $i -lt $num; $i++){
	    $in = Split-Path $in
	}
	$backTracking = $false
    } else {
	$backTracking = $false
    }

    $D = !$A
    if ($global:_debug_) { write-host " GO => $in`n  \ Create Missing Path? $C`n  \ Show All Item Types? $A" -ForegroundColor DarkGray }
    if ($in -eq "..") {
        $in = Split-Path "$PWD"
    }
    elseif ($null -ne $global:QueryResult) {
        n_debug "Parsing Query Results"
        if($in -match "([0-9]+)?([a-zA-Z]+)?"){
            if($in -match "^f$"){$in = 0} 
	    elseif($in -match "[a-zA-Z]+"){
		if($in -notmatch "[0-9]+") {
		    Write-Host "!_Invalid target format!    Expected [0-9]+[a-zA-Z]+   Found: $in _____!`n`n$_`n" -ForegroundColor Red
		    return ___return
		}
		$in_ = n_convert_index $(__match $in "[a-zA-Z]+" -Get)
		$in = __match $in "[0-9]+" -Get
	    }
            $in = $([int]$in) 
            if($global:QueryResult.length -le $in) { 
                Write-Host "Out of index for QueryResults: $in out of $(Query.Length)" -ForegroundColor Red
                return ___return
            }
            $in = $global:QueryResult[$in]
	    if($null -ne $in_){
		$dest = $(Get-ChildItem $in.FullName -Force -ErrorAction SilentlyContinue)[[int]$in_].FullName
	    } else {
		$dest = $in.FullName
	    }
	    ___debug " -> $dest"
	    Invoke-Go $dest -C:$C -A:$A -Tree:$Tree
	    if($passthru) {
		return ___return $dest
	    }
	    return ___return
        }
        foreach ($s in $global:QueryResult) {
            $replaced = $s
            if ($replaced.name -match $in) {
                if ($null -eq $arr) { $arr = @($s) }
                else { $arr += $s }
                n_debug "   \ true"
            } else {
                n_debug "   \ false"
            }
        }
        if ($null -ne $arr) {
            if($arr.length -eq 1) { $in = $arr[0].fullname }
            elseif ($arr.length -gt 1) {
                Write-Host `nMultiple matches found:
                $i = 0
                foreach ($p in $arr) {
                    Write-Host "[$i] $($p.fullname)"
                    $i++
                }
                $i = [int](Read-Host "Pick index of desired path")
                $in = $arr[$i].$fullname
            }
        }
    }
    elseif (Test-Path (Get-Path $in)) {
	$in = Get-Path $in
	    if($null -ne $global:project){
		if($null -eq $global:project.LastDirectory) {
		    $global:project.add("LastDirectory",$in)
		} else {
		    $global:project.LastDirectory = $in
		}
	    }
	if(!$backTracking) {
	    $global:last = "$pwd"
		$null = $global:last

		if($null -eq $global:history) {
		    [string[]]$global:history = @("$pwd")
		} else {
		    $global:history += "$pwd"
		}
	}	

	Set-Location $in
	    $first_item = Get-ChildItem "$pwd" -Force -ErrorAction SilentlyContinue | Select-Object -First 1
	    if($first_item.PSProvider.Name -eq "Registry") {
		$global:first = $first_item.Name
	    } else {
		$global:first = $first_item.FullName
	    }
	$null = $global:first
	    Show-Directories -D:$D -Tree:$Tree
    }
    elseif ($C) {
	try {
	    New-Item $in -ItemType Directory -Force -ErrorAction Stop
		Set-Location $in -ErrorAction Stop
		Show-Directories -D:$D -Tree:$Tree
		if($null -ne $global:project){
		    if($null -eq $global:project.LastDirectory) {
			$global:project.add("LastDirectory",$in)
		    } else {
			$global:project.LastDirectory = $in
		    }
		}
	} catch {
	    Write-Error $_
	}
    }
    elseif (!(test-path $in)) {

        if ($global:_debug_) {
            write-host "`n~~~~~~~~~~`nShortcuts:`n" -ForegroundColor DarkCyan 
            n_log -columns 3 $global:shortcuts -ForegroundColor DarkGray 
            write-host "`n~~~~~~~~~~    `n" -ForegroundColor DarkCyan 
        }

	foreach ($s in $global:shortcuts) {
	    n_debug "Checking shortcut: $s ~? $in"
		$in_regex = __stringify_regex $in
		if ($s -match $in_regex) {

		    if ($null -eq $arr) { $arr = @($s) }
		    else { $arr += $s }
		    n_debug "   \ true"
		} else {
		    n_debug "   \ false"
		}
	}

	if ($null -ne $arr) {
	    if($arr.length -eq 1) { $i = 0 }
	    elseif ($arr.length -gt 1) {
		Write-Host "`nMultiple matches found:"
                $i = __choose_item $arr $null 
	    }
	    ___debug " -> $($arr[$i])"
	    $null = Invoke-Go $arr[$i] -C:$C -A:$A -Tree:$Tree -PassThru
	    if($passthru) {
		return ___return $arr[$i]
	    }
	    return ___return
	}

        if($in -match "([0-9]+)?([a-zA-Z]+)?"){
            if($in -match "^f$"){$in = 0} 
	    elseif($in -match "[a-zA-Z]+"){
		if($in -notmatch "[0-9]+") {
		    Write-Host "!_Invalid target format!    Expected [0-9]+[a-zA-Z]+   Found: $in _____!`n`n$_`n" -ForegroundColor Red
		    return ___return
		}
		$in_ = n_convert_index $(__match $in "[a-zA-Z]+" -Get)
		$in = __match $in "[0-9]+" -Get
	    }

            n_debug "Parsing index: $in"
                
	    $children = Get-ChildItem $(Get-Location) -Force | Where-Object { $_.PSIsContainer }
	    $in = $([int]$in) 
	    $cin = $children[$in]
	    $path = if("$($cin.PsProvider)" -eq "Microsoft.PowerShell.Core\Registry") { $cin.name } else { $cin.FullName }
	    $path = Get-Path $path
	    if($null -ne $in_){
		$dest = $(Get-ChildItem $path -Force -ErrorAction SilentlyContinue)[[int]$in_].FullName 
	    } else {
		$dest = $path
	    }
	    ___debug " -> $dest"
	    Invoke-Go $dest -C:$C -A:$A -Tree:$Tree
	    if($passthru) {
		return ___return $passthru
	    }
	    return ___return
        }


    }

    else {
        Write-Host Path: $in :does not exist -ForegroundColor Red
    }
    ___end
}

function Get-PathPipe {
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        $pipe
    )

    return Get-Path $pipe
}

function ConvertTo-LixuxPathDelimiter ($path) {
    return $($path -replace "\\","/")
}

function Get-Path {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$clip,
        [Parameter()]
        [switch]$ignoreSymlink,
        [Parameter(ValueFromRemainingArguments)]
        $a_
    )

    $resolve = !$ignoreSymlink
    ___start Get-Path
    ___debug "clip:$clip"
    ___debug "resolve:$resolve"
    ___debug "a_:$a_"
    
    if($a_ -is [System.Array]) { return $a_ | ForEach-Object { return Get-Path $_ } }
    $l_ = "$(Get-Location)"
    switch ($a_) { 
	{ Test-Path $_ } { 
	     ___debug "Relative path passed is valid: $_"
	     try {
		 $item = Get-Item $_ -Force -ErrorAction Stop
	     } catch {
		 Write-Host "Path exists, but cannot read object" -ForegroundColor Red
		     return ___return
	     }
	     $isSym = Test-IsSymLink $item
	     $isReg = $item.PSProvider.Name -eq "Registry"
	    ___debug "isSym:$isSym"
	    ___debug "isReg:$isReg"
	     if($isSym -and $resolve){ $res = $item.ResolvedTarget } elseif($isReg) { $res = $item.Name } else { $res = $item.FullName }
	     if($null -eq $res) { $res = $item.name }
	     $res = $res -replace "HKEY_LOCAL_MACHINE", "HKLM:" -replace "HKEY_CURRENT_USER", "HKCU:"
	     if ($clip) { Set-Clipboard $(ConvertTo-LixuxPathDelimiter $res) } else { return ___return $(ConvertTo-LixuxPathDelimiter $res) }
	 }
	{ $null -ne $global:QueryResult } {
	    ___debug "Parsing Query Results"
	    $in = $_
	    if($in -match "^([0-9]+|f)$"){
		___debug "Returning index of query results: i = $in"
		if($in -match "^f$"){$in = 0} 
		$in = $([int]$in) 
		if($global:QueryResult.length -le $in) { 
		    Write-Host "Out of index for QueryResults: $in out of $(Query.Length)" -ForegroundColor Red
		    return ___return
		}
		$in = $global:QueryResult[$in]
		$global:QueryResult = $null
		return ___return $(ConvertTo-LixuxPathDelimiter $in.FullName)
	    }
	    foreach ($s in $global:QueryResult) {
		___debug "Iterating through query results: current = $s"
		$replaced = $s
		if ($replaced.name -match $in) {
		    if ($null -eq $arr) { $arr = @($s) }
		    else { $arr += $s }
		}
	    }
	    if ($null -ne $arr) {
		if($arr.length -eq 1) { $in = $arr[0].fullname }
		elseif ($arr.length -gt 1) {
		    Write-Host "`nMultiple matches found:"
		    $i = 0
		    foreach ($p in $arr) {
			Write-Host "[$i] $($p.fullname)"
			$i++
		    }
		    $i = [int](Read-Host "Pick index of desired path")
		    $in = $arr[$i].$fullname
		}
	    }
	    if($null -ne $in) {
		$global:QueryResult = $null
		return ___return $(ConvertTo-LixuxPathDelimiter $in)
	    }
	}

        { ($_ -is [System.IO.FileInfo]) -or ($_ -is [System.IO.DirectoryInfo]) } {
	    ___debug "System.IO object passed, returning literal path"
            $isSym = Test-IsSymLink $_
            $isReg = $_.PSProvider.Name -eq "Registry"
            if($isSym -and $resolve){
                if ($clip) { Set-Clipboard $(ConvertTo-LixuxPathDelimiter $_.ResolvedTarget) } else { return ___return $(ConvertTo-LixuxPathDelimiter $_.ResolvedTarget) } 
            } elseif($isReg) {
                if ($clip) { Set-Clipboard $(ConvertTo-LixuxPathDelimiter $_.Name) } else { return ___return $(ConvertTo-LixuxPathDelimiter $_.Name) } 
	    } else {
                if ($clip) { Set-Clipboard $(ConvertTo-LixuxPathDelimiter $_.FullName) } else { return ___return $(ConvertTo-LixuxPathDelimiter $_.FullName) } 
            }
        }
        { $_ -match "^m:.+$" } { 

            $regex = $($_ -split ":")[1]
	    ___debug "Checking current directory for name matching regex: $regex"
            Get-ChildItem $l_ -Force | Where-Object { $_.name -match $regex } | Foreach-Object {
                    if($null -eq $res){ $res = @($_.fullname) }
                    else { $res += ";$($_.fullname)" }
                }
             if ($clip) { Set-Clipboard $(ConvertTo-LixuxPathDelimiter $res) } else { return ___return $(ConvertTo-LixuxPathDelimiter $res) }
        }
        { $_ -match "^([0-9]+|f)$" } { 
	    ___debug "Checking current directory for index: $_"
	    if($_ -eq "f") { $_ = "0" }
            $res = $(Get-ChildItem $l_ -Force)[$([int]$_)]
            $isSym = Test-IsSymLink $res
	    ___debug "isSym:$isSym"
	    ___debug "PSProvider:$($res.PSProvider)"
            $isReg = $res.PSProvider.Name -eq "Registry"
	    ___debug "IsReg:$isReg"
            if($isSym -and $resolve){
                if ($clip) { Set-Clipboard $(ConvertTo-LixuxPathDelimiter $res.ResolvedTarget) } else { return ___return $(ConvertTo-LixuxPathDelimiter $res.ResolvedTarget) } 
            } elseif($isReg){
                if ($clip) { Set-Clipboard $(ConvertTo-LixuxPathDelimiter $res.Name) } else { return ___return $(ConvertTo-LixuxPathDelimiter $res.Name) } 
            } else {
                if ($clip) { Set-Clipboard $(ConvertTo-LixuxPathDelimiter $res.FullName) } else { return ___return $(ConvertTo-LixuxPathDelimiter $res.FullName) } 
            }
        }
        { $_ -match "vol::(.+)::(.+)"} {
	    ___debug "Parsing for volume: $_"
            $vol = n_match $_ "vol::(.+)::(.+)" -getMatch -index 1
            $path = n_match $_ "vol::(.+)::(.+)" -getMatch -index 2
            $res =  "$(Get-Volume | Where-Object {$_.FileSystemLabel -eq $vol } | Select-Object -ExpandProperty DriveLetter ):$path"
            $res = $res -replace "(?!^)\\\\","\" -replace "\\","/"
            n_debug "res:$res"
            if ($clip) { Set-Clipboard $res } else { return ___return $res }
        }
        { !(Test-Path $_) } {
	    ___debug "Relative path passed may be invalid: $_"
            $res =  $_ -replace "(?!^)\\\\","\" -replace "\\","/"
            $res = $res -replace "HKEY_LOCAL_MACHINE", "HKLM:" -replace "HKEY_CURRENT_USER", "HKCU:"
            if ($clip) { Set-Clipboard $(ConvertTo-LixuxPathDelimiter $res) } else { return ___return $(ConvertTo-LixuxPathDelimiter $res) }
        }
        Default { if($clip) { Set-Clipboard $(ConvertTo-LixuxPathDelimiter $l_) } else { return ___return $(ConvertTo-LixuxPathDelimiter $l_) } }
    }
    ___end
}
New-Alias -Name gtp -Value Get-Path -Scope Global -Force
function Get-Root ($inputObject) {
    if($null -eq $inputObject) { $inputObject = "$(Get-Location)" } 
    if($inputObject -is [string]) {
        $inputObject = $inputObject -replace ".+::\\\\","\\"
        $pathLast = $inputObject
        $path = Split-Path $pathLast
        while(($path -ne "") -and ($path -notmatch "\\\\.+?(?!\\)")) {
            $pathLast = $path
            $path = Split-Path $pathLast
        }
        return $pathLast
    }
}
