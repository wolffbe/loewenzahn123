<#
.SYNOPSIS
    Installs the QuickTime 2.1.2 runtime that early Löwenzahn CD-ROMs (parts 1-3)
    require, working around the UAC-virtualisation failure on 64-bit Windows 10/11.

.DESCRIPTION
    The bundled QT32.EXE installs its runtime into C:\Windows. Run un-elevated on
    Win10/11 those writes are redirected into the per-user VirtualStore and the
    install aborts (RESULT.QTW -> Complete=0) with a bogus "file handle / FILES"
    error. Run elevated, the writes hit the real C:\Windows and it completes.

    This script self-elevates, backs up the current QuickTime registry key, stages
    the installer at a short space-free path, launches it, and waits for it to
    report Complete=1, then verifies the runtime DLLs.

.PARAMETER InstallerPath
    Full path to QT32.EXE. If omitted, the script searches mounted CD-ROM/ISO
    drives for \QUICKTIM\QT32.EXE (present on the Löwenzahn part 1 disc).

.PARAMETER TimeoutSeconds
    How long to wait for the interactive installer to finish. Default 180.

.EXAMPLE
    .\Install-LoewenzahnQuickTime.ps1
.EXAMPLE
    .\Install-LoewenzahnQuickTime.ps1 -InstallerPath 'D:\QUICKTIM\QT32.EXE'
#>
[CmdletBinding()]
param(
    [string] $InstallerPath,
    [int]    $TimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'

# --- self-elevate -----------------------------------------------------------
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host 'Elevation required - relaunching as Administrator...' -ForegroundColor Yellow
    $fwd = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
    if ($InstallerPath)   { $fwd += @('-InstallerPath',"`"$InstallerPath`"") }
    if ($TimeoutSeconds)  { $fwd += @('-TimeoutSeconds',"$TimeoutSeconds") }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $fwd
    return
}

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

# --- locate the installer ---------------------------------------------------
if (-not $InstallerPath) {
    Write-Step 'Searching mounted discs for QUICKTIM\QT32.EXE ...'
    $InstallerPath = Get-Volume |
        Where-Object { $_.DriveLetter -and $_.DriveType -in 'CD-ROM','Removable','Fixed' } |
        ForEach-Object { Join-Path "$($_.DriveLetter):\" 'QUICKTIM\QT32.EXE' } |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1
}
if (-not $InstallerPath -or -not (Test-Path $InstallerPath)) {
    throw "QT32.EXE not found. Mount the Löwenzahn part 1 disc, or pass -InstallerPath. " +
          "(The 16-bit QT16.EXE cannot be used on 64-bit Windows.)"
}
Write-Host "    installer: $InstallerPath"

# refuse the 16-bit installer outright
$peMachine = & {
    $fs = [IO.File]::OpenRead($InstallerPath); $br = New-Object IO.BinaryReader($fs)
    try { $fs.Seek(0x3c,0) | Out-Null; $pe = $br.ReadInt32(); $fs.Seek($pe,0) | Out-Null
          $sig = [Text.Encoding]::ASCII.GetString($br.ReadBytes(2))
          if ($sig -ne 'PE') { return 'NE16' }
          $fs.Seek($pe+4,0) | Out-Null; '0x{0:x4}' -f $br.ReadUInt16() }
    finally { $fs.Close() }
}
if ($peMachine -eq 'NE16') { throw "$InstallerPath is a 16-bit installer; it cannot run on 64-bit Windows. Use QT32.EXE from the part 1 disc." }

# --- already installed? -----------------------------------------------------
$core = "$env:WINDIR\SysWOW64\QTIM32.DLL"
if (Test-Path $core) {
    Write-Host "QuickTime 2.x runtime already present ($core). Nothing to do." -ForegroundColor Green
    return
}

# --- back up the current QuickTime registry ---------------------------------
$backupDir = Join-Path $env:LOCALAPPDATA 'LoewenzahnQTFix'
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
$stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $backupDir "QuickTime-backup-$stamp.reg"
$qtKey  = 'HKLM\SOFTWARE\WOW6432Node\Apple Computer, Inc.\QuickTime'
if (reg query $qtKey 2>$null) {
    Write-Step "Backing up existing QuickTime registry -> $backup"
    reg export $qtKey $backup /y | Out-Null
} else {
    Write-Host '    (no existing QuickTime registry key to back up)'
}

# --- stage to a short, space-free path & clear stale state ------------------
$stage = 'C:\QT212'
New-Item -ItemType Directory -Force -Path $stage | Out-Null
Copy-Item $InstallerPath (Join-Path $stage 'QT32.EXE') -Force
Remove-Item "$env:WINDIR\RESULT.QTW","$env:WINDIR\QT`$INST`$.~32" -Force -ErrorAction SilentlyContinue
Remove-Item "$env:LOCALAPPDATA\VirtualStore\Windows\RESULT.QTW" -Force -ErrorAction SilentlyContinue

# --- run the installer (we are already elevated) ----------------------------
Write-Step 'Launching the QuickTime 2.1.2 installer.'
Write-Host  '    Click  Continue  ->  Install  in Apple''s wizard when it appears.' -ForegroundColor Yellow
Start-Process (Join-Path $stage 'QT32.EXE')

$result = "$env:WINDIR\RESULT.QTW"
$deadline = (Get-Date).AddSeconds($TimeoutSeconds)
$ok = $false
while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 2
    if ((Test-Path $result) -and (Get-Content $result -Raw) -match 'Complete=1') { $ok = $true; break }
    if (-not (Get-Process QT32 -ErrorAction SilentlyContinue) -and (Test-Path $result)) {
        if ((Get-Content $result -Raw) -match 'Complete=1') { $ok = $true }
        break
    }
}

# --- verify -----------------------------------------------------------------
if ($ok -and (Test-Path $core)) {
    Write-Host ''
    Write-Host 'SUCCESS - QuickTime 2.1.2 runtime installed.' -ForegroundColor Green
    Get-ChildItem "$env:WINDIR\SysWOW64\QT*.DLL","$env:WINDIR\SysWOW64\QTW32.CPL","$env:WINDIR\QTW.INI" -ErrorAction SilentlyContinue |
        Select-Object @{n='Installed';e={$_.FullName}} | Format-Table -AutoSize
    Write-Host 'Next: run Set-ProjectorCompat.ps1 against the game projector for stable video.' -ForegroundColor Cyan
} else {
    Write-Warning "Install did not confirm completion (Complete=1 / $core missing)."
    if (Test-Path $result) { Write-Host ("RESULT.QTW:`n" + (Get-Content $result -Raw)) }
    Write-Host 'If the wizard never appeared, re-run; if it errored, ensure you are elevated and the path is short/space-free.'
    exit 1
}
