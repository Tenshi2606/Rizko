extends Area2D
class_name NPCBase

signal player_entered(player: Player)
signal player_exited(player: Player)
signal interacted(player: Player)

@export_group("NPC Info")
@export var npc_name: String = "NPC"
@export var npc_type: String = "generic"

@export_group("Interaction")
@export var interaction_prompt: String = "Presiona E para interactuar"
@export var interaction_key: String = "ui_accept"

@export_group("Visual")
@export var idle_animation: String = "idle"

var player_nearby: Player = null
var is_interacting: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var prompt_label: Label = $PromptLabel

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if prompt_label:
		prompt_label.visible = false
	
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(idle_animation):
		sprite.play(idle_animation)
	
	_on_ready()
	print("🧑 NPC inicializado: ", npc_name)

func _on_ready() -> void:
	pass

func _input(event: InputEvent) -> void:
	if not player_nearby or is_interacting:
		return
	
	if event.is_action_pressed(interaction_key):
		_interact()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_nearby = body as Player
		_show_prompt()
		player_entered.emit(player_nearby)
		_on_player_nearby()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_nearby = null
		_hide_prompt()
		player_exited.emit(body as Player)
		
		# 🆕 SI ESTABA INTERACTUANDO, FORZAR CIERRE
		if is_interacting:
			print("👋 Jugador se alejó durante interacción, cerrando UI")
			_force_close_interaction()
		
		_on_player_left()

func _show_prompt() -> void:
	if prompt_label:
		prompt_label.text = interaction_prompt
		prompt_label.visible = true

func _hide_prompt() -> void:
	if prompt_label:
		prompt_label.visible = false

func _interact() -> void:
	print("💬 ", npc_name, " interactuado")
	is_interacting = true
	_hide_prompt()
	interacted.emit(player_nearby)
	on_interact()

func stop_interaction() -> void:
	is_interacting = false
	if player_nearby:
		_show_prompt()

# 🆕 NUEVA FUNCIÓN - Forzar cierre al alejarse
func _force_close_interaction() -> void:
	is_interacting = false
	on_interaction_forced_close()

# 🆕 Override en clases hijas para cerrar sus UIs
func on_interaction_forced_close() -> void:
	pass

func on_interact() -> void:
	pass

func _on_player_nearby() -> void:
	pass

func _on_player_left() -> void:
	pass
