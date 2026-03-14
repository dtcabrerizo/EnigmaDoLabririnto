extends Node3D

@export var rotate_speed := 0.01
@export var pan_speed := 0.01
@export var zoom_speed := 1.0

@export var min_zoom := 3.0
@export var max_zoom := 20.0

var rotating := false
var panning := false

var default_position : Vector3
var default_rotation : Vector3
var default_zoom : float

@onready var camera := $Camera3D

func _ready():
	default_position = global_position
	default_rotation = rotation
	default_zoom = camera.position.z

func _input(event):
	# Se o mouse estiver sobre um botão da UI que consome o clique, ignore a câmera
	if event is InputEventMouseButton and get_viewport().gui_get_focus_owner():
		return
		
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			rotating = event.pressed
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			panning = event.pressed

		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom(-zoom_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom(zoom_speed)

	if event is InputEventMouseMotion:
		if rotating:
			rotation.y -= event.relative.x * rotate_speed
			rotation.x -= event.relative.y * rotate_speed
			rotation.x = clamp(rotation.x, deg_to_rad(-90), deg_to_rad(-10)) 

		if panning:
			# vetores baseados só na rotação Y (ignora inclinação)
			var yaw = rotation.y

			var right = Vector3(cos(yaw), 0, -sin(yaw))
			var forward = Vector3(sin(yaw), 0, cos(yaw))

			global_position -= right * event.relative.x * pan_speed
			global_position -= forward * event.relative.y * pan_speed

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			reset_view()

func zoom(amount):
	camera.position.z = clamp(camera.position.z + amount, min_zoom, max_zoom)
	camera.position.z = camera.position.z + amount

func reset_view():
	global_position = default_position
	rotation = default_rotation
	camera.position.z = default_zoom
