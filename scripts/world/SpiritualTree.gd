extends Node2D
class_name SpiritualTree

# ============================================
# CONFIGURACIÓN
# ============================================

@export_group("Checkpoint")
## ID único de este checkpoint
@export var checkpoint_id: String = "checkpoint_1"
## Mostrar diálogo de confirmación antes de descansar
@export var show_confirmation: bool = false

@export_group("Visual")
## Color de las partículas
@export var particle_color: Color = Color(0.5, 1.0, 0.8, 0.8)
## Intensidad de la luz
@export var light_intensity: float = 1.5

@export_group("Audio")
## Sonido al activar el checkpoint
@export var activation_sound: AudioStream

@export_group("Animación")
## Nombre de la animación del árbol (en AnimatedSprite2D)
@export var tree_animation_name: String = "activate"
## Duración de la animación del árbol (en segundos)
@export var tree_animation_duration: float = 2.0
## Nombre de la animación del jugador descansando
@export var player_rest_animation: String = "sit"
## Si true, el jugador se queda quieto durante la animación
@export var freeze_player_during_rest: bool = true

@export_group("Transición")
## Duración del fade out antes de recargar
@export var fade_out_duration: float = 0.8
## Duración del fade in después de recargar
@export var fade_in_duration: float = 0.8

# ============================================
# ESTADO
# ============================================

var player_in_range: bool = false
var current_player: Player = null
var is_activated: bool = false
var is_resting: bool = false

# ============================================
# REFERENCIAS
# ============================================

@onready var area: Area2D = $Area2D
@onready var sprite: AnimatedSprite2D = get_node_or_null("AnimatedSprite2D")
@onready var particles: CPUParticles2D = get_node_or_null("CPUParticles2D")
@onready var light: PointLight2D = get_node_or_null("PointLight2D")
@onready var prompt_label: Label = get_node_or_null("PromptLabel")
@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")

# ============================================
# INICIALIZACIÓN
# ============================================

func _ready() -> void:
	add_to_group("checkpoints")
	
	# Conectar señales del área
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)
	else:
		push_error("❌ SpiritualTree necesita un nodo Area2D como hijo")
	
	# Configurar prompt
	if prompt_label:
		prompt_label.visible = false
		prompt_label.text = "Presiona E para descansar"
	
	# Configurar partículas
	if particles:
		particles.emitting = false
		particles.color = particle_color
	
	# Configurar luz
	if light:
		light.energy = 0.0
	
	print("🌳 SpiritualTree inicializado: ", checkpoint_id)

# ============================================
# PROCESO
# ============================================

func _process(_delta: float) -> void:
	if player_in_range and not is_resting:
		if Input.is_action_just_pressed("interact"):
			_activate_checkpoint()

# ============================================
# ACTIVACIÓN DEL CHECKPOINT
# ============================================

func _activate_checkpoint() -> void:
	if is_resting or not current_player:
		return
	
	print("🌳 Activando checkpoint: ", checkpoint_id)
	is_resting = true
	
	# Ocultar prompt
	if prompt_label:
		prompt_label.visible = false
	
	# Iniciar secuencia de descanso
	_rest_sequence()

# ============================================
# SECUENCIA DE DESCANSO
# ============================================

func _rest_sequence() -> void:
	print("💤 Iniciando secuencia de descanso...")
	
	# 1. Congelar al jugador si está configurado
	if freeze_player_during_rest and current_player:
		_freeze_player()
	
	# 2. Efectos visuales iniciales
	_start_visual_effects()
	
	# 3. Reproducir sonido
	if audio_player and activation_sound:
		audio_player.stream = activation_sound
		audio_player.play()
	
	# 4. Reproducir animación del árbol
	if sprite and sprite.sprite_frames:
		if sprite.sprite_frames.has_animation(tree_animation_name):
			print("🎬 Reproduciendo animación del árbol: ", tree_animation_name)
			sprite.play(tree_animation_name)
	
	# 5. Esperar a que termine la animación
	print("⏳ Esperando animación del árbol (", tree_animation_duration, "s)...")
	await get_tree().create_timer(tree_animation_duration).timeout
	
	# 6. Recuperar vida del jugador
	_restore_player_health()
	
	# 7. Registrar checkpoint en SceneManager
	_register_checkpoint()
	
	# 8. Guardar progreso
	_save_game()
	
	# 9. Descongelar jugador
	if freeze_player_during_rest and current_player:
		_unfreeze_player()
	
	# 10. Respawnear enemigos con transición suave
	_respawn_enemies_with_transition()

# ============================================
# FUNCIONES DE CHECKPOINT
# ============================================

func _restore_player_health() -> void:
	if not current_player:
		return
	
	var health_component = current_player.get_node_or_null("HealthComponent") as HealthComponent
	if health_component:
		if health_component.has_method("restore_full_health"):
			health_component.restore_full_health()
		else:
			# Fallback si no existe el método
			current_player.health = current_player.max_health
			if health_component.has_method("_update_health_bar"):
				health_component._update_health_bar()
		
		print("❤️ Vida restaurada a máximo")

func _register_checkpoint() -> void:
	if SceneManager:
		var current_scene = get_tree().current_scene.scene_file_path
		SceneManager.register_checkpoint(checkpoint_id, current_scene)
		print("📍 Checkpoint registrado en SceneManager")
	else:
		push_error("❌ SceneManager no encontrado")

func _respawn_enemies_with_transition() -> void:
	if not SceneManager:
		push_error("❌ SceneManager no encontrado")
		return
	
	print("☠️ Respawneando TODOS los enemigos globalmente...")
	
	# 🔥 LIMPIAR TODOS LOS ENEMIGOS MUERTOS (RESPAWN GLOBAL)
	var total_enemies = SceneManager.world_state["killed_enemies"].size()
	SceneManager.world_state["killed_enemies"].clear()
	print("  ✅ ", total_enemies, " enemigos han sido respawneados en todas las escenas")
	
	# 2. Guardar datos del jugador
	SceneManager._save_player_data()
	
	# 🔥 MARCAR QUE DEBE RESTAURAR VIDA COMPLETA
	SceneManager.should_restore_full_health = true
	
	# 3. Marcar el spawn point
	SceneManager.spawn_point_id = checkpoint_id
	
	# 4. 🎬 Llamar al SceneManager para hacer la transición
	SceneManager.reload_scene_with_fade(fade_out_duration, fade_in_duration)

func _save_game() -> void:
	if SaveManager:
		SaveManager.save_game()
		print("💾 Progreso guardado")
	else:
		push_warning("⚠️ SaveManager no encontrado - No se guardó el progreso")

# ============================================
# CONTROL DEL JUGADOR
# ============================================

func _freeze_player() -> void:
	if not current_player:
		return
	
	print("🧊 Congelando jugador para animación...")
	
	# Detener movimiento
	current_player.velocity = Vector2.ZERO
	
	# Desactivar el state machine si existe
	var state_machine = current_player.get_node_or_null("StateMachine")
	if state_machine:
		state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Reproducir animación de descanso si existe
	if current_player.sprite and current_player.sprite.sprite_frames:
		if current_player.sprite.sprite_frames.has_animation(player_rest_animation):
			current_player.sprite.play(player_rest_animation)
			print("  🪑 Jugador descansando: ", player_rest_animation)
		else:
			# Fallback a idle
			if current_player.sprite.sprite_frames.has_animation("idle"):
				current_player.sprite.play("idle")

func _unfreeze_player() -> void:
	if not current_player:
		return
	
	print("❄️ Descongelando jugador...")
	
	# Reactivar el state machine
	var state_machine = current_player.get_node_or_null("StateMachine")
	if state_machine:
		state_machine.process_mode = Node.PROCESS_MODE_INHERIT

# ============================================
# EFECTOS VISUALES
# ============================================

func _start_visual_effects() -> void:
	# Activar partículas
	if particles:
		particles.emitting = true
	
	# Animar luz
	if light:
		var tween = create_tween()
		tween.tween_property(light, "energy", light_intensity, 0.5)

func _stop_visual_effects() -> void:
	# Desactivar partículas gradualmente
	if particles:
		particles.emitting = false
	
	# Reducir luz gradualmente
	if light:
		var tween = create_tween()
		tween.tween_property(light, "energy", 0.3, 1.0)
	
	# Volver a animación idle
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

# ============================================
# DETECCIÓN DE JUGADOR
# ============================================

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_in_range = true
		current_player = body
		
		if prompt_label and not is_resting:
			prompt_label.visible = true
		
		print("👤 Jugador entró en rango del checkpoint: ", checkpoint_id)

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_range = false
		current_player = null
		
		if prompt_label:
			prompt_label.visible = false
		
		print("👤 Jugador salió del rango del checkpoint: ", checkpoint_id)

# ============================================
# UTILIDADES
# ============================================

func get_checkpoint_id() -> String:
	return checkpoint_id

func is_player_in_range() -> bool:
	return player_in_range
