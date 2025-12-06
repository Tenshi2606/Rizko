# res://scripts/player/components/AnimationController.gd
class_name AnimationController
extends Node

## ============================================
## ANIMATION CONTROLLER - SIN TRACKS DE HITBOX
## ============================================
## Reproduce animaciones y activa/desactiva hitboxes manualmente

var player: Player
var animation_player: AnimationPlayer
var sprite: Sprite2D
var attack_component: AttackComponent

var current_animation: String = ""
var previous_animation: String = ""
var can_cancel: bool = true

# 🆕 CONTROL MANUAL DE HITBOXES
var hitbox_active: bool = false
var hitbox_timer: float = 0.0
var hitbox_duration: float = 0.0

func _ready() -> void:
	await get_tree().process_frame
	
	if not player:
		player = get_parent() as Player
	
	# Buscar AnimationPlayer
	animation_player = player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	
	if not animation_player:
		push_error("AnimationController: No se encontró AnimationPlayer")
		return
	
	# Buscar Sprite2D
	sprite = player.get_node_or_null("Sprite2D") as Sprite2D
	
	if not sprite:
		push_error("AnimationController: No se encontró Sprite2D")
		return
	
	# Buscar AttackComponent
	attack_component = player.get_node_or_null("AttackComponent") as AttackComponent
	
	# 🐛 FIX: NO conectar a animation_finished aquí
	# ComboSystem ya maneja esto, tener dos callbacks causa conflictos
	# El callback de AnimationController ya no es necesario
	
	print("✅ AnimationController inicializado")

# ============================================
# 🎯 ANIMACIONES DE ATAQUE
# ============================================
# AnimationPlayer maneja los hitboxes vía tracks
# Este script solo reproduce las animaciones

func play(base_name: String, force: bool = false) -> void:
	if not animation_player:
		return
	
	var full_name = _get_animation_name(base_name)
	
	if current_animation == full_name and not force:
		return
	
	if not animation_player.has_animation(full_name):
		if OS.is_debug_build():
			print("ℹ️ Animación no encontrada: '", full_name, "' - usando base")
		if animation_player.has_animation(base_name):
			full_name = base_name
		else:
			return
	
	previous_animation = current_animation
	current_animation = full_name
	can_cancel = true
	
	print("🎬 AnimationController.play():")
	print("  📝 Base name: ", base_name)
	print("  🎯 Full name: ", full_name)
	print("  ✅ AnimationPlayer controlará los hitboxes")
	
	# 🆕 Limpiar lista de enemigos golpeados al empezar un ataque
	if _is_attack_animation(full_name) and attack_component:
		attack_component.enemies_hit_this_attack.clear()
		print("  🔄 Lista de golpes limpiada")
	
	animation_player.play(full_name)

# ============================================
# 🔧 PROCESO CONTINUO (YA NO GESTIONA HITBOX)
# ============================================

func _process(_delta: float) -> void:
	# Ya no hay gestión manual de hitboxes
	# AnimationPlayer lo hace todo vía tracks
	pass

# ============================================
# 📊 HELPERS
# ============================================

func _is_attack_animation(anim_name: String) -> bool:
	return anim_name.contains("attack") or anim_name.contains("scythe")

func _get_attack_type_from_animation(anim_name: String) -> String:
	if anim_name.contains("launcher"):
		return "launcher"
	elif anim_name.contains("pogo"):
		return "pogo"
	elif anim_name.contains("air"):
		return "air"
	else:
		return "ground"

func _get_hitbox_duration(attack_type: String) -> float:
	match attack_type:
		"ground":
			return 0.25
		"air":
			return 0.3
		"pogo":
			return 0.3
		"launcher":
			return 0.35
		_:
			return 0.3

# ============================================
# 🗺️ MAPEO DE NOMBRES SIMPLIFICADO
# ============================================

func _get_animation_name(base_name: String) -> String:
	if not animation_player:
		return base_name
	
	# Si ya tiene prefijo de arma, devolver tal cual
	if base_name.begins_with("scythe_") or base_name.begins_with("spectral_"):
		return base_name
	
	# Intentar con prefijo de arma PRIMERO
	var weapon = player.get_current_weapon() if player else null
	if weapon and weapon.weapon_id:
		var prefix = weapon.weapon_id + "_"
		
		# Solo añadir prefijo a animaciones básicas (idle, run, jump, fall)
		if base_name in ["idle", "run", "jump", "fall", "land"]:
			var prefixed_name = prefix + base_name
			# Verificar si existe la animación con prefijo
			if animation_player.has_animation(prefixed_name):
				return prefixed_name
	
	# Si la animación base existe, usarla como fallback
	if animation_player.has_animation(base_name):
		return base_name
	
	# Último fallback
	return base_name

# ============================================
# 🎮 API PÚBLICA
# ============================================

func stop() -> void:
	if animation_player:
		animation_player.stop()
	# AnimationPlayer maneja los hitboxes, no necesitamos desactivarlos manualmente

func pause() -> void:
	if animation_player:
		animation_player.pause()

func resume() -> void:
	if animation_player:
		animation_player.play()

func can_cancel_animation() -> bool:
	return can_cancel

func set_cancelable(cancelable: bool) -> void:
	can_cancel = cancelable

func get_current_animation() -> String:
	return current_animation

func get_previous_animation() -> String:
	return previous_animation

func has_animation(anim_name: String) -> bool:
	if not animation_player:
		return false
	
	var full_name = _get_animation_name(anim_name)
	return animation_player.has_animation(full_name)

func get_animation_length(anim_name: String) -> float:
	if not animation_player:
		return 0.0
	
	var full_name = _get_animation_name(anim_name)
	
	if animation_player.has_animation(full_name):
		return animation_player.get_animation(full_name).length
	
	return 0.0

func is_animation_finished() -> bool:
	if not animation_player:
		return true
	return not animation_player.is_playing()

func set_flip_h(flip: bool) -> void:
	if sprite:
		sprite.flip_h = flip
