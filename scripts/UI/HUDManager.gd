# res://scripts/managers/HUDManager.gd
extends Node

# ============================================
# HUD MANAGER - GESTIÓN CENTRALIZADA DE UIs
# ============================================

signal menu_opened(menu_name: String)
signal menu_closed(menu_name: String)

var active_menu: String = ""
var inventory_ui: InventoryUI = null
var shop_ui: ShopUI = null
var dialogue_ui: DialogueUI = null

func _ready() -> void:
	print("🔧 HUDManager inicializado")
	
	# 🔥 NO buscar UIs aquí - esperamos a que se conecten desde GameManager
	# Las UIs se conectarán cuando el jugador spawne
	
	# Conectar señal del SceneManager para re-buscar UIs al cambiar escena
	if SceneManager:
		if not SceneManager.scene_loading_finished.is_connected(_on_scene_loaded):
			SceneManager.scene_loading_finished.connect(_on_scene_loaded)
	
	print("✅ HUDManager LISTO")

# 🔥 NUEVA FUNCIÓN - Buscar UIs después de cargar escena
func _on_scene_loaded() -> void:
	print("🔍 Escena cargada, buscando UIs...")
	
	# Esperar 2 frames para asegurar que todo está instanciado
	await get_tree().process_frame
	await get_tree().process_frame
	
	_find_all_uis()

# 🔥 NUEVA FUNCIÓN - Conectar manualmente desde GameManager
func connect_uis() -> void:
	print("🔍 HUDManager.connect_uis() llamado")
	
	# Esperar a que el árbol esté completamente construido
	await get_tree().process_frame
	await get_tree().process_frame
	
	_find_all_uis()

func _find_all_uis() -> void:
	print("🔍 Buscando UIs en el árbol...")
	
	inventory_ui = _find_node("InventoryUI") as InventoryUI
	shop_ui = _find_node("ShopUI") as ShopUI
	dialogue_ui = _find_node("DialogueUI") as DialogueUI
	
	if inventory_ui:
		print("  ✅ InventoryUI encontrado")
	else:
		print("  ⚠️ InventoryUI NO encontrado")
	
	if shop_ui:
		print("  ✅ ShopUI encontrado")
	else:
		print("  ⚠️ ShopUI NO encontrado")
	
	if dialogue_ui:
		print("  ✅ DialogueUI encontrado")
	else:
		print("  ⚠️ DialogueUI NO encontrado")

func _find_node(node_name: String) -> Node:
	return _search_node(get_tree().root, node_name)

func _search_node(node: Node, node_name: String, max_depth: int = 10, current_depth: int = 0) -> Node:
	# 🔥 Limitar profundidad para evitar búsquedas infinitas
	if current_depth > max_depth:
		return null
	
	if node.name == node_name:
		print("    🎯 Encontrado: ", node_name, " en ", node.get_path())
		return node
	
	for child in node.get_children():
		var result = _search_node(child, node_name, max_depth, current_depth + 1)
		if result:
			return result
	
	return null

# ============================================
# 🔥 FUNCIÓN CRÍTICA - can_open_menu()
# ============================================

func can_open_menu(menu_name: String) -> bool:
	print("🔍 HUDManager.can_open_menu() - Menu solicitado: ", menu_name)
	print("  Active menu actual: ", active_menu)
	
	if active_menu.is_empty():
		print("  ✅ Sin menú activo - Permitir abrir")
		return true
	
	if active_menu == menu_name:
		print("  ✅ Mismo menú - Permitir toggle")
		return true
	
	print("  ❌ Otro menú activo - NO permitir")
	return false

func get_active_menu() -> String:
	return active_menu

# ============================================
# ABRIR MENÚS
# ============================================

func open_inventory() -> void:
	print("📦 HUDManager.open_inventory() llamado")
	
	if not can_open_menu("inventory"):
		print("❌ No se puede abrir inventario - ", active_menu, " está activo")
		return
	
	# 🔥 VERIFICAR QUE INVENTORY_UI EXISTE
	if not inventory_ui:
		print("⚠️ InventoryUI no encontrado, intentando buscar...")
		_find_all_uis()
	
	if inventory_ui:
		active_menu = "inventory"
		inventory_ui.open_inventory()
		menu_opened.emit("inventory")
		print("✅ Inventario abierto vía HUDManager")
	else:
		push_warning("❌ InventoryUI no encontrado en el árbol de escena")
		print("🔍 Árbol de escena actual:")
		_print_scene_tree(get_tree().root, 0, 5)

func open_shop() -> void:
	print("🪙 HUDManager.open_shop() llamado")
	
	if not can_open_menu("shop"):
		print("❌ No se puede abrir tienda - ", active_menu, " está activo")
		return
	
	active_menu = "shop"
	menu_opened.emit("shop")
	print("✅ Tienda marcada como activa")

func open_dialogue() -> void:
	print("💬 HUDManager.open_dialogue() llamado")
	
	if not can_open_menu("dialogue"):
		print("❌ No se puede abrir diálogo - ", active_menu, " está activo")
		return
	
	active_menu = "dialogue"
	menu_opened.emit("dialogue")
	print("✅ Diálogo marcado como activo")

# ============================================
# CERRAR MENÚS
# ============================================

func close_inventory() -> void:
	print("📦 HUDManager.close_inventory() llamado")
	
	if active_menu == "inventory":
		active_menu = ""
		
		if inventory_ui:
			inventory_ui.close_inventory()
		
		menu_closed.emit("inventory")
		print("✅ Inventario cerrado")

func close_shop() -> void:
	print("🪙 HUDManager.close_shop() llamado")
	
	if active_menu == "shop":
		active_menu = ""
		
		if shop_ui:
			shop_ui.close_shop()
		
		menu_closed.emit("shop")
		print("✅ Tienda cerrada")

func close_dialogue() -> void:
	print("💬 HUDManager.close_dialogue() llamado")
	
	if active_menu == "dialogue":
		active_menu = ""
		menu_closed.emit("dialogue")
		print("✅ Diálogo cerrado")

func close_all() -> void:
	if active_menu.is_empty():
		return
	
	print("🚪 Cerrando todos los menús...")
	
	if active_menu == "inventory":
		close_inventory()
	elif active_menu == "shop":
		close_shop()
	elif active_menu == "dialogue":
		close_dialogue()

# ============================================
# 🔥 NUEVA FUNCIÓN - DEBUG: Imprimir árbol
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
