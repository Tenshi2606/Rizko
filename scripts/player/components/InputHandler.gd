extends Node
class_name InputHandler

signal jump_pressed
signal jump_released
signal attack_pressed
signal dash_pressed
signal heal_pressed
signal next_fragment_pressed
signal prev_fragment_pressed
signal inventory_toggled

var player: Player

func _ready() -> void:
	await get_tree().process_frame
	player = get_parent() as Player
	
	if not player:
		push_error("InputHandler debe ser hijo de un Player")
		return
	
	print("🎮 InputHandler inicializado")

func _input(event: InputEvent) -> void:
	# Salto
	if event.is_action_pressed("jump"):
		jump_pressed.emit()
	
	if event.is_action_released("jump"):
		jump_released.emit()
	
	# Ataque
	if event.is_action_pressed("attack"):
		attack_pressed.emit()
	
	# Dash
	if event.is_action_pressed("dash"):
		dash_pressed.emit()
	
	# Curación
	if event.is_action_pressed("use_heal"):
		heal_pressed.emit()
	
	# Cambiar fragmentos
	if event.is_action_pressed("next_fragment"):
		next_fragment_pressed.emit()
	
	if event.is_action_pressed("prev_fragment"):
		prev_fragment_pressed.emit()
	
	# Inventario
	if event.is_action_pressed("toggle_inventory"):
		inventory_toggled.emit()

# Métodos de consulta (para estados)
func is_jump_held() -> bool:
	return Input.is_action_pressed("jump")

func is_attack_held() -> bool:
	return Input.is_action_pressed("attack")

func get_movement_input() -> float:
	return Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")

func is_moving_up() -> bool:
	return Input.is_action_pressed("ui_up")

func is_moving_down() -> bool:
	return Input.is_action_pressed("ui_down")
