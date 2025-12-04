# res://scripts/enemies/EnemyBase.gd
extends CharacterBody2D
class_name EnemyBase

# Sistema de Vida
@export_group("Vida")
@export var max_health: int = 30
@export var show_damage_feedback: bool = true
@export var damage_feedback_duration: float = 0.1

var current_health: int = 0

# Sistema de Knockback
@export_group("Knockback")
@export var can_receive_knockback: bool = true
@export var knockback_stun_duration: float = 0.3

var is_stunned: bool = false
var stun_timer: float = 0.0

# 🆕 SISTEMA DE PERSISTENCIA
@export_group("Persistencia")
## ID único del enemigo (se auto-genera si está vacío)
@export var enemy_id: String = ""
## Si true, el enemigo reaparece al volver a la escena
@export var respawns: bool = false

# Señales
signal enemy_died
signal health_changed(new_health: int, max_health: int)
signal took_damage(damage: int)
signal stunned
signal stun_ended

# Referencias
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D

func _ready() -> void:
	current_health = max_health
	add_to_group("enemies")
	
	# 🆕 AUTO-GENERAR ID SI NO EXISTE
	if enemy_id.is_empty():
		_generate_enemy_id()
	
	# 🆕 VERIFICAR SI YA ESTÁ MUERTO
	if not respawns and SceneManager.is_enemy_killed(enemy_id):
		print("☠️ Enemigo ya muerto (no respawnea): ", enemy_id)
		queue_free()
		return
	
	print("🟢 EnemyBase._ready() ejecutado para: ", name, " (ID: ", enemy_id, ")")
	_enemy_ready()

# 🆕 GENERAR ID ÚNICO
func _generate_enemy_id() -> void:
	var scene_name = get_tree().current_scene.name
	var pos = global_position
	enemy_id = "%s_%s_%.0f_%.0f" % [scene_name, name, pos.x, pos.y]
	print("  🆔 ID auto-generado: ", enemy_id)

# Método virtual para hijos
func _enemy_ready() -> void:
	pass

func _physics_process(delta: float) -> void:
	# Actualizar stun
	if is_stunned:
		stun_timer -= delta
		if stun_timer <= 0:
			_end_stun()
	
	_enemy_physics_process(delta)

# Método virtual para hijos
func _enemy_physics_process(_delta: float) -> void:
	pass

# Recibir daño
func take_damage(damage_amount: int, knockback_force: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0:
		return
	
	current_health = max(0, current_health - damage_amount)
	
	took_damage.emit(damage_amount)
	health_changed.emit(current_health, max_health)
	
	print("💥 ", name, " recibió ", damage_amount, " daño! HP: ", current_health, "/", max_health)
	
	# Aplicar knockback
	if can_receive_knockback and knockback_force != Vector2.ZERO:
		velocity = knockback_force
		_start_stun()
	
	# Feedback visual
	if show_damage_feedback and sprite:
		_show_damage_feedback()
	
	# Morir
	if current_health <= 0:
		die()

func _start_stun() -> void:
	is_stunned = true
	stun_timer = knockback_stun_duration
	stunned.emit()

func _end_stun() -> void:
	is_stunned = false
	stun_ended.emit()

func _show_damage_feedback() -> void:
	if not sprite:
		return
	
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(damage_feedback_duration).timeout
	
	if is_instance_valid(self) and sprite:
		sprite.modulate = Color(1, 1, 1)

func die() -> void:
	print("💀 ", name, " eliminado!")
	
	# 🆕 REGISTRAR MUERTE EN SCENEMANAGER
	if not respawns:
		SceneManager.register_enemy_killed(enemy_id)
	
	# 🎯 EMITIR EVENTO DE MUERTE
	EventBus.enemy_killed.emit(self, null)  # killer se puede agregar después
	
	enemy_died.emit()
	_on_die()
	queue_free()

# Método virtual para lógica de muerte personalizada
func _on_die() -> void:
	pass

func heal(amount: int) -> void:
	current_health = min(max_health, current_health + amount)
	health_changed.emit(current_health, max_health)

# 🆕 OBTENER ID (para persistencia)
func get_enemy_id() -> String:
	return enemy_id
