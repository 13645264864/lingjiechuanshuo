extends SceneTree

var failures := 0

func _initialize():
	call_deferred("run")

func check(value: bool, description: String):
	print("PASS " if value else "FAIL ", description)
	if not value: failures += 1

func run():
	var account_path := OS.get_environment("CHUMOWUJIN_TEST_ACCOUNT")
	if account_path.is_empty():
		printerr("Set CHUMOWUJIN_TEST_ACCOUNT to an ignored local JSON containing username/password.")
		quit(2)
		return
	var account = JSON.parse_string(FileAccess.get_file_as_string(account_path))
	var client = load("res://network/cloudbase_client.gd").new()
	root.add_child(client)
	var reply = await client.login(account.username, account.password)
	check(reply.ok and not client.user_id.is_empty(), "Real Godot HTTPS login")
	if not reply.ok:
		print(reply.get("message", "login failed"))
		quit(1)
		return
	reply = await client.create_character("接入测试")
	check(reply.ok, "Idempotent character creation")
	reply = await client.read_character()
	check(reply.ok and reply.data is Array and reply.data.size() == 1, "Read own character")
	var owner: String = client.user_id
	reply = await client.claim()
	check(reply.ok and reply.data is Dictionary, "Claim server-calculated cultivation")
	var first: int = int(reply.data.character.cultivation) if reply.ok else -1
	reply = await client.claim()
	check(reply.ok and int(reply.data.reward) == 0 and int(reply.data.character.cultivation) == first, "Immediate duplicate claim grants zero")
	client.logout()
	check(client.access_token.is_empty(), "Logout clears in-memory session")
	reply = await client.login(account.username, account.password)
	check(reply.ok and client.user_id == owner, "Relogin keeps account identity")
	reply = await client.read_character()
	check(reply.ok and reply.data.size() == 1 and int(reply.data[0].cultivation) == first, "Persistent server character after relogin")
	print("CLOUDBASE_TEST_RESULT failures=", failures)
	quit(0 if failures == 0 else 1)
