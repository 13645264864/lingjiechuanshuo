extends SceneTree

# Run after placing the unmodified CC0 source in .godot/boss-source.png.
# Direction rows are W, NW, N, NE, E, SE, S, SW. Columns contain seven clips.
const CLIPS = [
	["idle", 0, 4, 7.0, true],
	["walk", 4, 9, 12.0, true],
	["attack", 13, 5, 15.0, false],
	["dash", 18, 5, 22.0, false],
	["cast", 23, 6, 10.0, false],
	["hurt", 29, 2, 12.0, false],
	["death", 31, 11, 14.0, false]
]

func _initialize():
	var source := Image.load_from_file("res://.godot/boss-source.png")
	if source == null or source.get_size() != Vector2i(10752, 2048):
		push_error("Expected complete 10752 x 2048 CC0 demon sheet")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://Sprites/boss")
	for direction in range(8):
		var atlas := Image.create(2816, 1792, false, Image.FORMAT_RGBA8)
		for row in range(CLIPS.size()):
			var clip: Array = CLIPS[row]
			for frame in range(clip[2]):
				atlas.blit_rect(source, Rect2i((clip[1] + frame) * 256, direction * 256, 256, 256), Vector2i(frame * 256, row * 256))
		var path := "res://Sprites/boss/demon_" + str(direction) + ".png"
		atlas.save_png(path)
	print("BOSS_ASSET_BUILD directions=8 actions=7 source_frames=336")
	quit(0)
