<#
.SYNOPSIS
    Reverts the Löwenzahn QuickTime fix: removes the QuickTime 2.x runtime, the
    projector compat shims, and restores the backed-up QuickTime registry key.

.DESCRIPTION
    Runs Apple's installed uninstaller (C:\Windows\QTW32DEL.EXE), removes the
    projector AppCompat shims, and re-imports the most recent registry backup
    written by Install-LoewenzahnQuickTime.ps1. For a guaranteed-clean state,
    reinstall QuickTime 7.7.9 afterwards.

.PARAMETER ProjectorPath
    Projector exe path(s) whose compat shims should be removed (same value(s) you
    passed to Set-ProjectorCompat.ps1).

.PARAMETER BackupReg
    Specific registry backup .reg to restore. Defaults to the newest one under
    %LOCALAPPDATA%\LoewenzahnQTFix.

.EXAMPLE
    .\Uninstall-LoewenzahnQuickTime.ps1 -ProjectorPath 'D:\STARTW95.EXE'
#>
[CmdletBinding()]
param(
    [string[]] $ProjectorPath,
    [string]   $BackupReg
)

$ErrorActionPreference = 'Stop'

# self-elevate
$principal = New-Object Security.Principal.WindowsPrincipal(
    [Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host 'Elevation required - relaunching as Administrator...' -ForegroundColor Yellow
    $fwd = @('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"")
    if ($ProjectorPath) { $fwd += @('-ProjectorPath', ($ProjectorPath -join ',')) }
    if ($BackupReg)     { $fwd += @('-BackupReg',"`"$BackupReg`"") }
    Start-Process powershell.exe -Verb RunAs -ArgumentList $fwd
    return
}

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

# 1) Apple uninstaller
$del = "$env:WINDIR\QTW32DEL.EXE"
if (Test-Path $del) {
    Write-Step 'Running Apple QuickTime uninstaller (QTW32DEL.EXE) - follow its prompts.'
    Start-Process $del -Wait
} else {
    Write-Host '    QTW32DEL.EXE not present; removing known runtime files manually.'
    Remove-Item "$env:WINDIR\SysWOW64\QTIM32.DLL","$env:WINDIR\SysWOW64\QTOLE32.DLL",
                "$env:WINDIR\SysWOW64\QTWMCI32.DLL","$env:WINDIR\SysWOW64\QTW32.CPL",
                "$env:WINDIR\SysWOW64\QTWCP.HLP","$env:WINDIR\QTW.INI" -Force -ErrorAction SilentlyContinue
}

# 2) compat shims
if ($ProjectorPath) {
    Write-Step 'Removing projector compat shims.'
    foreach ($hive in 'HKCU:','HKLM:') {
        $key = "$hive\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
        foreach ($p in $ProjectorPath) {
            Remove-ItemProperty -Path $key -Name $p -ErrorAction SilentlyContinue
        }
    }
}

# 3) restore registry backup
if (-not $BackupReg) {
    $BackupReg = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'LoewenzahnQTFix') -Filter 'QuickTime-backup-*.reg' -ErrorAction SilentlyContinue |
                 Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if ($BackupReg -and (Test-Path $BackupReg)) {
    Write-Step "Restoring QuickTime registry from $BackupReg"
    reg import "$BackupReg" | Out-Null
} else {
    Write-Warning 'No registry backup found to restore. Reinstall QuickTime 7.7.9 for a clean state.'
}

# stage cleanup
Remove-Item 'C:\QT212' -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ''
Write-Host 'Revert complete. For a guaranteed-clean QuickTime, reinstall 7.7.9.' -ForegroundColor Green
