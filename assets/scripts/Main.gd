extends Node3D
class_name Main

@onready var board: Board = $Board
@onready var interface: Interface = $Interface

@onready var game_over_scene: PackedScene = preload("res://assets/scenes/GameOver.tscn")

enum GameState { STATE_INSERT, STATE_MOVE, STATE_WAITING, STATE_NULL }
var current_state = GameState.STATE_INSERT
var current_player: PlayerInfo

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Transition.play_bgm(Transition.BGM.GAME)
	# Conecta eventos do board
	board.piece_ejected.connect(_on_piece_ejected)
	board.pushing_animation_finished.connect(_on_board_pushing_animation_finished)
	interface.player_clicked.connect(_on_interface_player_clicked)
	
	NetworkManager.player_left.connect(_on_player_left)
	NetworkManager.player_joined.connect(_on_player_joined)
	
	# Se for o servidor, gera os dados e guarda na "memória"
	if multiplayer.is_server():
		NetworkManager.game_started = true
		
		# Host precisa iniciar o board
		board.init_board()		
		
		# Host cria a lista de targets dos players
		_setup_player_assignments()	
		
		# Host spawna seus próprios players
		# (os jogdaores farão isso depois)
		for id in NetworkManager.players:
			var player_info: PlayerInfo = NetworkManager.players[id]
			spawn_player(player_info)		
		
		# Host atualiza seu UI
		interface.update_ui_slot(board.current_hand)
		interface.update_char()	
		
		# Envia para quem já estiver pronto (incluindo o próprio host)
		# initial_setup.rpc(board.get_data_for_sync(), NetworkManager.get_players_array())
		
		# Inicia o primeiro turno via broadcast
		# TODO: por enquanto sempre começa com o HOST
		server_set_next_turn()
		client_set_turn.rpc(current_player.name)

	else:
		# Se for cliente, avisa ao servidor que a cena carregou e está prontas
		await get_tree().create_timer(1.0).timeout
		NetworkManager.debug_print("Solicitndo dados para o servidor...")		
		request_initial_data.rpc_id(1)

func _on_interface_player_clicked(player_info: PlayerInfo):
	board.highlight_player(player_info.name)
	
func spawn_player(player_info: PlayerInfo) -> void:
	# Instancia o peão do jogador		
	var spawned_node = board.add_player(player_info)
	spawned_node.name = player_info.name

	# Se este player_info for o MEU (local), eu guardo a referência
	if player_info.name == NetworkManager.local_player.name:
		interface.update_treasure_symbol(player_info.get_current_target())

func _process(_delta: float) -> void:
	# Se estiver no estado de inserir peça e for a vez do jogador local
	if board.current_hand and current_state == GameState.STATE_INSERT:		
		
		# Compara pelo nome pois o ID pode mudar se houver reconexão
		if current_player and current_player.name == NetworkManager.local_player.name:
			board.update_preview()

func _input(event: InputEvent) -> void:
	if not current_player: 
		return
	
	if NetworkManager.local_player.name != current_player.name: 
		return
	
	# Se já enviamos uma requisição e estamos esperando, ignoramos cliques extras
	if current_state == GameState.STATE_WAITING:
		return

	# Unificando Touch e Mouse
	var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	var is_touch = (event is InputEventScreenTouch and event.pressed)

	if is_click or is_touch:
		match current_state:
			GameState.STATE_INSERT:
				# NO MOBILE: Se o toque for na área da interface/mão, a gente gira. 
				# Se for no board, a gente insere.
				if board.is_animating:
					return
				elif _is_pos_on_ui(event.position):
					_rotate_current_hand()
				else:
					current_state = GameState.STATE_WAITING
					_request_insertion()					

			GameState.STATE_MOVE:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_handle_player_movement()
	
	# Mantém o botão direito para PC
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if current_state == GameState.STATE_INSERT:
			_rotate_current_hand()

func _is_pos_on_ui(pos: Vector2) -> bool:
	# Verifique se o toque foi em cima do Slot da Interface
	# Você pode usar o rect da sua interface.ui_slot para validar
	#return interface.get_ui_slot_rect().has_point(pos)
	return interface.get_piece_slot_rect().has_point(pos)
	
# Função que executa a rotação
func _rotate_current_hand() -> void:
	if not board.current_hand or board.is_animating:
		return

	# Aumenta a rotação (0 -> 1 -> 2 -> 3 -> 0...)
	board.current_hand.rotation = (board.current_hand.rotation + 1) % 4
	
	# 1. Atualiza visualmente o slot da UI
	interface.update_ui_slot(board.current_hand)
	
	# 2. O Board.gd já atualiza o preview no _process através do board.update_preview(current_hand)
	# mas se quiser forçar uma atualização imediata do preview:
	board.update_preview()

func _request_insertion():
	current_state = GameState.STATE_WAITING

	# 1. Descobrimos onde o mouse está tentando inserir no board
	var arrow_index = board.get_hovered_arrow_index()
	if arrow_index == -1: 
		# Não é possível inserir nessa linha/coluna
		current_state = GameState.STATE_INSERT
		return
	
	# 2. Enviamos para o servidor o índice da seta e a rotação da peça na mão (que eu estou vendo)
	server_process_insertion.rpc(arrow_index, board.current_hand.rotation)



@rpc("any_peer", "call_local", "reliable")
func server_process_insertion(arrow_index: int, piece_rotation: int) -> void:
	var caller_id = multiplayer.get_remote_sender_id()
	if not multiplayer.is_server(): return
	
	# Se o board não validar o movimento avisa o jogador para refazer a jogada
	if not board.validate_push(arrow_index):
		insertion_result.rpc_id(caller_id, false)
		return
	
	# Muda o estado no servidor IMEDIATAMENTE antes de avisar os clientes
	current_state = GameState.STATE_MOVE
	# O servidor avisa todos para executarem a inserção sincronizada
	client_execute_insertion.rpc(arrow_index, piece_rotation)
	
	# Avisa jogador que a inserção foi com sucesso
	insertion_result.rpc_id(caller_id, true)

@rpc("authority", "call_local", "reliable")
func insertion_result(success: bool) -> void:
	# Erro ao tentar inserir a peça dessa forma
	if success:
		current_state = GameState.STATE_MOVE
	else:	
		Transition.play_sound(Transition.Audio.WRONGMOVE)
		current_state = GameState.STATE_INSERT

@rpc("authority", "call_local", "reliable")
func client_execute_insertion(arrow_index: int, piece_rotation: int) -> void:
	# Ajustamos a rotação da nossa peça local para bater com a do jogador que jogou
	board.current_hand.rotation = piece_rotation

	# Chamamos a função do board que faz a animação de empurrar
	# Você precisará adaptar o insert_current_piece do seu Board.gd para aceitar o index
	board.execute_push_by_index(arrow_index, board.current_hand)

func _handle_player_movement() -> void:
	if board.is_animating or current_player.name != NetworkManager.local_player.name:
		return
	
	var target_pos = board.get_mouse_board_position()
	server_process_movement.rpc_id(1, target_pos)


@rpc("any_peer", "call_local", "reliable")
func server_process_movement(target_pos: Vector2i) -> void:	
	var caller_id: int = multiplayer.get_remote_sender_id()
	
	# Verifica se é possível fazer a movimentação selecionada
	if not multiplayer.is_server(): return
		
	
	var path = board.try_move_to_position(current_player, target_pos)
	if path.size() > 0:
		# AVISA TODOS: "Vou me mover por este caminho"
		# NetworkManager.debug_print("Sucesso no movimento de: ", caller_id, "=", current_player.id, "origem:", current_player.grid_position, " para: ", target_pos)
		sync_player_movement.rpc(current_player.name, path)
		movement_result.rpc_id(caller_id, true)
	else:
		# NetworkManager.debug_print("Falha no movimento de: ", caller_id, " para: ", target_pos)
		# Avisa jogador que o movimento falhou
		Transition.play_sound(Transition.Audio.WRONGMOVE)
		movement_result.rpc_id(caller_id, false)

# 2. Todos os clientes recebem o caminho e animam o peão correspondente
@rpc("any_peer", "call_local", "reliable")
func sync_player_movement(player_name: String, path: Array):
	
	# Procuramos o nó do peão pelo nome (que definimos como o ID no setup)
	var player_info = NetworkManager.get_player_by_name(player_name)
	var moving_node = board.tile_area.get_node(player_info.name)

	#NetworkManager.debug_print("Sincronizando no movimento de: ", player_name, " para: ", path[-1], " ", moving_node, " ", player_info,  )
	
	if moving_node and player_info:
		# 1. Antes de mover, a posição antiga vai ficar vazia (opcional: reorganizar a casa de onde ele saiu)
		var old_pos = player_info.grid_position
		
		await board.animate_path_movement(moving_node, path)

		# 2. Atualiza a posição lógica
		var target = path[-1]
		player_info.grid_position = target
		
		# 3. REORGANIZAR: Ajusta o offset de quem está na casa de destino
		board.organize_players_in_tile(target)
		# Opcional: Reorganizar também a casa de onde ele saiu
		board.organize_players_in_tile(old_pos)

		
		# Apenas o servidor valida se o tesouro foi obtido
		if multiplayer.is_server():
			if _server_check_treasure(current_player, target): 
				# Game Over
				print("GAME OVER")
				return
			
			server_request_next_turn()

	
@rpc("any_peer", "call_local", "reliable")
func server_request_next_turn() -> void:
	if not multiplayer.is_server(): return
	
	NetworkManager.debug_print("Enviando novo turno para os jogadores")
	server_set_next_turn()
	
	# 2. Avisar todos sobre a mudança
	client_set_turn.rpc(current_player.name)
	
@rpc("authority", "call_local", "reliable")
func movement_result(success: bool) -> void:
	# Se falhou a movimentação, exibe feedback e retorna estado
	if not success:
		var player_node = board.tile_area.get_node(NetworkManager.local_player.name)
		# Feedback de erro (ex: tremer o peão)
		var tween = create_tween()
		var original_pos = player_node.position
		tween.tween_property(player_node, "position", original_pos + Vector3(0.15, 0, 0), 0.05)
		tween.tween_property(player_node, "position", original_pos + Vector3(-0.15, 0, 0), 0.05)			
		tween.tween_property(player_node, "position", original_pos + Vector3(0, 0, 0), 0.05)
		current_state = GameState.STATE_MOVE
	
# Verifica se deve coletar tesouro ou finalziar jogo
func _server_check_treasure(player_info: PlayerInfo, pos: Vector2i) -> bool:	
	var tile = board.get_tile_at(pos.x, pos.y)
	
	if not tile or not player_info: return false
	
	var target_needed = player_info.get_current_target()
	
	#NetworkManager.debug_print("Validando tesouro de: ", player_info.name, " Need: ", target_needed, " got: ", tile.data.symbol)
	
	# Se o jogador ainda precisa de um tesouro
	if target_needed != -1:
		# Se o jogador alcançou o tesouro procurado
		if tile.data.symbol == target_needed:
			# O servidor avisa TODOS a executarem a animação e atualizarem os dados
			rpc_broadcast_treasure_collected.rpc(player_info.name, target_needed)
	# Se o jogador não precisa de um tesouro
	else:
		# Se o jogador voltou a sua casa inicial
		if pos == player_info.home_position:
			print("Temos um vencedor: ", player_info.name)
			rpc_broadcast_game_over.rpc(player_info.name, pos)
			return true
	
	return false

@rpc("authority", "call_local", "reliable")
func rpc_broadcast_game_over(winner_name: String, _pos: Vector2):
	NetworkManager.winner_name = winner_name
	set_process_input(false)
	
	# Pequeno delay para o jogador ver que chegou na casa inicial
	await get_tree().create_timer(1.0).timeout

	# Muda a cena	
	# NetworkManager.debug_print("Recebi mensagem de Game Over, mudando de cena...", board.grid_to_world(pos.x, pos.y))
	Transition.stop_bgm()
	Transition.fade_to_scene(game_over_scene)
	
@rpc("authority", "call_local", "reliable")
func rpc_broadcast_treasure_collected(player_name: String, symbol_id: int):
	var player_info = NetworkManager.get_player_by_name(player_name)

	# 1. Atualiza a lógica local (remover das metas, adicionar aos coletados)
	player_info.collect_current_target()

	# 2. Dispara a animação visual para todos os clientes (antes de mudar o current_user na troca de turno)
	interface.animate_card_collection_sync(player_info.name, symbol_id)	
	interface.update_lobby(current_player, current_state)
	Transition.play_sound(Transition.Audio.COLLECTED)


	# 3. Se for o jogador local, atualiza a UI (próximo alvo)
	# coloca um atraso de 1.5s para ajustar com a animação da carta
	if player_info.name == NetworkManager.local_player.name:
		#NetworkManager.debug_print("Atualizando simbolo do próximo tesouro: ", NetworkManager.local_player.get_current_target())	
		interface.update_treasure_symbol(NetworkManager.local_player.get_current_target())
		get_tree().create_timer(2.0).timeout.connect(func():
			interface.rebuild_pile(player_info.collected)
		)
		
	

func _on_piece_ejected(tile_node: Node) -> void:
	var next_hand_data = tile_node.data.duplicate()
	next_hand_data.grid_position = Vector2.ZERO # Limpa a posição pois agora está na mão
	board.current_hand = next_hand_data
	await interface.animate_fly_to_ui(tile_node)	
	interface.update_ui_slot(board.current_hand)

func _on_board_pushing_animation_finished() -> void:
	# O tabuleiro parou de mexer, agora o jogador pode mover o peão
	current_state = GameState.STATE_MOVE	
	interface.update_lobby(current_player, current_state)

func _on_player_left(player_id):
	var player_info = NetworkManager.players[player_id]
	Transition.show_toast("Jogador " + player_info.name + " desconectou da partida.")

func _on_player_joined(player_id):
	var player_info = NetworkManager.players[player_id]
	Transition.show_toast("Jogador " + player_info.name + " voltou a partida.")


func _setup_player_assignments() -> void:
	var all_symbols = range(0, 24) # DEBUG !!!
	all_symbols.shuffle()
	
	var player_ids = NetworkManager.players.keys()
	var cards_per_player = all_symbols.size() / player_ids.size()
	var card_index:int = 0
	
	for id in NetworkManager.players:
		
		var player_info: PlayerInfo = NetworkManager.players[id]
		#NetworkManager.debug_print("Configurando cartas e posição do player: ", player_info.name)
		
		# Atribui as cartas que vieram do servidor
		var start = card_index * cards_per_player
		var end = start + cards_per_player
		var cards = all_symbols.slice(start, end)
		player_info.targets.assign(cards)
		card_index += 1

@rpc("authority", "call_local", "reliable")
func initial_setup(board_data: Dictionary, players: Array, _current_player: Dictionary = {}, _state: GameState = GameState.STATE_NULL):
	# O servidor não precisa atualizar
	if multiplayer.is_server(): return
	if not is_node_ready():
		await ready # Garante que todos os @onready (como o board) já foram preenchidos
	
	NetworkManager.debug_print("Recebi informações do jogo: ", players, " state: ", _state, " turno: ", _current_player.name if _current_player else "")	

	# Cao ainda não tenha iniciado o turno tenta novamente
	if not _current_player:
		NetworkManager.debug_print("Não tenho info de turno, vou tentar de novo...")	
		await get_tree().create_timer(1.0).timeout
		request_initial_data.rpc_id(1)
		return
	
	# Limpa o tabuleiro caso haja algo (útil para restarts)
	board.clear()
	
	
	# Converte array serializado pelo network para um array de TileInfo
	var converted_board_data: Array[TileInfo] = []
	for data in board_data.data:
		converted_board_data.append(TileInfo.fromDict(data))
	
	NetworkManager.debug_print("Iniciando tabuleiro ", board_data)	
	
	board.init_board(converted_board_data)
	board.last_move = board_data.last_move
	
	if _current_player and _current_player.keys().size() > 0:
		current_player = PlayerInfo.fromDict(_current_player)
	
	if _state == GameState.STATE_NULL:
		current_state = _state
	
	# Atualiza players locais (substitui as infos que o client tem pelas que foi enviada pelo servidor)
	# obtém a posição do meu player para posicionar o meu spawn
	for player_data in players:
		var player:PlayerInfo = PlayerInfo.fromDict(player_data)
		NetworkManager.players[player.id] = player
		if player.name == NetworkManager.local_player.name:
			NetworkManager.local_player = player
		spawn_player(NetworkManager.players[player.id]) 

	interface.update_ui_slot(board.current_hand)
	interface.update_lobby(current_player, current_state)
	interface.update_char()
	
@rpc("any_peer", "call_local", "reliable")
func request_initial_data():
	if not multiplayer.is_server(): return
	
	if not is_node_ready():
		await ready # Garante que todos os @onready (como o board) já foram preenchidos
	
	var sender_id = multiplayer.get_remote_sender_id()
	
	NetworkManager.debug_print("Ciente: ", sender_id, " solicitou initial data")
	
	# O servidor envia os dados salvos especificamente para quem pediu
	initial_setup.rpc_id(
		sender_id, 
		board.get_data_for_sync(), 
		NetworkManager.get_players_array(), 
		current_player.toDict() if current_player else {}, 
		current_state
	)

func server_set_next_turn() -> void:
	
	var current_order = current_player.order if current_player else -1
	var next_order = (current_order + 1 ) % NetworkManager.players.size()
	
	var next_player: PlayerInfo = NetworkManager.get_player_by_order(next_order)
	
	current_player = next_player
	current_state = GameState.STATE_INSERT	

@rpc("authority", "call_local", "reliable")
func client_set_turn(player_name: String) -> void:	
	current_state = GameState.STATE_INSERT
	
	current_player = NetworkManager.get_player_by_name(player_name)	
	
	# Feedback visual (opcional)
	# NetworkManager.debug_print("Agora é a vez de: ",  current_player.name)
	
	interface.update_lobby(current_player, current_state)
	
	# Se for a MINHA vez, posso até dar um destaque na UI
	if player_name == NetworkManager.local_player.name:
		Transition.show_toast("Sua vez " + player_name, NetworkManager.local_player.color_rgb)
		board.highlight_player(player_name)
