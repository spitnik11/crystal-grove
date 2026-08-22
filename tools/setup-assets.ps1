$ErrorActionPreference = 'Stop'

$library = 'Z:\pixel-art-library'
$destination = Join-Path $PSScriptRoot '..\third_party'
$assets = @{
    'ground.png' = 'godot-sandbox\assets\fields\FieldsTile_01.png'
    'tree.png' = 'godot-sandbox\assets\props\Tree1.png'
    'rock.png' = 'godot-sandbox\assets\props\Rock1_1.png'
    'crystal.png' = 'packs\craftpix-net-106469-top-down-crystals-pixel-art\PNG\Assets_texture_shadow\Blue_crystal3.png'
    'house.png' = 'packs\craftpix-net-504452-free-village-pixel-tileset-for-top-down-defense\2 Objects\7 House\1.png'
    'swordsman_walk.png' = 'packs\craftpix-net-180537-free-swordsman-1-3-level-pixel-top-down-sprite-character\PNG\Swordsman_lvl1\With_shadow\Swordsman_lvl1_Walk_with_shadow.png'
    'slime_walk.png' = 'packs\craftpix-net-788364-free-slime-mobs-pixel-art-top-down-sprite-pack\PNG\Slime1\With_shadow\Slime1_Walk_with_shadow.png'
}

New-Item -ItemType Directory -Force -Path $destination | Out-Null
foreach ($entry in $assets.GetEnumerator()) {
    $source = Join-Path $library $entry.Value
    if (-not (Test-Path -LiteralPath $source)) { throw "Missing library asset: $source" }
    Copy-Item -LiteralPath $source -Destination (Join-Path $destination $entry.Key) -Force
}
Write-Output "Installed $($assets.Count) local runtime assets."
