param([string]$SourceDirectory = 'C:\Users\23604\Desktop\Arcane archer\Arcane archer')
$ErrorActionPreference = 'Stop'
$destination = Join-Path (Split-Path -Parent $PSScriptRoot) 'Sprites/arcane_archer'
New-Item -ItemType Directory -Force -Path $destination | Out-Null
foreach ($name in @('spritesheet.png', 'projectile.png')) {
    Copy-Item -LiteralPath (Join-Path $SourceDirectory $name) -Destination (Join-Path $destination $name)
}
