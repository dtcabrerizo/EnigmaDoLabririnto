extends Control

@onready var lobby_scene: PackedScene = preload("res://assets/scenes/Lobby.tscn")
@onready var main_panel: PanelContainer = $MainPanel
@onready var input_panel: PanelContainer = $InputPanel
@onready var help_panel: PanelContainer = $HelpPanel

@onready var label_conn_type: Label = %LabelConnType
@onready var player_name_input: LineEdit = %PlayerName
@onready var ip_input: LineEdit = %IP
@onready var button_connect: Button = %ButtonConnect


enum CONN_TYPES { INVALID, HOST, CLIENT }

var player_info = PlayerInfo.new()
var connection_type: CONN_TYPES = CONN_TYPES.INVALID
 
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Conecta os sinais do Autoload à funções locais
	NetworkManager.host_created.connect(_goto_lobby)
	NetworkManager.join_success.connect(_goto_lobby)
	NetworkManager.join_failed.connect(_error)
	
	await get_tree().create_timer(4.0).timeout
	_animate_menu_enter(main_panel)
	
	Transition.play_bgm(Transition.BGM.MENU)

func _error() -> void:
	pass
	
func _goto_lobby() -> void:
	get_tree().change_scene_to_packed(lobby_scene)


func _animate_menu_enter(menu: PanelContainer) -> void:
	
	menu.modulate.a = 0
	menu.visible = true
	create_tween().tween_property(menu, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT)

	var itens = menu.find_child("VBoxContainer").get_children()
	for i in range(itens.size()):
		var item = itens[i]
		# Começa invisível e um pouco abaixo
		item.modulate.a = 0

		# Cria o efeito cascata
		var tween = create_tween().set_parallel(true)
		tween.tween_property(item, "modulate:a", 1.0, 0.5).set_delay(i * 0.1)		
		#tween.tween_property(item, "position:y", item.position.y - 50, 0.5)\
			#.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(i * 0.1)


func _animate_menu_exit(menu: PanelContainer) -> void:	
	create_tween().tween_property(menu, "modulate:a", 0.0, 0.6).set_ease(Tween.EASE_OUT)
	menu.visible = false
	
	
func _animate_field_error(field: LineEdit) -> Tween:
	var original_position: Vector2 = field.position
	var tween = create_tween()
	
	for i in range(4):
		tween.tween_property(field, "position:x", field.position.x - 10, 0.1)
		tween.tween_property(field, "position:x", field.position.x + 10, 0.1)
	
	tween.tween_property(field, "position:x", original_position.x, 0.1)
	field.modulate = Color.RED
	tween.finished.connect(func(): 
		field.modulate = Color.WHITE	
	)
	return tween

func _on_button_back_pressed() -> void:
	_animate_menu_exit(input_panel)
	_animate_menu_enter(main_panel)

func _on_button_host_pressed() -> void:
	connection_type = CONN_TYPES.HOST
	label_conn_type.text = "Servidor"
	_animate_menu_exit(main_panel)	
	_animate_menu_enter(input_panel)

func _on_button_join_pressed() -> void:
	label_conn_type.text = "Conectar a"
	connection_type = CONN_TYPES.CLIENT
	_animate_menu_exit(main_panel)	
	_animate_menu_enter(input_panel)



func _on_button_connect_pressed() -> void:
	# validar campos
	button_connect.disabled = true
	var ip: String = ip_input.text.strip_edges()
	var player_name: String = player_name_input.text.strip_edges()	
	
	if ip.is_empty():
		await _animate_field_error(ip_input).finished
		button_connect.disabled = false
		return
	
	if player_name.is_empty():
		await _animate_field_error(player_name_input).finished
		
		button_connect.disabled = false
		return

	player_info.name = player_name
	
	if connection_type == CONN_TYPES.HOST:
		player_info.id = 1
		NetworkManager.create_host(ip, 12345, player_info)
	elif connection_type == CONN_TYPES.CLIENT:
		NetworkManager.join_game(ip, 12345, player_info)
		
		
	button_connect.disabled = false	
	
func _on_close_help_pressed() -> void:
	_animate_menu_exit(help_panel)

func display_help() -> void:
	_animate_menu_enter(help_panel)
