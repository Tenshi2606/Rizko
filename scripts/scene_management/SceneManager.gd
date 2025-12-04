extends Node

signal scene_changed(new_scene_path: String)
signal scene_loading_started
signal scene_loading_finished

# Estado del jugador
var player_data: Dictionary = {}
var current_scene_path: String = ""
var spawn_point_id: String = "default"

# CHECKPOINT SYSTEM
var last_checkpoint_id: String = "default"
var last_checkpoint_scene: String = ""

# FLAG PARA RESPAWN DE ENEMIGOS
var is_respawning_enemies: bool = false

# FLAG PARA RESTAURAR VIDA COMPLETA
var should_restore_full_health: bool = false

# SISTEMA DE ENTRADA DIRECCIONAL CON PRESERVACIÓN DE POSICIÓN
var entry_direction: String = ""
var entry_spawn_offset: Vector2 = Vector2.ZERO
var preserve_horizontal_position: bool = false
var preserve_vertical_position: bool = false
var saved_player_position: Vector2 = Vector2.ZERO

# PERSISTENCIA DE MUNDO (Hollow Knight style)
var world_state: Dictionary = {
	"killed_enemies": [],
	"opened_chests": [],
	"collected_items": [],
	"unlocked_doors": [],
	"completed_events": [],
	"broken_walls": []  # 🆕 Muros rotos
}

# Control de transiciones
var is_transitioning: bool = false
var fade_layer: CanvasLayer = null
var fade_rect: ColorRect = null

# CONFIGURACIÓN DE ESTABILIZACIÓN DE CÁMARA
var camera_stabilization_frames: int = 3
var camera_stabilization_delay: float = 0.2

func _ready() -> void:
	_create_fade_layer()
	
	var root = get_tree().root
	var current_scene = root.get_child(root.get_child_count() - 1)
	current_scene_path = current_scene.scene_file_path
	last_checkpoint_scene = current_scene_path
	
	print("🗺️ SceneManager inicializado")
	print("  Escena actual: ", current_scene_path)
	print("  📷 Frames de estabilización: ", camera_stabilization_frames)
	print("  📷 Delay de estabilización: ", camera_stabilization_delay, "s")
	
	# FORZAR ACTIVACIÓN DE CAMERA ZONES AL INICIAR
	call_deferred("_initialize_camera_zones_on_start")

func _initialize_camera_zones_on_start() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	print("\n🎬 ═══ INICIALIZACIÓN DE CAMERA ZONES ═══")
	
	var player = get_tree().get_first_node_in_group("Player") as Player
	if not player:
		print("  ⚠️  No se encontró Player al iniciar")
		return
	
	print("  ✅ Player encontrado, forzando activación de CameraZones...")
	_force_activate_camera_zones(player)

# ============================================
# CHECKPOINT SYSTEM
# ============================================

func register_checkpoint(checkpoint_id: String, scene_path: String) -> void:
	last_checkpoint_id = checkpoint_id
	last_checkpoint_scene = scene_path
	spawn_point_id = checkpoint_id
	
	print("📍 Checkpoint registrado:")
	print("  - ID: ", checkpoint_id)
	print("  - Escena: ", scene_path)

func respawn_enemies_in_current_scene() -> void:
	print("☠️ Respawneando enemigos en escena actual...")
	
	is_respawning_enemies = true
	
	var current_scene_name = get_current_scene_name()
	var enemies_to_remove = []
	
	for enemy_id in world_state["killed_enemies"]:
		if enemy_id.begins_with(current_scene_name):
			enemies_to_remove.append(enemy_id)
	
	for enemy_id in enemies_to_remove:
		world_state["killed_enemies"].erase(enemy_id)
		print("  ✅ Enemigo limpiado de lista: ", enemy_id)
	
	_reload_current_scene_with_player_position()

func _reload_current_scene_with_player_position() -> void:
	var player = get_tree().get_first_node_in_group("Player") as Player
	var player_pos = Vector2.ZERO
	
	if player:
		player_pos = player.global_position
	
	_save_player_data()
	
	var error = get_tree().reload_current_scene()
	
	if error != OK:
		push_error("❌ Error al recargar escena: ", error)
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	_restore_player_data()
	
	player = get_tree().get_first_node_in_group("Player") as Player
	if player:
		player.global_position = player_pos
		print("📍 Jugador reposicionado en: ", player_pos)

# ============================================
# CAMBIAR DE ESCENA
# ============================================

func change_scene(target_scene_path: String, target_spawn_point: String = "default") -> void:
	if is_transitioning:
		print("⚠️ Ya hay una transición en curso")
		return
	
	is_transitioning = true
	spawn_point_id = target_spawn_point
	
	print("🚪 Cambiando a escena: ", target_scene_path)
	print("  Spawn point: ", spawn_point_id)
	
	_save_player_data()
	
	await _fade_out()
	
	scene_loading_started.emit()
	
	var error = get_tree().change_scene_to_file(target_scene_path)
	
	if error != OK:
		push_error("❌ Error al cargar escena: ", error)
		is_transitioning = false
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	current_scene_path = target_scene_path
	
	fade_rect.color.a = 1.0
	print("📷 Manteniendo pantalla negra para configuración...")
	
	reset_all_transition_cooldowns()
	_restore_player_data()
	_apply_world_state()
	_position_player_at_spawn()
	
	await _wait_for_camera_stabilization()
	
	is_respawning_enemies = false
	
	scene_loading_finished.emit()
	scene_changed.emit(target_scene_path)
	
	await _fade_in()
	
	is_transitioning = false
	print("✅ Transición completada")

func change_scene_with_custom_fade(
	target_scene_path: String, 
	target_spawn_point: String = "default",
	fade_out_time: float = 0.5,
	fade_in_time: float = 0.5
) -> void:
	if is_transitioning:
		print("⚠️ Ya hay una transición en curso")
		return
	
	is_transitioning = true
	spawn_point_id = target_spawn_point
	
	print("\n🚪 ═══════════════════════════════════════")
	print("🚪 CAMBIO DE ESCENA CON FADE PERSONALIZADO")
	print("🚪 ═══════════════════════════════════════")
	print("  📁 Escena: ", target_scene_path)
	print("  📍 Spawn: ", spawn_point_id)
	print("  🎬 Fade Out: ", fade_out_time, "s")
	print("  🎬 Fade In: ", fade_in_time, "s")
	
	_save_player_data()
	
	await _fade_out(fade_out_time)
	
	scene_loading_started.emit()
	
	var error = get_tree().change_scene_to_file(target_scene_path)
	
	if error != OK:
		push_error("❌ Error al cargar escena: ", error)
		is_transitioning = false
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	current_scene_path = target_scene_path
	
	fade_rect.color.a = 1.0
	print("📷 Manteniendo pantalla negra para configuración...")
	
	reset_all_transition_cooldowns()
	_restore_player_data()
	_apply_world_state()
	_position_player_at_spawn()
	
	await _wait_for_camera_stabilization()
	
	is_respawning_enemies = false
	
	scene_loading_finished.emit()
	scene_changed.emit(target_scene_path)
	
	print("🎬 Iniciando fade in...")
	await _fade_in(fade_in_time)
	
	is_transitioning = false
	print("✅ Transición completada\n")

# ============================================
# ESTABILIZACIÓN DE CÁMARA
# ============================================

func _wait_for_camera_stabilization() -> void:
	print("\n📷 ═══ ESTABILIZACIÓN DE CÁMARA ═══")
	
	for i in range(camera_stabilization_frames):
		await get_tree().process_frame
		print("  Frame ", i + 1, "/", camera_stabilization_frames)
	
	var player = get_tree().get_first_node_in_group("Player") as Player
	if not player:
		print("  ⚠️  No se encontró Player")
		print("📷 ═══ Estabilización completada ═══\n")
		return
	
	var camera = player.get_node_or_null("Camera2D") as CameraController
	if not camera:
		print("  ⚠️  No se encontró Camera2D")
		print("📷 ═══ Estabilización completada ═══\n")
		return
	
	print("  ✅ Cámara encontrada")
	
	if camera.has_method("force_apply_camera_zones"):
		print("  🔧 Forzando aplicación de CameraZones...")
		camera.force_apply_camera_zones()
	else:
		print("  ⚠️  Método force_apply_camera_zones no encontrado")
		
		if camera_stabilization_delay > 0:
			print("  ⏱️  Esperando ", camera_stabilization_delay, "s adicionales...")
			await get_tree().create_timer(camera_stabilization_delay).timeout
	
	if camera.has_method("get") and camera.get("current_zone"):
		var zone = camera.get("current_zone")
		if zone:
			print("  ✅ CameraZone activa: ", zone.get("zone_name") if zone.has_method("get") else "Unknown")
			print("    Límites aplicados:")
			print("      Left: ", camera.limit_left)
			print("      Top: ", camera.limit_top)
			print("      Right: ", camera.limit_right)
			print("      Bottom: ", camera.limit_bottom)
	else:
		print("  ℹ️  Sin CameraZone (cámara libre)")
		print("    Límites actuales:")
		print("      Left: ", camera.limit_left)
		print("      Top: ", camera.limit_top)
		print("      Right: ", camera.limit_right)
		print("      Bottom: ", camera.limit_bottom)
	
	await get_tree().process_frame
	
	print("📷 ═══ Estabilización completada ═══\n")

# ============================================
# PERSISTENCIA DE MUNDO
# ============================================

func register_enemy_killed(enemy_id: String) -> void:
	if not world_state["killed_enemies"].has(enemy_id):
		world_state["killed_enemies"].append(enemy_id)
		print("☠️ Enemigo registrado como muerto: ", enemy_id)

func register_chest_opened(chest_id: String) -> void:
	if not world_state["opened_chests"].has(chest_id):
		world_state["opened_chests"].append(chest_id)
		print("📦 Cofre registrado como abierto: ", chest_id)

func register_item_collected(item_id: String) -> void:
	if not world_state["collected_items"].has(item_id):
		world_state["collected_items"].append(item_id)
		print("✨ Item registrado como recogido: ", item_id)

func register_door_unlocked(door_id: String) -> void:
	if not world_state["unlocked_doors"].has(door_id):
		world_state["unlocked_doors"].append(door_id)
		print("🔓 Puerta registrada como desbloqueada: ", door_id)

func is_enemy_killed(enemy_id: String) -> bool:
	return world_state["killed_enemies"].has(enemy_id)

func is_chest_opened(chest_id: String) -> bool:
	return world_state["opened_chests"].has(chest_id)

func is_item_collected(item_id: String) -> bool:
	return world_state["collected_items"].has(item_id)

func is_door_unlocked(door_id: String) -> bool:
	return world_state["unlocked_doors"].has(door_id)

# 🆕 MUROS ROTOS
func register_wall_broken(wall_id: String) -> void:
	if not world_state["broken_walls"].has(wall_id):
		world_state["broken_walls"].append(wall_id)
		print("🧱 Muro registrado como roto: ", wall_id)

func is_wall_broken(wall_id: String) -> bool:
	return world_state["broken_walls"].has(wall_id)

func _apply_world_state() -> void:
	print("🌍 Aplicando estado del mundo...")
	
	if is_respawning_enemies:
		print("  ⚠️ Modo respawn activo - Los enemigos NO se eliminarán")
	else:
		var enemies = get_tree().get_nodes_in_group("enemies")
		for enemy in enemies:
			if enemy.has_method("get_enemy_id"):
				var enemy_id = enemy.get_enemy_id()
				if is_enemy_killed(enemy_id):
					print("  ☠️ Eliminando enemigo: ", enemy_id)
					enemy.queue_free()
	
	var items = get_tree().get_nodes_in_group("item_pickups")
	for item in items:
		if item.has_method("get_item_id"):
			var item_id = item.get_item_id()
			if is_item_collected(item_id):
				print("  ✨ Eliminando item: ", item_id)
				item.queue_free()
	
	var chests = get_tree().get_nodes_in_group("chests")
	for chest in chests:
		if chest.has_method("get_chest_id"):
			var chest_id = chest.get_chest_id()
			if is_chest_opened(chest_id):
				print("  📦 Marcando cofre como abierto: ", chest_id)
				if chest.has_method("set_opened"):
					chest.set_opened(true)
	
	# 🆕 MUROS ROTOS
	# Los muros se auto-verifican en su _ready(), no necesitan aplicación manual aquí
	# pero podemos hacer un log
	var walls = get_tree().get_nodes_in_group("breakable_walls")
	var broken_count = 0
	for wall in walls:
		if wall.has_method("get") and wall.get("is_broken"):
			broken_count += 1
	if broken_count > 0:
		print("  🧱 Muros rotos en esta escena: ", broken_count)

# ============================================
# GUARDAR/RESTAURAR DATOS
# ============================================

func _save_player_data() -> void:
	var player = get_tree().get_first_node_in_group("Player") as Player
	if not player:
		return
	
	player_data = {
		"health": player.health,
		"max_health": player.max_health,
		"inventory": player.inventory.serialize() if player.inventory else {},
		"weapons": player.weapon_system.serialize() if player.weapon_system else {},
		"wallet": player.get_node_or_null("Wallet").serialize() if player.get_node_or_null("Wallet") else {}
	}
	
	print("💾 Datos del jugador guardados")

func _restore_player_data() -> void:
	if player_data.is_empty():
		print("⚠️ No hay datos del jugador para restaurar")
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	var player = get_tree().get_first_node_in_group("Player") as Player
	if not player:
		push_warning("⚠️ No se encontró Player en la nueva escena")
		return
	
	if should_restore_full_health:
		player.health = player.max_health
		print("  ❤️ Vida restaurada a máximo (checkpoint/muerte)")
		should_restore_full_health = false
	else:
		player.health = player_data.get("health", player.max_health)
		print("  ❤️ Vida mantenida: ", player.health, "/", player.max_health)
	
	player.max_health = player_data.get("max_health", 5)
	
	var health_component = player.get_node_or_null("HealthComponent")
	if health_component and health_component.has_method("_update_health_bar"):
		health_component._update_health_bar()
	
	if player.inventory and player_data.has("inventory"):
		player.inventory.deserialize(player_data["inventory"])
	
	if player.weapon_system and player_data.has("weapons"):
		player.weapon_system.deserialize(player_data["weapons"])
	
	var wallet = player.get_node_or_null("Wallet")
	if wallet and player_data.has("wallet"):
		wallet.deserialize(player_data["wallet"])
	
	print("📂 Datos del jugador restaurados")

# ============================================
# POSICIONAR JUGADOR
# ============================================

func _position_player_at_spawn() -> void:
	var player = get_tree().get_first_node_in_group("Player") as Player
	if not player:
		print("❌ No se encontró Player en la escena")
		return
	
	print("\n📍 ═══════════════════════════════════════")
	print("📍 POSICIONANDO JUGADOR")
	print("📍 ═══════════════════════════════════════")
	print("  🎯 Buscando spawn_point_id: ", spawn_point_id)
	
	var spawn_position: Vector2 = Vector2.ZERO
	var found_spawn: bool = false
	
	var checkpoints = get_tree().get_nodes_in_group("checkpoints")
	print("  🔍 Checkpoints encontrados: ", checkpoints.size())
	
	for checkpoint in checkpoints:
		if checkpoint.has_method("get_checkpoint_id"):
			var checkpoint_id = checkpoint.get_checkpoint_id()
			if checkpoint_id == spawn_point_id:
				spawn_position = checkpoint.global_position
				found_spawn = true
				print("  ✅ ENCONTRADO en checkpoint: ", spawn_point_id)
				print("    Position: (", "%.1f" % spawn_position.x, ", ", "%.1f" % spawn_position.y, ")")
				break
	
	if not found_spawn:
		var spawn_points = get_tree().get_nodes_in_group("spawn_points")
		print("  🔍 SpawnPoints encontrados: ", spawn_points.size())
		
		for spawn in spawn_points:
			var spawn_sid = spawn.get("spawn_id") if spawn.has_method("get") else ""
			
			if spawn.name == spawn_point_id or spawn_sid == spawn_point_id:
				spawn_position = spawn.global_position
				found_spawn = true
				print("  ✅ ENCONTRADO SpawnPoint: ", spawn_point_id)
				print("    Position: (", "%.1f" % spawn_position.x, ", ", "%.1f" % spawn_position.y, ")")
				break
		
		if not found_spawn:
			print("  ⚠️  No se encontró '", spawn_point_id, "', buscando 'default'...")
			for spawn in spawn_points:
				var spawn_sid = spawn.get("spawn_id") if spawn.has_method("get") else ""
				
				if spawn.name == "default" or spawn_sid == "default":
					spawn_position = spawn.global_position
					found_spawn = true
					print("  ✅ ENCONTRADO default")
					print("    Position: (", "%.1f" % spawn_position.x, ", ", "%.1f" % spawn_position.y, ")")
					break
	
	if not found_spawn:
		print("  ❌ NO SE ENCONTRÓ NINGÚN SPAWN POINT")
		return
	
	if entry_direction != "":
		spawn_position += entry_spawn_offset
		print("  📏 Offset direccional aplicado: (", "%.1f" % entry_spawn_offset.x, ", ", "%.1f" % entry_spawn_offset.y, ")")
	
	if preserve_horizontal_position and saved_player_position != Vector2.ZERO:
		var old_x = spawn_position.x
		spawn_position.x = saved_player_position.x
		print("  ↔️  Posición X PRESERVADA: ", "%.1f" % old_x, " → ", "%.1f" % spawn_position.x)
	
	if preserve_vertical_position and saved_player_position != Vector2.ZERO:
		var old_y = spawn_position.y
		spawn_position.y = saved_player_position.y
		print("  ↕️  Posición Y PRESERVADA: ", "%.1f" % old_y, " → ", "%.1f" % spawn_position.y)
	
	print("\n  🎯 POSICIÓN FINAL: (", "%.1f" % spawn_position.x, ", ", "%.1f" % spawn_position.y, ")")
	print("📍 ═══════════════════════════════════════\n")
	
	clear_entry_direction()
	saved_player_position = Vector2.ZERO
	
	player.global_position = spawn_position
	
	_force_activate_camera_zones(player)

# ============================================
# FORZAR ACTIVACIÓN DE CAMERA ZONES
# ============================================

func _force_activate_camera_zones(player: Player) -> void:
	print("\n📷 ═══ FORZANDO ACTIVACIÓN DE CAMERA ZONES ═══")
	
	var camera = player.get_node_or_null("Camera2D") as CameraController
	if not camera:
		print("  ⚠️  Player sin Camera2D")
		return
	
	var player_pos = player.global_position
	print("  Player Position: (", "%.1f" % player_pos.x, ", ", "%.1f" % player_pos.y, ")")
	
	var camera_zones = get_tree().get_nodes_in_group("camera_zones")
	print("  CameraZones encontradas: ", camera_zones.size())
	
	var zone_activated = false
	
	for zone in camera_zones:
		if not zone is CameraZone:
			continue
		
		# USAR get_overlapping_bodies() EN LUGAR DE CALCULAR MANUALMENTE
		var bodies = zone.get_overlapping_bodies()
		var player_inside = false
		
		for body in bodies:
			if body == player:
				player_inside = true
				break
		
		print("  Verificando zona: ", zone.zone_name)
		print("    Player dentro: ", player_inside)
		
		if player_inside:
			print("  ✅ PLAYER DENTRO DE ZONA: ", zone.zone_name)
			print("    Aplicando límites:")
			print("      Left: ", zone.limit_left)
			print("      Top: ", zone.limit_top)
			print("      Right: ", zone.limit_right)
			print("      Bottom: ", zone.limit_bottom)
			
			camera.current_zone = zone
			camera.limit_left = zone.limit_left
			camera.limit_top = zone.limit_top
			camera.limit_right = zone.limit_right
			camera.limit_bottom = zone.limit_bottom
			camera.follow_vertical = zone.follow_vertical
			camera.vertical_offset = zone.vertical_offset
			camera.is_in_zone = true
			
			zone_activated = true
			break
	
	if not zone_activated:
		print("  ⚠️ Player NO está en ninguna CameraZone")
		print("  Aplicando cámara libre...")
		camera.limit_left = -10000000
		camera.limit_top = -10000000
		camera.limit_right = 10000000
		camera.limit_bottom = 10000000
		camera.is_in_zone = false
	
	print("📷 ═══════════════════════════════════════\n")

# ============================================
# RECARGAR ESCENA CON FADE
# ============================================

func reload_scene_with_fade(fade_out_time: float = 0.8, fade_in_time: float = 0.8) -> void:
	print("🎬 Recargando escena con transición...")
	
	await _fade_out(fade_out_time)
	
	var error = get_tree().reload_current_scene()
	
	if error != OK:
		push_error("❌ Error al recargar escena: ", error)
		return
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	_restore_player_data()
	_position_player_at_spawn()
	
	await _fade_in(fade_in_time)
	
	print("✅ Recarga con transición completada")

# ============================================
# FADE IN/OUT
# ============================================

func _create_fade_layer() -> void:
	fade_layer = CanvasLayer.new()
	fade_layer.name = "FadeLayer"
	fade_layer.layer = 100
	add_child(fade_layer)
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

func _fade_out(duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, duration)
	await tween.finished

func _fade_in(duration: float = 0.5) -> void:
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, duration)
	await tween.finished

# ============================================
# UTILIDADES
# ============================================

func get_current_scene_name() -> String:
	return current_scene_path.get_file().get_basename()

func is_in_scene(scene_name: String) -> bool:
	return get_current_scene_name() == scene_name

func clear_world_state() -> void:
	world_state = {
		"killed_enemies": [],
		"opened_chests": [],
		"collected_items": [],
		"unlocked_doors": [],
		"completed_events": []
	}
	print("🗑️ Estado del mundo limpiado")

# ============================================
# SISTEMA DE ENTRADA DIRECCIONAL CON PRESERVACIÓN
# ============================================

func set_entry_direction(direction: String, offset: Vector2, preserve_x: bool = false, preserve_y: bool = false) -> void:
	entry_direction = direction
	entry_spawn_offset = offset
	preserve_horizontal_position = preserve_x
	preserve_vertical_position = preserve_y
	
	print("\n📍 ═══ SCENEMANAGER: Entry Direction ═══")
	print("  Direction: ", direction)
	print("  Offset: (", "%.1f" % offset.x, ", ", "%.1f" % offset.y, ")")
	print("  Preserve X: ", preserve_x)
	print("  Preserve Y: ", preserve_y)

func set_player_transition_position(pos: Vector2) -> void:
	saved_player_position = pos
	print("\n💾 ═══ SCENEMANAGER: Posición Guardada ═══")
	print("  Position: (", "%.1f" % pos.x, ", ", "%.1f" % pos.y, ")")

func clear_entry_direction() -> void:
	entry_direction = ""
	entry_spawn_offset = Vector2.ZERO
	preserve_horizontal_position = false
	preserve_vertical_position = false

# ============================================
# RESETEAR COOLDOWNS DE TRANSICIONES
# ============================================

func reset_all_transition_cooldowns() -> void:
	print("\n🔄 ═══ RESETEANDO COOLDOWNS ═══")
	
	var transitions = get_tree().get_nodes_in_group("scene_transitions")
	print("  Transiciones encontradas: ", transitions.size())
	
	for transition in transitions:
		if transition.has_method("reset_cooldown"):
			transition.reset_cooldown()
	
	print("🔄 ═══════════════════════════════════════\n")
