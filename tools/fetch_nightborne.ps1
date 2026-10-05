$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$assetRoot = Join-Path $projectRoot 'Sprites/nightborne'
$tempRoot = Join-Path $projectRoot '.godot/NightBorne-source'
$archive = Join-Path $projectRoot '.godot/NightBorne.zip'
New-Item -ItemType Directory -Force -Path $assetRoot, (Split-Path -Parent $archive) | Out-Null
$page = Invoke-WebRequest -Uri 'https://creativekind.itch.io/nightborne-warrior' -SessionVariable assetSession -TimeoutSec 30
$token = [regex]::Match($page.Content, '<meta[^>]*name="csrf_token"[^>]*value="([^"]+)"').Groups[1].Value
if (-not $token) { throw 'Official page did not supply its download token.' }
$download = Invoke-RestMethod -Uri 'https://creativekind.itch.io/nightborne-warrior/file/3664225?source=view_game&as_props=1' -Method Post -WebSession $assetSession -Body @{ csrf_token = $token } -TimeoutSec 30
if (-not $download.url) { throw 'Official free download was unavailable.' }
Invoke-WebRequest -Uri $download.url -OutFile $archive -TimeoutSec 60
Expand-Archive -LiteralPath $archive -DestinationPath $tempRoot -Force
Copy-Item -LiteralPath (Join-Path $tempRoot 'NightBorne.png') -Destination (Join-Path $assetRoot 'NightBorne.png')
Write-Output 'NIGHTBORNE_ASSET_READY Sprites/nightborne/NightBorne.png'
