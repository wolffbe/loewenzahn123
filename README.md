# Löwenzahn QuickTime-Fix (Windows 10/11)

Bringt die frühen **Löwenzahn**-CD-ROMs (Teile **1–3**, Terzio / Tivola, Macromedia
Director) unter 64-Bit-Windows 10/11 zum Starten, wo sie sonst mit folgender
Meldung den Dienst verweigern:

> *„Auf diesem Computer ist keine oder die falsche Version von QuickTime für
> Windows installiert. Die Videos auf dieser CD-ROM können deshalb nicht
> abgespielt werden.“*

Diese Titel prüfen fest auf die **QuickTime-2.x**-Laufzeitumgebung, mit der sie
ausgeliefert wurden, und lehnen jedes moderne QuickTime (7.x) ab. Dieses Repo
automatisiert die korrekte Installation dieser alten Laufzeit und stabilisiert
den Director-Projektor.

## Welche Teile brauchen das

| Teil | Datenträger | Video | Benötigtes QuickTime |
|------|-------------|-------|----------------------|
| **1** | `LOEWENZA` | QuickTime `.mov` | **QuickTime 2.1.2** (dieser Fix) |
| **2** | `LZ_2`     | QuickTime (Installation auf Festplatte) | QuickTime 2.1.2 **oder** das mitgelieferte QuickTime 3 (`SETUP\TREIBER\QTW3`) |
| **3** | `LOEWE3`   | QuickTime (Installation auf Festplatte) | QuickTime 2.1.2 (dieser Fix) |
| 4–8  | — | **MPEG-1** über das QuickTime-6-Director-Xtra | **Nichts** — laufen mit bereits installiertem modernem QuickTime 7.x |

> Die Teile **4–8 brauchen diesen Fix nicht.** Sie spielen MPEG-1 über das
> `QT6Asset.x32`- / `QT3Asset.x32`-Director-Xtra ab und laufen mit einer
> vorhandenen QuickTime-7.x-Installation. Nur **1–3** hängen am alten QuickTime 2.x.

## Warum der mitgelieferte Installer allein scheitert

`QUICKTIM\QT32.EXE` (QuickTime 2.1.2, 1996) installiert seine Laufzeit nach
`C:\Windows`. **Ohne erhöhte Rechte** unter Win10/11 *virtualisiert* UAC diese
Schreibzugriffe in den benutzereigenen `VirtualStore`, die Installation bricht ab
(`RESULT.QTW → Complete=0`) mit der irreführenden Meldung:

> *An operation could not be performed because a file handle could not be
> opened … see the "FILES" command in your DOS manual.*

**Mit erhöhten Rechten** landen die Schreibzugriffe im echten `C:\Windows`, und die
Installation läuft durch. Das ist der Kern des Fixes. (Das 16-Bit-`QT16.EXE` läuft
auf 64-Bit-Windows gar nicht — nur `QT32.EXE` ist nutzbar, und es liegt auf dem
Datenträger von **Teil 1**.)

## Voraussetzungen

- 64-Bit-Windows 10 oder 11, Administratorrechte.
- Der Datenträger / das ISO von **Teil 1** eingebunden (er enthält
  `QUICKTIM\QT32.EXE`). Die Installation davon deckt die Teile 1, 2 und 3
  systemweit ab — alle wollen dasselbe 2.1.2.
- PowerShell 5.1+ (in Windows enthalten).

## Verwendung

```powershell
# in einer erhöhten PowerShell, oder das Skript fordert die Rechte selbst an:
Set-ExecutionPolicy -Scope Process Bypass -Force

# 1) QuickTime-2.1.2-Laufzeit installieren (findet QT32.EXE auf eingebundenem Datenträger)
.\scripts\Install-LoewenzahnQuickTime.ps1

#    ...oder den Installer direkt angeben:
.\scripts\Install-LoewenzahnQuickTime.ps1 -InstallerPath 'D:\QUICKTIM\QT32.EXE'

# 2) Kompatibilitäts-Shims auf den Spiel-Projektor anwenden (für stabiles Video).
#    Teil 1 läuft direkt von der CD:
.\scripts\Set-ProjectorCompat.ps1 -Path 'D:\STARTW95.EXE'
#    Teile 2/3 werden erst auf die Festplatte installiert (deren SETUP\AUTORUN
#    ausführen), danach auf die installierte .exe zeigen, z. B.:
.\scripts\Set-ProjectorCompat.ps1 -Path 'C:\Terzio\Loewenzahn2\<projektor>.exe'
```

Der Installer ist Apples originaler GUI-Assistent — auf **Continue → Install**
klicken, wenn er erscheint. Das Skript wartet auf die Erfolgsmeldung und prüft
anschließend, ob die Laufzeit-DLLs in `C:\Windows\SysWOW64` gelandet sind.

## Was installiert / geändert wird

- `C:\Windows\SysWOW64\`: `QTIM32.DLL` (Kern-Engine), `QTOLE32.DLL`,
  `QTWMCI32.DLL`, `QTW32.CPL`, `QTWCP.HLP`
- `C:\Windows\`: `QTW.INI`, `QTW32DEL.EXE` (Apples Deinstallationsprogramm)
- `HKLM\…\AppCompatFlags\Layers`: `WIN98 DWM8And16BitMitigation 16BITCOLOR` auf dem
  Projektor, den du an `Set-ProjectorCompat.ps1` übergibst
- Eine Sicherung deines bestehenden QuickTime-Registry-Schlüssels wird unter
  `%LOCALAPPDATA%\LoewenzahnQTFix\QuickTime-backup-<zeitstempel>.reg` abgelegt

Deine QuickTime-7.x-Player-Installation bleibt erhalten; die 2.x-Laufzeit liegt
daneben.

## Rückgängig machen

```powershell
.\scripts\Uninstall-LoewenzahnQuickTime.ps1
```

Führt Apples `QTW32DEL.EXE` aus, entfernt die Projektor-Shims und stellt den
gesicherten QuickTime-Registry-Schlüssel wieder her. Für einen garantiert
sauberen Zustand danach QuickTime 7.7.9 neu installieren.

## Bekannte Einschränkungen

- **Die Videowiedergabe unter Win11 ist nicht perfekt.** Mit dem Fix startet
  Teil 1 an der Versionssperre vorbei, Menü und Szenen werden gezeichnet, und
  Videobilder *erscheinen* — aber der QuickTime-Videopfad von 1996 ist unter dem
  modernen Desktop-Compositor wackelig, und der Projektor kann nach kurzer Zeit
  instabil werden. Die Shims helfen deutlich, machen es aber nicht kugelsicher.
- Für **zuverlässiges** Video bei den Teilen 1–3 diese in einer
  **Windows-98/XP-VM** ausführen, wo `QT32.EXE` sauber installiert und die Spiele
  normal laufen.
- Die Clips lassen sich immer direkt ansehen: Die `.mov`-Dateien unter
  `MEDIA\` / `MEDIA\VIDEOS\` öffnen in QuickTime 7 oder VLC.

## Rechtliches

Dieses Repository enthält **nur Skripte**. Es liefert keine Apple-Software mit. Die
QuickTime-Laufzeit wird zur Laufzeit aus dem Original-Installer **auf deinen
eigenen Datenträgern** entpackt. QuickTime ist © Apple Inc.; Löwenzahn ist ©
Terzio/Tivola. Verwende ausschließlich rechtmäßig erworbene Medien.

---

# Löwenzahn QuickTime Fix (Windows 10/11)

Get the early **Löwenzahn** CD‑ROMs (parts **1–3**, Terzio / Tivola, Macromedia
Director) to launch on 64‑bit Windows 10/11, where they otherwise refuse to
start with:

> *„Auf diesem Computer ist keine oder die falsche Version von QuickTime für
> Windows installiert. Die Videos auf dieser CD‑ROM können deshalb nicht
> abgespielt werden.“*

These titles hard‑check for the **QuickTime 2.x** runtime they shipped with and
reject any modern QuickTime (7.x). This repo automates installing that old
runtime correctly and stabilising the Director projector.

## Which parts need this

| Part | Disc label | Video | QuickTime needed |
|------|-----------|-------|------------------|
| **1** | `LOEWENZA` | QuickTime `.mov` | **QuickTime 2.1.2** (this fix) |
| **2** | `LZ_2`     | QuickTime (HD install) | QuickTime 2.1.2 **or** the bundled QuickTime 3 (`SETUP\TREIBER\QTW3`) |
| **3** | `LOEWE3`   | QuickTime (HD install) | QuickTime 2.1.2 (this fix) |
| 4–8  | — | **MPEG‑1** via the QuickTime 6 Director Xtra | **Nothing** — they work with modern QuickTime 7.x already installed |

> Parts **4–8 do not need this fix.** They switched to MPEG‑1 played through the
> `QT6Asset.x32` / `QT3Asset.x32` Director Xtra and run fine against an existing
> QuickTime 7.x install. Only **1–3** are tied to the old QuickTime 2.x.

## Why the bundled installer fails on its own

`QUICKTIM\QT32.EXE` (QuickTime 2.1.2, 1996) installs its runtime into
`C:\Windows`. Run **un‑elevated** on Win10/11, UAC *virtualises* those writes
into your per‑user `VirtualStore`, the install aborts
(`RESULT.QTW → Complete=0`) with the misleading error:

> *An operation could not be performed because a file handle could not be
> opened … see the "FILES" command in your DOS manual.*

Run **elevated**, and the writes hit the real `C:\Windows`, so it completes.
That is the core of the fix. (The 16‑bit `QT16.EXE` cannot run on 64‑bit Windows
at all — only `QT32.EXE` is usable, and it lives on the **part 1** disc.)

## Requirements

- 64‑bit Windows 10 or 11, Administrator rights.
- The **part 1** disc/ISO mounted (it carries `QUICKTIM\QT32.EXE`). Installing
  from it covers parts 1, 2 and 3 system‑wide — they all want the same 2.1.2.
- PowerShell 5.1+ (built in).

## Usage

```powershell
# from an elevated PowerShell, or let the script self-elevate:
Set-ExecutionPolicy -Scope Process Bypass -Force

# 1) Install the QuickTime 2.1.2 runtime (auto-finds QT32.EXE on a mounted disc)
.\scripts\Install-LoewenzahnQuickTime.ps1

#    ...or point it at the installer explicitly:
.\scripts\Install-LoewenzahnQuickTime.ps1 -InstallerPath 'D:\QUICKTIM\QT32.EXE'

# 2) Apply the compatibility shims to the game's projector so video is stable.
#    Part 1 runs from the CD:
.\scripts\Set-ProjectorCompat.ps1 -Path 'D:\STARTW95.EXE'
#    Parts 2/3 install to disk first (run their SETUP\AUTORUN), then point at
#    the installed .exe, e.g.:
.\scripts\Set-ProjectorCompat.ps1 -Path 'C:\Terzio\Loewenzahn2\<projector>.exe'
```

The installer is Apple's original GUI wizard — click **Continue → Install** when
it appears. The script waits for it to report success and then verifies the
runtime DLLs landed in `C:\Windows\SysWOW64`.

## What gets installed / changed

- `C:\Windows\SysWOW64\`: `QTIM32.DLL` (core engine), `QTOLE32.DLL`,
  `QTWMCI32.DLL`, `QTW32.CPL`, `QTWCP.HLP`
- `C:\Windows\`: `QTW.INI`, `QTW32DEL.EXE` (Apple's uninstaller)
- `HKLM\…\AppCompatFlags\Layers`: `WIN98 DWM8And16BitMitigation 16BITCOLOR` on the
  projector you pass to `Set-ProjectorCompat.ps1`
- A backup of your existing QuickTime registry key is saved to
  `%LOCALAPPDATA%\LoewenzahnQTFix\QuickTime-backup-<timestamp>.reg`

Your QuickTime 7.x player install is left in place; the 2.x runtime coexists
beside it.

## Reverting

```powershell
.\scripts\Uninstall-LoewenzahnQuickTime.ps1
```

This runs Apple's `QTW32DEL.EXE`, removes the projector compat shims, and
restores the backed‑up QuickTime registry key. For a guaranteed‑clean state,
reinstall QuickTime 7.7.9 afterwards.

## Known limitations

- **Video playback on Win11 is imperfect.** With the fix, part 1 launches past
  the version gate, the menu and scenes render, and video frames *do* appear —
  but the 1996 QuickTime video path is shaky under the modern desktop compositor
  and the projector can become unstable after a short while. The shims help a
  lot but do not make it bullet‑proof.
- For **reliable** video on parts 1–3, run them in a **Windows 98/XP VM**, where
  `QT32.EXE` installs and the games play normally.
- You can always watch the raw clips directly: the `.mov` files under
  `MEDIA\` / `MEDIA\VIDEOS\` open in QuickTime 7 or VLC.

## Legal

This repository contains **scripts only**. It ships no Apple software. The
QuickTime runtime is extracted from the original installer **on your own discs**
at run time. QuickTime is © Apple Inc.; Löwenzahn is © Terzio/Tivola. Use your
own legally‑owned media.
