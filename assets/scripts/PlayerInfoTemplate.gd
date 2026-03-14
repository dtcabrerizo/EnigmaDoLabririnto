extends PanelContainer
class_name PlayerInfoTemplate

signal button_pressed

@onready var player_color: ColorRect = %PlayerColor
@onready var status_icon: TextureRect = %StatusIcon
@onready var player_name_label: Label = %PlayerName
@onready var player_score: Label = %PlayerScore

@export var color: Color:
	set(value):
		color = value
		player_color.modulate = color
		

@export var state: int:
	set(value):
		state = value
		var tex: AtlasTexture = status_icon.texture.duplicate()
		tex.region = Rect2(state * 25, 0, 25, 25)
		status_icon.texture = tex
		
@export var player_name: String:
	set(value):
		player_name = value
		player_name_label.text = player_name

@export var score: int:
	set(value):
		score = value
		player_score.text = str(score)
		


func _on_button_pressed() -> void:
	button_pressed.emit()
