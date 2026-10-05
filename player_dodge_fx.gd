extends Node2D

const NEON_SHADER = preload("res://dodge_afterimage.gdshader")
var elapsed := 0.0
var duration := 0.25

func setup(source: Polygon2D, color: Color):
	add_to_group("dodge_afterimage")
	var ghost := Polygon2D.new()
	ghost.texture = source.texture
	ghost.polygon = source.polygon
	ghost.uv = source.uv
	ghost.polygons = source.polygons
	ghost.color = Color.WHITE
	var neon_material := ShaderMaterial.new()
	neon_material.shader = NEON_SHADER
	neon_material.set_shader_parameter("neon_color", color)
	ghost.material = neon_material
	add_child(ghost)
	ghost.global_transform = source.global_transform

func _process(delta: float):
	elapsed += delta
	modulate.a = pow(maxf(1.0 - elapsed / duration, 0.0), 1.5)
	if elapsed >= duration:
		queue_free()
