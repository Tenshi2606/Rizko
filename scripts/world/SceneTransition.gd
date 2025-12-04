extends Area2D
class_name SceneTransition

## Escena de destino
@export_file("*.tscn") var target_scene: String = ""

## Spawn point de destino
@export var target_spawn_point: String = "default"

## Dirección de entrada (para posicionar correctamente al jugador)
enum TransitionDirection { LEFT, RIGHT, UP, DOWN }
@export var transition_direction: TransitionDirection = TransitionDirection.RIGHT

## Offset adicional (en píxeles) desde el spawn point
@export var spawn_offset: Vector2 = Vector2.ZERO

@export_group("Timing de Transición")
## 🆕 Delay antes de iniciar la transición (útil para transiciones en techos)
@export var activation_delay: float = 0.0
## 🆕 Duración del fade out (negro entrante)
@export var fade_out_duration: float = 0.5
## 🆕 Duración del fade in (negro saliente)
@export var fade_in_duration: float = 0.5
## Activar transición instantánea (sin fade)
@export var instant_transition: bool = false

@export_group("Visual")
## Color del fade (negro para transiciones normales)
@export var fade_color: Color = Color.BLACK

@export_group("Anti-Spam")
## Cooldown solo para evitar re-entrada inmediata
@export var anti_spam_cooldown: float = 0.3

var player_inside: bool = false
var transitioning: bool = false
var last_transition_time: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	add_to_group("scene_transitions")
	
	# Configurar CollisionShape2D automáticamente si no existe
	if not has_node("CollisionShape2D"):
		_create_collision_shape()
	
	print("🚪 SceneTransition configurado")
	print("  → Destino: ", target_scene.get_file())
	print("  → Spawn: ", target_spawn_point)
	print("  → Delay: ", activation_delay, "s")
	print("  → Fade Out: ", fade_out_duration, "s")
	print("  → Fade In: ", fade_in_duration, "s")

func _create_collision_shape() -> void:
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	
	# Tamaño según dirección
	match transition_direction:
		TransitionDirection.LEFT, TransitionDirection.RIGHT:
			shape.size = Vector2(50, 300)  # Delgado vertical
		TransitionDirection.UP, TransitionDirection.DOWN:
			shape.size = Vector2(300, 50)  # Delgado horizontal
	
	collision.shape = shape
	add_child(collision)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not transitioning:
		player_inside = true
		
		# Verificar cooldown anti-spam
		var time_since_last = Time.get_ticks_msec() / 1000.0 - last_transition_time
		
		if time_since_last < anti_spam_cooldown:
			print("⚠️ Anti-spam activo (", anti_spam_cooldown - time_since_last, "s)")
			return
		
		# 🆕 Activar transición con delay si está configurado
		if activation_delay > 0:
			_trigger_transition_with_delay()
		else:
			_trigger_transition()

func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_inside = false

# 🆕 Activar transición con delay
func _trigger_transition_with_delay() -> void:
	if transitioning:
		return
	
	transitioning = true
	
	print("⏳ Esperando ", activation_delay, "s antes de transición...")
	
	# Esperar el delay
	await get_tree().create_timer(activation_delay).timeout
	
	# Verificar que el jugador sigue dentro (o si no importa)
	# Comentar esta línea si quieres que se active aunque el jugador salga
	if not player_inside:
		print("⚠️ Jugador salió durante el delay, cancelando transición")
		transitioning = false
		return
	
	_execute_transition()

func _trigger_transition() -> void:
	if transitioning or target_scene.is_empty():
		return
	
	transitioning = true
	_execute_transition()

func _execute_transition() -> void:
	if target_scene.is_empty():
		push_error("❌ SceneTransition sin target_scene configurado")
		transitioning = false
		return
	
	last_transition_time = Time.get_ticks_msec() / 1000.0
	
	print("🚪 Transición activada → ", target_scene.get_file())
	
	# Aplicar offset según dirección
	_apply_spawn_offset()
	
	# 🆕 Cambiar escena con duraciones personalizadas
	if instant_transition:
		SceneManager.change_scene(target_scene, target_spawn_point)
	else:
		SceneManager.change_scene_with_custom_fade(
			target_scene, 
			target_spawn_point, 
			fade_out_duration, 
			fade_in_duration
		)

func _apply_spawn_offset() -> void:
	# TODO: Implementar offset dinámico según dirección
	# Por ahora, SceneManager maneja el spawn point
	pass

# ============================================
# MÉTODO PÚBLICO PARA RESETEAR
# ============================================

## Llamar esto desde SceneManager después de cargar una escena
func reset_cooldown() -> void:
	transitioning = false
	print("🔄 Transición reseteada: ", name)

# ============================================
# UTILIDADES PARA EL EDITOR
# ============================================

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	# Dibujar flecha de dirección en el editor
	var arrow_color = Color(0, 1, 0, 0.5)
	
	# 🆕 Cambiar color si tiene delay (naranja = con delay)
	if activation_delay > 0:
		arrow_color = Color(1, 0.6, 0, 0.5)  # Naranja
	
	var arrow_length = 50.0
	var arrow_dir = Vector2.ZERO
	
	match transition_direction:
		TransitionDirection.LEFT:
			arrow_dir = Vector2.LEFT
		TransitionDirection.RIGHT:
			arrow_dir = Vector2.RIGHT
		TransitionDirection.UP:
			arrow_dir = Vector2.UP
		TransitionDirection.DOWN:
			arrow_dir = Vector2.DOWN
	
	var arrow_end = arrow_dir * arrow_length
	draw_line(Vector2.ZERO, arrow_end, arrow_color, 3.0)
	draw_circle(arrow_end, 8, arrow_color)
	
	# 🆕 Dibujar texto con el delay si existe
	if activation_delay > 0:
		var font = ThemeDB.fallback_font
		var font_size = 14
		var delay_text = str(activation_delay) + "s"
		draw_string(font, Vector2(-20, -20), delay_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.ORANGE)
