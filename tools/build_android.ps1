param([string]$GodotPath = 'F:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolchain = Get-Content -LiteralPath (Join-Path $projectRoot '.tmp/android/toolchain.json') -Raw | ConvertFrom-Json
$signing = Get-Content -LiteralPath (Join-Path $projectRoot '.tmp/android/signing.json') -Raw | ConvertFrom-Json
$env:JAVA_HOME = $toolchain.java_home
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = Join-Path $projectRoot '.tmp/android/release.keystore'
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $signing.alias
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $signing.password
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot 'export') | Out-Null
    & $GodotPath --path $projectRoot --headless --export-release Android (Join-Path $projectRoot 'export/除邪务尽-内测版.apk')
    if ($LASTEXITCODE -ne 0) { throw "Android export failed with exit code $LASTEXITCODE" }
    & (Join-Path $toolchain.android_sdk 'build-tools/35.0.1/apksigner.bat') verify --verbose (Join-Path $projectRoot 'export/除邪务尽-内测版.apk')
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed' }
    Copy-Item -LiteralPath (Join-Path $projectRoot 'export/除邪务尽-内测版.apk') -Destination (Join-Path $projectRoot 'export/demonslayer-beta.apk')
} finally {
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_USER -ErrorAction SilentlyContinue
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH -ErrorAction SilentlyContinue
}
