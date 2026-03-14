extends Control

@onready var start_button: Button = %StartButton

@onready var main_scene : PackedScene = preload("res://assets/scenes/Main.tscn")
@onready var players: Array[HBoxContainer] = [%Player0, %Player1, %Player2, %Player3]

func _ready() -> void:
	# Atualiza a lista quando alguém entra ou sai
	NetworkManager.player_joined.connect(_update_lobby)
	NetworkManager.player_left.connect(_update_lobby)
	NetworkManager.game_status_received.connect(_update_game_status)
	
	NetworkManager.update_game_status()
	_update_lobby(multiplayer.get_unique_id())
	


func _update_lobby(_id: int) -> void:	
	# Só o Host pode ver o botão de iniciar
	start_button.visible = multiplayer.is_server() 
	start_button.disabled = NetworkManager.players.size() < 2
	
	# Adiciona os nomes dos jogadores conectados
	NetworkManager.debug_print("Atualizando lobby com o splayers: ", _id)
	var player_seq: int = 0
	for id in NetworkManager.players:
		var player_info: PlayerInfo = NetworkManager.players[id]
		var player_container: HBoxContainer = players[player_seq]
		# Referências
		var player_pawn: TextureRect = player_container.find_child("TextureRect")
		var player_label: Label = player_container.find_child("Label")
		
		# Se este foi o jogador que acabou de entrar (o _id passado na função)
		# ou se é a primeira vez que carregamos, vamos animar!
		if id == _id:
			_animate_player_entry(player_container)
		
		# Atualiza dados
		# player_pawn.modulate = NetworkManager.players[id].color_rgb
		
		var h: int = (player_info.color + 1) * 213
		var texture: AtlasTexture = player_pawn.texture
		texture.region = Rect2(0, h, 216, 213)
		player_label.text = player_info.name
		player_label.text += "\n(" + PlayerInfo.CHAR_NAME[player_info.color] + ")"
		
		#if id == multiplayer.get_unique_id():
			#player_label.text += "\n(Você)"
		#else:
			#player_label.text += "\n(Inimigo)"
			
		player_seq += 1


	
func _animate_player_entry(container: Control):
	NetworkManager.debug_print("Animando entrada do player", container)	
	container.modulate.a = 0.0
	create_tween().tween_property(container, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_OUT)

func _on_start_button_pressed() -> void:
	var order = 0
	for id in NetworkManager.players:
		NetworkManager.players[id].order = order
		order += 1
		
	# O Host avisa todos para mudarem para a cena do Jogo	
	start_game_rpc.rpc()

func _update_game_status() -> void:
	if NetworkManager.game_started:
		get_tree().change_scene_to_packed(main_scene)
	

@rpc("authority", "call_local", "reliable")
func start_game_rpc() -> void:
	Transition.stop_bgm()
	Transition.iris_to_scene(main_scene)
	


		
