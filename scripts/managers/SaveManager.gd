# res://scripts/managers/SaveManager.gd
# ⚠️ ESTE SCRIPT DEBE IR EN AUTOLOAD
# Proyecto → Configuración → Autoload → Añadir como "SaveManager"

extends Node

const SAVE_PATH: String = "user://save_game.dat"

signal game_saved
signal game_loaded

# Estructura del archivo de guardado
var save_data: Dictionary = {
	"player": {},
	"world": {},
	"meta": {}
}

func _ready() -> void:
	print("💾 SaveManager inicializado")

# ============================================
# GUARDAR PARTIDA
# ============================================

func save_game() -> bool:
	print("💾 Guardando partida...")
	
	# 1. Obtener datos del jugador
	var player = get_tree().get_first_node_in_group("Player") as Player
	if player:
		save_data["player"] = _serialize_player(player)
	
	# 2. Obtener datos del mundo (escena actual, enemigos muertos, items recogidos)
	save_data["world"] = _serialize_world()
	
	# 3. Metadata (fecha, versión, tiempo de juego)
	save_data["meta"] = {
		"timestamp": Time.get_datetime_string_from_system(),
		"version": "0.1.0",
		"playtime": 0.0,  # TODO: Implementar contador de tiempo
		"scene": SceneManager.current_scene_path,
		"checkpoint_id": SceneManager.last_checkpoint_id,
		"checkpoint_scene": SceneManager.last_checkpoint_scene
	}
	
	# 4. Escribir archivo
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("❌ No se pudo abrir archivo de guardado")
		return false
	
	# Convertir a JSON y guardar
	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()
	
	print("✅ Partida guardada en: ", SAVE_PATH)
	game_saved.emit()
	return true

# ============================================
# CARGAR PARTIDA
# ============================================

func load_game() -> bool:
	print("📂 Cargando partida...")
	
	if not FileAccess.file_exists(SAVE_PATH):
		print("⚠️ No hay archivo de guardado")
		return false
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("❌ No se pudo abrir archivo de guardado")
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		push_error("❌ Error al parsear JSON: ", json.get_error_message())
		return false
	
	save_data = json.get_data()
	
	# 🆕 Cargar checkpoint guardado
	var checkpoint_scene = save_data["meta"].get("checkpoint_scene", "")
	var checkpoint_id = save_data["meta"].get("checkpoint_id", "default")
	
	# Si no hay checkpoint, usar escena guardada
	if checkpoint_scene.is_empty():
		checkpoint_scene = save_data["meta"].get("scene", "res://assets/scenas/levels/level_01.tscn")
	
	# 🆕 Restaurar estado del checkpoint en SceneManager
	if SceneManager:
		SceneManager.last_checkpoint_scene = checkpoint_scene
		SceneManager.last_checkpoint_id = checkpoint_id
	
	# Cambiar a la escena del checkpoint
	SceneManager.player_data = save_data["player"]  # Pre-cargar datos
	SceneManager.change_scene(checkpoint_scene, checkpoint_id)
	
	print("✅ Partida cargada exitosamente")
	print("  - Checkpoint: ", checkpoint_id)
	print("  - Escena: ", checkpoint_scene)
	game_loaded.emit()
	return true

# ============================================
# SERIALIZACIÓN DE DATOS
# ============================================

func _serialize_player(player: Player) -> Dictionary:
	var data = {
		"health": player.health,
		"max_health": player.max_health,
		"position": {
			"x": player.global_position.x,
			"y": player.global_position.y
		},
		"last_checkpoint": SceneManager.last_checkpoint_id,
		"last_checkpoint_scene": SceneManager.last_checkpoint_scene,
		"inventory": {},
		"wallet": {},
		"abilities": [],
		"weapons": []
	}
	
	# Inventario
	if player.inventory:
		data["inventory"] = player.inventory.serialize() if player.inventory.has_method("serialize") else {}
	
	# Billetera
	var wallet = player.get_node_or_null("Wallet") as Wallet
	if wallet:
		data["wallet"] = wallet.serialize()
	
	# Habilidades
	var ability_system = player.get_node_or_null("AbilitySystem") as AbilitySystem
	if ability_system:
		data["abilities"] = ability_system.unlocked_abilities.keys()
	
	# Armas
	if player.weapon_system:
		data["weapons"] = player.weapon_system.serialize()
	
	return data

func _serialize_world() -> Dictionary:
	var data = {
		"enemies_killed": [],  # IDs de enemigos que no deben respawnear
		"items_collected": [], # IDs de items que ya no deben aparecer
		"doors_unlocked": [],  # IDs de puertas desbloqueadas
		"npcs_talked": [],     # NPCs con los que ya hablaste
		"checkpoints": []      # Checkpoints activados
	}
	
	# 🆕 Guardar estado del mundo desde SceneManager
	if SceneManager:
		data["enemies_killed"] = SceneManager.world_state["killed_enemies"].duplicate()
		data["items_collected"] = SceneManager.world_state["collected_items"].duplicate()
		data["doors_unlocked"] = SceneManager.world_state["unlocked_doors"].duplicate()
	
	return data

# ============================================
# UTILIDADES
# ============================================

func has_save_file() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		print("🗑️ Archivo de guardado eliminado")

func get_save_info() -> Dictionary:
	if not has_save_file():
		return {}
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return {}
	
	var data = json.get_data()
	return data.get("meta", {})

# ============================================
# AUTOGUARDADO
# ============================================

func autosave() -> void:
	print("💾 Autoguardado...")
	save_game()
