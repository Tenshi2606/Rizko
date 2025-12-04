# res://scripts/core/GameManager.gd
# ⚠️ AUTOLOAD - Nombre: "GameManager"

extends Node

signal player_spawned(player: Player)

var current_player: Player = null
var persistent_ui_layer: CanvasLayer = null

# Referencias directas a UIs (se cachean una vez)
var _inventory_ui: InventoryUI = null
var _currency_hud: CurrencyHUD = null
var _weapon_hud: WeaponHUD = null
var _heal_cooldown_hud: HealCooldownHUD = null
var _death_screen: DeathScreen = null  # 🆕 Death Screen

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("🎮 GameManager inicializado")
	
	# Crear capa de UI persistente (vacía por ahora)
	persistent_ui_layer = CanvasLayer.new()
	persistent_ui_layer.name = "PersistentUILayer"
	persistent_ui_layer.layer = 100  # Encima de todo
	add_child(persistent_ui_layer)
	
	print("✅ Capa de UI persistente creada")

# ============================================
# REGISTRAR JUGADOR
# ============================================

func register_player(player: Player) -> void:
	if current_player == player:
		return
	
	current_player = player
	print("🎮 Jugador registrado: ", player.name)
	
	# 🔥 CONECTAR UIs DESPUÉS DE QUE EL JUGADOR ESTÉ LISTO
	call_deferred("_connect_player_to_uis")
	
	# 🔥 TAMBIÉN CONECTAR HUDManager
	call_deferred("_connect_hudmanager")
	
	player_spawned.emit(player)

# ============================================
# 🔥 NUEVA FUNCIÓN - Conectar HUDManager
# ============================================

func _connect_hudmanager() -> void:
	if HUDManager:
		print("🔗 GameManager → Conectando HUDManager...")
		HUDManager.connect_uis()
	else:
		push_error("❌ HUDManager no encontrado (¿olvidaste agregarlo como Autoload?)")

# ============================================
# CONECTAR JUGADOR CON UIs (DEFERRED)
# ============================================

func _connect_player_to_uis() -> void:
	if not current_player:
		return
	
	print("🔗 Conectando jugador con UIs...")
	
	# Solo buscar UIs una vez (no en cada frame)
	if not _inventory_ui:
		_inventory_ui = _find_ui_in_tree("InventoryUI")
	
	if not _currency_hud:
		_currency_hud = _find_ui_in_tree("CurrencyHUD")
	
	if not _weapon_hud:
		_weapon_hud = _find_ui_in_tree("WeaponHUD")
	
	if not _heal_cooldown_hud:
		_heal_cooldown_hud = _find_ui_in_tree("HealCooldownHUD")
	
	# 🆕 BUSCAR DEATH SCREEN
	if not _death_screen:
		_death_screen = _find_ui_in_tree("DeathScreen")
	
	# Conectar cada UI si existe
	if _inventory_ui and _inventory_ui.has_method("connect_to_player"):
		_inventory_ui.connect_to_player(current_player)
		print("  ✅ InventoryUI conectado")
	
	if _currency_hud and _currency_hud.has_method("connect_to_player"):
		_currency_hud.connect_to_player(current_player)
		print("  ✅ CurrencyHUD conectado")
	
	if _weapon_hud and _weapon_hud.has_method("connect_to_player"):
		_weapon_hud.connect_to_player(current_player)
		print("  ✅ WeaponHUD conectado")
	
	if _heal_cooldown_hud and _heal_cooldown_hud.has_method("connect_to_player"):
		_heal_cooldown_hud.connect_to_player(current_player)
		print("  ✅ HealCooldownHUD conectado")
	
	# 🆕 VERIFICAR DEATH SCREEN
	if _death_screen:
		print("  ✅ DeathScreen encontrado")
	else:
		push_warning("  ⚠️ DeathScreen NO encontrado")

# ============================================
# BUSCAR UI EN EL ÁRBOL (UNA SOLA VEZ)
# ============================================

func _find_ui_in_tree(ui_name: String) -> Node:
	# Buscar en persistent_ui_layer primero
	if persistent_ui_layer:
		var ui = persistent_ui_layer.get_node_or_null(ui_name)
		if ui:
			return ui
	
	# Buscar en el árbol principal
	var root = get_tree().root
	return _search_node_recursive(root, ui_name)

func _search_node_recursive(node: Node, target_name: String, max_depth: int = 10, current_depth: int = 0) -> Node:
	# Limitar profundidad para evitar lag
	if current_depth > max_depth:
		return null
	
	if node.name == target_name:
		return node
	
	for child in node.get_children():
		var result = _search_node_recursive(child, target_name, max_depth, current_depth + 1)
		if result:
			return result
	
	return null

# ============================================
# 🆕 MOSTRAR PANTALLA DE MUERTE
# ============================================

func show_death_screen(checkpoint_id: String = "default") -> void:
	print("💀 GameManager.show_death_screen() llamado")
	print("  - Checkpoint: ", checkpoint_id)
	
	# Buscar DeathScreen si no lo tenemos
	if not _death_screen:
		print("  🔍 Buscando DeathScreen...")
		_death_screen = _find_ui_in_tree("DeathScreen")
	
	if not _death_screen:
		push_error("❌ DeathScreen NO encontrado en el árbol de escena")
		print("🔍 Árbol de escena actual:")
		_print_scene_tree(get_tree().root, 0, 5)
		return
	
	# Mostrar pantalla de muerte
	if _death_screen.has_method("show_death_screen"):
		_death_screen.show_death_screen(checkpoint_id)
		print("✅ DeathScreen mostrado")
	else:
		push_error("❌ DeathScreen no tiene método 'show_death_screen()'")

# ============================================
# 🆕 DEBUG: Imprimir árbol de escena
# ============================================

func _print_scene_tree(node: Node, indent: int = 0, max_depth: int = 5) -> void:
	if indent > max_depth:
		return
	
	var indent_str = ""
	for i in range(indent):
		indent_str += "  "
	
	print(indent_str, "└─ ", node.name, " (", node.get_class(), ")")
	
	for child in node.get_children():
		_print_scene_tree(child, indent + 1, max_depth)

# ============================================
# ACCESO PÚBLICO
# ============================================

func get_player() -> Player:
	return current_player

func get_inventory_ui() -> InventoryUI:
	return _inventory_ui

func get_currency_hud() -> CurrencyHUD:
	return _currency_hud

func get_weapon_hud() -> WeaponHUD:
	return _weapon_hud

func get_death_screen() -> DeathScreen:
	return _death_screen

# ============================================
# GESTIÓN DE JUEGO
# ============================================

func start_new_game() -> void:
	print("🆕 Iniciando nueva partida...")
	
	if SaveManager:
		SaveManager.delete_save()
	
	var first_level = "res://assets/scenas/Principal/Escenaprincipal.tscn"
	SceneManager.change_scene(first_level, "default")

func continue_game() -> bool:
	print("📂 Continuando partida...")
	
	if SaveManager and SaveManager.load_game():
		return true
	
	return false
