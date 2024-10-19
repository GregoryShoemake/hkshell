function u_decrypt_secure ([securestring] $secure) {
    $passN = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
    return $passN
}
function Invoke-HandleUser ($name, [switch]$wmi) {

    if ($wmi) {
        if ($null -eq $name) {
            $users = Get-WmiObject -Class Win32_UserAccount -Filter  "LocalAccount='True'" | Select-Object *
        }
        else {
            $users = Get-WmiObject -Class Win32_UserAccount -Filter  "LocalAccount='True'" | Where-Object { ($_.Name -eq $name) -or ($_.Fullname -eq $name) } | Select-Object *
        }
        $hash = @{ Function = "Get-WmiObject"; Users = $users }
        return $hash
    }
    try {
        if ($null -eq $name) {
            $users = Get-LocalUser -ErrorAction Stop | Select-Object * -ErrorAction Stop
        }
        else {
            $users = Get-LocalUser -ErrorAction Stop | Where-Object { ($_.Name -eq $name) -or ($_.Fullname -eq $name) } -ErrorAction Stop | Select-Object * -ErrorAction Stop
        }
        $hash = @{ Function = "Get-LocalUser"; Users = $users }
        return $hash
    }
    catch {
        if ($null -eq $name) {
            $users = Get-WmiObject -Class Win32_UserAccount -Filter  "LocalAccount='True'" | Select-Object *
        }
        else {
            $users = Get-WmiObject -Class Win32_UserAccount -Filter  "LocalAccount='True'" | Where-Object { ($_.Name -eq $name) -or ($_.Fullname -eq $name) } | Select-Object *
        }
        $hash = @{ Function = "Get-WmiObject"; Users = $users }
        return $hash
    }
}
function user_set_admin ([string]$name, [boolean] $admin) {
    if ($admin) {
        net localgroup Administrators $name /add
    }
    else {
        net localgroup Administrators $name /delete
    }
}
function user_set_active ([string]$name, [boolean] $enable) {
    $req = if (!$enable) { "no" } else { "yes" }
    net user $name /active:$req
}

function user_set_username ([string]$oldName, [string]$newName, [boolean] $refactor) {
    try {
        $ErrorActionPreference = "Stop"
        if ($PSVersionTable.PSVersion.Major -ge 3) {
            Rename-LocalUser $oldName -NewName $newName
        }
        else {
            (Get-WmiObject Win32_UserAccount -Filter "name='$oldName'").Rename("$newName")
        }
        $ErrorActionPreference = "Continue"
    }
    catch {
        Write-Host "Failed to modify user: $oldName : to : $newName :: $_" -foregroundcolor red
        $ErrorActionPreference = "Continue"
        return
    }
    if ($refactor) {
        Get-Item C:\Users\$oldName -Force | Rename-Item -NewName $newName -Force
        Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList" -Force | Get-ItemProperty | Where-Object { $_ -match $name } | Set-ItemProperty -Name ProfileImagePath -value "C:\Users\$newName"
    }    
}
function user_set_password ([string]$name, [securestring]$password) {
    try {
        $ErrorActionPreference = "Stop"
        if ($PSVersionTable.PSVersion.Major -ge 3) {
            Set-LocalUser $name -Password $password -Verbose
        }
        else {
            [string]$password = u_decrypt_secure $password
            net user $name $password
        }
        $ErrorActionPreference = "Continue"
    }
    catch {
        Write-Host "Failed to modify user password: $name :: $_" -foregroundcolor red
        $ErrorActionPreference = "Continue"
        return
    }  
}
function user_delete ([string]$name, [boolean]$force) {
    try {
        $ErrorActionPreference = "Stop"
        if ($force -or (__choice "Delete User: $name ?")) {
            if ($PSVersionTable.PSVersion.Major -ge 3) {
                Remove-LocalUser $name
            }
            else {
                net user $name /delete /yes                        
            }
            Write-Host "Deleted User:$name" -foregroundcolor darkcyan
        }
        else { return $false }
        $ErrorActionPreference = "Continue"
        return $true
    }
    catch {
        Write-Host "Failed to delete user : $name :: $_" -foregroundcolor red
        $ErrorActionPreference = "Continue"
        return $false
    }  
}
function user_create ([string]$name, [securestring] $password, [switch] $passthru) {
    try {
        $ErrorActionPreference = "Stop"
        $hostname = hostname   
        $comp = [adsi] "WinNT://$hostname"
        $user = $comp.Create("User", $name)   
        [string]$password = u_decrypt_secure $password
        $user.SetPassword($password)   
        $user.SetInfo()   
    }
    catch [System.Management.Automation.MethodInvocationException] {
        $pass = Password "$_, Input a new password"
        $user = user_create $name (ConvertTo-SecureString $pass -AsPlainText -Force) -passthru
    }
    $ErrorActionPreference = "Continue"
    if ($passthru) { return $user }
}

function user_handle {
    [CmdletBinding()]
    param (
        [Parameter()] [string] $name, 
        [Parameter()] [securestring] $changePassword,
        [Parameter()] [securestring] $newPass,
        [Parameter()] $changeUsername,
        [Parameter()] $newName,
        [Parameter()] [switch] $refactor,
        [Parameter()] [switch] $isAdmin,
        [Parameter()] $rights,
        [Parameter()] $active,
        [Parameter()] [switch] $exists,
        [Parameter()] [switch] $create,
        [Parameter()] [switch] $preClient,
        [Parameter()] [switch] $delete,
        [Parameter()] [switch] $yes,
        [Parameter()] [switch] $no,
        [Parameter()] [switch] $wmi,
        [Parameter()] [switch] $SID,
        [Parameter()] [switch] $isactive
    )

    if ($null -eq $changePassword) { $changePassword = $newPass } 
    $pass = $changePassword

    if ($null -eq $changeUsername) { $changeUsername = $newName }
    $username = $changeUsername

    if ($yes -and $no) { Write-Host "InvalidParameterCombination ! Cannot pass -yes and -no together" -ForegroundColor Red; return $null }
    if ($create -and $delete) { Write-Host "InvalidParameterCombination ! Cannot pass -create and -delete together" -ForegroundColor Red; return $null }

    $h = Invoke-HandleUser $name -wmi:$wmi
    $u = $h.Users
    if ($null -ne $pass) { $pN = u_decrypt_secure $pass }
    $w = ($null -ne $pass) -or $($null -ne $username) -or ($null -ne $rights) -or ($null -ne $active) -or $create -or $preClient
    $r = $isAdmin -or $exists -or $SID -or $isactive
    $n = $null -eq $u
    $m = $u.Users -is [System.Array]

    if ($global:prolix) {
        write-host ">_ user_handle: $args" -ForegroundColor Cyan
        write-host "    \ read:     $r
    \ write:    $w
    \ null:     $n
    \ multiple: $m" -ForegroundColor DarkCyan
    }

    if ($null -eq $name) { return $u }

    if ($n) {
        if ($w) {
            if ($create) { $u = user_create $name $pass -passthru }
            elseif (($yes -or (Yes "Create Local User: $name ?")) -and !$no) { $u = user_create $name $pass -passthru }
        }
        if ($null -eq $u) {
            if ($w -and !$r) { Write-Host "User $name doesn't exist, creation declined" -ForegroundColor Red; return $null }
            if ($r -and !$w) { return $false }
            if (!$r -and !$w) { return $null }
            if ($r -and $w) { Write-Host "User $name doesn't exist, creation declined" -ForegroundColor Red; return $false }
        }
    }
    
    if ($m) { Write-Host "    << Multiple matches for $name >>`n" -ForegroundColor DarkYellow }

    if ($delete) {
        if ($w) { Write-Host "InvalidParameterCombination ! Cannot delete and modify in same command" -ForegroundColor Red; return $null }

        if ($m) {
            foreach ($u_ in $u) {
                $name = $u_.name
                $res = user_delete $name $yes
            }
        }
        else {
            $res = user_delete $name $yes
        }


        if ($r) { 
            if ($res) {
                return $false
            }
        }
    }

    if (!$r -and !$w) { return $u }

    if ($w) {
        if ($m) {
            foreach ($u_ in $u) {
                $name = $u_.name
                if ($null -ne $username) {
                    Write-Host "    << Cannot modify multiple user's usernames >>`n" -ForegroundColor DarkYellow
                }
                if ($null -ne $pass) {
                    Write-Host "    << Cannot modify multiple user's passwords >>`n" -ForegroundColor DarkYellow
                }
                if ($null -ne $rights) {
                    if ($name -eq $ENV:USERNAME) {
                        Write-Host "    << CurrentUserModificationWarning :: Cannot change current user: $name :rights >>`n" -ForegroundColor DarkYellow 
                    }
                    else {
                        switch ($rights) {
                            ADMIN {
                                user_set_admin $name $true 
                                Write-Host "Elevated User:$name" -foregroundcolor darkcyan
                            }
                            STANDARD {
                                user_set_admin $name $false 
                                Write-Host "Reduced User:$name" -foregroundcolor darkcyan
                            }
                            Default {
                                Write-Host "    << Invalid Input For User: $name :Access Rights Designation: $_ >>`n" -ForegroundColor DarkYellow 
                            }
                        }
                    }
                }
                if ($null -ne $active) {
                    if ($name -eq $ENV:USERNAME) {
                        Write-Host "    << CurrentUserModificationWarning :: Cannot change current user: $name :active status >>`n" -ForegroundColor DarkYellow 
                    }
                    else {
                        switch ($active) {
                            ENABLE { 
                                user_set_active $name $true 
                                Write-Host "Enabled User:$name" -foregroundcolor darkcyan
                            }
                            DISABLE { 
                                user_set_active $name $false 
                                Write-Host "Disabled User:$name" -foregroundcolor darkcyan
                            }
                            Default {
                                Write-Host "    << Invalid Input For User: $name :Active Designation: $_ >>`n" -ForegroundColor DarkYellow 
                            }
                        }
                    }
                }
                if ($preClient) {
                    net user $name /logonpasswordchg:yes
                    wmic useraccount where "Name='$name'" set PasswordExpires=TRUE
                    Write-Host "Finalized User:$name" -foregroundcolor darkcyan
                }
            }
        }
        else {
            $name = $u.name
            if ($null -ne $username) {
                if ($name -eq $ENV:USERNAME) {
                    Write-Host "    << CurrentUserModificationWarning :: Cannot change current user: $name :Username >>`n" -ForegroundColor DarkYellow
                }
                else {
                    user_set_username $name $username $refactor
                    Write-Host "User:$name Renamed to => $username" -foregroundcolor darkcyan
                }
            }
            if ($null -ne $pass) {
                user_set_password $name $pass
                Write-Host "User:$name Password Changed" -foregroundcolor darkcyan
            }
            if ($null -ne $rights) {
                if ($name -eq $ENV:USERNAME) {
                    Write-Host "    << CurrentUserModificationWarning :: Cannot change current user: $name :rights >>`n" -ForegroundColor DarkYellow
                }
                else {
                    switch ($rights) {
                        ADMIN {
                            user_set_admin $name $true 
                            Write-Host "Elevated User:$name" -foregroundcolor darkcyan
                        }
                        STANDARD {
                            user_set_admin $name $false 
                            Write-Host "Reduced User:$name" -foregroundcolor darkcyan
                        }
                        Default {
                            Write-Host "    << Invalid Input For User: $name :Access Rights Designation: $_ >>`n" -ForegroundColor DarkYellow 
                        }
                    }
                }
            }
            if ($null -ne $active) {
                if ($name -eq $ENV:USERNAME) {
                    Write-Host "    << CurrentUserModificationWarning :: Cannot change current user: $name :active status >>`n" -ForegroundColor DarkYellow 
                }
                else {
                    switch ($active) {
                        ENABLE { 
                            user_set_active $name $true 
                            Write-Host "Enabled User:$name" -foregroundcolor darkcyan
                        }
                        DISABLE { 
                            user_set_active $name $false 
                            Write-Host "Disabled User:$name" -foregroundcolor darkcyan
                        }
                        Default {
                            Write-Host "    << Invalid Input For User: $name :Active Designation: $_ >>`n" -ForegroundColor DarkYellow 
                        }
                    }
                }
            }
            if ($preClient) {
                net user $name /logonpasswordchg:yes
                wmic useraccount where "Name='$name'" set PasswordExpires=TRUE
                Write-Host "Finalized User:$name"
            }
        }
    }

    if ($r) {
        if ($m) {
            $hashes = @()
            foreach ($u_ in $u) {
                $hash - @{}
                if ($isactive) { $hash.add('Active', $u_.Enabled) }
                if ($exists) { $hash.add('Exists', $true) }
                if ($isAdmin) { $hash.add('Admin', $($null -ne (net localgroup Administrators | select-String $u_.name))) }
                if ($sid) { $hash.add('SID', $u_.SID) }
                $hashes += $hash
            }
            return $hashes
        }
        else {
            $hash = @{}
            if ($isactive) { $hash.add('Active', $u.Enabled) }
            if ($exists) { $hash.add('Exists', $true) }
            if ($isAdmin) { $hash.add('Admin', $($null -ne (net localgroup Administrators | select-String $u.name))) }
            if ($sid) {
                if ($h.function -eq "Get-LocalUser") {
                    $sidVal = $u.SID.Value
                }
                else {
                    $sidVal = $u.SID
                }
                $hash.add('SID', $sidVal) 
            }
            return $hash
        }
    }    
}
New-Alias -Name huserii -Value user_handle -Scope Global -Force

function Set-Owner ($target, $user) {
   if($null -eq $user) { $user = $ENV:USERNAME }
   $user = New-Object -TypeName System.Security.Principal.NTAccount -argumentList $user

   if($target -isnot [System.Array]) { $target = @($target) }
   foreach ($t in $target) {
        if($t -isnot [string]) {
            if(($t -is [System.IO.FileInfo]) -or ($t -is [System.IO.DirectoryInfo])) {
                $t = $t.fullname
            } else {
                Write-Host "Invalid Type Exception: $($t.GetType())"
            }
        }
        try {
            $acl = $null
            $acl = Get-ACL -Path $t
            $acl.SetOwner($user)
            Set-ACL -Path $t -ACLObject $acl -ErrorAction Stop
        } catch {
            Write-Host "Failed to set ACL: $_" -ForegroundColor Red
        }
   }
}
