extends Control


var back_node: TextureRect
var symbol_node: TextureRect

func update(type: int, symbol: int) -> void:
	back_node = get_child(0)
	symbol_node = get_child(1)
	_update_back(type)
	_update_symbol(symbol)
	
func _update_rotation(angle: int) -> void:
	rotation_degrees = -angle * 90
	
func _update_back(tile_type: int) -> void:
	var texture: AtlasTexture = back_node.texture.duplicate()
	var x = float(tile_type) * 100
	texture.region = Rect2(x, 0.0, 100.0, 100.0)
	back_node.texture = texture

func _update_symbol(tile_symbol: int) -> void:	
	var texture: AtlasTexture = symbol_node.texture.duplicate()
	var x = tile_symbol % 6 * 80
	var y = floor(tile_symbol / 6.0) * 80
	texture.region = Rect2(x, y, 80.0, 80.0)
	symbol_node.texture = texture
	symbol_node.visible = tile_symbol >= 0
	

		
