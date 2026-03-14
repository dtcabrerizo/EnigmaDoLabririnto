extends Node

signal host_created          # Avisa que o servidor subiu
signal join_success          # Avisa o cliente que ele conectou
signal join_failed           # Avisa o cliente que deu erro
signal player_joined(player_id: int)		 # Avisa que um player entrou e se identificou
signal player_left(player_id: int)			 # Avisa que um player identificado saiu 
signal game_status_received  # Avisa que recebeu o status do jogo

var game_started: bool = false
var peer: ENetMultiplayerPeer = ENetMultiplayerPeer.new()
var players: Dictionary = {} # Dicionário para guardar info dos jogadores
var winner_name: String

var local_player: PlayerInfo
		
var available_colors: Array[int] = [0, 1, 2, 3]
var start_positions : Array[Vector2i] = [
	Vector2i(0, 0),    # Cor 0
	Vector2i(6, 0),  # Cor 1
	Vector2i(6, 6),   # Cor 2
	Vector2i(0, 6)    # Cor 3
]

func get_player_by_name(player_name: String) -> PlayerInfo:
	var results = players.values().filter(func (p): return p.name == player_name) 
	return results[0] if results.size() == 1 else null

func get_player_by_order(order: int) -> PlayerInfo:
	var results = players.values().filter(func (p): return p.order == order) 
	return results[0] if results.size() == 1 else null


func _ready() -> void:
	# Conectamos os sinais no ready para que funcionem tanto para Host quanto para Client
	multiplayer.peer_connected.connect(_on_player_connected)
	multiplayer.peer_disconnected.connect(_on_player_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_ok)
	multiplayer.server_disconnected.connect(_on_server_down)
	# multiplayer.connection_failed.connect(_on_connected_fail)

func create_host(ip: String, port: int, player_info: PlayerInfo) -> void:
	peer.set_bind_ip(ip)
	var error = peer.create_server(port)
	if error != OK:
		print("Erro ao criar servidor: ", error)
		return
		
	multiplayer.multiplayer_peer = peer	
	# O Host (ID 1) precisa se registrar manualmente
	player_info.id = 1
	player_info.color = get_random_color()
	player_info.grid_position = start_positions[player_info.color]
	player_info.home_position = player_info.grid_position
	local_player = player_info
	
	_register_player(player_info) 
	
	host_created.emit()
	print("Host iniciado no ID 1")

func join_game(ip: String, port: int, player_info: PlayerInfo) -> void:
	local_player = player_info
	var error = peer.create_client(ip, port)
	if error != OK:
		print("Erro ao tentar conectar: ", error)
		join_failed.emit()
		return
		
	multiplayer.multiplayer_peer = peer

# Chamado no CLIENTE quando ele consegue conectar ao servidor
func _on_connected_ok():
	# Avisa o servidor quem eu sou (usando Dictionary em vez de objeto)
	rpc_id(1, "server_register_player", local_player.toDict())
	
	join_success.emit()

func _on_player_connected(id: int) -> void:
	print("Player conectado: ", str(id))

func _on_player_disconnected(id: int) ->void:
	print("Player saiu: ", str(id))
	if players.has(id):
		player_left.emit(id)


# Função auxiliar para organizar o dicionário
func _register_player(player_info: PlayerInfo) -> void:
	players[player_info.id] = player_info
	player_joined.emit(player_info.id)
	debug_print("Player registrado: ", player_info.name, " Total: ", players.size(), " cor: ", player_info.color, " pos: ", player_info.grid_position)

# Servidor recebe as infos do cliente e registra
@rpc("any_peer", "reliable")
func server_register_player(info: Dictionary) -> void:
	debug_print("Inicio do registro do player: ", info.name, " cor: ", info.color, " pos: ", info.grid_position)
	var new_id = multiplayer.get_remote_sender_id()
	
	var player_info: PlayerInfo = null
	# Busca se o nome já existe na partida (Reconexão)
	for p in players.values():
		if p.name == info.name:
			player_info = p
			break
	
	if player_info:
		# Não é um jogador novo, valida se ele está retornando a um jogo iniciado
		if game_started == true:
			print("Jogador ", info.name, " voltou ")
			players.erase(player_info.id)
			player_info.id = new_id
		else:
			# Jogo ainda não iniciou
			# Rejeita conexão de um jogador com o mesmo nome de um jogador existente no Lobby
			_reject_connection(new_id, "Já existe um jogador com esse nome")
			return
	elif players.size() == 4:
		# Se já temos 4 jogadores conectados recusa conexões de jogadores novos 
		_reject_connection(new_id, "Número máximo de jogadores atingido")
		return
	elif game_started:
		# Jogo em andamento, se é um jogador novo recusa conexão
		_reject_connection(new_id, "Jogo em andamento")
		return
	else:
		# 1. Cria o PlayerInfo do novo jogador no Servidor		
		player_info = PlayerInfo.new()
		player_info.id = new_id
		player_info.name = info.name
		player_info.color = get_random_color()
		player_info.grid_position = start_positions[player_info.color]
		player_info.home_position = player_info.grid_position
	
	_register_player(player_info)

	# 2. Avisa TODOS os outros sobre esse novo jogador
	# (Inclusive o próprio novo jogador, para ele se registrar na sua lista local)
	rpc("client_add_player", player_info.toDict(), player_info.id)
		
	# 3. Manda para o NOVO jogador a lista de quem JÁ ESTAVA lá
	for id in players:
		if id != player_info.id: # Não manda ele mesmo de novo
			var p = players[id]
			rpc_id(player_info.id, "client_add_player", p.toDict(), id)

func _reject_connection(id: int, reason: String) -> void:
	# Envia mensagem para client exibit e desconecta
	rpc_id( id,  "client_reject_connection", reason)	

@rpc("authority", "reliable")
func client_reject_connection(reason: String) -> void:
	Transition.show_toast(reason, Color.RED)
	multiplayer.multiplayer_peer.close()

func update_game_status() -> void:
	check_game_status.rpc_id(1)

@rpc("any_peer", "reliable")
func check_game_status() -> void:
	debug_print("::::::: Pedindo status :::::::: ", game_started )
	var sender_id = multiplayer.get_remote_sender_id()
	# O servidor responde apenas para quem perguntou
	receive_game_status.rpc_id(sender_id, game_started)

@rpc("authority", "reliable")
func receive_game_status(is_started: bool) -> void:
	debug_print("::::::: Recebido status :::::::: ", is_started )
	game_started = is_started
	game_status_received.emit()
	
	
@rpc("authority", "reliable")
func client_add_player(info: Dictionary, id: int) -> void:
	debug_print("Recebi info de um player: ", id, " nome: ", info.name , " cor: ", info.color, " pos: ", info.grid_position)
	
	
	# Se o player já existe pelo nome (reconexão), só atualiza o ID
	for p in players.values():
		if p.name == info.name:
			debug_print("Player ", info.name, " já existe, atualizando...")
			players.erase(p.id)
			p.id = id
			players[id] = p
			return
	
	# Se já temos ele (ex: o host), não faz nada
	if players.has(id): return
	
	var player_info = PlayerInfo.fromDict(info)
	player_info.id = id
	_register_player(player_info)

func get_random_color() -> int:
	if available_colors.is_empty(): 
		return 0 # Segurança
	available_colors.shuffle()
	return available_colors.pop_back()
	
func _on_server_down():
	print("O Host encerrou a partida.")
	get_tree().change_scene_to_file("res://assets/scenes/StartMenu.tscn")


func get_players_array() -> Array[Dictionary]:
	var ret:Array[Dictionary] = []
	for id in players:
		var player = players[id]
		ret.append(player.toDict())
	return ret
	
func debug_print(...args):	
	var pre = "(HOST)   " if multiplayer.is_server() else "(CLIENT) "
	pre += " [" + local_player.name + "] "
	print(pre, args)
