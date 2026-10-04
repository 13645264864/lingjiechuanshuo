extends Area2D
@export var aura_value:float = 10.0 #这个灵气球给多少修为

func _on_body_entered(body):
	if body.has_method("add_aura"):
		body.add_aura(aura_value)
		queue_free()

func _ready():
	body_entered.connect(_on_body_entered)
