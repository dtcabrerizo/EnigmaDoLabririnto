extends Control

@onready var winner_container: HBoxContainer = %Winner
@onready var winner_cards: Control = %WinnerCards
@onready var TREASURE_CARD: PackedScene = preload("res://assets/scenes/TreasureCard.tscn")
@onready var other_player_template: HBoxContainer = %OtherPlayerTemplate
@onready var other_players_container: VBoxContainer = %OtherPlayersContainer

var other_players_info: Dictionary = {}
var winner_info: PlayerInfo

func _ready() -> void:

## DEBUG
#
	#NetworkManager.players = {
		#1: PlayerInfo.fromDict({"id": 1, "name": "Jogador 1", "color": 0, "collected": [1,2,3,4,5,6,7,8,9,10,11,12]}),
		#2: PlayerInfo.fromDict({"id": 2, "name": "Jogador 2", "color": 1, "collected": [1,2,3,4,5,6,7,8,9,10,11,12]}),
		#3: PlayerInfo.fromDict({"id": 3, "name": "Jogador 3", "color": 2, "collected": [1,2,3,4,5,6,7,8,9,10,11,12]}),
		#4: PlayerInfo.fromDict({"id": 4, "name": "Jogador 4", "color": 3, "collected": [1,2,3,4,5,6,7,8,9,10,11,12]})
	#}
	#NetworkManager.winner_name = "Jogador 1"
#
	winner_info = NetworkManager.get_player_by_name(NetworkManager.winner_name)

	
	_create_other_players_container()
	_configure_winner_container()

	Transition.fire_cannons()
	Transition.play_sound(Transition.Audio.GAMEOVER)
	await Transition.audio_finished
	
	# Anima carta dos jogadores
	for card_index:int in range(0, 12):
		for player_id: int in NetworkManager.players:
			var player_info: PlayerInfo = NetworkManager.players[player_id]
			if card_index >= player_info.collected.size():
				continue
			
			var player_control: HBoxContainer
			var parent: Control
			var symbol: int
			var card_position: Vector2
			var final_scale: float
			
			if player_info.name == NetworkManager.winner_name:
				player_control = winner_container
				parent = winner_cards
				symbol = player_info.collected[card_index]
				card_position = Vector2(card_index * 15 + 78, 208 / 2)
				final_scale = 1					
			else:
				player_control = other_players_info[player_info.id]
				parent = player_control.find_child("Cards", true, false)
				symbol = player_info.collected[card_index]
				card_position = Vector2(card_index * 15 + 39, 52)
				final_scale = 0.5
			
			_animate_card(parent, symbol, card_position, final_scale)
		
		await get_tree().create_timer(0.3).timeout	
			
func _configure_winner_container() -> void:
	var winner_label: Label = winner_container.find_child("Label", true, false)
	var winner_pawn: TextureRect = winner_container.find_child("TextureRect", true, false)		
	var h:int = (winner_info.color + 1) * 213
	winner_pawn.texture.region = Rect2(0, h, 216, 213)
	winner_label.text = winner_info.name + " (" + str(winner_info.collected.size()) + ")"
	winner_label.text += "\n (" + PlayerInfo.CHAR_NAME[winner_info.color] + ")"
	
func _create_other_players_container() -> void:
	for player_id: int in NetworkManager.players:
		var player_info: PlayerInfo = NetworkManager.players[player_id]		
		if player_info.name == NetworkManager.winner_name: 
			continue
		
		var player_control: HBoxContainer = other_player_template.duplicate()
		var player_control_label: Label = player_control.find_child("Label", true, false)
		var player_control_pawn: TextureRect = player_control.find_child("TextureRect", true, false)
		player_control.name = player_info.name
		
		var h:int = (player_info.color + 1) * 213
		var texture: AtlasTexture = player_control_pawn.texture.duplicate(true) 
		texture.region = Rect2(0, h, 216, 213)
		player_control_pawn.texture = texture
		player_control_label.text = player_info.name + " (" + str(player_info.collected.size()) + ")"
		player_control_label.text += "\n (" + PlayerInfo.CHAR_NAME[player_info.color] + ")"

		player_control.visible = true
		other_players_info[player_info.id] = player_control
		other_players_container.add_child(player_control)

func _animate_card(parent: Control, symbol: int, card_position: Vector2, final_scale: float) -> void:
		var treasure_card = TREASURE_CARD.instantiate()
		treasure_card.symbol = symbol
		parent.add_child(treasure_card)
		
		# 1. Configuração inicial da carta (invisível e fora do lugar)
		treasure_card.position = card_position + Vector2(0, -100) # Começa 100px acima
		treasure_card.modulate.a = 0 # Começa transparente
		treasure_card.scale = Vector2(final_scale / 2, final_scale / 2) # Começa menor
		
		
		# 2. Criação do Tween para a animação
		var tween = create_tween().set_parallel(true) # Anima posição e opacidade ao mesmo tempo

		# Anima para a posição final
		tween.tween_property(treasure_card, "position", card_position, 0.4)\
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# Anima a opacidade
		tween.tween_property(treasure_card, "modulate:a", 1.0, 0.3)

		# Anima o tamanho (dando um efeito de impacto)
		tween.tween_property(treasure_card, "scale", Vector2(final_scale, final_scale), 0.4)\
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		
		Transition.play_sound(Transition.Audio.STEP)
		tween.finished.connect(func(): treasure_card.scale = Vector2(final_scale, final_scale))
