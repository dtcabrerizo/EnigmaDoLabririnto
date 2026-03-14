extends Node2D
class_name TreasureCard

@onready var icon_sprite = $Symbol
@onready var card_container = $"."

@export var symbol: int:
	set(value):
		symbol = value
		# A mágica está aqui: verificamos se o icon_sprite já existe
		if is_inside_tree() and icon_sprite:
			icon_sprite.frame = symbol
			
		if value == -1:
			icon_sprite.visible = false

func _ready() -> void:
	icon_sprite.frame = symbol


func setup_and_animate(symbol_id: int, target_pile_pos: Vector2):
	# 1. Configura o visual do ícone (assumindo que usas Spritesheet)
	icon_sprite.frame = symbol_id
	
	# Pega o tamanho real da janela/viewport corretamente
	var view_size = get_viewport().get_visible_rect().size
	var screen_center = view_size / 2
	
	# Posição inicial: Centro, mas abaixo da borda da tela
	card_container.global_position = Vector2(screen_center.x, view_size.y + 200)
	card_container.scale = Vector2(0.5, 0.5) # Começa pequena ou normal
	
	var tween = create_tween()
	
	# FASE 1: Sobe para o centro e aumenta
	tween.tween_property(card_container, "global_position", screen_center, 0.6)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(card_container, "scale", Vector2(1.5, 1.5), 0.6)
	
	# Pausa dramática para o jogador ver o tesouro
	tween.tween_interval(1.0)
	
	# FASE 2: Voa para a pilha de cartas coletadas
	tween.tween_property(card_container, "global_position", target_pile_pos, 0.6)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(card_container, "scale", Vector2(0.2, 0.2), 0.6)
	tween.parallel().tween_property(card_container, "modulate:a", 0.0, 0.6)
	
	# Auto-destruição após a animação
	tween.tween_callback(queue_free)
