$typefunctions = @(
    "`n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Some functions support argument [-info] for more information on each function
Note: Not all functions have info yet
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`n",
    "[PInvoke.Win32.UserInput]::LastInput ~doesn't support -info",
    "[PInvoke.Win32.UserInput]::IdleTime ~doesn't support -info",
    "[PInvoke.Win32.UserInput]::LastInputTicks ~doesn't support -info",
    "Set-WindowState ~ supports -info",
    "[System.Windows.Forms]::SendWait ~doesn't support -info",
    "[WinAp]::SetForegroundWindow ~doesn't support -info",
    "[WinAp]::ShowWindow ~doesn't support -info",
    "[CloseButtonToggle.Status]::Disable()"
    ""
)
function t_list {
    return $typefunctions
}
Add-Type -ErrorAction SilentlyContinue @"
    using System;
    using System.Runtime.InteropServices;
    public class WinAp {
      [DllImport("user32.dll")]
      [return: MarshalAs(UnmanagedType.Bool)]
      public static extern bool SetForegroundWindow(IntPtr hWnd);

      [DllImport("user32.dll")]
      [return: MarshalAs(UnmanagedType.Bool)]
      public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    }
"@

Add-Type -ErrorAction SilentlyContinue @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

namespace PInvoke.Win32 {

    public static class UserInput {

        [DllImport("user32.dll", SetLastError=false)]
        private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

        [StructLayout(LayoutKind.Sequential)]
        private struct LASTINPUTINFO {
            public uint cbSize;
            public int dwTime;
        }

        public static DateTime LastInput {
            get {
                DateTime bootTime = DateTime.UtcNow.AddMilliseconds(-Environment.TickCount);
                DateTime lastInput = bootTime.AddMilliseconds(LastInputTicks);
                return lastInput;
            }
        }

        public static TimeSpan IdleTime {
            get {
                return DateTime.UtcNow.Subtract(LastInput);
            }
        }

        public static int LastInputTicks {
            get {
                LASTINPUTINFO lii = new LASTINPUTINFO();
                lii.cbSize = (uint)Marshal.SizeOf(typeof(LASTINPUTINFO));
                GetLastInputInfo(ref lii);
                return lii.dwTime;
            }
        }
    }
}
'@

Add-Type -AssemblyName System.Windows.Forms

function Set-WindowState {
    param(
        [Parameter()]
        [ValidateSet('FORCEMINIMIZE', 'HIDE', 'MAXIMIZE', 'MINIMIZE', 'RESTORE', 
            'SHOW', 'SHOWDEFAULT', 'SHOWMAXIMIZED', 'SHOWMINIMIZED', 
            'SHOWMINNOACTIVE', 'SHOWNA', 'SHOWNOACTIVATE', 'SHOWNORMAL')]
        [Alias('Style')]
        [String] $State = 'SHOW',
        
        [Parameter(ValueFromPipelineByPropertyname = 'True')]
        [System.IntPtr] $MainWindowHandle = (Get-Process -id $pid).MainWindowHandle,
    
        [Parameter()]
        [switch] $PassThru,

        [Parameter()]
        [switch] $Info
    
    )
    BEGIN {
    
        
        if ($info) {
            $information = '
<#
.SYNOPSIS
Imports user32.dll to include function ShowWindowAsync(IntPtr hWnd, int nCmdShow)

Pipe this function onto a process to set the window style

$WindowStates = @{
    FORCEMINIMIZE   = 11
    HIDE            = 0
    MAXIMIZE        = 3
    MINIMIZE        = 6
    RESTORE         = 9
    SHOW            = 5
    SHOWDEFAULT     = 10
    SHOWMAXIMIZED   = 3
    SHOWMINIMIZED   = 2
    SHOWMINNOACTIVE = 7
    SHOWNA          = 8
    SHOWNOACTIVATE  = 4
    SHOWNORMAL      = 1

.EXAMPLE
    Get-Process Excel | Set-WindowState -State MINIMIZE
}
#>
'
            return $information
        }
        $WindowStates = @{
            'FORCEMINIMIZE'   = 11
            'HIDE'            = 0
            'MAXIMIZE'        = 3
            'MINIMIZE'        = 6
            'RESTORE'         = 9
            'SHOW'            = 5
            'SHOWDEFAULT'     = 10
            'SHOWMAXIMIZED'   = 3
            'SHOWMINIMIZED'   = 2
            'SHOWMINNOACTIVE' = 7
            'SHOWNA'          = 8
            'SHOWNOACTIVATE'  = 4
            'SHOWNORMAL'      = 1
        }

        $definition = @" 
    [DllImport("user32.dll")] 
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow); 
"@
        
        $Win32ShowWindowAsync = Add-Type -memberDefinition $definition -name "Win32ShowWindowAsync" -namespace Win32Functions -passThru
    
    }
    PROCESS {
        $Win32ShowWindowAsync::ShowWindowAsync($MainWindowHandle, $WindowStates[$State]) | Out-Null
        Write-Verbose ("Set Window State on '{0}' to '{1}' " -f $MainWindowHandle, $State)
    
        if ($PassThru) {
            Write-Output $MainWindowHandle
        }
    
    }
    END {
    }
    
}
    
Set-Alias -Name 'setwin' -Value 'Set-WindowState'

Add-Type -ErrorAction SilentlyContinue @'
using System;
using System.Runtime.InteropServices;

namespace CloseButtonToggle {

 internal static class WinAPI {
   [DllImport("kernel32.dll")]
   internal static extern IntPtr GetConsoleWindow();

   [DllImport("user32.dll")]
   [return: MarshalAs(UnmanagedType.Bool)]
   internal static extern bool DeleteMenu(IntPtr hMenu,
                          uint uPosition, uint uFlags);

   [DllImport("user32.dll")]
   [return: MarshalAs(UnmanagedType.Bool)]
   internal static extern bool DrawMenuBar(IntPtr hWnd);

   [DllImport("user32.dll")]
   internal static extern IntPtr GetSystemMenu(IntPtr hWnd,
              [MarshalAs(UnmanagedType.Bool)]bool bRevert);

   const uint SC_CLOSE     = 0xf060;
   const uint MF_BYCOMMAND = 0;

   internal static void ChangeCurrentState(bool state) {
     IntPtr hMenu = GetSystemMenu(GetConsoleWindow(), state);
     DeleteMenu(hMenu, SC_CLOSE, MF_BYCOMMAND);
     DrawMenuBar(GetConsoleWindow());
   }
 }

 public static class Status {
   public static void Disable() {
     WinAPI.ChangeCurrentState(false); //its 'true' if need to enable
   }
 }
}
'@

Add-Type -AssemblyName Microsoft.VisualBasic

Add-Type -AssemblyName System.Drawing
