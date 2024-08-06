if ($null -eq $global:_backup_module_location ) {
    if ($PSVersionTable.PSVersion.Major -ge 3) {
        $global:_backup_module_location = $PSScriptRoot
    }
    else {
        $global:_backup_module_location = Split-Path -Parent $MyInvocation.MyCommand.Definition
    }
}

$userDir = "~/.hkshell/backup"
if(!(Test-Path $userDir)) { mkdir $userDir }


$null = importhks persist
$null = importhks nav

$global:backupLogsPath = "$userDir/logs"
if(!(Test-Path $global:backupLogsPath)) { $null = mkdir $global:backupLogsPath }

function Invoke-EnsureBackupScope {
    ___start Invoke-EnsureBackupScope
    if(!(Get-Scope backup -exists)) {
	if($IsWindows) {
	    $backupPath = "C:\users\$ENV:USERNAME\.powershell\scopes\backup"
	} elseif ($IsLinux) {
	    $backupPath = "/home/$(whoami)/.powershell/scopes/backup"
	}
        if(!(Test-Path $backupPath)) { mkdir $backupPath } 
        Invoke-Persist addScope>_backup::$backupPath\persist.cfg::yes
    }  
    ___end
}

function Format-BackupConfiguration {
    ___start Format-BackupConfiguration
    ___debug "args:$args"
    $hash = __search_args $args "-goto"  
    $goto = $hash.RES
    $hash = __search_args $hash.ARGS "-backupLocation" -All -UntilSwitch
    $aLocation = $hash.RES
    ___debug "goto:$goto"
    ___debug "backupLocation|alocation:$aLocation"
    ___debug "bareMetalLocation|bLocation:$bLocation"

    Invoke-EnsureBackupScope

    Invoke-PushScope backup
    
    $goto = __default $goto "standardbackup"
    if($goto -eq "standardbackup") {
        if(($null -ne $aLocation) -or (Invoke-Persist backupDirectory!?) -or (__choice "Modify backup directory: $(Invoke-Persist backupDirectory)?")) {
            $location = if($null -ne $aLocation) { $aLocation } else { $(Read-Host "Input the desired directory to direct your backup targets to") } 
            $lbak = $location
            $location = Get-Path $location
            ___debug "$goto : $location"
            while(!(Test-Path $location) -and $($location -notmatch "(.+?)@(.+?):")) {
                if($location -notmatch "^(\\\\.+?\\|[a-zA-Z]:\\|^/).+$") {
                    ___debug "location isn't in the expected format" red
                    $location = Read-Host "Input a valid directory syntax"
                    $lbak = $location
                    $location = Get-Path $location
                }
                elseif(($null -ne $aLocation) -or (__choice "$location does not exist, attempt to create?")){
                    ___debug "location does not exist" red
                    mkdir $location
                }
                else {
                    ___debug "location does not exist and was not created" red
                    $location = Read-Host "$location does not exist, input an existing directory"
                    $lbak = $location
                    $location = Get-Path $location
                }
            }
            Invoke-Persist backupDirectory=.$lbak
        }
        $goto = $null
    }

    $goto = __default $goto "baremetalbackup"
    if($goto -eq "baremetalbackup") {
        if((persist nullOrEmpty>_bareMetalBackup) -and ($null -eq $aLocation)) {  
            if(__choice "Authorize full image recoveries?") {
                Invoke-Persist _>_[boolean]bareMetalBackup=true
                Write-Host "Input the drive letter or volume name of the desired backup volume. NOTE: Do not make this on the same DISK that contains the C: drive" Cyan
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
            if(__choice "Modify full image backup settings?") {
                Invoke-PushWrapper Invoke-Persist remove>_bareMetalBackup
                return ___return Format-BackupConfiguration -goto baremetalbackup
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

    Invoke-Push
     
    Invoke-PopScope

    ___end
}
function Start-CheckDiskIntegrity ($path, $log) {
    ___start Start-CheckDiskIntegrity
    $pathRoot = Get-Root $path
    Push-Location $pathRoot
    $loginfo = "$(Get-Date -Format "dMMMy@H:m:s:fff") <::> validating disk integrity of $pathRoot"
    ___debug $loginfo
    $chkdskres = chkdsk.exe
    $success = $chkdskres -contains "Windows has scanned the file system and found no problems."
    Pop-Location

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
    return ___return $success
}
function Start-Backup {
    ___start Start-Backup
    ___debug "args:$args"
    $hash = __search_args $args "-directories" -Switch
    $dirs = $hash.RES
    $hash = __search_args $hash.ARGS "-quiet" -Switch
    $quiet = $hash.RES
    $hash = __search_args $hash.ARGS "-bareMetal" -Switch
    $bare = $hash.RES
    $hash = __search_args $hash.ARGS "-exclude" -All -UntilSwitch
    $exclude = $hash.RES
    $hash = __search_args $hash.ARGS "-validate" -Switch
    $validate = $hash.RES
    $hash = __search_args $hash.ARGS "-log" -All -UntilSwitch
    $logPath = $hash.RES
    ___debug "ARGUMENTS\\" Blue
    ___debug "backupDirectories:$dirs"
    ___debug "backupBareMetal:$bare"
    ___debug "exclude:$exclude"
    ___debug "validate:$validate"
    ___debug "log:$logPath"
    ___debug "ARGUMENTS\\" Blue

    Invoke-EnsureBackupScope

    Invoke-PushScope backup

    if($null -ne $logPath) {
        if(!(Test-Path $logPath)) {
            $null = New-Item -Path $logPath -ItemType File
        }
    }

    if($dirs) {
        if(Invoke-Persist backupDirectory!?){
            Write-Host "Backup has not been configured... Please run Format-BackupConfiguration to configure" -ForegroundColor Red
            return ___return
        }
        $backupDirectory = Get-PersistentVariable backupDirectory
        $backupDirectory = Get-Path $backupDirectory
        if($backupDirectory -notmatch "(.+?)@(.+?):") {
            try {
                $null = Get-Item $backupDirectory -ErrorAction Stop
            }
            catch {
                Write-Host "Could not retrieve backupDirectory ($backupDirectory) : $_" -ForegroundColor Red
                    return ___return
            }
            if($validate) {
                if(!(Start-CheckDiskIntegrity -Path $backupDirectory -Log $log)) {
                    return ___return
                }
            }
        }
        $items = Get-Content "$userDir/backup.items.conf"
        ___debug "ITEMS\\`n$items`n    \\ITEMS\\" Blue
        foreach ($i in $items) {
            if($i.StartsWith("#")) { continue }
            $i = Get-Path $i
            if(Test-Path $i) {
                if($log) {
                    $logPath = "$global:backupLogsPath/$($item.name)-$(Get-Date -Format dMMMy).log"
                    if(!(Test-Path $logPath )) { New-Item $logPath -ItemType File }
                    Add-Content -Path $logPath -Value "[$(Get-Date)]Pushing $i to $backupDirectory" -Force
                }
                try {
                    m_copy $i $backupDirectory -ErrorAction Stop
                } catch {
                    Write-Host "Failed to backup $i -- $_" -ForegroundColor Red -BackgroundColor DarkGray
                    if($log) {
                        $logPath = "$global:backupLogsPath/$($item.name)-$(Get-Date -Format dMMMy).log"
                        if(!(Test-Path $logPath )) { New-Item $logPath -ItemType File }
                        Add-Content -Path $logPath -Value "[$(Get-Date)] >> Failed to push $i to $backupDirectory" -Force
                    }
                }  
            }
        }
    }

    if($bare) {
        ___debug "Running bare metal backup"
        if(Invoke-Persist nullOrEmpty>_bareMetalBackup){
            Write-Host "Backup has not been configured... Please run Format-BackupConfiguration to configure" -ForegroundColor Red
            return ___return
        }
        if(Invoke-Persist bareMetalBackup?!){
            Write-Host "Backup has been declined... Please run Format-BackupConfiguration to configure" -ForegroundColor Red
            return ___return
        }
        $backupVol = Use-Scope Backup Invoke-Persist bareMetalBackupVolume
        $backupVol = Get-Path $backupVol
        ___debug "backup destination: $backupVol"
        try {
            $null = Get-Item $backupVol -ErrorAction Stop
        }
        catch {
            Write-Host "Could not retrieve backup Volume Destination ($backupVol) : $_" -ForegroundColor Red
            return ___return
        }
        [string]$letter = ([System.Environment]::SystemDirectory).substring(0,1)
        $disk = Get-Disk -Partition (Get-Partition | Where-Object {$_.driveletter -eq $letter})
        $allVols = Get-Partition -Disk $disk | Foreach-Object { $v_ = Get-Volume -Partition $_; if ($null -eq $v_) { return ___return }; if ($v_.FileSystemType -ne "NTFS") { return }; return $_ } | Select-Object -ExpandProperty GUID | Foreach-Object { return "\\?\Volume$_\" }
        if($allVols -isnot [System.Array]){ $allVols = @( $allVols ) }
        if($validate) {
            ___debug "Validating destination and system volume"
            if(!(Start-CheckDiskIntegrity -Path $backupVol -Log $log)) {
                ___debug "Destination validation failed"
                return ___return
            }
            ___debug "Destination validated"
            if(!(Start-CheckDiskIntegrity -Path "$($letter):\" -Log $log)) {
                ___debug "System disk validation failed"
                return ___return
            }
            ___debug "System volume validated"
        }

        $allVols = $allVols -join ","

        ___debug "backup sources: $allVols"

        ___debug "Starting backup"

        wbadmin.exe start backup -backupTarget:$backupVol -include:$allVols -noverify -quiet
        #
    }

    Invoke-PopScope
     
    ___end
}












