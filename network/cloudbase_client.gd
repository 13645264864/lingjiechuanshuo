extends Node

const CONFIG_PATH = "res://network/cloudbase_config.json"
var base_url := ""
var publishable_key := ""
var access_token := ""
var user_id := ""
var busy := false

func _ready():
	var config = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if config is Dictionary:
		base_url = "https://%s.api.tcloudbasegateway.com" % config.get("environment_id", "")
		publishable_key = config.get("publishable_key", "")

func login(username: String, password: String) -> Dictionary:
	logout()
	var reply = await _request("/auth/v1/signin", HTTPClient.METHOD_POST,
		{"username": username.strip_edges(), "password": password}, publishable_key)
	if reply.ok:
		var data = reply.data
		if not data is Dictionary or str(data.get("access_token", "")).is_empty() or str(data.get("sub", "")).is_empty():
			return {"ok": false, "message": "登录响应缺少有效凭证"}
		access_token = data.access_token
		user_id = data.sub
	return reply

func logout():
	# Prototype sessions are memory-only; no passwords or tokens are written to disk.
	access_token = ""
	user_id = ""

func read_character() -> Dictionary:
	return await _request("/v1/rdb/rest/cultivation_characters?select=*&limit=1", HTTPClient.METHOD_GET)

func create_character(display_name: String) -> Dictionary:
	return await _request("/v1/rdb/rest/rpc/create_cultivation_character", HTTPClient.METHOD_POST,
		{"p_display_name": display_name.strip_edges()})

func claim() -> Dictionary:
	return await _request("/v1/rdb/rest/rpc/claim_cultivation", HTTPClient.METHOD_POST, {})

func _request(path: String, method: int, payload: Dictionary = {}, token: String = "") -> Dictionary:
	if busy:
		return {"ok": false, "message": "请求处理中，请稍后"}
	var bearer := token if not token.is_empty() else access_token
	if bearer.is_empty():
		return {"ok": false, "message": "请先登录"}
	busy = true
	var request := HTTPRequest.new()
	request.timeout = 20.0
	request.body_size_limit = 1048576
	add_child(request)
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json", "Authorization: Bearer " + bearer])
	var body := "" if method == HTTPClient.METHOD_GET else JSON.stringify(payload)
	var error := request.request(base_url + path, headers, method, body)
	if error != OK:
		request.queue_free()
		busy = false
		return {"ok": false, "message": "无法发起网络请求"}
	var response = await request.request_completed
	request.queue_free()
	busy = false
	if response[0] != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "message": "网络连接失败或超时，请稍后重试"}
	var status: int = response[1]
	var data = JSON.parse_string(response[3].get_string_from_utf8())
	if status < 200 or status >= 300:
		if status == 401:
			logout()
		var message := "请求失败（%d）" % status
		if data is Dictionary:
			message = str(data.get("error_description", data.get("message", data.get("error", message))))
		return {"ok": false, "status": status, "message": message}
	return {"ok": true, "status": status, "data": data}
