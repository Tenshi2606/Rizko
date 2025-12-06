# res://scripts/player/components/ComboSystem.gd
extends Node
class_name ComboSystem

## ============================================
## SISTEMA DE COMBOS SIMPLIFICADO
## ============================================
## Maneja el combo de 3 golpes en tierra

signal combo_hit(hit_index: int)
signal combo_finished
signal combo_reset

var player: Player
var attack_component: AttackComponent
var animation_controller: AnimationController

# Estado del combo
var combo_index: int = 0
var combo_window_timer: float = 0.0
const COMBO_WINDOW_DURATION: float = 2.0  # 🆕 Ventana extendida para continuar combo
var is_attacking: bool = false
var active_combo: ComboData = null  # Combo actualmente activo
var hit_enemies: Array = []  # Lista de enemigos ya golpeados en este hit

var attack_queued: bool = false
var queued_is_air: bool = false
var input_buffer_timer: float = 0.0  # Buffer pre-animación para spam
const INPUT_BUFFER_DURATION: float = 0.3  # 🆕 Ventana más grande para detectar spam
var auto_combo_enabled: bool = false  # Si está presionando ataque, auto-continuar combo

# ============================================
# 🎯 CONFIGURACIÓN DE COMBOS (RECURSOS)
# ============================================

## Combo por defecto (para armas sin combo específico)
@export var default_combo: ComboData

## Combos específicos por arma
## Key: weapon_id (ej: "scythe"), Value: ComboData
@export var weapon_combos: Dictionary = {}

## Combo de ataques aéreos
@export var air_combo: ComboData

## Combo de ataques pogo
@export var pogo_combo: ComboData

## Combo de ataques launcher
@export var launcher_combo: ComboData

func _ready() -> void:
	await get_tree().process_frame
	player = get_parent() as Player
	
	if not player:
		push_error("ComboSystem debe ser hijo de un Player")
		return
	
	# Obtener componentes
	attack_component = player.get_node_or_null("AttackComponent") as AttackComponent
	animation_controller = player.get_node_or_null("AnimationController") as AnimationController
	
	# 🐛 FIX: Esperar un frame más para asegurar que AnimationController esté listo
	await get_tree().process_frame
	
	# Conectar a AnimationController para saber cuándo termina una animación
	if animation_controller and animation_controller.animation_player:
		print("🔗 Conectando ComboSystem a animation_finished...")
		if not animation_controller.animation_player.animation_finished.is_connected(_on_animation_finished):
			animation_controller.animation_player.animation_finished.connect(_on_animation_finished)
			print("  ✅ ComboSystem conectado a animation_finished")
		else:
			print("  ⚠️ Ya estaba conectado")
	else:
		push_error("❌ No se pudo conectar a animation_finished - AnimationController o AnimationPlayer no encontrado")
	
	print("✅ ComboSystem inicializado")

func _process(delta: float) -> void:
	# Actualizar ventana de combo
	if combo_window_timer > 0:
		combo_window_timer -= delta
		
		# 🐛 FIX: Solo resetear si el timer expiró Y hay un combo activo
		# Esto evita resetear antes de que _on_animation_finished active la ventana
		if combo_window_timer <= 0 and combo_index > 0:
			print("⏱️ Ventana de combo expirada - reseteando")
			reset_combo()
	
	# 🆕 Actualizar buffer de input
	if input_buffer_timer > 0:
		input_buffer_timer -= delta

## Obtener el combo activo según el arma actual
func _get_active_combo() -> ComboData:
	var weapon = player.get_current_weapon()
	
	# Buscar combo específico para esta arma
	if weapon and weapon.weapon_id in weapon_combos:
		var combo = weapon_combos[weapon.weapon_id]
		if combo and combo.can_use_with_weapon(weapon):
			return combo
	
	# Usar combo por defecto
	return default_combo

# ============================================
# 🎯 EJECUTAR ATAQUE
# ============================================

## Intentar ejecutar un ataque (llamado desde estados)
func try_attack() -> bool:
	return _try_attack_internal(Player.AttackDirection.FORWARD, false)

func try_air_attack() -> bool:
	return _try_attack_internal(Player.AttackDirection.FORWARD, true)

## Intenta ejecutar ataque pogo (hacia abajo)
func try_pogo_attack() -> bool:
	return _try_attack_internal(Player.AttackDirection.DOWN, false)

## Intenta ejecutar ataque launcher (hacia arriba)
func try_launcher_attack() -> bool:
	return _try_attack_internal(Player.AttackDirection.UP, false)

## Lógica interna para manejar ataques
func _try_attack_internal(direction: Player.AttackDirection, is_air: bool = false) -> bool:
	# Si hay ventana de combo activa, continuar el combo
	if combo_window_timer > 0 and combo_index > 0:
		return _execute_next_attack(is_air)
	
	# 🆕 AUTO-COMBO: Si está atacando, activar auto-combo
	if is_attacking:
		var active_combo = _get_active_combo_for_context(is_air)
		var max_hits = active_combo.get_attack_count() if active_combo else 3
		
		# Solo encolar si no hemos llegado al máximo
		if combo_index < max_hits:
			if not attack_queued:
				attack_queued = true
				queued_is_air = is_air
				auto_combo_enabled = true  # Activar auto-combo
				print("🎮 Auto-combo activado (hit ", combo_index + 1, "/", max_hits, ")")
		return false
	
	# Ejecutar ataque
	return _execute_next_attack(is_air)

func _execute_next_attack(is_air: bool = false) -> bool:
	print("\n>>> _execute_next_attack llamado - is_air:", is_air, " combo_index:", combo_index)
	
	# Marcar que estamos atacando
	is_attacking = true
	print("🔒 is_attacking = TRUE")
	
	# Limpiar ataque encolado
	attack_queued = false
	queued_is_air = false
	
	# Obtener combo activo según contexto
	var active_combo = _get_active_combo_for_context(is_air)
	
	# 🆕 FALLBACK: Si no hay combo, usar sistema hardcodeado antiguo
	if not active_combo:
		print("⚠️ No hay combo disponible - usando fallback hardcodeado")
		return _execute_hardcoded_attack()
	
	# Incrementar combo
	combo_index += 1
	
	# Verificar si llegamos al final del combo
	var max_hits = active_combo.get_attack_count()
	if combo_index > max_hits:
		if active_combo.loop_combo:
			combo_index = 1
		else:
			reset_combo()
			return false
	
	# Obtener ataque actual
	var attack_data = active_combo.get_attack(combo_index - 1)
	if not attack_data:
		print("⚠️ No se encontró AttackData para índice ", combo_index)
		return false
	
	var anim_name = attack_data.animation_name
	
	print("⚔️ Ejecutando combo hit ", combo_index, "/", max_hits)
	print("  Animación: ", anim_name)
	print("  Combo: ", active_combo.combo_name)
	print("  Tipo: ", "AIRE" if is_air else "TIERRA")
	
	# Reproducir animación
	if animation_controller:
		animation_controller.play(anim_name, true)
	
	# Marcar como atacando
	is_attacking = true
	attack_queued = false
	
	# Iniciar ventana de combo (usar duración del combo)
	combo_window_timer = active_combo.combo_window
	
	# Emitir señal
	combo_hit.emit(combo_index)
	return true

## Ejecutar ataques especiales (pogo, launcher)
func _execute_special_attack(attack_type: String) -> bool:
	var combo_to_use: ComboData = null
	
	match attack_type:
		"pogo":
			combo_to_use = pogo_combo
		"launcher":
			combo_to_use = launcher_combo
	
	if not combo_to_use:
		print("⚠️ No hay combo configurado para ", attack_type)
		return _execute_hardcoded_special(attack_type)
	
	# Resetear combo para ataques especiales (no son secuencias)
	reset_combo()
	
	var attack_data = combo_to_use.get_attack(0)
	if not attack_data:
		print("⚠️ No se encontró AttackData para ", attack_type)
		return false
	
	var anim_name = attack_data.animation_name
	
	print("⚔️ Ejecutando ataque especial: ", attack_type.to_upper())
	print("  Animación: ", anim_name)
	
	# Reproducir animación
	if animation_controller:
		animation_controller.play(anim_name, true)
	
	# Marcar como atacando
	is_attacking = true
	attack_queued = false
	combo_window_timer = 0.0  # No hay ventana para ataques especiales
	
	return true

## Obtener combo según contexto (aire vs tierra)
func _get_active_combo_for_context(is_air: bool) -> ComboData:
	if is_air and air_combo:
		return air_combo
	return _get_active_combo()

## Fallback para cuando no hay combo configurado
func _execute_hardcoded_attack() -> bool:
	combo_index += 1
	if combo_index > 3:
		combo_index = 1
	
	var anim_name = "attack_ground_" + str(combo_index)
	
	print("⚔️ Ejecutando ataque hardcodeado ", combo_index, "/3")
	print("  Animación: ", anim_name)
	
	if animation_controller:
		animation_controller.play(anim_name, true)
	
	is_attacking = true
	attack_queued = false
	combo_window_timer = 1.5  # Ventana por defecto
	combo_hit.emit(combo_index)
	return true

## Fallback para ataques especiales sin recursos
func _execute_hardcoded_special(attack_type: String) -> bool:
	var anim_name = "attack_" + attack_type
	
	print("⚔️ Ejecutando ataque especial hardcodeado: ", attack_type)
	print("  Animación: ", anim_name)
	
	if animation_controller:
		animation_controller.play(anim_name, true)
	
	is_attacking = true
	attack_queued = false
	combo_window_timer = 0.0
	return true

# ============================================
# 🔔 CALLBACKS
# ============================================

func _on_animation_finished(anim_name: String) -> void:
	print("\n<<< _on_animation_finished: ", anim_name)
	print("🔍 Estado ANTES: is_attacking=", is_attacking, " auto_combo_enabled=", auto_combo_enabled, " attack_queued=", attack_queued)
	
	# Solo procesar si es una animación de ataque
	if not anim_name.begins_with("scythe_attack") and not anim_name.begins_with("spectral_attack"):
		return
	
	# 🆕 NO poner is_attacking en false todavía si hay auto-combo
	# Esto evita que spam reinicie la animación
	
	# Activar ventana de combo
	combo_window_timer = COMBO_WINDOW_DURATION
	
	# Limpiar lista de enemigos golpeados para el siguiente hit
	hit_enemies.clear()
	
	# 🆕 AUTO-COMBO: Si está activado, ejecutar siguiente hit automáticamente
	if auto_combo_enabled and combo_index < (active_combo.get_attack_count() if active_combo else 3):
		print("⚡ AUTO-COMBO: Ejecutando hit ", combo_index + 1, " - MANTENIENDO is_attacking=true")
		# NO poner is_attacking = false, mantenerlo true
		_execute_next_attack(queued_is_air)
		auto_combo_enabled = false
		return
	
	# Verificar si hay ataque encolado
	if attack_queued:
		print("🔄 ATAQUE ENCOLADO: Ejecutando - MANTENIENDO is_attacking=true")
		# NO poner is_attacking = false, mantenerlo true
		_execute_next_attack(queued_is_air)
		return
	
	# Solo ahora poner is_attacking en false
	print("🔓 is_attacking = FALSE (no hay más ataques encolados)")
	is_attacking = false
	
	# Si era el último golpe del combo, terminar
	if active_combo and combo_index > active_combo.get_attack_count():
		print("🎯 Combo completo!")
		combo_finished.emit()
		reset_combo()
		return
	
	# Si no hay combo activo, resetear
	if not active_combo:
		reset_combo()
		return
	
	# Extender ventana de combo después de cada golpe para permitir continuar
	# Esto da tiempo al jugador para presionar ataque de nuevo
	var window_duration = active_combo.combo_window
	combo_window_timer = window_duration
	print("⏳ Ventana de combo activa (", COMBO_WINDOW_DURATION, "s)")
	print("  📊 Estado: hit ", combo_index, "/", active_combo.get_attack_count())
	
	# 🆕 Limpiar lista de enemigos golpeados después de cada hit
	# Esto permite que el siguiente hit del combo golpee al mismo enemigo
	_clear_hit_list()


# ============================================
# 🗺️ HELPERS
# ============================================

## Esta función ya no se usa - ahora se obtiene desde ComboData
## Mantener por compatibilidad pero marcar como deprecated
func _get_attack_animation() -> String:
	var active_combo = _get_active_combo()
	if not active_combo:
		return "attack_ground_1"
	
	var attack_data = active_combo.get_attack(combo_index - 1)
	if attack_data:
		return attack_data.animation_name
	
	return "attack_ground_1"

## Resetear combo
func reset_combo() -> void:
	if combo_index > 0:
		print("🔄 Combo reseteado")
		combo_reset.emit()
	
	combo_index = 0
	combo_window_timer = 0.0
	is_attacking = false
	attack_queued = false
	queued_is_air = false  # Resetear contexto
	
	# 🆕 Limpiar lista de enemigos al resetear
	_clear_hit_list()

## Limpiar lista de enemigos golpeados
func _clear_hit_list() -> void:
	hit_enemies.clear()

## Verificar si está en medio de un combo
func is_in_combo() -> bool:
	return combo_index > 0 and combo_window_timer > 0

## Verificar si está atacando
func is_currently_attacking() -> bool:
	return is_attacking
