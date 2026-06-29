<#
.SYNOPSIS
    Applies the compatibility shims that stabilise the Löwenzahn Director
    projector's QuickTime video path on Windows 10/11.

.DESCRIPTION
    Sets the AppCompatFlags "Layers" string for the given projector executable to
    'WIN98 DWM8And16BitMitigation 16BITCOLOR'. The DWM mitigation and forced
    16-bit colour are what keep the 1996 QuickTime blitting path alive under the
    modern desktop compositor.

    By default the shim is written per-user (HKCU, no elevation needed). Use
    -Machine to write it for all users (HKLM, requires elevation).

.PARAMETER Path
    One or more full paths to projector .exe files (e.g. D:\STARTW95.EXE, or the
    .exe of a parts 2/3 hard-disk install). CD paths are drive-letter specific.

.PARAMETER Layer
    Override the layer string. Default 'WIN98 DWM8And16BitMitigation 16BITCOLOR'.

.PARAMETER Machine
    Write to HKLM (all users) instead of HKCU. Requires Administrator.

.PARAMETER Remove
    Remove the shim for the given Path(s) instead of setting it.

.EXAMPLE
    .\Set-ProjectorCompat.ps1 -Path 'D:\STARTW95.EXE'
.EXAMPLE
    .\Set-ProjectorCompat.ps1 -Path 'C:\Terzio\LZ3\start.exe' -Machine
.EXAMPLE
    .\Set-ProjectorCompat.ps1 -Path 'D:\STARTW95.EXE' -Remove
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string[]] $Path,
    [string] $Layer = 'WIN98 DWM8And16BitMitigation 16BITCOLOR',
    [switch] $Machine,
    [switch] $Remove
)

$ErrorActionPreference = 'Stop'

$hive = if ($Machine) { 'HKLM:' } else { 'HKCU:' }
$key  = "$hive\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"

if ($Machine) {
    $principal = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        throw '-Machine writes to HKLM and requires an elevated PowerShell.'
    }
}

if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }

foreach ($p in $Path) {
    if ($Remove) {
        Remove-ItemProperty -Path $key -Name $p -ErrorAction SilentlyContinue
        Write-Host "removed shim: $p" -ForegroundColor Yellow
        continue
    }
    if (-not (Test-Path $p)) {
        Write-Warning "path not found (shim still set so it applies when present): $p"
    }
    New-ItemProperty -Path $key -Name $p -Value $Layer -PropertyType String -Force | Out-Null
    Write-Host "set shim [$Layer]" -ForegroundColor Green
    Write-Host "  -> $p"
}

Write-Host ''
Write-Host "Scope: $(if($Machine){'all users (HKLM)'}else{'current user (HKCU)'})"
