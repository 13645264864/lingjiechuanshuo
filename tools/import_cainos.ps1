param(
    [string]$SourceDirectory = 'C:\Users\23604\Desktop\Pixel Art Top Down - Basic v1.2.3'
)
$ErrorActionPreference = 'Stop'
$textureSource = Join-Path $SourceDirectory 'Texture'
$assetDestination = Join-Path (Split-Path -Parent $PSScriptRoot) 'Sprites/cainos'
if (-not (Test-Path -LiteralPath $textureSource -PathType Container)) {
    throw 'Choose the unpacked official Cainos asset directory containing Texture.'
}
New-Item -ItemType Directory -Force -Path $assetDestination | Out-Null
foreach ($name in @('TX Tileset Grass.png', 'TX Tileset Stone Ground.png', 'TX Tileset Wall.png', 'TX Struct.png', 'TX Props.png', 'TX Plant.png', 'TX Shadow.png', 'TX Shadow Plant.png')) {
    Copy-Item -LiteralPath (Join-Path $textureSource $name) -Destination (Join-Path $assetDestination $name)
}
Write-Output 'CAINOS_ASSETS_READY Sprites/cainos'
