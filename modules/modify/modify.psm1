if ($null -eq $global:_modify_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_modify_module_location = $PSScriptRoot
    }
    else {
        $global:_modify_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}

$null = importhks nav

function New-Symlink ($RealTarget, [string]$NewSymPath){
    ___start "New-Symlink"
    ___debug "realTarget:$RealTarget"
    ___debug "newSymPath:$NewSymPath"
    $RealTarget = Get-Path $RealTarget
    if($NewSymPath -eq "") {
        $name = Get-Item $RealTarget | Select-Object -ExpandProperty Name
        $NewSymPath = "$pwd\$name"
    }
    if($RealTarget -eq $NewSymPath) {
        Write-Host "The real target:$RealTarget `nexists at the path provided:$NewSymPath" -ForegroundColor Yellow
        return ___return
    }
    New-Item -ItemType SymbolicLink -Path $NewSymPath -Value $RealTarget -Force
    ___end
}

function New-Tunnel ($targetDirectory){
    ___start New-Tunnel
    if($targetDirectory -is [System.IO.DirectoryInfo]){
        $targetDirectory = $targetDirectory.FullName
    }
    ___debug "targetDirectory:$targetDirectory"
    if($targetDirectory -is [String]) {
        try {
            $current = Get-Item "$pwd" -ErrorAction Stop
            $target = Get-Item $targetDirectory -ErrorAction Stop
            $a = "$($current.FullName)\$($target.Name)"
            $b = "$($target.FullName)\$($current.Name)"
            New-Item -ItemType SymbolicLink -Path $a -Value $target.Fullname -Force -ErrorAction Stop
            New-Item -ItemType SymbolicLink -Path $b -Value $current.FullName -Force -ErrorAction Stop
        }
        catch {
            Write-Host "!_Failed to create tunnelmod_modmod_!`n`n$_`n" -ForegroundColor Red
            return ___return
        }
    } else {
        Write-Host "!_target_directory_type_: $($targetDirectory.GetType) :_is_invalidmod_modmod_!`n`n$_`n" -ForegroundColor Red
        return ___return
    }
    ___end
}

function m_copy ($path, $destination, [switch] $mirror, [switch] $passthru) {
    ___start m_copy
    try {
	$i = Get-Item $path -Force -ErrorAction Stop
	if($i.psIsContainer) {
	    if($mirror) {
		Robocopy $i.FullName $destination /MT /MIR /NFL /NDL /NJH /NJS /NC /NS > NUL 
	    } else {
		Robocopy $i.FullName $destination /MT /E /NFL /NDL /NJH /NJS /NC /NS > NUL 
	    }
	    if($passthru) { return ___return $(Get-Item $destination -Force) }
	} else {
	    Robocopy $(Split-Path $i.FullName) $destination $i.name /MT /E /NFL /NDL /NJH /NJS /NC /NS > NUL 
	    if($passthru) { return ___return $(Get-Item "$destination\$($i.name)" -Force) }
	}
    } catch {
	Write-Error $_
    }
    ___end
}

function Invoke-GetItem ($item, [switch]$all) {
    ___start Invoke-GetItem
    if($null -eq $global:clip) { $global:clip = @() }
    if($all){
        return ___return $(Get-ChildItem "$PWD" | ForEach-Object {
            Invoke-GetItem $_.FullName
        })
    }
    if($item -is [System.Array]) {
        return ___return $($item | ForEach-Object {
            Invoke-GetItem $_
        })
    }
    $global:clip += Get-Path $item
    $null = $global:clip ## To remove debug message
    ___end
}

function Invoke-Rename ($from,[string]$to) {
	___start Invoke-Rename
	if(__is $from @("System.IO.FileInfo","System.IO.DirectoryInfo")) {
		$from = $from.FullName
	}
	if($from -isnot [string]) {
	    if($from -is [int]) { $from = "$from" }
	    else {
		Write-Host "`n! Invalid type of $('$from') variable: $($from.GetType()) !`n" -ForegroundColor Red
		return ___return
	    }
	}

	[string]$from_STRING = $from

	if($from_STRING -match "^[0-9]+$") {
		$from_STRING = Get-Path $from_STRING
	}
	elseif($from_STRING -notmatch "\.[a-zA-Z0-9]+") {
		[string]$from_PARENT = Split-Path $from_STRING
		if($from_PARENT -eq "") { $from_PARENT = "$pwd" }

		$from_ITEM = Get-ChildItem $from_PARENT | Where-Object { $_.name -match $from_LEAF }

		if($from_ITEM.Count -gt 1) {
			$i = Read-Host "Multiple matches found for '$from_LEAF', input the index of the correct file from the list above`n$($from_ITEM | Foreach-Object { $i++; Write-Host "[$i] - $($_.Name)" })"
			$from_ITEM = $from_ITEM[$i - 1]
		}

		$from_STRING = $from_ITEM.FullName
	}

	[string]$from_LEAF = Split-Path -Leaf $from_STRING
 	[string]$from_NAME = __match $from_LEAF "(.+?)\..+?$" -Get -Index 1
 	[string]$from_EXT = __match $from_LEAF ".+?(\..+?)$" -Get -Index 1
	
	___debug "from_LEAF:$from_LEAF"
	___debug "from_NAME:$from_NAME"
	___debug "from_EXT:$from_EXT"


 	[string]$to_NAME = __match $to "((?!.).+?)\..+?$" -Get -Index 1
 	[string]$to_EXT = __match $to "((?!.).+?)?(\..+?)$" -Get -Index 2

	___debug "to_LEAF:$to"
	___debug "to_NAME:$to_NAME"
	___debug "to_EXT:$to_EXT"

	$final_NAME = if($to_NAME -eq "") { $from_NAME } else { $to_NAME }
	$final_EXT = if($to_EXT -eq "") { $from_EXT } else { $to_EXT }

	$final = "$final_NAME$final_EXT"

	Rename-Item -Path $from_STRING -NewName $final -Force
	___end
}
function Invoke-MoveItem ([string]$path, [int]$index = -1, [switch]$force, [switch] $all,[switch] $removeItemFromClip) {
    ___start Invoke-MoveItem
    if ($all) {
        $n = $clip.count
        for ($i = $n - 1; $i -ge 1; $i--) {
            Invoke-MoveItem -index $i -force:$force -removeItemFromClip:$removeItemFromClip -path $path
        }
        Invoke-MoveItem -index 0 -force:$force -removeItemFromClip:$removeItemFromClip -path $path
        return ___return
    }
    if($index -eq -1) { $index = $global:clip.Count - 1 }
    if($path -eq "") {
        $path = "$pwd"
    }
    $path = Get-Path $path
    m_copy $global:clip[$index] $path
    Remove-Item $global:clip[$index] -Force
    if($removeItemFromClip){
        if($global:clip.count -eq 1) {
            $global:clip = $null
            return ___return
        }
        if($global:clip.count -eq 2) {
            $global:clip = @($global:clip[1-$index])
            return ___return
        }
        $global:clip = __truncate -array $global:clip -indexAndDepth @($index, 1)
    } else {
	$global:clip[$index] = $path
    }
    ___end
}

function Invoke-CopyItem ([string]$path, [int]$index = -1, [switch]$force, [switch]$all, [switch] $removeItemFromClip) {
    ___start Invoke-CopyItem
    if ($all) {
        $n = $clip.count
        for ($i = $n - 1; $i -ge 1; $i--) {
            Invoke-CopyItem -index $i -force:$force -removeItemFromClip:$removeItemFromClip -path $path
        }
        Invoke-CopyItem -index 0 -force:$force -removeItemFromClip:$removeItemFromClip -path $path
        return ___return
    }
    if($index -eq -1) { $index = $global:clip.Count - 1 }
    if($path -eq "") {
        $path = "$pwd"
    }
    $path = Get-Path $path
    m_copy $global:clip[$index] $path
    if($removeItemFromClip){
        if($global:clip.count -eq 1) {
            $global:clip = $null
            return ___return
        }
        if($global:clip.count -eq 2) {
            $global:clip = @($global:clip[1-$index])
            return ___return
        }
        $global:clip = __truncate -array $global:clip -indexAndDepth @($index, 1)
    }
    ___end
}

function Invoke-Extract([string]$archive,[string]$destination,[string]$extractor){
    ___start Invoke-Extract
    if($extractor -eq ""){
        $7z = "D:\Program Files\7-Zip\7z.exe"
        $7za = "D:\Program Files\7-Zip\7za.exe"
        if(Test-Path $7z){
            $extractor = $7z
        } elseif (Test-Path $7za) {
            $extractor = $7za
        } else {
            Write-Host "failed - could not find valid executable 7z or 7za: $extractor" -ForegroundColor Red
            return ___return 1
        }
    }
    while(!( Test-Path $archive )){
        $archive = Read-Host "Input full or relative path to a valid target archive file, or press <Ctrl-c> to cancel"
    }
    if($extractor -match "7za") {
        $argument = "e"
    } elseif ($extractor -match "7z") {
        $argument = "x"
    } else {
        Write-Host "failed - invalid extraction executable: $extractor" -ForegroundColor Red
        return ___return 2
    }
     
    $destination = if($destination -ne "") { " -o'$destination'" } else { "" }
    Start-Process -NoNewWindow -Wait -FilePath $extractor -ArgumentList "$argument $('"')$archive$('"')$destination"
    ___end
}

function Invoke-Compress ( $files, [string]$destination, [string]$level = "Fastest"){
    ___start Invoke-Compress
    if($files -isnot [System.Array]){
        $files =  @($files)
    }
    if($destination -eq "") {
        $destination = "$pwd"
    }
    ___debug "files:$files"
    ___debug "destination:$destination"
    ___debug "level/speed:$level"
    $compress = @{
        Path = $files
        CompressionLevel = $level
        DestinationPath = $destination
    }
    Compress-Archive $compress -Force
    ___end
}
