<#
.SYNOPSIS
  Capture the Darktide window to a PNG for in-game visual verification by an agent.

.DESCRIPTION
  The engine's own capture (FrameCapture.screen_shot, via the claude_bridge `screenshot`
  command) is not available in retail builds, and a plain desktop grab misses the game when
  it is alt-tabbed or on another monitor. This finds the Darktide window by process name and
  captures just that window:
    1. PrintWindow with PW_RENDERFULLCONTENT - grabs the window even when it is in the
       background (works for borderless/windowed; may come back black for true
       exclusive-fullscreen DirectX).
    2. If that frame is blank, falls back to bringing the window to the foreground and doing
       a GDI screen copy of its rectangle.

  Exclusive-fullscreen note: if captures are black, set Darktide to Borderless/Windowed in
  its video options - then PrintWindow works without stealing focus.

.PARAMETER OutFile
  Destination PNG path. Defaults to tools/.cache/darktide-shot.png under the repo.

.PARAMETER Process
  Process name to capture (default "Darktide").

.PARAMETER NoFocus
  Skip the foreground fallback (never steal focus); only PrintWindow is attempted.

.EXAMPLE
  pwsh -NoProfile -File tools/screenshot.ps1
  pwsh -NoProfile -File tools/screenshot.ps1 -OutFile C:\tmp\shot.png
#>
param(
  [string]$OutFile,
  [string]$Process = "Darktide",
  [switch]$NoFocus
)

$ErrorActionPreference = "Stop"

# Become per-monitor DPI-aware BEFORE any window query, so GetWindowRect/CopyFromScreen
# report real physical pixels instead of DPI-virtualized logical ones (otherwise a 3840x2160
# window on a 150%-scaled display reads back as 2560x1440 and the capture is downscaled).
if (-not ("DpiAware" -as [type])) {
  Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DpiAware {
  [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr value);
  public static void Set() {
    // DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2 = -4
    try { SetProcessDpiAwarenessContext((IntPtr)(-4)); } catch {}
  }
}
'@
}
[DpiAware]::Set()

if (-not $OutFile) {
  $cache = Join-Path $PSScriptRoot ".cache"
  if (-not (Test-Path $cache)) { New-Item -ItemType Directory -Path $cache | Out-Null }
  $OutFile = Join-Path $cache "darktide-shot.png"
}

Add-Type -AssemblyName System.Drawing, System.Windows.Forms

$sig = @'
using System;
using System.Runtime.InteropServices;
public static class Win32 {
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hWnd, IntPtr hdcBlt, uint nFlags);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
'@
if (-not ("Win32" -as [type])) { Add-Type -TypeDefinition $sig }

$proc = Get-Process -Name $Process -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $proc) { Write-Error "Process '$Process' with a visible window not found. Is the game running?"; exit 2 }
$h = $proc.MainWindowHandle

$rect = New-Object Win32+RECT
[void][Win32]::GetWindowRect($h, [ref]$rect)
$w = $rect.Right - $rect.Left
$hgt = $rect.Bottom - $rect.Top
if ($w -le 0 -or $hgt -le 0) { Write-Error "Window has no size ($w x $hgt)."; exit 3 }

function Test-Blank([System.Drawing.Bitmap]$bmp) {
  # sample a grid; if every sampled pixel is near-black, treat as a failed capture
  $stepX = [Math]::Max(1, [int]($bmp.Width / 16))
  $stepY = [Math]::Max(1, [int]($bmp.Height / 16))
  for ($x = 0; $x -lt $bmp.Width; $x += $stepX) {
    for ($y = 0; $y -lt $bmp.Height; $y += $stepY) {
      $p = $bmp.GetPixel($x, $y)
      if ($p.R -gt 16 -or $p.G -gt 16 -or $p.B -gt 16) { return $false }
    }
  }
  return $true
}

# --- Attempt 1: PrintWindow (background-safe) ---
$bmp = New-Object System.Drawing.Bitmap($w, $hgt)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$hdc = $g.GetHdc()
$PW_RENDERFULLCONTENT = 0x2
[void][Win32]::PrintWindow($h, $hdc, $PW_RENDERFULLCONTENT)
$g.ReleaseHdc($hdc)
$g.Dispose()

$method = "PrintWindow"
if (Test-Blank $bmp) {
  if ($NoFocus) {
    $bmp.Dispose()
    Write-Error "PrintWindow returned a blank frame and -NoFocus is set. Try Borderless/Windowed mode."
    exit 4
  }
  # --- Attempt 2: foreground + GDI copy ---
  $bmp.Dispose()
  if ([Win32]::IsIconic($h)) { [void][Win32]::ShowWindow($h, 9) } # SW_RESTORE
  [void][Win32]::SetForegroundWindow($h)
  Start-Sleep -Milliseconds 350
  [void][Win32]::GetWindowRect($h, [ref]$rect)
  $w = $rect.Right - $rect.Left; $hgt = $rect.Bottom - $rect.Top
  $bmp = New-Object System.Drawing.Bitmap($w, $hgt)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
  $g.Dispose()
  $method = "Foreground+CopyFromScreen"
}

$bmp.Save($OutFile, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output ("saved {0} ({1}x{2}) via {3}" -f $OutFile, $w, $hgt, $method)
