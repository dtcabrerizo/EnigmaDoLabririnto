extends Resource
class_name PlayerInfo

@export var id: int
@export var name: String = "Jogador"
@export var color: int = 0
@export var grid_position: Vector2i = Vector2i.ZERO
@export var home_position: Vector2i = Vector2i.ZERO
@export var order: int = 0

# Lista de IDs de símbolos que o jogador deve buscar
@export var targets: Array[int] = [] 
# Lista de IDs de símbolos que o jogador já coletou
@export var collected: Array[int] = []

@export var color_rgb: Color:
	get:
		return COLOR_MAP[color]

static var COLOR_MAP: Dictionary = {
	0: Color.BLUE,
	1: Color.GREEN,
	2: Color.RED,
	3: Color.YELLOW
}

static var CHAR_NAME: Array[String] = [
	"Lady Celeste",
	"Dama Olivia",
	"Sir Rouge",
	"Mestre Âmbar"
] 

func get_current_target() -> int:
	if targets.is_empty():
		return -1 # Ganhou o jogo ou não tem alvos
	return targets[0] # No Labirinto, você busca um por vez (o do topo da pilha)

func collect_current_target() -> void:
	var collected_id = targets.pop_front()
	collected.append(collected_id)
	
func toDict() -> Dictionary:
	return { 
		"id": id,
		"name": name,
		"order": order,
		"color": color,
		"grid_position": grid_position,
		"home_position": home_position,
		"targets": targets,
		"collected": collected
	}
	 
static func fromDict(new_info: Dictionary) -> PlayerInfo:
	
	var player_info = PlayerInfo.new()
	player_info.id =  new_info.get("id", 0)
	player_info.name =  new_info.get("name", "")
	player_info.order = new_info.get("order", 0)
	player_info.color =  new_info.get("color", 0)
	player_info.grid_position =  new_info.get("grid_position", Vector2i(0,0))
	player_info.home_position =  new_info.get("home_position", Vector2i(0,0))
	player_info.targets.assign(new_info.get("targets", []))
	player_info.collected.assign(new_info.get("collected", []))
	return player_info
	
