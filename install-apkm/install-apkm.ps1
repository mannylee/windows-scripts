<#
.SYNOPSIS
    Extracts an .apkm bundle and installs its split APKs on an ADB-connected device.

.DESCRIPTION
    An .apkm file is a ZIP container used by APKMirror and Aurora Store. It wraps
    multiple APK splits plus a META-INF signature folder plus an info.json. ADB
    cannot read .apkm directly, so this script extracts the bundle next to the
    input file and runs `adb install-multiple` against the splits in the right
    order.

    By default the script uses the single device reported by `adb devices`. With
    zero or multiple devices connected it errors out -- pass -Device to pick one.

.PARAMETER ApkmPath
    Required. Path to the .apkm file.

.PARAMETER Device
    Optional adb device serial (e.g. 192.168.1.67:5555). If omitted, the script
    uses the single connected device and errors if there isn't exactly one.

.PARAMETER Replace
    Pass -r to `adb install-multiple` so the install overwrites an existing copy
    of the same package on the device.

.PARAMETER PassThrough
    Pass any extra arguments through to adb install-multiple (e.g. -d to allow
    downgrade). Wrap in quotes when called.

.PARAMETER CleanUp
    Remove the extracted folder on success. Default is to keep it so you can
    re-install without re-extracting.

.EXAMPLE
    .\install-apkm.ps1 -ApkmPath C:\path\to\app.apkm -Device 192.168.1.67:5555

.EXAMPLE
    .\install-apkm.ps1 C:\path\to\app.apkm -Replace -PassThrough "-d -g"

.NOTES
    Tested on PowerShell 5.1 (Windows 10/11) and PowerShell 7.x. The script does
    NOT call `adb connect` itself -- run that before invoking this script.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$ApkmPath,

    [string]$Device,

    [switch]$Replace,

    [string]$PassThrough,

    [switch]$CleanUp
)

$ErrorActionPreference = 'Stop'

# --- Locate adb ----------------------------------------------------------------
$adb = (Get-Command adb.exe -ErrorAction SilentlyContinue).Source
if (-not $adb) {
    throw "adb.exe was not found on PATH. Install Android platform-tools (https://developer.android.com/studio/releases/platform-tools) and retry."
}

# --- Validate input ------------------------------------------------------------
if (-not (Test-Path -LiteralPath $ApkmPath -PathType Leaf)) {
    throw "File not found: $ApkmPath"
}

$resolved = (Resolve-Path -LiteralPath $ApkmPath).Path
$ext = [System.IO.Path]::GetExtension($resolved).ToLowerInvariant()
if ($ext -ne '.apkm') {
    Write-Warning "Input does not end in .apkm -- proceeding anyway ($resolved)"
}

# --- Build extraction folder next to the input ---------------------------------
$stem   = [System.IO.Path]::GetFileNameWithoutExtension($resolved)
$parent = Split-Path -Parent $resolved
$extractDir = Join-Path $parent ($stem + '__extracted')

if (Test-Path -LiteralPath $extractDir) {
    Write-Host "[*] Removing previous extraction: $extractDir" -ForegroundColor Yellow
    Remove-Item -LiteralPath $extractDir -Recurse -Force
}

Write-Host "[*] Extracting $resolved -> $extractDir" -ForegroundColor Cyan
Expand-Archive -LiteralPath $resolved -DestinationPath $extractDir -Force

# --- Sanity-check that it looks like an APKM bundle ----------------------------
$infoJson = Join-Path $extractDir 'info.json'
$baseApk  = Join-Path $extractDir 'base.apk'
if (-not (Test-Path -LiteralPath $infoJson) -or -not (Test-Path -LiteralPath $baseApk)) {
    throw "Extracted bundle doesn't look like an APKM (missing info.json or base.apk): $extractDir"
}

try {
    $info = Get-Content -Raw -LiteralPath $infoJson | ConvertFrom-Json
    Write-Host "[*] Package:      $($info.pname)" -ForegroundColor Cyan
    Write-Host "[*] Version:      $($info.release_version)  (versionCode $($info.versioncode))" -ForegroundColor Cyan
    if ($info.capabilities) {
        Write-Host "[*] Capabilities: $($info.capabilities -join ', ')" -ForegroundColor Cyan
    }
}
catch {
    Write-Warning "Could not parse info.json: $_"
}

# --- Collect APK splits --------------------------------------------------------
# Sort-Object Name keeps 'base.apk' first (b < s) and the rest alphabetical.
$apks = @(Get-ChildItem -LiteralPath $extractDir -Filter *.apk | Sort-Object Name)
if ($apks.Count -lt 1) {
    throw "No .apk files found inside $extractDir"
}

Write-Host "[*] Found $($apks.Count) APK splits:" -ForegroundColor Green
$apks | ForEach-Object { Write-Host "    - $($_.Name)" }

# --- Resolve target device -----------------------------------------------------
if (-not $Device) {
    $devs = @(& $adb devices | Select-String 'device$' | ForEach-Object { ($_ -split "`t")[0] })
    $devs = @($devs | Where-Object { $_ -and $_ -ne 'List' -and $_ -ne '*' })
    if ($devs.Count -eq 0) {
        throw "No adb device connected. Run 'adb connect <ip>:<port>' first, then retry."
    }
    if ($devs.Count -gt 1) {
        throw "Multiple adb devices connected. Pass -Device <serial> to choose. Connected: $($devs -join ', ')"
    }
    $Device = $devs[0]
}
Write-Host "[*] Target device: $Device" -ForegroundColor Cyan

# --- Install -------------------------------------------------------------------
# PowerShell splatting the array into separate args.
$adbArgs = @('-s', $Device, 'install-multiple')
if ($Replace) { $adbArgs += '-r' }

# PassThrough lets the caller inject extra adb flags like -d (allow downgrade)
# or -g (grant all permissions). Tokenize on whitespace; quote-handling is the
# caller's responsibility for anything more complex.
if ($PassThrough) {
    $adbArgs += $PassThrough.Split([char[]]' ', [System.StringSplitOptions]::RemoveEmptyEntries)
}

$adbArgs += $apks.FullName

Write-Host "[*] Running: adb $($adbArgs -join ' ')" -ForegroundColor Cyan
& $adb @adbArgs
if ($LASTEXITCODE -ne 0) {
    throw "adb install-multiple failed with exit code $LASTEXITCODE"
}

Write-Host "[+] Install succeeded." -ForegroundColor Green
Write-Host "    Bundle kept at: $extractDir"

if ($CleanUp) {
    Write-Host "[*] Cleaning up extracted folder" -ForegroundColor Yellow
    Remove-Item -LiteralPath $extractDir -Recurse -Force
}
