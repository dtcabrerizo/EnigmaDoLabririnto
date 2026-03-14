extends Resource
class_name TileInfo

@export var type: int = 0
@export var symbol: int = -1
@export var rotation: int = 0
@export var color: int = -1
@export var fixed: bool = false
@export var grid_position: Vector2i = Vector2i.ZERO

@export var color_rgb: Color:
	get:
		if (color >= 0):
			return PlayerInfo.COLOR_MAP[color]
		return Color.BLACK

# Helper para converter rotação em graus
func get_rotation_degrees() -> float:
	return rotation * 90.0

func get_exits() -> Array[int]:
	var exits: Array[int] = []
	match type:
		0: exits = [1, 3]       # I (Leste, Oeste)
		1: exits = [0, 1]       # L (Norte, Leste)
		2: exits = [0, 1, 3]    # T (Norte, Leste, Oeste)
	
	var rotated_exits: Array[int] = []
	for e in exits:
		rotated_exits.append((e + rotation) % 4)
	return rotated_exits

static func fromDict(data: Dictionary) -> TileInfo:
	var res = TileInfo.new()
	res.type = data.get("type", 0)
	res.symbol = data.get("symbol", -1)
	res.rotation = data.get("rotation", 0)
	res.fixed = data.get("fixed", false)
	res.color = data.get("color", -1)
	res.grid_position = data.get("grid_position", Vector2i.ZERO)
	return res
	
func toDict() -> Dictionary:
	return {
		"type": type,
		"symbol": symbol,
		"rotation": rotation,
		"fixed": fixed,
		"color": color,
		"grid_position": grid_position
	}
