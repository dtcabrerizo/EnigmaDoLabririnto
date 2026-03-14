extends Control
class_name Interface

signal player_clicked(player_info: PlayerInfo)

@onready var treasure_card_scene: PackedScene = preload("res://assets/scenes/TreasureCard.tscn")
@onready var player_info_template: PackedScene = preload("res://assets/scenes/PlayerInfoTemplate.tscn")

@onready var piece_slot: Control = %PieceSlot
@onready var char_tex: TextureRect = %Char
@onready var treasure_card: TreasureCard = %TreasureCard
@onready var discard_pile: Control = %DiscardPile
@onready var player_list: VBoxContainer = %PlayerList

enum GameState { STATE_INSERT, STATE_MOVE }

func get_piece_slot_rect() -> Rect2:
	return piece_slot.get_global_rect()

func update_treasure_symbol(symbol: int) -> void:
	treasure_card.symbol = symbol
	
func rebuild_pile(collected_symbols: Array):
	# Limpa a pilha atual
	for child in discard_pile.get_children():
		child.queue_free()

	var num_cards = collected_symbols.size()
	if num_cards == 0: return

	# 1. Configurações
	var max_total_width = 190.0  # O espaço máximo que a pilha pode ocupar
	var card_visual_width = 156.0 * 0.3 # A largura da sua carta (já considerando o scale de 0.5)
	
	var dynamic_offset = -20.0 # O menor espaço visível de uma carta embaixo da outra
	
	# 2. Cálculo do offset

	while 80 + (card_visual_width + dynamic_offset) * (num_cards + 1) > max_total_width:
		dynamic_offset -= 1

	# Reconstrói a pilha
	for i in range(collected_symbols.size()):
		var new_card = treasure_card_scene.instantiate()
		# Define o símbolo
		new_card.symbol = collected_symbols[i]
		# Aplica o deslocamento progressivo
		new_card.scale = Vector2(0.3, 0.3)
		#new_card.position = Vector2(80 + 20 * i, 80)
		# Posição X calculada dinamicamente
		new_card.position = Vector2(40 + (card_visual_width + dynamic_offset) * i, 40)
		
		discard_pile.add_child(new_card)

func animate_card_collection_sync(player_name: String, symbol_id: int) -> void:
	var card_anim = treasure_card_scene.instantiate()
	card_anim.z_index = 10
	add_child(card_anim)
	
	# Define o destino (ex: um nó Position2D que colocaste no canto da tua UI)
	# Destino:
	var target_pos: Vector2
	if player_name == NetworkManager.local_player.name:
		target_pos = discard_pile.global_position		
	else:
		# Voar para cima/fora para indicar que o oponente ganhou a carta		
		target_pos = Vector2(get_viewport().get_visible_rect().get_center().x, -200)
	
	card_anim.setup_and_animate(symbol_id, target_pos)

func update_lobby(current_turn_player: PlayerInfo, current_state: GameState) -> void:
	# Limpa a lista visual
	for child in player_list.get_children():
		child.queue_free()

# Adiciona os nomes dos jogadores conectados
	for id in NetworkManager.players:
		var player_info = NetworkManager.players[id]
		var template: PlayerInfoTemplate = player_info_template.instantiate()
		player_list.add_child(template)
		
		# Verificação de segurança (evita o crash de 'null instance')
		template.color = player_info.color_rgb
		template.player_name = player_info.name
		template.score = player_info.collected.size()
		
		# Só mostramos o ícone se for o turno deste jogador
		if player_info.name == current_turn_player.name:			
			# Criamos uma cópia única da textura para este template não afetar os outros
			template.state = current_state
		else:
			# Esconde o ícone se não for a vez do jogador
			template.state = -1
		
		template.button_pressed.connect(func(): player_clicked.emit(player_info))
		template.visible = true


func update_char():
	var h: int = (NetworkManager.local_player.color + 1) * 213
	char_tex.texture.region = Rect2(0, h, 216, 213)

func update_ui_slot(tile_info: TileInfo ) -> void:
	piece_slot.update(tile_info.type, tile_info.symbol)	
	
func animate_fly_to_ui(tile_node: Tile) -> void:
	# Camera atual
	var camera: Camera3D = get_viewport().get_camera_3d()

	# 1️⃣ Converter posição 3D → posição de tela
	var screen_pos: Vector2 = camera.unproject_position(tile_node.global_position)

	# 2️⃣ Esconder a peça 3D
	tile_node.visible = false

	# 3️⃣ Criar ícone na UI
	var icon = piece_slot.duplicate()
	icon.update(tile_node.data.type, tile_node.data.symbol)
	
	# adicionar no mesmo pai do slot (mesmo espaço de UI)
	var ui_root = piece_slot.get_parent()
	ui_root.add_child(icon)

	# centralizar no ponto
	icon.global_position = screen_pos - icon.size / 2

	# 4️⃣ Calcular destino (slot da UI)
	var target: Vector2 = piece_slot.global_position

	# garantir que fique acima da UI
	icon.z_index = 100

	# 5️⃣ Animar
	var tween = create_tween().set_parallel(true)

	tween.tween_property(icon, "global_position", target, 1.0).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(icon, "scale", Vector2(1.2, 1.2), 0.25)
	tween.chain().tween_property(icon, "scale", Vector2(1.0, 1.0), 0.2)
	await tween.finished
	
	# limpar
	icon.queue_free()
	tile_node.queue_free()
