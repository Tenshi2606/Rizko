# res://scripts/player/components/AnimationController.gd
class_name AnimationController
extends Node

## ============================================
## ANIMATION CONTROLLER - DESACTIVACIÓN GARANTIZADA
## ============================================

var player: Player
var animation_player: AnimationPlayer
var sprite: Sprite2D
var attack_component: AttackComponent

var current_animation: String = ""
var previous_animation: String = ""
var can_cancel: bool = true

func _ready() -> void:
	await get_tree().process_frame
	
	if not player:
		player = get_parent() as Player
	
	animation_player = player.get_node_or_null("AnimationPlayer") as AnimationPlayer
	
	if not animation_player:
		push_error("AnimationController: No se encontró AnimationPlayer")
		return
	
	sprite = player.get_node_or_null("Sprite2D") as Sprite2D
	
	if not sprite:
		push_error("AnimationController: No se encontró Sprite2D")
		return
	
	attack_component = player.get_node_or_null("AttackComponent") as AttackComponent
	
	# 🆕 CONECTAR A animation_started PARA LIMPIAR
	if not animation_player.animation_started.is_connected(_on_animation_started):
		animation_player.animation_started.connect(_on_animation_started)
		print("  ✅ AnimationController conectado a animation_started")
	
	print("✅ AnimationController inicializado")

# 🆕 LIMPIAR AL INICIAR NUEVA ANIMACIÓN
func _on_animation_started(anim_name: String) -> void:
	if _is_attack_animation(anim_name):
		print("🎬 Nueva animación iniciada: ", anim_name)
		
		# Limpiar lista de enemigos golpeados
		if attack_component:
			attack_component.enemies_hit_this_attack.clear()
			print("  🧹 Lista limpiada al iniciar")

func play(base_name: String, force: bool = false) -> void:
	if not animation_player:
		return
	
	var full_name = _get_animation_name(base_name)
	
	if current_animation == full_name and not force:
		return
	
	if not animation_player.has_animation(full_name):
		if OS.is_debug_build():
			print("ℹ️ Animación no encontrada: '", full_name, "'")
		if animation_player.has_animation(base_name):
			full_name = base_name
		else:
			return
	
	previous_animation = current_animation
	current_animation = full_name
	can_cancel = true
	
	print("🎬 AnimationController.play(): ", full_name)
	
	animation_player.play(full_name)

func _is_attack_animation(anim_name: String) -> bool:
	return anim_name.contains("attack") or anim_name.contains("scythe") or anim_name.contains("pogo")

func _get_animation_name(base_name: String) -> String:
	if not animation_player:
		return base_name
	
	if base_name.begins_with("scythe_") or base_name.begins_with("spectral_"):
		return base_name
	
	var weapon = player.get_current_weapon() if player else null
	if weapon and weapon.weapon_id:
		var prefix = weapon.weapon_id + "_"
		
		if base_name in ["idle", "run", "jump", "fall", "land"]:
			var prefixed_name = prefix + base_name
			if animation_player.has_animation(prefixed_name):
				return prefixed_name
	
	if animation_player.has_animation(base_name):
		return base_name
	
	return base_name

func stop() -> void:
	if animation_player:
		animation_player.stop()

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
