# res://scripts/ui/InventoryUI.gd
extends Control
class_name InventoryUI

# ⚠️ YA NO USAR @export var inventory_component_path
# Ahora se conecta dinámicamente desde GameManager

var inventory: InventoryComponent
var weapon_system: WeaponSystem
var current_player: Player

# Referencias UI
@onready var wallet_label: Label = get_node_or_null("MarginContainer/VBoxContainer/Header/WalletLabel")
@onready var items_panel: PanelContainer = get_node_or_null("MarginContainer/VBoxContainer/Content/ItemsPanel")
@onready var weapons_panel: PanelContainer = get_node_or_null("MarginContainer/VBoxContainer/Content/WeaponsPanel")
@onready var items_list: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/Content/ItemsPanel/ScrollContainer/ItemsList")
@onready var weapons_list: VBoxContainer = get_node_or_null("MarginContainer/VBoxContainer/Content/WeaponsPanel/ScrollContainer/WeaponsList")
@onready var selected_fragment_label: Label = get_node_or_null("MarginContainer/VBoxContainer/Footer/SelectedFragmentLabel")
@onready var controls_hint: Label = get_node_or_null("MarginContainer/VBoxContainer/Footer/ControlsHint")

var fragment_slots: Array[Control] = []
var weapon_slots: Array[Control] = []

func _ready() -> void:
	visible = false
	
	# 🎯 CONECTAR A EVENTBUS PARA NOTIFICACIONES
	EventBus.item_collected.connect(_on_item_collected_event)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	
	print("🎒 InventoryUI inicializado")

# ============================================
# 🆕 NUEVA FUNCIÓN - CONECTAR CON JUGADOR
# ============================================

func connect_to_player(player: Player) -> void:
	if not player:
		push_error("❌ Player es null")
		return
	
	current_player = player
	
	# Obtener componentes del jugador
	inventory = player.get_node_or_null("InventoryComponent") as InventoryComponent
	weapon_system = player.get_node_or_null("WeaponSystem") as WeaponSystem
	
	if not inventory:
		push_error("❌ Player no tiene InventoryComponent")
		return
	
	# Conectar señales
	if not inventory.inventory_changed.is_connected(_on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)
	
	if inventory.has_signal("selected_fragment_changed"):
		if not inventory.selected_fragment_changed.is_connected(_on_selected_fragment_changed):
			inventory.selected_fragment_changed.connect(_on_selected_fragment_changed)
	
	# Conectar WeaponSystem
	if weapon_system:
		if not weapon_system.weapon_equipped.is_connected(_on_weapon_equipped):
			weapon_system.weapon_equipped.connect(_on_weapon_equipped)
		if not weapon_system.weapon_unlocked.is_connected(_on_weapon_unlocked):
			weapon_system.weapon_unlocked.connect(_on_weapon_unlocked)
	
	# Conectar Wallet
	var wallet = player.get_node_or_null("Wallet") as Wallet
	if wallet:
		if not wallet.currency_changed.is_connected(_on_currency_changed):
			wallet.currency_changed.connect(_on_currency_changed)
		_update_wallet_display(wallet)
	
	print("✅ InventoryUI conectado al jugador")

func _input(event: InputEvent) -> void:
	# Solo procesar si tenemos jugador conectado
	if not current_player or not inventory:
		return
	
	# Abrir inventario
	if not visible:
		if event.is_action_pressed("toggle_inventory"):
			if HUDManager.can_open_menu("inventory"):
				HUDManager.open_inventory()
			else:
				print("❌ No se puede abrir inventario - Hay otro menú activo")
			get_viewport().set_input_as_handled()
		return
	
	# Cerrar o interactuar
	if event.is_action_pressed("toggle_inventory"):
		HUDManager.close_inventory()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_select_next_fragment(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_up"):
		_select_next_fragment(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept") or event.is_action_pressed("use_heal"):
		_use_selected_fragment()
		get_viewport().set_input_as_handled()

func open_inventory() -> void:
	if not current_player or not inventory:
		print("⚠️ No hay jugador conectado")
		return
	
	visible = true
	modulate.a = 0
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	
	_refresh_ui()
	_update_wallet_from_player()
	
	print("🎒 InventoryUI abierto")

func close_inventory() -> void:
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	await tween.finished
	
	visible = false
	print("🎒 Inventario cerrado")

# ============================================
# ACTUALIZACIÓN DE UI
# ============================================

func _refresh_ui() -> void:
	_refresh_items()
	_refresh_weapons()
	_update_selected_fragment_display()
	_update_controls_hint()

func _refresh_items() -> void:
	if not inventory or not items_list:
		return
	
	# Limpiar lista
	for child in items_list.get_children():
		child.queue_free()
	
	fragment_slots.clear()
	
	var items = inventory.get_all_items()
	
	if items.is_empty():
		var empty_label = Label.new()
		empty_label.text = "(Sin items)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		items_list.add_child(empty_label)
		return
	
	# Separar fragmentos y otros items
	var fragments = []
	var other_items = []
	
	for item_data in items:
		var item = item_data["item"]
		if item is SoulFragment:
			fragments.append(item_data)
		else:
			other_items.append(item_data)
	
	# Mostrar fragmentos
	if not fragments.is_empty():
		var header = _create_section_header("💎 FRAGMENTOS DE ALMA")
		items_list.add_child(header)
		
		for item_data in fragments:
			var item = item_data["item"]
			var quantity = item_data["quantity"]
			var slot = _create_fragment_slot(item, quantity)
			items_list.add_child(slot)
			fragment_slots.append(slot)
	
	# Mostrar otros items
	if not other_items.is_empty():
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(0, 15)
		items_list.add_child(spacer)
		
		var header = _create_section_header("📦 OTROS ITEMS")
		items_list.add_child(header)
		
		for item_data in other_items:
			var item = item_data["item"]
			var quantity = item_data["quantity"]
			var slot = _create_item_slot(item, quantity)
			items_list.add_child(slot)
	
	_update_selection_highlight()

func _refresh_weapons() -> void:
	if not weapon_system or not weapons_list:
		return
	
	# Limpiar lista
	for child in weapons_list.get_children():
		child.queue_free()
	
	weapon_slots.clear()
	
	var weapons = weapon_system.available_weapons
	
	if weapons.is_empty():
		var empty_label = Label.new()
		empty_label.text = "(Sin armas desbloqueadas)"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		weapons_list.add_child(empty_label)
		return
	
	# Header
	var header = _create_section_header("🗡️ ARMAS DESBLOQUEADAS")
	weapons_list.add_child(header)
	
	# Listar armas
	for weapon in weapons:
		var slot = _create_weapon_slot(weapon)
		weapons_list.add_child(slot)
		weapon_slots.append(slot)

# ============================================
# [EL RESTO DE FUNCIONES SE MANTIENEN IGUAL]
# Solo copio las esenciales modificadas:
# ============================================

func _update_wallet_display(wallet: Wallet) -> void:
	if not wallet or not wallet_label:
		return
	
	var amount = wallet.get_asteriones()
	wallet_label.text = "💰 %d Asteriones" % amount

func _update_wallet_from_player() -> void:
	if not current_player:
		return
	
	var wallet = current_player.get_node_or_null("Wallet") as Wallet
	if wallet:
		_update_wallet_display(wallet)

func _on_inventory_changed() -> void:
	_refresh_items()

# 🎯 LISTENER DE EVENTBUS
@warning_ignore("unused_parameter")
func _on_item_collected_event(item: Item, collector: Node) -> void:
	# Solo procesar si el collector es el player actual
	if collector != current_player:
		return
	
	# Aquí se puede agregar notificación visual en el futuro
	# Por ahora solo refrescar UI si está visible
	if visible:
		_refresh_items()

func _on_selected_fragment_changed(_fragment: SoulFragment) -> void:
	_update_selection_highlight()
	_update_selected_fragment_display()

func _on_currency_changed(_new_amount: int) -> void:
	_update_wallet_from_player()

func _on_weapon_equipped(_weapon: WeaponData) -> void:
	_refresh_weapons()

func _on_weapon_unlocked(_weapon: WeaponData) -> void:
	_refresh_weapons()

func _select_next_fragment(direction: int) -> void:
	if inventory:
		inventory.cycle_fragment_selection(direction)

func _use_selected_fragment() -> void:
	if inventory:
		if inventory.use_selected_fragment():
			HUDManager.close_inventory()

# ============================================
# FUNCIONES AUXILIARES (mantener las mismas)
# ============================================

func _create_section_header(title: String) -> Label:
	var header = Label.new()
	header.text = title
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	return header

func _create_fragment_slot(fragment: SoulFragment, quantity: int) -> PanelContainer:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(0, 50)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = fragment.get_rarity_color() * 0.5
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	slot.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	slot.add_child(hbox)
	
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.color = fragment.get_rarity_color()
	hbox.add_child(icon)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = fragment.name
	name_label.add_theme_color_override("font_color", fragment.get_rarity_color())
	name_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(name_label)
	
	var info_label = Label.new()
	info_label.text = "⚔️ %d golpes → %d HP" % [fragment.hits_required, fragment.hits_required]
	info_label.add_theme_font_size_override("font_size", 11)
	info_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(info_label)
	
	var quantity_label = Label.new()
	quantity_label.text = "x%d" % quantity
	quantity_label.add_theme_font_size_override("font_size", 16)
	quantity_label.add_theme_color_override("font_color", Color(1, 1, 1))
	hbox.add_child(quantity_label)
	
	return slot

func _create_item_slot(item: Item, quantity: int) -> HBoxContainer:
	var slot = HBoxContainer.new()
	slot.add_theme_constant_override("separation", 10)
	
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(32, 32)
	icon.color = item.get_rarity_color()
	slot.add_child(icon)
	
	var label = Label.new()
	label.text = "%s x%d" % [item.name, quantity]
	label.add_theme_color_override("font_color", item.get_rarity_color())
	slot.add_child(label)
	
	return slot

func _create_weapon_slot(weapon: WeaponData) -> PanelContainer:
	var slot = PanelContainer.new()
	slot.custom_minimum_size = Vector2(0, 80)
	
	var style = StyleBoxFlat.new()
	var is_equipped = weapon_system.current_weapon == weapon
	
	if is_equipped:
		style.bg_color = Color(0.2, 0.3, 0.2, 0.9)
		style.border_color = Color(0.3, 1, 0.3)
	else:
		style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
		style.border_color = Color(0.3, 0.3, 0.4)
	
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	slot.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	slot.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	margin.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = weapon.weapon_name + (" ⭐" if is_equipped else "")
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.5) if is_equipped else Color(1, 1, 1))
	vbox.add_child(name_label)
	
	var desc_label = Label.new()
	desc_label.text = weapon.description
	desc_label.add_theme_font_size_override("font_size", 10)
	desc_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)
	
	var stats_label = Label.new()
	var stats_text = "💥 Daño: %d" % int(weapon.base_damage)
	
	if weapon.has_projectile:
		stats_text += " | 🔫 Ranged"
		if weapon.burst_count > 1:
			stats_text += " (x%d)" % weapon.burst_count
	else:
		stats_text += " | ⚔️ Melee"
	
	if weapon.crit_chance_bonus > 0:
		stats_text += " | 🎯 +%d%% Crit" % int(weapon.crit_chance_bonus * 100)
	
	if weapon.has_dot:
		stats_text += " | 🔥 DOT"
	
	stats_label.text = stats_text
	stats_label.add_theme_font_size_override("font_size", 11)
	stats_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
	vbox.add_child(stats_label)
	
	return slot

func _update_selected_fragment_display() -> void:
	if not inventory or not selected_fragment_label:
		return
	
	var fragment = inventory.get_selected_fragment()
	
	if fragment:
		var quantity = inventory.get_item_quantity(fragment.id)
		selected_fragment_label.text = "▶ EQUIPADO: %s x%d" % [fragment.name, quantity]
		selected_fragment_label.add_theme_color_override("font_color", fragment.get_rarity_color())
	else:
		selected_fragment_label.text = "▶ EQUIPADO: (ninguno)"
		selected_fragment_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))

func _update_controls_hint() -> void:
	if not controls_hint:
		return
	
	controls_hint.text = "[↑/↓: Cambiar fragmento] [Z: Usar] [I: Cerrar]"
	controls_hint.add_theme_font_size_override("font_size", 11)
	controls_hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	controls_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _update_selection_highlight() -> void:
	if not inventory or fragment_slots.is_empty():
		return
	
	var selected_index = inventory.selected_fragment_index
	
	for i in range(fragment_slots.size()):
		var slot = fragment_slots[i] as PanelContainer
		if not slot:
			continue
		
		var style = slot.get_theme_stylebox("panel") as StyleBoxFlat
		if not style:
			continue
		
		slot.modulate = Color(1, 1, 1)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
		
		var item_data = inventory.get_all_items()[i] if i < inventory.get_all_items().size() else null
		if item_data and item_data["item"] is SoulFragment:
			var fragment = item_data["item"] as SoulFragment
			style.border_color = fragment.get_rarity_color() * 0.5
	
	if selected_index >= 0 and selected_index < fragment_slots.size():
		var selected_slot = fragment_slots[selected_index] as PanelContainer
		if selected_slot:
			var style = selected_slot.get_theme_stylebox("panel") as StyleBoxFlat
			if style:
				selected_slot.modulate = Color(1.2, 1.2, 1)
				style.border_width_left = 4
				style.border_width_right = 4
				style.border_width_top = 4
				style.border_width_bottom = 4
				style.border_color = Color(1, 1, 0)
