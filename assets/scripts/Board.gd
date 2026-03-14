extends Node3D
class_name Board

const SIZE = 7
const TILE_SIZE = 1.0

# Sinais: O Board só "fala", ele não decide o que a UI faz.
signal piece_ejected(tile_node: Node)
signal pushing_animation_finished


@onready var player_scene: PackedScene = preload("res://assets/scenes/Player.tscn")
@onready var tile_scene : PackedScene = preload("res://assets/scenes/Tile.tscn")
@onready var tile_area: Node3D = $TileArea
@onready var board_base: MeshInstance3D = $BoardBase

var current_hand: TileInfo
var preview_tile: Tile = null
var last_move: int = -1:
	set(value):
		last_move = value
		var opposite_index = get_opposite_index(last_move)
		for arrow: Decal in board_base.get_children():
			if arrow.name.ends_with(str(opposite_index)):
				arrow.modulate = Color.BLACK
			else:
				arrow.modulate = Color.WHITE
		
var is_animating: bool = false

var fixed_tiles: Array[TileInfo] = [
	TileInfo.fromDict({ "grid_position": Vector2i(0, 0), "rotation": 1, "type": 1, "color": 0, "fixed": true, "symbol": -1 }),
	TileInfo.fromDict({ "grid_position": Vector2i(6, 0), "rotation": 2, "type": 1, "color": 1, "fixed": true, "symbol": -1 }),
	TileInfo.fromDict({ "grid_position": Vector2i(6, 6), "rotation": 3, "type": 1, "color": 2, "fixed": true, "symbol": -1 }),
	TileInfo.fromDict({ "grid_position": Vector2i(0, 6), "rotation": 0, "type": 1, "color": 3, "fixed": true, "symbol": -1 }),
	TileInfo.fromDict({ "grid_position": Vector2i(2, 0), "rotation": 2, "type": 2, "fixed": true, "symbol": 22 }),
	TileInfo.fromDict({ "grid_position": Vector2i(4, 0), "rotation": 2, "type": 2, "fixed": true, "symbol": 21 }),
	TileInfo.fromDict({ "grid_position": Vector2i(0, 2), "rotation": 1, "type": 2, "fixed": true, "symbol": 14 }),
	TileInfo.fromDict({ "grid_position": Vector2i(2, 2), "rotation": 1, "type": 2, "fixed": true, "symbol": 16 }),
	TileInfo.fromDict({ "grid_position": Vector2i(4, 2), "rotation": 2, "type": 2, "fixed": true, "symbol": 15 }),
	TileInfo.fromDict({ "grid_position": Vector2i(6, 2), "rotation": 3, "type": 2, "fixed": true, "symbol": 17 }),
	TileInfo.fromDict({ "grid_position": Vector2i(0, 4), "rotation": 1, "type": 2, "fixed": true, "symbol": 0 }),
	TileInfo.fromDict({ "grid_position": Vector2i(2, 4), "rotation": 0, "type": 2, "fixed": true, "symbol": 7 }),
	TileInfo.fromDict({ "grid_position": Vector2i(4, 4), "rotation": 3, "type": 2, "fixed": true, "symbol": 5 }),
	TileInfo.fromDict({ "grid_position": Vector2i(6, 4), "rotation": 3, "type": 2, "fixed": true, "symbol": 11 }),
	TileInfo.fromDict({ "grid_position": Vector2i(2, 6), "rotation": 0, "type": 2, "fixed": true, "symbol": 1 }),
	TileInfo.fromDict({ "grid_position": Vector2i(4, 6), "rotation": 0, "type": 2, "fixed": true, "symbol": 2 })
]

var data:Array[Dictionary]:
	get():
		# Le todas as peças do tabuleiro e transforma em um array
		var ret:Array[Dictionary] = []
		for tile in tile_area.get_children():
			if tile.is_in_group("tiles"):				
				var dict = tile.data
				# Atualiza o grid_position
				var grid_position = world_to_grid(tile.position.x, tile.position.z)			
				dict.grid_position = grid_position
				ret.append(dict.toDict())
						
		# Adiciona a mão
		ret.append(current_hand.toDict())
		return ret
		
func get_data_for_sync() -> Dictionary:
	var ret = {
		"data": data,
		"last_move": last_move
	}
	return ret
		
func grid_to_world(x:int, y:int) -> Vector3:
	var offset = (SIZE - 1) * TILE_SIZE / 2.0
	return Vector3(
		x * TILE_SIZE - offset,
		0.1,
		y * TILE_SIZE - offset
	)
func world_to_grid(wx: float, wz: float) -> Vector2i:
	var offset = (SIZE - 1) * TILE_SIZE / 2.0
	return Vector2i(round(wx + offset) / TILE_SIZE, round(wz + offset) / TILE_SIZE)
	
func get_tile_at(gx: int, gy: int) -> Node3D:
	for child in tile_area.get_children():
		if child == preview_tile: continue
		if not child.is_in_group("tiles"): continue
		var local: Vector2i = world_to_grid(child.position.x, child.position.z)
		if local.x == gx and local.y == gy:
			return child
	return null
		
		
		
func _create_piece(tile_info: TileInfo) -> void:
	var tile: Tile = tile_scene.instantiate()
	tile_area.add_child(tile)
	tile.setup(tile_info)
	var world_pos = grid_to_world(tile_info.grid_position.x, tile_info.grid_position.y)
	tile.position = world_pos
	
func init_board(pieces_data: Array[TileInfo] = []) -> void:	
	# Gera peças do tabuleiro e mão
	if pieces_data.size() == 0:
		pieces_data = _generate_pieces_data()

	# Pega a última peça gerada e atribui como mão
	current_hand = pieces_data.pop_back()
	
	# Adiciona peças no tabuleiro
	for piece_data:TileInfo in pieces_data:
		_create_piece(piece_data)

func clear() -> void:
	for child in tile_area.get_children(): 
		child.queue_free()

func _generate_pieces_data() -> Array[TileInfo]:
	var state:Array[TileInfo] = []
	var loose_pieces = _generate_loose_pieces()
	loose_pieces.shuffle()
	
	# Mapa de posições fixas para não sobrepor
	var fixed_positions = {}
	for d:TileInfo in fixed_tiles:
		fixed_positions[d.grid_position] = d
		state.append(d)
	
	# Preenche o resto
	for y in range(SIZE):
		for x in range(SIZE):
			var pos = Vector2i(x, y)
			if not fixed_positions.has(pos):
				if loose_pieces.size() > 0:
					var res:TileInfo = loose_pieces.pop_back()
					res.grid_position = pos
					state.append(res)
				else:
					print("Eror add peça: ", pos, " Agora estou com: ", loose_pieces.size())
					push_error("ERRO: Pool de peças acabou antes de preencher o grid!")
	
	# A peça que sobrou no pool vai para o final do array (será a mão)
	var last_piece = loose_pieces[0]
	state.append(last_piece)
	
	return state

func _generate_loose_pieces() -> Array[TileInfo]:
	var list: Array[TileInfo] = []
	
	# Símbolos (Tipo 2)
	for s in [23, 10, 12, 13, 6, 3, 4]:
		list.append(TileInfo.fromDict({"type": 2, "symbol": s, "rotation": randi() % 4}))
	
	# Símbolos (Tipo 0)
	for s in [20, 19, 18, 9, 8]:
		list.append(TileInfo.fromDict({"type": 2, "symbol": s, "rotation": randi() % 4}))
		
	# Genéricas (11 de cada tipo: 1 = Reta, 0 = Curva)
	for i in range(11):
		list.append(TileInfo.fromDict({"type": 1, "rotation": randi() % 4}))
		list.append(TileInfo.fromDict({"type": 0, "rotation": randi() % 4}))
	
	return list
	
func add_player(player_info: PlayerInfo) -> Node:
	var player: Player = player_scene.instantiate()
	player.add_to_group("players") # Grupo para facilitar busca
	tile_area.add_child(player)
	player.setup(player_info)
	player.position = grid_to_world(player_info.grid_position.x, player_info.grid_position.y)
	player.position.y = 0.25
	player.name = player_info.name
	return player

func update_preview() -> void:
	
	var pos = get_mouse_board_position()
	if not pos: return
	
	# Colunas e linhas permitidas (1, 3, 5)
	var valid_lanes = [1, 3, 5]
	var is_valid = (pos.x in valid_lanes and (pos.y == -1 or pos.y == SIZE)) or \
				   (pos.y in valid_lanes and (pos.x == -1 or pos.x == SIZE))
	
	if is_valid and not is_animating:
		_show_preview(pos.x, pos.y)
	else:
		_hide_preview()
		
func _show_preview(gx: int, gy: int) -> void:
	if not preview_tile:
		preview_tile = tile_scene.instantiate()
		preview_tile.alpha = 0.5
		preview_tile.remove_from_group("tiles")
		tile_area.add_child(preview_tile)
	
	preview_tile.setup(current_hand) # Atualiza o visual da peça fantasma
	preview_tile.position = grid_to_world(gx, gy)
	preview_tile.visible = true

func _hide_preview() -> void:
	if preview_tile: 
		preview_tile.visible = false
	

func get_mouse_board_position() -> Variant:
	var mouse = get_viewport().get_mouse_position()
	var camera = $CameraPivot/Camera3D

	var ray_origin = camera.project_ray_origin(mouse)
	var ray_dir = camera.project_ray_normal(mouse)

	var plane = Plane(Vector3.UP, 0)
	var pos = plane.intersects_ray(ray_origin, ray_dir)
	
	if not pos: return null

	var local_pos = tile_area.to_local(pos)	
	var gy = int(floor(local_pos.z + 0.5)) + 3
	var gx = int(floor(local_pos.x + 0.5)) + 3
	
	return Vector2i(gx, gy)
	
# Valida se o movimento é valido
# Para ser válido o movimento não pode ser contrário ao anterior
func validate_push(arrow_index: int) -> bool:
	if last_move == -1: # -1 significa que nenhum movimento foi feito ainda
		return true
	
	if is_animating:
		return false

	var opposite_index = get_opposite_index(last_move)
	
	return arrow_index != opposite_index
	
	
func execute_push_by_index(index: int, hand_data: TileInfo) -> void:
	var gx: int
	var gy: int
	
	match index:
		0: gx = 1; gy = -1
		1: gx = 3; gy = -1
		2: gx = 5; gy = -1
		3: gx = SIZE; gy = 1
		4: gx = SIZE; gy = 3
		5: gx = SIZE; gy = 5
		6: gx = 5; gy = SIZE
		7: gx = 3; gy = SIZE
		8: gx = 1; gy = SIZE
		9: gx = -1; gy = 5
		10: gx = -1; gy = 3
		11: gx = -1; gy = 1
	
	# Atualizamos o dado da mão local para o que veio da rede (garante rotação igual)
	current_hand = hand_data
	
	# Chamamos sua função original de animação!
	_do_insert_animation(gx, gy)
	last_move = index

func _do_insert_animation(gx:int, gy:int) -> void:
	is_animating = true
	_hide_preview()

	var new_tile = tile_scene.instantiate()
	tile_area.add_child(new_tile)

	new_tile.setup(current_hand)
	new_tile.position = grid_to_world(gx, gy)

	var dir = Vector2.ZERO

	if gx == -1: dir = Vector2.RIGHT
	elif gx == SIZE: dir = Vector2.LEFT
	elif gy == -1: dir = Vector2.DOWN
	elif gy == SIZE: dir = Vector2.UP

	var tween = create_tween().set_parallel(true)
	var ejected_tile: Node3D = null

	for child in tile_area.get_children():

		if child == preview_tile:
			continue

		var pos = child.position
		var c_gx = round(pos.x)
		var c_gy = round(pos.z)

		var in_lane = (dir.x != 0 and c_gy + 3 == gy) or (dir.y != 0 and c_gx + 3 == gx)

		if in_lane:

			var target = pos + Vector3(dir.x, 0, dir.y)

			tween.tween_property(
				child,
				"position",
				target,
				0.4
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)

			# Se este "child" for o jogador, precisamos atualizar a lógica dele
			if child.is_in_group("players"):
				_handle_player_wrap(child, target, dir)
				continue

			var next_gx = round(target.x)
			var next_gy = round(target.z)
			
			if next_gx < -3 or next_gx > 3 or next_gy < -3 or next_gy > 3:
				ejected_tile = child

	await tween.finished

	if ejected_tile:
		piece_ejected.emit(ejected_tile)		

	is_animating = false
	pushing_animation_finished.emit()

# Função auxiliar para o "loop" do jogador nas bordas
func _handle_player_wrap(player_node: Node, target_pos: Vector3, _push_dir: Vector2):
	var grid_pos = world_to_grid(target_pos.x, target_pos.z)
	var gx = grid_pos.x
	var gy = grid_pos.y

	var needs_wrap = (gx < 0 or gx >= SIZE or gy < 0 or gy >= SIZE)

	if needs_wrap:
		# Lógica de "Loop": Se saiu por um lado, entra pelo outro
		if gx < 0: gx = SIZE - 1
		elif gx >= SIZE: gx = 0
		elif gy < 0: gy = SIZE - 1
		elif gy >= SIZE: gy = 0

		# Atualizamos a lógica imediatamente
		player_node.info.grid_position = Vector2i(gx, gy)

		self.pushing_animation_finished.connect(func():
				player_node.position = grid_to_world(gx, gy)
				# Opcional: Efeito visual para disfarçar o teleporte
				var t = create_tween()
				player_node.scale = Vector3.ZERO
				t.tween_property(player_node, "scale", Vector3.ONE, 1).set_trans(Tween.TRANS_BACK)				
				,
		 CONNECT_ONE_SHOT)
	else:
		# Movimento normal: apenas atualiza a posição lógica
		player_node.info.grid_position = Vector2i(gx, gy)
		
func organize_players_in_tile(grid_pos: Vector2i):
	for id in NetworkManager.players:
		var info = NetworkManager.players[id]
		if info.grid_position == grid_pos:
			var node = tile_area.get_node(info.name)
			if node:
				var target_offset = get_dynamic_offset(grid_pos, id)
				var base_world_pos = grid_to_world(grid_pos.x, grid_pos.y)
				base_world_pos.y = 0.25
				
				# Tween suave para os peões se "chegarem para o lado"
				create_tween().tween_property(node, "position", base_world_pos + target_offset, 0.2)\
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
					
func get_dynamic_offset(target_pos: Vector2i, player_id: int) -> Vector3:
	var players_in_tile = []
	
	# 1. Encontrar todos os IDs que estão na mesma posição
	for id in NetworkManager.players:
		if NetworkManager.players[id].grid_position == target_pos:
			players_in_tile.append(id)
	
	# Se só tem um, ele fica no centro
	if players_in_tile.size() <= 1:
		return Vector3.ZERO
		
	# 2. Se houver mais de um, define a posição baseada na ordem do ID
	players_in_tile.sort()
	var my_rank = players_in_tile.find(player_id)
	
	var gap = 0.2 # Distância do deslocamento
	match my_rank:
		0: return Vector3(-gap, 0,  -gap) # Noroeste
		1: return Vector3(gap,  0, -gap)  # Nordeste
		2: return Vector3(-gap, 0,  gap)  # Sudoeste
		3: return Vector3(gap,  0, gap)   # Sudeste
	
	return Vector3.ZERO
	
func get_hovered_arrow_index() -> int:
	var pos = get_mouse_board_position()
		
	# Mapeamento baseado nas suas lanes (1, 3, 5)
	if pos.y == -1: # Topo (0, 1, 2)
		if pos.x == 1: return 0
		if pos.x == 3: return 1
		if pos.x == 5: return 2
	elif pos.x == SIZE: # Direita (3, 4, 5)
		if pos.y == 1: return 3
		if pos.y == 3: return 4
		if pos.y == 5: return 5
	elif pos.y == SIZE: # Baixo (6, 7, 8)
		if pos.x == 5: return 6
		if pos.x == 3: return 7
		if pos.x == 1: return 8
	elif pos.x == -1: # Esquerda (9, 10, 11)
		if pos.y == 5: return 9
		if pos.y == 3: return 10
		if pos.y == 1: return 11
		
	return -1
	
func get_opposite_index(index: int) -> int:
	# Eixo Vertical (Topo vs Baixo)
	if index <= 2: return 8 - index     # 0->8, 1->7, 2->6
	if index >= 6 and index <= 8: return 8 - index # 8->0, 7->1, 6->2
	
	# Eixo Horizontal (Direita vs Esquerda)
	if index >= 3 and index <= 5: return 14 - index # 3->11, 4->10, 5->9
	if index >= 9 and index <= 11: return 14 - index # 11->3, 10->4, 9->5
	
	return -1

func _get_player_node_by_name(player_name: String) -> Node:
	for c in tile_area.get_children():
		if c.is_in_group("players"):
			if c.info.name == player_name:
				return c
	return null

func _is_valid_pos(p: Vector2i) -> bool:
	# Verifica se o X está entre 0 e 6 (tamanho - 1)
	var x_ok = p.x >= 0 and p.x < SIZE
	# Verifica se o Y está entre 0 e 6 (tamanho - 1)
	var y_ok = p.y >= 0 and p.y < SIZE
	
	# Só retorna verdadeiro se ambos estiverem dentro do limite
	return x_ok and y_ok

func try_move_to_position(current_player: PlayerInfo, target_pos: Vector2i) -> Array[Vector2i]:
	if not _is_valid_pos(target_pos): return []
	
	# Busca o caminho localmente para validar se existe
	return Pathfinder.find_path(current_player.grid_position, target_pos, self)

func animate_path_movement(node: Node, path: Array[Vector2i]) -> void:
	# NetworkManager.debug_print("Movendo o player: ", info.name, "pos: ", info.grid_position, " path[0]: ", path[0], " destino: ", path[path.size() - 1] )
	is_animating = true
	
	# Começamos do índice 1 porque o 0 é onde o player já está
	for i in range(1, path.size()):
		var next_step = Vector2i(path[i])
		
		var target_world_pos = grid_to_world(next_step.x, next_step.y)
		target_world_pos.y = 0.25
		Transition.play_sound(Transition.Audio.STEP)

		var tween = create_tween()
		# Animação de "pulo" ou caminhada
		tween.tween_property(node, "position", target_world_pos, 0.2)\
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		# Espera este passo terminar antes de ir para o próximo
		await tween.finished
	
	is_animating = false

func highlight_player(player_name: String) -> void:
	var player: Player = _get_player_node_by_name(player_name)
	if player:
		player.highlight()
