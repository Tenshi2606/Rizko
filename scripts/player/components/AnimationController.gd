# res://scripts/player/components/AnimationController.gd
class_name AnimationController
extends Node

## ============================================
## ANIMATION CONTROLLER
## ============================================
## Centraliza todas las animaciones del player
## Soporte automático para armas
## Base para sistema de combos

# ============================================
# REFERENCIAS
# ============================================

@onready var player: Player = get_parent()
@onready var sprite: AnimatedSprite2D

# ============================================
# CONFIGURACIÓN
# ============================================

## Tiempo de blend entre animaciones (para transiciones suaves)
@export var default_blend_time: float = 0.1

## Si las animaciones pueden ser canceladas
@export var allow_canceling: bool = true

## Frame mínimo para poder cancelar animación
@export var min_cancel_frame: int = 5

# ============================================
# VARIABLES INTERNAS
# ============================================

## Animación actual
var current_animation: String = ""

## Animación anterior
var previous_animation: String = ""

## Si la animación actual puede ser cancelada
var can_cancel: bool = true

## Tiempo desde que empezó la animación actual
var animation_time: float = 0.0

# ============================================
# READY
# ============================================

func _ready() -> void:
	await get_tree().process_frame
	
	if not player:
		player = get_parent() as Player
	
	sprite = player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	
	if not sprite:
		push_error("AnimationController: No se encontró AnimatedSprite2D")
		return
	
	print("✅ AnimationController inicializado")

# ============================================
# PROCESS
# ============================================

func _process(delta: float) -> void:
	if sprite and sprite.is_playing():
		animation_time += delta

# ============================================
# MÉTODOS PÚBLICOS - REPRODUCIR ANIMACIONES
# ============================================

## Reproduce una animación con soporte automático para armas
## @param base_name: Nombre base de la animación (ej: "run", "attack")
## @param force: Si debe forzar la reproducción aunque ya esté activa
## @param blend_time: Tiempo de transición (no usado aún, para futuro)
func play(base_name: String, force: bool = false, _blend_time: float = -1.0) -> void:
	if not sprite:
		return
	
	# Obtener sufijo de arma
	var weapon_suffix = _get_weapon_suffix()
	
	# 🔧 PRIORIDAD: Arma primero, luego base
	# Buscar: attack_scythe_down → attack_down
	var full_name = base_name + weapon_suffix
	
	if weapon_suffix != "" and sprite.sprite_frames.has_animation(full_name):
		# ✅ Tiene animación específica de arma (ej: attack_scythe_down)
		_play_animation(full_name, force)
	elif sprite.sprite_frames.has_animation(base_name):
		# ✅ Usar animación base (ej: attack_down) - fallback
		_play_animation(base_name, force)
	else:
		# ❌ No existe ninguna
		push_warning("⚠️ Animación no encontrada: '" + base_name + "' ni '" + full_name + "'")

## Reproduce una animación de combo específica
## @param combo_index: Índice del combo (1, 2, 3, etc.)
func play_combo(combo_index: int) -> void:
	var anim_name = "attack_" + str(combo_index)
	play(anim_name, true)

## Reproduce animación de launcher (para combos aéreos)
func play_launcher() -> void:
	play("attack_launcher", true)

## Reproduce animación de ataque aéreo
## @param air_index: Índice del ataque aéreo (1, 2, etc.)
func play_air_attack(air_index: int = 1) -> void:
	var anim_name = "air_attack_" + str(air_index)
	play(anim_name, true)

# ============================================
# MÉTODOS PÚBLICOS - CONTROL DE ANIMACIÓN
# ============================================

## Detiene la animación actual
func stop() -> void:
	if sprite:
		sprite.stop()
		animation_time = 0.0

## Pausa la animación actual
func pause() -> void:
	if sprite:
		sprite.pause()

## Reanuda la animación pausada
func resume() -> void:
	if sprite:
		sprite.play()

## Verifica si se puede cancelar la animación actual
func can_cancel_animation() -> bool:
	if not allow_canceling:
		return false
	
	if not can_cancel:
		return false
	
	# Verificar frame mínimo
	if sprite and sprite.is_playing():
		var current_frame = sprite.frame
		return current_frame >= min_cancel_frame
	
	return true

## Fuerza que la animación actual sea cancelable
func set_cancelable(cancelable: bool) -> void:
	can_cancel = cancelable

# ============================================
# MÉTODOS PÚBLICOS - INFORMACIÓN
# ============================================

## Obtiene el nombre de la animación actual
func get_current_animation() -> String:
	return current_animation

## Obtiene el nombre de la animación anterior
func get_previous_animation() -> String:
	return previous_animation

## Verifica si una animación existe
func has_animation(anim_name: String) -> bool:
	if not sprite:
		return false
	
	var weapon_suffix = _get_weapon_suffix()
	var full_name = anim_name + weapon_suffix
	
	return sprite.sprite_frames.has_animation(full_name) or sprite.sprite_frames.has_animation(anim_name)

## Obtiene la duración de una animación en segundos
func get_animation_length(anim_name: String) -> float:
	if not sprite or not sprite.sprite_frames:
		return 0.0
	
	var weapon_suffix = _get_weapon_suffix()
	var full_name = anim_name + weapon_suffix
	
	# Intentar con arma primero
	if sprite.sprite_frames.has_animation(full_name):
		var frame_count = sprite.sprite_frames.get_frame_count(full_name)
		var fps = sprite.sprite_frames.get_animation_speed(full_name)
		return frame_count / fps if fps > 0 else 0.0
	elif sprite.sprite_frames.has_animation(anim_name):
		var frame_count = sprite.sprite_frames.get_frame_count(anim_name)
		var fps = sprite.sprite_frames.get_animation_speed(anim_name)
		return frame_count / fps if fps > 0 else 0.0
	
	return 0.0

## Obtiene el tiempo transcurrido de la animación actual
func get_animation_time() -> float:
	return animation_time

## Verifica si la animación actual ha terminado
func is_animation_finished() -> bool:
	if not sprite:
		return true
	return not sprite.is_playing()

## Obtiene el frame actual de la animación
func get_current_frame() -> int:
	if not sprite:
		return 0
	return sprite.frame

## Obtiene el total de frames de la animación actual
func get_frame_count() -> int:
	if not sprite or current_animation == "":
		return 0
	return sprite.sprite_frames.get_frame_count(current_animation)

# ============================================
# MÉTODOS INTERNOS
# ============================================

func _play_animation(anim_name: String, force: bool) -> void:
	if not sprite:
		return
	
	# Si es la misma animación y no se fuerza, no hacer nada
	if current_animation == anim_name and not force:
		return
	
	# Guardar animación anterior
	previous_animation = current_animation
	current_animation = anim_name
	animation_time = 0.0
	can_cancel = true
	
	# Reproducir
	sprite.play(anim_name)

func _get_weapon_suffix() -> String:
	if not player:
		return ""
	
	var weapon_system = player.get_node_or_null("WeaponSystem") as WeaponSystem
	if not weapon_system:
		return ""
	
	var weapon = weapon_system.get_current_weapon()
	if not weapon:
		return ""
	
	# Mapeo de IDs de arma a sufijos
	match weapon.weapon_id:
		"scythe":
			return "_scythe"
		"sword":
			return "_sword"
		"axe":
			return "_axe"
		_:
			return ""
