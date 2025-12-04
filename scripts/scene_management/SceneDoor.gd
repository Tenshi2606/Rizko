# res://scripts/world/AdvancedDoor.gd
extends Area2D
class_name AdvancedDoor

@export_group("Destino")
@export_file("*.tscn") var target_scene: String = ""
@export var target_spawn_point: String = "default"

@export_group("Visual")
@export var door_name: String = "Puerta"
@export var prompt_text: String = "Presiona ↑ para entrar"
@export var can_use: bool = true

@export_group("Requisitos (Opcional)")
@export var requires_ability: String = ""  # Ej: "dash", "double_jump"
@export var requires_item: String = ""     # Ej: "key_red"
@export var requires_weapon: String = ""   # 🆕 Requiere arma específica

@export_group("Tipo de Puerta")
enum DoorType { NORMAL, LOCKED, BREAKABLE, ONE_WAY }
@export var door_type: DoorType = DoorType.NORMAL

var player_nearby: Player = null
var is_broken: bool = false

@onready var prompt_label: Label = $PromptLabel
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if prompt_label:
		prompt_label.visible = false
	
	if sprite:
		_update_sprite_state()
	
	add_to_group("doors")
	print("🚪 Puerta configurada: ", door_name, " → ", target_scene.get_file())

func _input(event: InputEvent) -> void:
	if not player_nearby or not can_use:
		return
	
	# Abrir con flecha arriba
	if event.is_action_pressed("ui_up"):
		_use_door()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_nearby = body as Player
		_show_prompt()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_nearby = null
		_hide_prompt()

func _show_prompt() -> void:
	if not can_use or is_broken:
		return
	
	# Verificar requisitos
	if not _check_requirements():
		if prompt_label:
			prompt_label.text = _get_requirement_message()
			prompt_label.modulate = Color(1, 0.5, 0.5)  # Rojo
			prompt_label.visible = true
		return
	
	if prompt_label:
		prompt_label.text = prompt_text
		prompt_label.modulate = Color(1, 1, 1)
		prompt_label.visible = true

func _hide_prompt() -> void:
	if prompt_label:
		prompt_label.visible = false

func _use_door() -> void:
	# Verificar tipo de puerta
	match door_type:
		DoorType.LOCKED:
			if not _check_requirements():
				_show_locked_feedback()
				return
		
		DoorType.BREAKABLE:
			if not _check_weapon_requirement():
				_show_breakable_feedback()
				return
			else:
				_break_door()
		
		DoorType.ONE_WAY:
			# Solo permite pasar en una dirección
			if not _check_direction():
				return
	
	if target_scene.is_empty():
		push_error("❌ Puerta sin target_scene configurado")
		return
	
	print("🚪 Usando puerta: ", door_name)
	SceneManager.change_scene(target_scene, target_spawn_point)

# ============================================
# REQUISITOS
# ============================================

func _check_requirements() -> bool:
	if not player_nearby:
		return false
	
	# Verificar habilidad requerida
	if not requires_ability.is_empty():
		var ability_system = player_nearby.get_node_or_null("AbilitySystem")
		if not ability_system or not ability_system.has_ability(requires_ability):
			return false
	
	# Verificar item requerido
	if not requires_item.is_empty():
		var inventory = player_nearby.get_node_or_null("InventoryComponent")
		if not inventory or not inventory.has_item(requires_item):
			return false
	
	# Verificar arma requerida
	if not requires_weapon.is_empty():
		if not player_nearby.weapon_system or not player_nearby.weapon_system.has_weapon(requires_weapon):
			return false
	
	return true

func _check_weapon_requirement() -> bool:
	if not player_nearby or not player_nearby.weapon_system:
		return false
	
	var weapon = player_nearby.weapon_system.get_current_weapon()
	if not weapon:
		return false
	
	# Verificar si el arma puede romper esta puerta
	# (implementar según tu WeaponData.can_break)
	return weapon.can_break != WeaponData.BreakableType.NONE

func _check_direction() -> bool:
	# Para puertas unidireccionales
	# TODO: Implementar verificación de dirección
	return true

func _get_requirement_message() -> String:
	if not requires_ability.is_empty():
		var ability = AbilityDB.get_ability(requires_ability)
		if ability:
			return "Requiere: " + ability.ability_name
		return "Requiere habilidad"
	
	if not requires_item.is_empty():
		var item = ItemDB.create_item(requires_item)
		if item:
			return "Requiere: " + item.name
		return "Requiere item"
	
	if not requires_weapon.is_empty():
		var weapon = WeaponDB.get_weapon(requires_weapon)
		if weapon:
			return "Requiere: " + weapon.weapon_name
		return "Requiere arma"
	
	return "Bloqueado"

# ============================================
# FEEDBACK VISUAL
# ============================================

func _show_locked_feedback() -> void:
	print("🔒 Puerta bloqueada: ", door_name)
	
	# Animación de sacudida
	if sprite:
		var tween = create_tween()
		var original_pos = sprite.position
		tween.tween_property(sprite, "position:x", original_pos.x + 5, 0.05)
		tween.tween_property(sprite, "position:x", original_pos.x - 5, 0.05)
		tween.tween_property(sprite, "position:x", original_pos.x, 0.05)

func _show_breakable_feedback() -> void:
	print("🔨 Necesitas un arma más fuerte")
	
	if prompt_label:
		var original_text = prompt_label.text
		prompt_label.text = "¡Usa un arma más fuerte!"
		prompt_label.modulate = Color(1, 0.5, 0)
		
		await get_tree().create_timer(1.5).timeout
		
		if is_instance_valid(prompt_label):
			prompt_label.text = original_text
			prompt_label.modulate = Color(1, 1, 1)

func _break_door() -> void:
	print("💥 Puerta rota!")
	is_broken = true
	
	# Animación de ruptura
	if sprite and sprite.sprite_frames.has_animation("break"):
		sprite.play("break")
	
	# Desactivar colisión
	if collision_shape:
		collision_shape.disabled = true
	
	# Partículas de ruptura (opcional)
	# TODO: Instanciar partículas

func _update_sprite_state() -> void:
	if not sprite or not sprite.sprite_frames:
		return
	
	match door_type:
		DoorType.LOCKED:
			if sprite.sprite_frames.has_animation("locked"):
				sprite.play("locked")
		DoorType.BREAKABLE:
			if sprite.sprite_frames.has_animation("breakable"):
				sprite.play("breakable")
		DoorType.ONE_WAY:
			if sprite.sprite_frames.has_animation("one_way"):
				sprite.play("one_way")
		_:
			if sprite.sprite_frames.has_animation("idle"):
				sprite.play("idle")

# ============================================
# UTILIDADES
# ============================================

func lock() -> void:
	can_use = false
	door_type = DoorType.LOCKED
	_update_sprite_state()

func unlock() -> void:
	can_use = true
	door_type = DoorType.NORMAL
	_update_sprite_state()
