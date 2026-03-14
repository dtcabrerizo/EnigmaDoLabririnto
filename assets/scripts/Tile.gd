extends Node3D
class_name Tile

@onready var top: MeshInstance3D = $Top
@onready var base: MeshInstance3D = $Base

@export var data: TileInfo

@export var alpha: float = 1:
	set(value):
		alpha = value
		_update_visuals()

func setup(tile_data: TileInfo) -> void:
	data = tile_data
	_update_visuals()



func _update_visuals():
	if not data: return		
	
	var top_material: Material = top.get_active_material(0).duplicate()
	
	top_material.set_shader_parameter("tile_type", data.type)
	top_material.set_shader_parameter("symbol", data.symbol)
	top_material.set_shader_parameter("color", data.color)
	top_material.set_shader_parameter("alpha", alpha)
	top.set_surface_override_material(0, top_material)
	
	var base_material: StandardMaterial3D = base.get_active_material(0).duplicate()
	base_material.albedo_color.a = alpha
	base.set_surface_override_material(0, base_material)
			
	rotation_degrees.y = -data.rotation * 90


	
