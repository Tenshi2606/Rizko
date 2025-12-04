# res://scripts/world/Checkpoint.gd
extends Area2D
class_name Checkpoint

@export var checkpoint_id: String = "checkpoint_01"
@export var autosave: bool = true
@export var heal_player: bool = true
@export var restore_abilities: bool = true  # 🆕 Restaurar habilidades usadas

var is_activated: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var particles: CPUParticles2D = $CPUParticles2D
@onready var activation_label: Label = $ActivationLabel

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	add_to_group("checkpoints")
	add_to_group("spawn_points")  # También funciona como spawn point
	
	# Estado inicial (desactivado)
	if sprite:
		if sprite.sprite_frames.has_animation("inactive"):
			sprite.play("inactive")
	
	if particles:
		particles.emitting = false
	
	if activation_label:
		activation_label.visible = false
	
	print("📍 Checkpoint configurado: ", checkpoint_id)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not is_activated:
		activate(body as Player)

func activate(player: Player) -> void:
	if is_activated:
		return
	
	is_activated = true
	
	print("✅ Checkpoint activado: ", checkpoint_id)
	
	# 🔥 Actualizar spawn point del SceneManager
	SceneManager.spawn_point_id = checkpoint_id
	
	# Animación de activación
	if sprite:
		if sprite.sprite_frames.has_animation("active"):
			sprite.play("active")
	
	if particles:
		particles.emitting = true
		particles.one_shot = true
	
	# Curar al jugador (opcional)
	if heal_player:
		_heal_player(player)
	
	# Restaurar habilidades (opcional)
	if restore_abilities:
		_restore_abilities(player)
	
	# Autoguardar (opcional)
	if autosave:
		SaveManager.autosave()
	
	# Feedback visual
	_show_activation_feedback()

func _heal_player(player: Player) -> void:
	if player.health < player.max_health:
		var health_component = player.get_node_or_null("HealthComponent") as HealthComponent
		if health_component:
			var heal_amount = player.max_health - player.health
			health_component.heal(heal_amount)
			print("💚 Jugador curado completamente")

func _restore_abilities(player: Player) -> void:
	# Restaurar cooldowns de habilidades
	var ability_system = player.get_node_or_null("AbilitySystem") as AbilitySystem
	if ability_system:
		ability_system.active_abilities.clear()
		print("🔄 Cooldowns de habilidades restaurados")
	
	# Restaurar munición de armas
	if player.weapon_system:
		player.weapon_system.current_ammo = player.weapon_system.max_ammo
		player.weapon_system.is_reloading = false
		player.weapon_system.reload_timer = 0.0
		print("🔫 Munición restaurada")

func _show_activation_feedback() -> void:
	if activation_label:
		activation_label.text = "📍 Checkpoint Activado"
		activation_label.visible = true
		
		# Animación de fade out
		activation_label.modulate.a = 1.0
		var tween = create_tween()
		tween.tween_property(activation_label, "modulate:a", 0.0, 2.0)
		tween.tween_callback(func(): activation_label.visible = false)
	
	print("✨ Checkpoint ", checkpoint_id, " activado")

# Obtener la posición del spawn
func get_spawn_position() -> Vector2:
	return global_position

# Para compatibilidad con SpawnPoint
var spawn_id: String:
	get:
		return checkpoint_id
