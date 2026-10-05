extends Control

const CLIENT = preload("res://network/cloudbase_client.gd")
var client: Node
var username: LineEdit
var password: LineEdit
var nickname: LineEdit
var status: Label
var buttons: Array[Button] = []

func _ready():
	client = CLIENT.new()
	add_child(client)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	var title := Label.new()
	title.text = "除魔务尽 · 联网内测"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var notice := Label.new()
	notice.text = "使用预先创建的测试账号。凭证仅保存在本次运行内存。\n本入口连接腾讯云，发送账号登录信息并保存角色及修为。\n正式发布前需更新隐私政策与账号管理功能。"
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notice)
	username = _field(column, "用户名", false)
	password = _field(column, "密码", true)
	nickname = _field(column, "角色名字（1～16 字）", false)
	_button(column, "登录并读取角色", _login)
	_button(column, "创建角色", _create)
	_button(column, "刷新角色", _read)
	_button(column, "领取修为（每分钟 1 点，最多 12 小时）", _claim)
	_button(column, "退出账号", _logout)
	_button(column, "返回离线主菜单", func(): get_tree().change_scene_to_file("res://main_menu.tscn"))
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = "请输入测试账号登录。"
	column.add_child(status)

func _field(column: VBoxContainer, placeholder: String, secret: bool) -> LineEdit:
	var field := LineEdit.new()
	field.placeholder_text = placeholder
	field.secret = secret
	field.max_length = 128
	field.custom_minimum_size.y = 48
	column.add_child(field)
	return field

func _button(column: VBoxContainer, text: String, action: Callable):
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 48
	button.pressed.connect(action)
	column.add_child(button)
	buttons.append(button)

func _working(value: bool):
	for button in buttons:
		button.disabled = value
	if value: status.text = "连接服务器中……"

func _login():
	_working(true)
	var reply = await client.login(username.text, password.text)
	password.clear()
	if reply.ok: reply = await client.read_character()
	_show(reply)
	_working(false)

func _create():
	_working(true)
	_show(await client.create_character(nickname.text))
	_working(false)

func _read():
	_working(true)
	_show(await client.read_character())
	_working(false)

func _claim():
	_working(true)
	var reply = await client.claim()
	_show(reply)
	if reply.ok and reply.data is Dictionary:
		status.text += "\n本次领取：%s 点修为" % reply.data.get("reward", 0)
	_working(false)

func _logout():
	client.logout()
	password.clear()
	status.text = "已退出账号。"

func _show(reply: Dictionary):
	if not reply.ok:
		status.text = reply.get("message", "请求失败")
		return
	var row = reply.data
	if row is Array:
		if row.is_empty():
			status.text = "登录成功，尚无角色。输入角色名字后点击创建角色。"
			return
		row = row[0]
	if row is Dictionary and row.has("character"): row = row.character
	if row is Dictionary:
		status.text = "角色：%s\n境界阶段：%s\n修为：%s\n上次结算：%s" % [row.get("display_name", ""), row.get("realm", 0), row.get("cultivation", 0), row.get("last_claim_at", "")]
	else: status.text = "服务器响应格式异常，请稍后重试。"
