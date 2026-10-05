# Boss Animation Artwork

Asset: Demon - Flare sprite sheets
Author: ryan.dansie (sprite rendering), umask007 (animated daemon model).
Source: https://opengameart.org/content/demon-flare-sprite-sheets
Original model: https://opengameart.org/content/animated-daemon
Original file: https://opengameart.org/sites/default/files/demon_0.png
License selected: CC0 1.0 Universal
License URL: https://creativecommons.org/publicdomain/zero/1.0/

The sprite submission explicitly offers CC0. No paid assets or extracted
commercial game artwork are used. Attribution is retained as a courtesy.

Project changes: rearranged frames into eight direction atlases to stay within
GPU texture limits. In-game recoloring, emissive wing edges, rune orbit effects,
charge and dash effects are implemented by project code and shaders.

Original animations per direction: idle 4, walk 9, attack 5, second attack 5,
cast 6, flinch 2, death 11 (42 distinct frames per direction, eight directions).
Rebuild: download the original file into `.godot/boss-source.png`, then run
Godot headless with `--script res://tools/build_boss_sprites.gd`.
