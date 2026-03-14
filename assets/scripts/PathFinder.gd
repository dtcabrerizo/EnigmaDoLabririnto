extends RefCounted
class_name Pathfinder

# Esta função é o ponto de entrada principal
static func find_path(start: Vector2i, target: Vector2i, board: Board) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var came_from: Dictionary = {start: null} # Guarda de onde viemos para cada célula
	
	var head = 0
	while head < queue.size():
		var current = queue[head]
		head += 1
		
		if current == target:
			return _reconstruct_path(came_from, target)
		
		for dir_idx in range(4):
			var neighbor = current + _get_dir_vector(dir_idx)
			
			if _is_within_bounds(neighbor, board.SIZE) and not neighbor in came_from:
				if _are_connected(current, neighbor, dir_idx, board):
					came_from[neighbor] = current
					queue.push_back(neighbor)
					
	return [] # Caminho não encontrado

static func _reconstruct_path(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	
	# Usamos uma variável Variant (sem tipo fixo) para permitir o valor null
	var temp = current
	
	while temp != null:
		# Como sabemos que o que está vindo é um Vector2i antes do null, 
		# podemos adicionar ao array de Vector2i
		path.push_front(temp)
		
		# Pega o próximo da trilha. O dicionário retornará null para o ponto inicial.
		temp = came_from[temp]
		
	return path

# Verifica se a peça A e B têm caminhos que se conectam
static func _are_connected(pos_a: Vector2i, pos_b: Vector2i, dir_from_a: int, board: Board) -> bool:
	var tile_a = board.get_tile_at(pos_a.x, pos_a.y)
	var tile_b = board.get_tile_at(pos_b.x, pos_b.y)
	
	if not tile_a or not tile_b: return false
	
	var exits_a = tile_a.data.get_exits()
	var exits_b = tile_b.data.get_exits()
	
	# Para A conectar com B, A precisa ter saída na direção X 
	# e B precisa ter entrada na direção oposta (X + 2)
	var opposite_dir = (dir_from_a + 2) % 4
	
	return (dir_from_a in exits_a) and (opposite_dir in exits_b)

static func _get_dir_vector(dir: int) -> Vector2i:
	return [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0)][dir]

static func _is_within_bounds(p: Vector2i, size: int) -> bool:
	return p.x >= 0 and p.x < size and p.y >= 0 and p.y < size
