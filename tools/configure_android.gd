extends SceneTree

func _initialize():
	configure.call_deferred()

func configure():
	var file := FileAccess.open("res://.tmp/android/toolchain.json", FileAccess.READ)
	if file == null:
		push_error("Run tools/prepare_android.py first")
		quit(1)
		return
	var paths: Dictionary = JSON.parse_string(file.get_as_text())
	var settings := EditorInterface.get_editor_settings()
	settings.set_setting("export/android/java_sdk_path", paths.java_home.replace("\\", "/"))
	settings.set_setting("export/android/android_sdk_path", paths.android_sdk.replace("\\", "/"))
	print("ANDROID_EDITOR_PATHS_CONFIGURED")
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	quit(0)
