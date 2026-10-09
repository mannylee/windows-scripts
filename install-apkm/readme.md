# install-apkm.ps1

Side-load an `.apkm` bundle (used by APKMirror and Aurora Store) onto an
ADB-connected Android device. The script extracts the bundle to a sibling
folder and runs `adb install-multiple` against the splits in the correct
order (`base.apk` first, then the rest alphabetically).

## Why

`adb install` only accepts plain `.apk` files. `.apkm` is a ZIP container
holding split APKs + a `META-INF` signature block + an `info.json`. The
official way to install one is the APKMirror Installer app on-device. For
a PC-driven workflow, the simplest path is to extract the bundle and let
`adb install-multiple` handle it -- this preserves the original signature
so reinstalls won't trip a signature-mismatch error.

## Usage

```powershell
.\install-apkm.ps1 -ApkmPath C:\path\to\app.apkm -Device 192.168.1.67:5555
```

The device flag is optional when exactly one device is connected.

### Parameters

| Parameter      | Description |
|----------------|-------------|
| `-ApkmPath`    | (Required, positional 1) Path to the `.apkm` file. |
| `-Device`      | ADB device serial, e.g. `192.168.1.67:5555`. Omit to use the single connected device. |
| `-Replace`     | Pass `-r` so the install overwrites an existing copy of the same package on the device. |
| `-PassThrough` | Pass extra flags through to `adb install-multiple` (e.g. `"-d -g"` to allow downgrade + grant runtime permissions). |
| `-CleanUp`     | Remove the extracted folder on success. Default is to keep it for debugging. |

### Examples

```powershell
# Plain install on a known device
.\install-apkm.ps1 C:\Downloads\myapp.apkm -Device 192.168.1.67:5555

# Re-install over the existing copy
.\install-apkm.ps1 C:\Downloads\myapp.apkm -Replace

# Downgrade (handy when the on-device version is newer than what you have)
.\install-apkm.ps1 C:\Downloads\myapp.apkm -Replace -PassThrough "-d"
```

## Prerequisites

- PowerShell 5+ (already on Windows 10/11).
- Android `adb.exe` on `PATH`. Either install via Android Studio SDK
  Manager ("Platform Tools") or grab the standalone zip from
  <https://developer.android.com/studio/releases/platform-tools>.
- A device already connected and authorized (`adb connect <ip>:<port>`,
  then `adb devices` shows it as `device`). **The script does not call
  `adb connect` for you** -- run that first.

## What it does

1. Validates the input file exists and ends in `.apkm` (warns if not).
2. Creates `<input>.apkm__extracted` next to the input file (after wiping
   any prior extraction).
3. Extracts the bundle via `Expand-Archive`.
4. Sanity-checks for `info.json` and `base.apk`.
5. Reads `info.json` and prints package id, version, and capabilities.
6. Lists the splits, then runs
   `adb -s <device> install-multiple [-r] [pass-through] <apks...>`.
7. Reports success or surfaces the adb exit code as an exception.

## Known quirks

- The ARMv7 split is conventionally named
  `split_config.armeabi-v7a.apk`. The dash occasionally confuses a few
  Java tools (e.g. `apksigner.bat`); `adb install-multiple` itself is
  unaffected, but if you ever pull a split out for off-line inspection,
  copy it to a path without the hyphen first.
- On PowerShell 5.1 the script works but produces noisier colored output
  in legacy console hosts. Use the Windows Terminal or PS 7 for the
  cleanest experience.
