if ($null -eq $global:_backup_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_backup_module_location = $PSScriptRoot
    }
    else {
        $global:_backup_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}

$userDir = "~\.hkshell\backup"
if(!(Test-Path $userDir)) { mkdir $userDir }

function bk_debug ($message, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "DarkYellow" }
    Write-Host "    \\$message" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function bk_debug_function ($function, $messageColor, $meta) {
    if (!$global:_debug_) { return }
    if ($null -eq $messageColor) { $messageColor = "Yellow" }
    Write-Host ">_ $function" -ForegroundColor $messageColor
    if ($null -ne $meta) {
        write-Host -NoNewline " $meta " -ForegroundColor Yellow
    }
}
function bk_debug_return {
    if (!$global:_debug_) { return }
    Write-Host "#return# $($args -join " ")" -ForegroundColor Black -BackgroundColor DarkGray
    return
}

function bk_prolix ($message, $messageColor) {
    if (!$global:prolix) { return }
    if ($null -eq $messageColor) { $messageColor = "Cyan" }
    Write-Host $message -ForegroundColor $messageColor
}
function bk_choice ($prompt) {
    while((Read-Host $prompt) -notmatch "[Yy]([EeSs])?|[Nn]([Oo])?") {
            $prompt = ""
            Write-Host "Please input a [Y]es or [N]o answer" -ForegroundColor yellow
        }
    if($MATCHES[0] -match "[Yy]"){ return $true }
    return $false
}
function bk_int_equal {
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
function bk_truncate {
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
    bk_debug_function "bk_truncate"
    bk_debug "array:
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
        bk_debug_return empty array
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
        if (($i -gt $fromStart) -and !(bk_int_equal $i $middle ) -and ($i -lt $fromEnd)) {
            $res += $array[$i]
        }
    }
    bk_debug_return $(Out-String -inputObject $res)
    return $res
}
function bk_search_args ($a_, $param, [switch]$switch, [switch]$all, [switch]$untilSwitch) {
    bk_debug_function "bk_search_args"    
    $c_ = $a_.Count
    bk_debug "args:$a_ | len:$c_"
    bk_debug "param:$param"
    bk_debug "switch:$switch"
    if($switch) { 
        for ($i = 0; $i -lt $c_; $i++) {
            $a = $a_[$i]
            bk_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if($null -eq $res) { 
                $res = $true 
                $a_ = bk_truncate $a_ -indexAndDepth @($i,1)
            }
            else {
                throw [System.ArgumentException] "Duplicate argument passed: $param"
            }
        }
        $res = $res -and $true
        bk_debug_return
        return @{
            RES = $res
            ARGS = $a_
        }
    } else {
        for ($i = 0; $i -lt $a_.length; $i++) {
            $a = $a_[$i]
            bk_debug "a[$i]:$a"
            if ($a -ne $param) { continue }
            if(($null -eq $res) -and ($i -lt ($c_ - 1))) {
                if($all) {
                    $ibak = $i
                    $res = @()
                    $remove = 1
                    for ($i = $i + 1; $i -lt ($c_); $i++) {
                        if($untilSwitch -and ($a_[$i] -match "^-")) {
                            bk_debug "[-untilSwitch] next switch found"
                            break
                        }
                        $res += $a_[$i]
                        $remove++
                    }
                    $res = $res -join " "
                    $a_ = bk_truncate $a_ -indexAndDepth @($ibak, $remove)
                } else {
                    $res = $a_[$i + 1]
                    if($res -match "^-") { 
                        $res = $null 
                        bk_debug "switch argument expected, not found" Red
                    } else {
                        $a_ = bk_truncate $a_ -indexAndDepth @($i,2)
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
        bk_debug_return
        return @{
            RES = $res
            ARGS = $a_
        }
    }
}
function bk_default ($variable, $value) {
    bk_debug_function "e_default"
    if ($null -eq $variable) { 
        bk_debug_return "variable is null, returning: $value"
        return $value 
    }
    switch ($variable.GetType().name) {
        String { 
            if($variable -eq "") {
                bk_debug_return "$value"
                return $value
            } else {
                bk_debug_return "variable is empty, returning: $value"
                return $variable
            }
        }
    }
}
function bk_match {
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
    bk_debug_function "__match"
    if ($null -eq $string) {
        bk_debug_return string is null
        if ($getMatch) { return $null }
        return $false
    }
    if ($null -eq $regex) {
        bk_debug_return regex is null
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
        bk_debug_return
        return ($logic -eq "AND") -or ($logic -eq "NOT")
    }
    $found = $string -match $regex
    if ($found) {
        if ($getMatch) {
            bk_debug_return
            return $Matches[0]
        }
        bk_debug_return
        return $logic -ne "NOT"
    }
    bk_debug_return
    if ($logic -eq "NOT") { return $true }
    if ($getMatch) { return $null }
    return $false
}

$null = importhks persist
$null = importhks nav

$global:backupLogsPath = "$userDir\logs"
if(!(Test-Path $global:backupLogsPath)) { $null = mkdir $global:backupLogsPath }

function Invoke-EnsureBackupScope {
    if(!(Get-Scope backup -exists)) {
        $backupPath = "C:\users\$ENV:USERNAME\.powershell\scopes\backup"
        if(!(Test-Path $backupPath)) { mkdir $backupPath } 
        Invoke-Persist addScope>_backup::$backupPath\persist.cfg::yes
    }
}

function Format-BackupConfiguration {
    bk_debug_function "Format-BackupConfiguration"
    bk_debug "args:$args"
    $hash = bk_search_args $args "-goto"  
    $goto = $hash.RES
    $hash = bk_search_args $hash.ARGS "-backupLocation" -All -UntilSwitch
    $aLocation = $hash.RES
    bk_debug "goto:$goto"
    bk_debug "backupLocation|alocation:$aLocation"
    bk_debug "bareMetalLocation|bLocation:$bLocation"

    Invoke-EnsureBackupScope

    Invoke-Persist -> backup
    
    $goto = bk_default $goto "standardbackup"
    if($goto -eq "standardbackup") {
        if(($null -ne $aLocation) -or (Invoke-Persist backupDirectory!?) -or (bk_choice "Modify backup directory: $(Invoke-Persist backupDirectory)?")) {
            $location = if($null -ne $aLocation) { $aLocation } else { $(Read-Host "Input the desired directory to direct your backup targets to") } 
            $lbak = $location
            $location = Get-Path $location
            bk_debug "$goto : $location"
            while(!(Test-Path $location)) {
                if($location -notmatch "^(\\\\.+?\\|[a-zA-Z]:\\).+$") {
                    bk_debug "location isn't in the expected format" red
                    $location = Read-Host "Input a valid directory syntax"
                    $lbak = $location
                    $location = Get-Path $location
                }
                elseif(($null -ne $aLocation) -or (bk_choice "$location does not exist, attempt to create?")){
                    bk_debug "location does not exist" red
                    mkdir $location
                }
                else {
                    bk_debug "location does not exist and was not created" red
                    $location = Read-Host "$location does not exist, input an existing directory"
                    $lbak = $location
                    $location = Get-Path $location
                }
            }
            Invoke-Persist backupDirectory=.$lbak
        }
        $goto = $null
    }

    $goto = bk_default $goto "baremetalbackup"
    if($goto -eq "baremetalbackup") {
        if((persist nullOrEmpty>_bareMetalBackup) -and ($null -eq $aLocation)) {  
            if(bk_choice "Authorize full image recoveries?") {
                Invoke-Persist _>_[boolean]bareMetalBackup=true
                bk_prolix "Input the drive letter or volume name of the desired backup volume. NOTE: Do not make this on the same DISK that contains the C: drive" Cyan
                Write-Host "$(Get-AllVolumes -Expand Volumes | Out-String -width 100)"
                $volLet = Read-Host " "
                while(($volLet -notmatch "^[a-zA-Z]:\\$") -or !(Test-Path $volLet)) {
                    $volLet = Read-Host "Drive letter must match the format [A-Z]:\ and be accessible"
                }
                Invoke-Persist [string]bareMetalBackupVolume=.$volLet
            } else {
                Invoke-Persist _>_[boolean]bareMetalBackup=false
                Invoke-Persist remove>_bareMetalBackupVolume
            }
        } elseif($null -eq $aLocation) { 
            if(bk_choice "Modify full image backup settings?") {
                Invoke-PushWrapper Invoke-Persist remove>_bareMetalBackup
                return Format-BackupConfiguration -goto baremetalbackup
            }
        } elseif($null -ne $bLocation) {
                Invoke-Persist _>_[boolean]bareMetalBackup=true
                if(($bLocation -notmatch "^[a-zA-Z]:\\$") -or !(Test-Path $bLocation)) { 
                    Write-Host "Invalid bare metal backup location: $bLocation" -ForegroundColor Red
                    Invoke-Persist _>_[boolean]bareMetalBackup=false
                    Invoke-Persist remove>_bareMetalBackupVolume
                } else {
                    Invoke-Persist bareMetalBackupVolume=.$bLocation
                }
        }
        $goto = $null
    }
    Invoke-PushWrapper
}
function Start-CheckDiskIntegrity ($path, $log) {
    $locBak = Get-Location
    $pathRoot = Get-Root $path
    Set-Location $pathRoot
    $loginfo = "$(Get-Date -Format "dMMMy@H:m:s:fff") <::> validating disk integrity of $pathRoot"
    bk_debug $loginfo
    $chkdskres = chkdsk.exe
    $success = $chkdskres -contains "Windows has scanned the file system and found no problems."
    Set-Location $locBak

    if($log -is [System.IO.FileInfo]) { $log = $log.FullName }
    if($null -ne $log) {
        Add-Content -Path $log -Value "$loginfo`n$chkdskres`n"
    }
    if(!$success) {
        if($null -ne $log) {
            Write-Host "chkdsk.exe validation of $backupDirectoryRoot failed, read logs at $logPath" -ForegroundColor Red -BackgroundColor DarkGray
        } else {
            Write-Host "chkdsk.exe validation of $backupDirectoryRoot failed: $chkdskres" -ForegroundColor Red -BackgroundColor DarkGray
        }
    }
    return $success
}
function Start-Backup {
    bk_debug_function "Start-Backup"
    bk_debug "args:$args"
    $hash = bk_search_args $args "-directories" -Switch
    $dirs = $hash.RES
    $hash = bk_search_args $hash.ARGS "-bareMetal" -Switch
    $bare = $hash.RES
    $hash = bk_search_args $hash.ARGS "-exclude" -All -UntilSwitch
    $exclude = $hash.RES
    $hash = bk_search_args $hash.ARGS "-validate" -Switch
    $validate = $hash.RES
    $hash = bk_search_args $hash.ARGS "-log" -All -UntilSwitch
    $logPath = $hash.RES
    bk_debug "ARGUMENTS\\" Blue
    bk_debug "backupDirectories:$dirs"
    bk_debug "backupBareMetal:$bare"
    bk_debug "exclude:$exclude"
    bk_debug "validate:$validate"
    bk_debug "log:$logPath"
    bk_debug "ARGUMENTS\\" Blue

    Invoke-EnsureBackupScope

    $scopeBak = ($scope -split "::")[0]

    Invoke-Persist -> backup

    if($null -ne $logPath) {
        if(!(Test-Path $logPath)) {
            $null = New-Item -Path $logPath -ItemType File
        }
    }

    if($dirs) {
        if(Invoke-Persist backupDirectory!?){
            Write-Host "Backup has not been configured... Please run Format-BackupConfiguration to configure" -ForegroundColor Red
            return
        }
        $backupDirectory = Get-PersistentVariable backupDirectory
        $backupDirectory = Get-Path $backupDirectory
        try {
            $null = Get-Item $backupDirectory -ErrorAction Stop
        }
        catch {
            Write-Host "Could not retrieve backupDirectory ($backupDirectory) : $_" -ForegroundColor Red
            return
        }
        if($validate) {
            if(!(Start-CheckDiskIntegrity -Path $backupDirectory -Log $log)) {
                return
            }
        }
        $items = Get-Content "$userDir\backup.items.conf"
        bk_debug "ITEMS\\`n$items`n    \\ITEMS\\" Blue
        foreach ($i in $items) {
            $i = Get-Path $i
            if(Test-Path $i) {
                try {
                    $item = Get-item $i -Force -ErrorAction Stop
                    if($item.PsIsContainer) {
                        $loginfo = "$(Get-Date -Format "dMMMy@H:m:s:fff") <::> Backing up directory: $i  =>  $backupDirectory"
                        bk_debug $loginfo
                        $source = $item.fullname
                        $destination = "$backupDirectory\$($item.name)"
                        if($null -ne $logPath) {
                            Add-Content -Path $logPath -Value $loginfo
                        }
                        $robocopyLogPath = "$global:backupLogsPath\robocopy-$($item.name)-$(Get-Date -Format dMMMy).log"
                        if(!(Test-Path $robocopyLogPath )) { New-Item $robocopyLogPath -ItemType File }
                        $null = Robocopy.exe $source $destination /mir /mt /log+:$robocopyLogPath } 
                    else {
                        $loginfo = "$(Get-Date -Format "dMMMy@H:m:s:fff") <::> Backing up file: $i  =>  $backupDirectory"
                        bk_debug $loginfo
                        if($null -ne $logPath) {
                            Add-Content -Path $logPath -Value $loginfo
                        }
                        Copy-Item $item.fullname $backupDirectory -ErrorAction Stop
                    }
                } catch {
                    Write-Host "Failed to backup $i -- $_" -ForegroundColor Red -BackgroundColor DarkGray
                }  
            }
        }
    }

    if($bare) {
        bk_debug "Running bare metal backup"
        if(Invoke-Persist nullOrEmpty>_bareMetalBackup){
            Write-Host "Backup has not been configured... Please run Format-BackupConfiguration to configure" -ForegroundColor Red
            return
        }
        if(Invoke-Persist bareMetalBackup?!){
            Write-Host "Backup has been declined... Please run Format-BackupConfiguration to configure" -ForegroundColor Red
            return
        }
        $backupVol = Use-Scope Backup Invoke-Persist bareMetalBackupVolume
        $backupVol = Get-Path $backupVol
        bk_debug "backup destination: $backupVol"
        try {
            $null = Get-Item $backupVol -ErrorAction Stop
        }
        catch {
            Write-Host "Could not retrieve backup Volume Destination ($backupVol) : $_" -ForegroundColor Red
            return
        }
        [string]$letter = ([System.Environment]::SystemDirectory).substring(0,1)
        $disk = Get-Disk -Partition (Get-Partition | Where-Object {$_.driveletter -eq $letter})
        $allVols = Get-Partition -Disk $disk | Foreach-Object { $v_ = Get-Volume -Partition $_; if ($null -eq $v_) { return }; if ($v_.FileSystemType -ne "NTFS") { return }; return $_ } | Select-Object -ExpandProperty GUID | Foreach-Object { return "\\?\Volume$_\" }
        if($allVols -isnot [System.Array]){ $allVols = @( $allVols ) }
        if($validate) {
            bk_debug "Validating destination and system volume"
            if(!(Start-CheckDiskIntegrity -Path $backupVol -Log $log)) {
                bk_debug "Destination validation failed"
                return
            }
            bk_debug "Destination validated"
            if(!(Start-CheckDiskIntegrity -Path "$($letter):\" -Log $log)) {
                bk_debug "System disk validation failed"
                return
            }
            bk_debug "System volume validated"
        }

        $allVols = $allVols -join ","

        bk_debug "backup sources: $allVols"

        bk_debug "Starting backup"

        wbadmin.exe start backup -backupTarget:$backupVol -include:$allVols -noverify -quiet
        #
    }

    Invoke-Persist -> $scopeBak
}












