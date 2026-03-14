extends Node3D
class_name Player

@onready var mesh: MeshInstance3D = $Mesh
@onready var arrow: Sprite3D = $Arrow

@export var color: Color:
	set(value):
		color = value
		if is_inside_tree():
			_update_visuals()

var info: PlayerInfo

func _ready() -> void:
	_update_visuals()

func _update_visuals() -> void:
	var material: StandardMaterial3D = mesh.get_active_material(0).duplicate()
	material.albedo_color = color
	mesh.material_override = material
	
	arrow.modulate = color
	
func setup(player_info: PlayerInfo) -> void:
	info = player_info
	color = player_info.color_rgb
	
	
func highlight() -> void:	
	arrow.modulate.a = 0.0
	arrow.visible = true
	
	var tween: Tween = create_tween()
	
	# Fade in
	tween.tween_property(arrow, "modulate:a", 1.0, 0.4)
	
	# 3 pulos	
	for i in range(3):
		tween.tween_property(arrow, "position:y", 0.7, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(arrow, "position:y", 0.6, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# Fade out
	tween.tween_property(arrow, "modulate:a", 0.0, 0.4)
	
	await tween.finished
	arrow.visible = false
	
	
