extends CanvasLayer

@onready var rect = $ColorRect

@onready var particles: Array[CPUParticles2D] = [ $CPUParticlesL, $CPUParticlesR ]
@onready var toast_notification: MarginContainer = $ToastNotification
@onready var toast_label: Label = %ToastLabel
@onready var panel_container: PanelContainer = %PanelContainer
@onready var bgms: Array[AudioStreamPlayer2D] = [ $Menu_BGM, $Game_BGM ]

signal audio_finished

enum Audio { COLLECTED, PUSHING, STEP, GAMEOVER, WRONGMOVE }
enum BGM { MENU, GAME }

@onready var AUDIOS: Array[Resource] =  [
	preload("res://assets/sounds/collected.wav"),
	preload("res://assets/sounds/pushing.wav"),
	preload("res://assets/sounds/step.wav"),
	preload("res://assets/sounds/gameover.wav"),
	preload("res://assets/sounds/wrongmove.mp3")
]

func play_sound(audio: Audio) -> void:
	var asp: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	asp.stream = AUDIOS[audio]
	add_child(asp)
	asp.play()
	asp.finished.connect(func():
		asp.queue_free()
		audio_finished.emit()
	)

func stop_bgm() -> void:
	for b: AudioStreamPlayer2D in bgms:
		b.stop()
	
func play_bgm(bgm: BGM) -> void:
	stop_bgm()
	bgms[bgm].play()

func _reset():
	rect.position = Vector2.ZERO
	rect.scale = Vector2.ONE
	rect.modulate.a = 0
	rect.show()
	# Se usar o shader da íris, reseta o tamanho do círculo também
	if rect.material is ShaderMaterial:
		rect.material.set_shader_parameter("circle_size", 0.0)
		
	for p in particles:
		p.emitting = false

func fire_cannons():
	for p in particles:
		p.emitting = true

func fade_to_scene(target_scene: PackedScene):
	_reset()
	
	# 1. Fade In (Escurece)
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, 0.5)
	await tween.finished
	
	# 2. Troca a cena
	NetworkManager.debug_print("Trocando de cena para ", target_scene)
	get_tree().change_scene_to_packed(target_scene)
	await get_tree().process_frame
	
	# 3. Fade Out (Clareia)
	var tween_out = create_tween()
	tween_out.tween_property(rect, "modulate:a", 0.0, 0.5)
	
func curtain_to_scene(target_scene: PackedScene):
	_reset()
	
	# 1. Fade In (Escurece)
	var tween = create_tween()
	tween.tween_property(rect, "modulate:a", 1.0, 0.5)
	await tween.finished
	
	# 2. Troca a cena
	# Limpa sinais ou processos pendentes
	get_tree().paused = false
	NetworkManager.debug_print("Trocando de cena para ", target_scene)
	get_tree().change_scene_to_packed(target_scene)
	await get_tree().process_frame
	
	# 3. Fade Out (Clareia)
	var tween_up = create_tween()
	tween_up.tween_property(rect, "position:y", -920, 0.5)
	
func iris_to_scene(target_scene: PackedScene, center: Vector2 = Vector2(0.5, 0.5)):
	_reset()
	rect.modulate.a = 1.0 # Mantém o rect visível, o shader cuida da transparência
	var mat = rect.material as ShaderMaterial
	mat.set_shader_parameter("screen_center", center)
	
	# 1. Fecha o círculo
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(mat, "shader_parameter/circle_size", 0.0, 0.6)
	await tween.finished
	
	get_tree().change_scene_to_packed(target_scene)
	await get_tree().process_frame
	
	# 2. Abre o círculo
	var tween_out = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_out.tween_property(mat, "shader_parameter/circle_size", 1.05, 0.6)
	
# No TransitionScene.gd

func iris_to_winner(target_scene: PackedScene, winner_pos: Vector2):
	_reset()
	rect.modulate.a = 0.0
	var mat = rect.material as ShaderMaterial
	
	# Converter a posição da tela para coordenadas 0.0 - 1.0 (UV)
	var screen_size = get_viewport().get_visible_rect().size
	var center_uv = Vector2(
		winner_pos.x / screen_size.x,
		winner_pos.y / screen_size.y
	)
	
	mat.set_shader_parameter("screen_center", center_uv)
	mat.set_shader_parameter("circle_size", 1.05) # Começa aberto
	
	# 1. Fecha o círculo no vencedor
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(rect, "modulate:a", 1.0, 0.5)
	tween.tween_property(mat, "shader_parameter/circle_size", 0.0, 0.8)
	await tween.finished
	
	# 2. Troca a cena
	get_tree().change_scene_to_packed(target_scene)
	
	# 3. Abre o círculo (agora no centro da nova cena ou mantém no vencedor)
	var tween_out = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween_out.tween_property(mat, "shader_parameter/circle_size", 1.05, 0.6)
	
	
	
func show_toast(message: String, color: Color = Color.BLACK, duration: float = 3.0):
	toast_label.text = message
	var theme:StyleBoxFlat = panel_container.get_theme_stylebox("panel")
	theme.bg_color = color
	theme.bg_color.a = 0.3
	
	var tween = create_tween()
	# 1. Aparece (Fade in e desliza)
	toast_notification.modulate.a = 0
	toast_notification.position.y = -50 # Começa um pouco acima da tela

	tween.set_parallel(true)
	tween.tween_property(toast_notification, "modulate:a", 1.0, 0.5)
	tween.tween_property(toast_notification, "position:y", 20, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 2. Espera o tempo de leitura
	await get_tree().create_timer(duration).timeout

	# 3. Desaparece
	var tween_out = create_tween().set_parallel(true)
	tween_out.tween_property(toast_notification, "modulate:a", 0.0, 0.5)
	tween_out.tween_property(toast_notification, "position:y", -50, 0.5)
